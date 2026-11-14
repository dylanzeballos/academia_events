import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

export const PAGOSYA_API_URL =
  Deno.env.get("PAGOSYA_API_URL") ??
  "https://nbjwpakpimrqfocsxkda.supabase.co/functions/v1/saas-platform";

export class PagosyaError extends Error {
  code: string;
  status: number;
  constructor(code: string, status = 502) {
    super(code);
    this.code = code;
    this.status = status;
  }
}

export function adminClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

export function corsHeaders(req: Request): Record<string, string> {
  const allowed = (Deno.env.get("PAGOSYA_ALLOWED_ORIGINS") ?? "*")
    .split(",")
    .map((o) => o.trim())
    .filter(Boolean);
  const origin = req.headers.get("origin") ?? "";
  const allowOrigin = allowed.includes("*")
    ? "*"
    : (allowed.includes(origin) ? origin : allowed[0] ?? "");

  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

export function json(
  req: Request,
  body: unknown,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), "Content-Type": "application/json" },
  });
}

export async function pagosya(
  action: string,
  payload: Record<string, unknown>,
): Promise<Record<string, any>> {
  const key = Deno.env.get("PAGOSYA_PLATFORM_KEY");
  if (!key) throw new PagosyaError("PAGOSYA_NOT_CONFIGURED", 500);

  const res = await fetch(PAGOSYA_API_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ action, payload }),
  });

  let result: Record<string, any> = {};
  try {
    result = await res.json();
  } catch {
    throw new PagosyaError("PAGOSYA_INVALID_RESPONSE", 502);
  }

  if (!res.ok || result.error || result.success === false) {
    throw new PagosyaError(result.error ?? `PAGOSYA_HTTP_${res.status}`, res.status);
  }
  return result;
}

function hexToBytes(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

function timingSafeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

/** X-PagosYa-Signature: t=UNIX_SECONDS,v1=HEX_HMAC_SHA256 sobre `${t}.${rawBody}` */
export async function verifyPagosyaSignature(
  rawBody: string,
  signature: string | null,
  secret: string,
): Promise<boolean> {
  const match = /^t=(\d+),v1=([a-f0-9]{64})$/.exec(signature ?? "");
  if (!match) return false;

  const timestamp = Number(match[1]);
  if (Math.abs(Date.now() / 1000 - timestamp) > 300) return false;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${timestamp}.${rawBody}`)),
  );
  return timingSafeEqual(mac, hexToBytes(match[2]));
}

export async function requireUser(req: Request, admin: SupabaseClient) {
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!jwt) throw new PagosyaError("UNAUTHENTICATED", 401);

  const { data, error } = await admin.auth.getUser(jwt);
  if (error || !data?.user) throw new PagosyaError("UNAUTHENTICATED", 401);
  return data.user;
}

export async function requireOrgRole(
  admin: SupabaseClient,
  organizationId: string,
  userId: string,
): Promise<void> {
  const { data, error } = await admin
    .from("organization_members")
    .select("role")
    .eq("organization_id", organizationId)
    .eq("user_id", userId)
    .eq("is_active", true)
    .maybeSingle();

  if (error) throw new PagosyaError("MEMBERSHIP_CHECK_FAILED", 500);
  if (!data || !["owner", "admin"].includes(String(data.role))) {
    throw new PagosyaError("FORBIDDEN", 403);
  }
}

export async function requirePlatformAdmin(
  admin: SupabaseClient,
  userId: string,
): Promise<void> {
  const { data, error } = await admin
    .from("user_roles")
    .select("role")
    .eq("user_id", userId)
    .eq("role", "admin")
    .maybeSingle();

  if (error) throw new PagosyaError("ROLE_CHECK_FAILED", 500);
  if (!data) throw new PagosyaError("FORBIDDEN", 403);
}

export function errorResponse(req: Request, err: unknown): Response {
  if (err instanceof PagosyaError) {
    return json(req, { error: err.code }, err.status);
  }
  console.error("unexpected error", err);
  return json(req, { error: "INTERNAL_ERROR" }, 500);
}
