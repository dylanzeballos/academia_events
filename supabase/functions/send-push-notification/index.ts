import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create } from "https://deno.land/x/djwt@v2.8/mod.ts";

const ANDROID_CHANNEL_ID = "academia_notifications";

type NotificationRecord = {
  id?: string | number;
  user_id?: string;
  title?: string;
  message?: string;
  type?: string | null;
  data?: Record<string, unknown> | null;
};

type FcmToken = {
  id: string;
  fcm_token: string;
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function getGoogleAccessToken(
  serviceAccount: { client_email: string; private_key: string },
): Promise<string> {
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 3600;

  const pem = serviceAccount.private_key
    .replace(/\\n/g, "\n")
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binaryDerString = atob(pem);
  const binaryDer = new Uint8Array(binaryDerString.length);
  for (let i = 0; i < binaryDerString.length; i++) {
    binaryDer[i] = binaryDerString.charCodeAt(i);
  }

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp,
      iat,
    },
    key,
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    throw new Error(`Google OAuth respondió ${res.status}`);
  }

  const data = await res.json();
  if (!data.access_token) {
    throw new Error("Google OAuth no devolvió access_token");
  }
  return data.access_token;
}

function toFcmData(notification: NotificationRecord): Record<string, string> {
  const data: Record<string, string> = {
    notification_id: String(notification.id ?? ""),
    type: String(notification.type ?? ""),
  };

  for (const [key, value] of Object.entries(notification.data ?? {})) {
    if (key === "notification_id" || key === "type") continue;
    data[key] = typeof value === "string" ? value : JSON.stringify(value);
  }

  return data;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // El webhook de base de datos envía este header. Sin él, cualquiera con la
  // URL pública podría mandar push arbitrarios a cualquier usuario.
  const expectedSecret = Deno.env.get("PUSH_WEBHOOK_SECRET");
  if (expectedSecret && req.headers.get("x-push-secret") !== expectedSecret) {
    return json({ error: "Unauthorized" }, 401);
  }

  try {
    const payload = await req.json();
    const notification: NotificationRecord = payload?.record ?? payload;

    if (!notification?.user_id) {
      return json({ error: "No notification record provided" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SECRET_KEY");
    if (!supabaseUrl || !serviceKey) {
      throw new Error("Faltan credenciales de Supabase en la función");
    }

    // Service role: puede leer los tokens de cualquier usuario sin depender de RLS.
    const supabase = createClient(supabaseUrl, serviceKey);

    const { data: tokens, error: tokenError } = await supabase
      .from("user_fcm_tokens")
      .select("id, fcm_token")
      .eq("user_id", notification.user_id);

    if (tokenError) {
      throw new Error(`No se pudieron leer los tokens: ${tokenError.message}`);
    }

    if (!tokens || tokens.length === 0) {
      return json({ status: "skipped", reason: "user_without_tokens" });
    }

    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      throw new Error("Variable FIREBASE_SERVICE_ACCOUNT no configurada");
    }

    const serviceAccount = JSON.parse(serviceAccountJson);
    if (!serviceAccount.project_id || !serviceAccount.client_email ||
      !serviceAccount.private_key) {
      throw new Error("FIREBASE_SERVICE_ACCOUNT incompleto");
    }

    const accessToken = await getGoogleAccessToken(serviceAccount);
    const fcmUrl =
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

    const title = notification.title?.trim() || "Academia Events";
    const bodyText = notification.message?.trim() || "";
    const data = toFcmData(notification);

    const results = await Promise.all(
      (tokens as FcmToken[]).map(async (token) => {
        const message = {
          token: token.fcm_token,
          notification: { title, body: bodyText },
          data,
          android: {
            priority: "HIGH",
            notification: {
              channel_id: ANDROID_CHANNEL_ID,
              sound: "default",
            },
          },
          apns: {
            headers: { "apns-priority": "10" },
            payload: {
              aps: {
                sound: "default",
                "interruption-level": "active",
              },
            },
          },
        };

        const res = await fetch(fcmUrl, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ message }),
        });

        if (res.ok) {
          return { ok: true, tokenId: token.id };
        }

        let errorBody: Record<string, any> | null = null;
        try {
          errorBody = await res.json();
        } catch {
          // FCM no siempre devuelve JSON en errores de infraestructura.
        }

        const detail = errorBody?.error?.details?.[0];
        const errorCode = String(detail?.errorCode ?? errorBody?.error?.status ?? "");
        const errorMessage = String(errorBody?.error?.message ?? "");
        const isInvalidToken = res.status === 404 ||
          errorCode === "UNREGISTERED" ||
          errorCode === "INVALID_ARGUMENT" ||
          /not a valid fcm registration token|no longer valid|unregistered/i
            .test(errorMessage);

        // Token viejo o desinstalado: se elimina para no volver a intentarlo.
        if (isInvalidToken) {
          await supabase.from("user_fcm_tokens").delete().eq("id", token.id);
        }

        console.error("FCM error", {
          tokenId: token.id,
          status: res.status,
          errorCode,
          errorMessage,
          removed: isInvalidToken,
        });

        return {
          ok: false,
          tokenId: token.id,
          status: res.status,
          errorCode,
          removed: isInvalidToken,
        };
      }),
    );

    const sent = results.filter((result) => result.ok).length;
    const removed = results.filter((result) => !result.ok && result.removed)
      .length;

    return json({
      status: sent > 0 ? "success" : "failed",
      count: tokens.length,
      sent,
      failed: tokens.length - sent,
      removed,
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("send-push-notification error", message);
    return json({ error: message }, 500);
  }
});
