// pagosya-reconcile
// Invocada por pg_cron (o manualmente). Revisa cobros pendientes, confirma
// pagos si el webhook no llegó y libera stock de órdenes abandonadas.
import {
  adminClient,
  json,
  pagosya,
  PagosyaError,
} from "../_shared/pagosya.ts";

const LOOKBACK_MINUTES = 2;
const EXPIRE_MINUTES = 30;
const MAX_ITEMS = 50;

async function sha256(value: string): Promise<Uint8Array> {
  return new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
  );
}

async function secretMatches(header: string | null, expected: string): Promise<boolean> {
  if (!header) return false;
  const [a, b] = await Promise.all([sha256(header), sha256(expected)]);
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return json(req, { ok: true });
  if (req.method !== "POST") return json(req, { error: "METHOD_NOT_ALLOWED" }, 405);

  const expected = Deno.env.get("PAGOSYA_CRON_SECRET");
  if (!expected) return json(req, { error: "CRON_NOT_CONFIGURED" }, 500);

  const provided =
    req.headers.get("x-cron-secret") ??
    (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");

  if (!(await secretMatches(provided, expected))) {
    return json(req, { error: "UNAUTHORIZED" }, 401);
  }

  const admin = adminClient();
  const since = new Date(Date.now() - LOOKBACK_MINUTES * 60_000).toISOString();

  // 1) liberar stock de compras abandonadas
  const { data: expired } = await admin.rpc("pagosya_expire_stale_payments", {
    p_minutes: EXPIRE_MINUTES,
  });

  // 2) intents: pases de clase y membresías
  const { data: intents } = await admin
    .from("payment_intents")
    .select("id, kind, reference_id, amount, currency, affiliate_id, pagosya_checkout_id")
    .eq("status", "pending")
    .not("pagosya_checkout_id", "is", null)
    .lt("created_at", since)
    .limit(MAX_ITEMS);

  const intentResults: Array<Record<string, unknown>> = [];

  for (const intent of intents ?? []) {
    try {
      const status = await pagosya("get_checkout_status", {
        affiliate_id: intent.affiliate_id,
        checkout_id: intent.pagosya_checkout_id,
      });
      const providerStatus = String(status.status ?? status.checkout?.status ?? "");

      if (providerStatus === "completed" || providerStatus === "paid") {
        const { error } = await admin.rpc("pagosya_ingest_event", {
          p_event: {
            id: `reconcile:${intent.pagosya_checkout_id}`,
            event: "checkout.completed",
            affiliate_id: intent.affiliate_id,
            external_id: intent.reference_id,
            data: {
              checkout_id: intent.pagosya_checkout_id,
              payment_id: status.payment_id ?? status.id ?? null,
              amount: Number(intent.amount),
              currency: intent.currency,
            },
          },
        });
        intentResults.push({
          intent_id: intent.id,
          kind: intent.kind,
          paid: !error,
          error: error?.message ?? null,
        });
      } else {
        intentResults.push({
          intent_id: intent.id,
          kind: intent.kind,
          provider_status: providerStatus || null,
        });
      }
    } catch (err) {
      intentResults.push({
        intent_id: intent.id,
        error: err instanceof PagosyaError ? err.code : "UNKNOWN",
      });
    }
  }

  // 3) órdenes de tickets
  const { data: orders, error } = await admin
    .from("orders")
    .select(
      "id, total_amount, currency, pagosya_checkout_id, " +
        "events!inner(organization_id)",
    )
    .eq("status", "pending")
    .not("pagosya_checkout_id", "is", null)
    .lt("created_at", since)
    .order("created_at", { ascending: true })
    .limit(MAX_ITEMS);

  if (error) return json(req, { error: "QUERY_FAILED" }, 500);

  const orderResults: Array<Record<string, unknown>> = [];

  for (const order of orders ?? []) {
    const organizationId = (order as any).events.organization_id as string;

    const { data: account } = await admin
      .from("organization_payment_accounts")
      .select("affiliate_id")
      .eq("organization_id", organizationId)
      .maybeSingle();

    if (!account) {
      orderResults.push({ order_id: order.id, skipped: "ORGANIZATION_NOT_ONBOARDED" });
      continue;
    }

    try {
      const status = await pagosya("get_checkout_status", {
        affiliate_id: account.affiliate_id,
        checkout_id: order.pagosya_checkout_id,
      });

      const providerStatus = String(status.status ?? status.checkout?.status ?? "");

      if (providerStatus === "completed" || providerStatus === "paid") {
        const { error: ingestError } = await admin.rpc("pagosya_ingest_event", {
          p_event: {
            id: `reconcile:${order.pagosya_checkout_id}`,
            event: "checkout.completed",
            affiliate_id: account.affiliate_id,
            external_id: order.id,
            data: {
              checkout_id: order.pagosya_checkout_id,
              payment_id: status.payment_id ?? status.id ?? null,
              amount: Number(order.total_amount),
              currency: order.currency,
            },
          },
        });
        orderResults.push({
          order_id: order.id,
          paid: !ingestError,
          error: ingestError?.message ?? null,
        });
      } else {
        orderResults.push({
          order_id: order.id,
          provider_status: providerStatus || null,
        });
      }
    } catch (err) {
      orderResults.push({
        order_id: order.id,
        error: err instanceof PagosyaError ? err.code : "UNKNOWN",
      });
    }
  }

  return json(req, {
    expired: expired ?? null,
    intents: intentResults,
    orders: orderResults,
  });
});
