// pagosya-webhook
// Receptor público de eventos de PagosYa. NO contiene reglas de negocio:
// verifica la firma, deduplica y delega en public.pagosya_ingest_event().
import {
  adminClient,
  json,
  verifyPagosyaSignature,
} from "../_shared/pagosya.ts";

const MAX_BODY_BYTES = 64 * 1024;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const secret = Deno.env.get("PAGOSYA_WEBHOOK_SECRET");
  if (!secret) {
    console.error("PAGOSYA_WEBHOOK_SECRET no configurado");
    return new Response("Not configured", { status: 500 });
  }

  const rawBody = await req.text();
  if (rawBody.length > MAX_BODY_BYTES) {
    return new Response("Payload too large", { status: 413 });
  }

  const valid = await verifyPagosyaSignature(
    rawBody,
    req.headers.get("X-PagosYa-Signature"),
    secret,
  );
  if (!valid) {
    console.warn("firma inválida", {
      event: req.headers.get("X-PagosYa-Event"),
      id: req.headers.get("X-PagosYa-Event-Id"),
    });
    return new Response("Invalid signature", { status: 401 });
  }

  let event: Record<string, unknown>;
  try {
    event = JSON.parse(rawBody);
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  // el sobre debe traer id y event; se completan desde cabeceras si faltan
  if (!event.id) event.id = req.headers.get("X-PagosYa-Event-Id");
  if (!event.event) event.event = req.headers.get("X-PagosYa-Event");

  if (typeof event.id !== "string" || typeof event.event !== "string") {
    return new Response("Invalid envelope", { status: 400 });
  }

  const admin = adminClient();
  const { data, error } = await admin.rpc("pagosya_ingest_event", { p_event: event });

  if (error) {
    console.error("ingest failed", {
      eventId: event.id,
      event: event.event,
      error: error.message,
    });
    return new Response("Retry later", { status: 500 });
  }

  // Evento de negocio rechazado (monto/afiliado/orden): queda auditado y no se reintenta.
  if (data && (data as Record<string, unknown>).ok === false) {
    console.warn("event rejected", { eventId: event.id, data });
    return json(req, data, 200);
  }

  return json(req, { ok: true, ...(data as Record<string, unknown> ?? {}) });
});
