// pagosya-api
// Endpoint autenticado (JWT del usuario) para operar PagosYa desde el backend.
// La clave de plataforma (spk_) nunca sale de esta función.
import {
  adminClient,
  errorResponse,
  isPlatformAdmin,
  isSandboxCheckoutId,
  json,
  pagosya,
  PagosyaError,
  requireOrgRole,
  requirePlatformAdmin,
  requireUser,
  sandboxCheckout,
  sandboxCheckoutId,
  sandboxMode,
} from "../_shared/pagosya.ts";

type Body = {
  action?: string;
  kind?:
    | "ticket"
    | "class_pass"
    | "class_monthly"
    | "vip_membership"
    | "membership"
    | "event_publication"
    | "class_publication";
  reference_id?: string;
  order_id?: string;
  organization_id?: string;
  seat_ids?: string[];
  session_ids?: string[];
  intent_id?: string;
  amount?: number;
  offset?: number;
  url?: string;
  enabled?: boolean;
  rotate?: boolean;
  event_id?: string;
  branding_mode?: "powered_by_pagosya" | "white_label";
  payment_ui?: "merchant" | "provider" | "both";
};

const BANK_URL = "https://www.pagosya.com.bo/plataformas/componente";
const CHECKOUT_TTL_MINUTES = 15;

/** Vencimiento del checkout: el del proveedor si viene; si no, 15 minutos. */
function checkoutExpiry(iso?: string | null): string {
  return iso ?? new Date(Date.now() + CHECKOUT_TTL_MINUTES * 60_000).toISOString();
}

function checkoutUrls(result: Record<string, any>) {
  const rawId =
    result.checkout_id ?? result.id ?? result.checkout?.checkout_id ?? null;
  const isSandbox =
    result.sandbox === true || result.environment === "sandbox";
  return {
    checkoutId: rawId
      ? (isSandbox ? sandboxCheckoutId(String(rawId)) : String(rawId))
      : null,
    checkoutUrl:
      result.checkout_url ?? result.url ?? result.checkout?.url ?? null,
    qrDataUrl:
      result.qr?.data_url ??
      result.qr_data_url ??
      result.qr_image ??
      result.checkout?.qr?.data_url ??
      null,
    expiresAt:
      result.expires_at ?? result.checkout?.expires_at ?? result.expiresAt ?? null,
  };
}

function appUrl(path: string) {
  return `${Deno.env.get("APP_BASE_URL") ?? "https://app.academia.bo"}${path}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return json(req, { ok: true });
  if (req.method !== "POST") return json(req, { error: "METHOD_NOT_ALLOWED" }, 405);

  const admin = adminClient();

  try {
    const user = await requireUser(req, admin);
    const body = (await req.json().catch(() => ({}))) as Body;
    const action = body.action;

    // ---------------------------------------------------------------- checkout
    if (action === "create_checkout") {
      const kind = body.kind ?? "ticket";
      const sandbox = sandboxMode();
      const referenceId = body.reference_id ?? body.order_id;
      if (!referenceId) throw new PagosyaError("REFERENCE_ID_REQUIRED", 400);

      // ------------------------------------------------------------- tickets
      if (kind === "ticket") {
        const { data: order } = await admin
          .from("orders")
          .select(
            "id, user_id, event_id, order_number, status, total_amount, currency, " +
              "pagosya_checkout_id, pagosya_checkout_url, pagosya_qr_data_url, " +
              "events!inner(organization_id, title)",
          )
          .eq("id", referenceId)
          .maybeSingle();

        if (!order || order.user_id !== user.id) {
          throw new PagosyaError("ORDER_NOT_FOUND", 404);
        }
        if (order.status !== "pending") {
          throw new PagosyaError(
            order.status === "paid" || order.status === "completed"
              ? "ORDER_ALREADY_PAID"
              : "ORDER_NOT_PENDING",
            409,
          );
        }

        const organizationId = (order as any).events.organization_id as string;

        if (order.pagosya_checkout_id) {
          return json(req, {
            kind,
            reference_id: order.id,
            order_id: order.id,
            checkout_id: order.pagosya_checkout_id,
            checkout_url: order.pagosya_checkout_url,
            qr_data_url: order.pagosya_qr_data_url,
            total_amount: order.total_amount,
            currency: order.currency,
            order_number: order.order_number,
            reused: true,
            sandbox: isSandboxCheckoutId(order.pagosya_checkout_id),
            expires_at: checkoutExpiry(),
          });
        }

        const affiliateId = sandbox ? "sandbox" : await affiliateFor(admin, organizationId);
        const { data: profile } = await admin
          .from("profiles")
          .select("first_name, last_name, phone_number")
          .eq("id", user.id)
          .maybeSingle();

        const checkoutPayload = {
          amount: Number(order.total_amount),
          currency: order.currency,
          order_id: order.id,
          expiration_minutes: 15,
          success_url: appUrl("/pago/confirmado"),
          cancel_url: appUrl("/pago/cancelado"),
          customer: {
            name: [profile?.first_name, profile?.last_name].filter(Boolean).join(" ") || "Cliente",
            email: user.email ?? undefined,
            phone: profile?.phone_number ?? undefined,
          },
        };

        const result = sandbox
          ? await sandboxCheckout(checkoutPayload)
          : await pagosya("create_checkout", {
              affiliate_id: affiliateId,
              checkout: checkoutPayload,
            });

        const urls = checkoutUrls(result);
        if (!urls.checkoutId) throw new PagosyaError("PAGOSYA_WITHOUT_CHECKOUT_ID", 502);

        await admin
          .from("orders")
          .update({
            pagosya_checkout_id: urls.checkoutId,
            pagosya_checkout_url: urls.checkoutUrl,
            pagosya_qr_data_url: urls.qrDataUrl,
            pagosya_seat_ids: body.seat_ids?.length ? body.seat_ids : null,
          })
          .eq("id", order.id);

        return json(req, {
          kind,
          reference_id: order.id,
          order_id: order.id,
          checkout_id: urls.checkoutId,
          checkout_url: urls.checkoutUrl,
          qr_data_url: urls.qrDataUrl,
          total_amount: order.total_amount,
          currency: order.currency,
          order_number: order.order_number,
          sandbox,
          expires_at: checkoutExpiry(urls.expiresAt),
        });
      }

      // ------------------------------------- pase de clase por sesiones
      if (kind === "class_pass") {
        const sessionIds = (body.session_ids ?? []).filter(Boolean);
        if (!sessionIds.length) {
          throw new PagosyaError("SESSION_IDS_REQUIRED", 400);
        }

        const { data: quote, error } = await admin.rpc("quote_class_sessions", {
          p_enrollment_id: referenceId,
          p_session_ids: sessionIds,
          p_user_id: user.id,
        });
        if (error) throw new PagosyaError("QUOTE_FAILED", 500);
        if (!quote?.success) {
          throw new PagosyaError(quote?.reason ?? "CLASS_PASS_NOT_AVAILABLE", 409);
        }

        const affiliateId = sandbox
          ? "sandbox"
          : await affiliateFor(admin, quote.organization_id);

        return json(
          req,
          await startIntent(admin, {
            userId: user.id,
            organizationId: quote.organization_id,
            kind,
            referenceId,
            amount: Number(quote.total_amount),
            currency: quote.currency,
            affiliateId,
            metadata: {
              mode: "sessions",
              session_ids: quote.session_ids,
              session_count: quote.session_count,
              price: quote.price,
            },
          }),
        );
      }

      // ------------------------------------- pase mensual de una clase
      if (kind === "class_monthly") {
        const { data: quote, error } = await admin.rpc("quote_class_monthly", {
          p_enrollment_id: referenceId,
          p_user_id: user.id,
        });
        if (error) throw new PagosyaError("QUOTE_FAILED", 500);
        if (!quote?.success) {
          throw new PagosyaError(quote?.reason ?? "CLASS_MONTHLY_NOT_AVAILABLE", 409);
        }

        const affiliateId = sandbox
          ? "sandbox"
          : await affiliateFor(admin, quote.organization_id);

        return json(
          req,
          await startIntent(admin, {
            userId: user.id,
            organizationId: quote.organization_id,
            kind,
            referenceId,
            amount: Number(quote.total_amount),
            currency: quote.currency,
            affiliateId,
            metadata: {
              mode: "monthly",
              period_start: quote.period_start,
              period_end: quote.period_end,
              session_count: quote.session_count,
              price: quote.price,
            },
          }),
        );
      }

      // ------------------------------------- pase VIP de la organización
      if (kind === "vip_membership") {
        const organizationId = body.organization_id ?? referenceId;
        const { data: quote, error } = await admin.rpc("quote_vip_membership", {
          p_organization_id: organizationId,
          p_user_id: user.id,
        });
        if (error) throw new PagosyaError("QUOTE_FAILED", 500);
        if (!quote?.success) {
          throw new PagosyaError(quote?.reason ?? "VIP_NOT_AVAILABLE", 409);
        }

        const affiliateId = sandbox
          ? "sandbox"
          : await affiliateFor(admin, quote.organization_id);

        return json(
          req,
          await startIntent(admin, {
            userId: user.id,
            organizationId: quote.organization_id,
            kind,
            referenceId: quote.organization_id,
            amount: Number(quote.price_monthly),
            currency: quote.currency,
            affiliateId,
            metadata: {
              mode: "vip",
              plan_id: quote.plan_id,
              class_count: quote.class_count,
              period_start: quote.period_start,
              period_end: quote.period_end,
            },
          }),
        );
      }

      // ----------------------------------------------------------- membership
      if (kind === "membership") {
        const { data: subscription } = await admin
          .from("subscriptions")
          .select(
            "id, organization_id, plan_id, status, billing_interval, " +
              "subscription_plans!inner(price, currency, name)",
          )
          .eq("id", referenceId)
          .maybeSingle();

        if (!subscription) throw new PagosyaError("SUBSCRIPTION_NOT_FOUND", 404);
        await requireOrgRole(admin, subscription.organization_id, user.id);

        if (!["pending", "past_due"].includes(String(subscription.status))) {
          throw new PagosyaError("SUBSCRIPTION_NOT_PAYABLE", 409);
        }

        let affiliateId = "sandbox";
        if (!sandbox) {
          const { data: config } = await admin
            .from("payment_platform_config")
            .select("affiliate_id")
            .eq("id", true)
            .maybeSingle();

          if (!config?.affiliate_id) {
            throw new PagosyaError("PLATFORM_MERCHANT_NOT_CONFIGURED", 409);
          }
          affiliateId = config.affiliate_id;
        }

        const plan = (subscription as any).subscription_plans;

        return json(
          req,
          await startIntent(admin, {
            userId: user.id,
            organizationId: subscription.organization_id,
            kind,
            referenceId,
            amount: Number(plan.price),
            currency: plan.currency,
            affiliateId,
            metadata: { plan: plan.name, billing_interval: subscription.billing_interval },
          }),
        );
      }

      // ------------------------------------ publicaciones (evento / clase)
      if (kind === "event_publication" || kind === "class_publication") {
        // La publicación de clases está incluida en la suscripción mensual:
        // no se genera ningún cobro adicional.
        if (kind === "class_publication") {
          throw new PagosyaError("CLASS_PUBLICATION_INCLUDED", 409);
        }

        const isEvent = kind === "event_publication";
        const table = isEvent ? "events" : "dance_classes";
        const { data: entity } = await admin
          .from(table)
          .select("id, title, organization_id")
          .eq("id", referenceId)
          .maybeSingle();

        if (!entity) throw new PagosyaError("PUBLICATION_TARGET_NOT_FOUND", 404);

        // El admin de plataforma define el monto; la organización paga el
        // precio configurado en `payment_platform_config`.
        let amount: number;
        if (await isPlatformAdmin(admin, user.id)) {
          amount = Number(body.amount);
          if (!Number.isFinite(amount) || amount <= 0) {
            throw new PagosyaError("AMOUNT_REQUIRED", 400);
          }
        } else {
          await requireOrgRole(admin, entity.organization_id, user.id, [
            "owner",
            "admin",
            "manager",
          ]);

          const { data: config } = await admin
            .from("payment_platform_config")
            .select("class_publication_price, event_publication_price")
            .eq("id", true)
            .maybeSingle();

          const configured = Number(
            isEvent
              ? config?.event_publication_price
              : config?.class_publication_price,
          );
          if (!Number.isFinite(configured) || configured <= 0) {
            throw new PagosyaError("PUBLICATION_PRICE_NOT_CONFIGURED", 409);
          }
          amount = configured;
        }

        // Regla obligatoria: sin suscripción mensual activa no se genera el QR
        // de publicación. Además se cobra la publicación aparte.
        const { data: hasMembership, error: membershipError } = await admin.rpc(
          "organization_has_active_monthly_membership",
          { p_organization_id: entity.organization_id },
        );
        if (membershipError) throw new PagosyaError("MEMBERSHIP_CHECK_FAILED", 500);
        if (!hasMembership) {
          throw new PagosyaError("MEMBERSHIP_REQUIRED", 409);
        }

        const { data: alreadyPaid } = await admin
          .from(isEvent ? "event_publication_payments" : "dance_class_publication_payments")
          .select("id")
          .eq(isEvent ? "event_id" : "dance_class_id", referenceId)
          .maybeSingle();

        if (alreadyPaid) throw new PagosyaError("PUBLICATION_ALREADY_PAID", 409);

        let affiliateId = "sandbox";
        if (!sandbox) {
          const { data: config } = await admin
            .from("payment_platform_config")
            .select("affiliate_id")
            .eq("id", true)
            .maybeSingle();

          if (!config?.affiliate_id) {
            throw new PagosyaError("PLATFORM_MERCHANT_NOT_CONFIGURED", 409);
          }
          affiliateId = config.affiliate_id;
        }

        return json(
          req,
          await startIntent(admin, {
            userId: user.id,
            organizationId: entity.organization_id,
            kind,
            referenceId,
            amount,
            currency: "BOB",
            affiliateId,
            metadata: { title: entity.title },
          }),
        );
      }

      throw new PagosyaError("UNKNOWN_KIND", 400);
    }

    // -------------------------------------------------------- reconciliación
    if (action === "refresh_checkout") {
      // intents (pase de clase / membresía)
      if (body.intent_id) {
        const { data: intent } = await admin
          .from("payment_intents")
          .select("id, user_id, kind, reference_id, amount, currency, affiliate_id, " +
            "status, pagosya_checkout_id")
          .eq("id", body.intent_id)
          .maybeSingle();

        if (!intent || intent.user_id !== user.id) {
          throw new PagosyaError("INTENT_NOT_FOUND", 404);
        }
        if (intent.status === "paid") {
          return json(req, { intent_id: intent.id, status: "paid", paid: true });
        }
        if (isSandboxCheckoutId(intent.pagosya_checkout_id)) {
          // El sandbox no confirma pagos ni envía webhooks: sigue pendiente.
          return json(req, {
            intent_id: intent.id,
            provider_status: "sandbox",
            status: intent.status,
            paid: false,
            sandbox: true,
          });
        }
        if (!intent.pagosya_checkout_id) {
          throw new PagosyaError("CHECKOUT_NOT_CREATED", 409);
        }

        const result = await pagosya("get_checkout_status", {
          affiliate_id: intent.affiliate_id,
          checkout_id: intent.pagosya_checkout_id,
        });
        const providerStatus = String(result.status ?? result.checkout?.status ?? "");

        if (providerStatus === "completed" || providerStatus === "paid") {
          await admin.rpc("pagosya_ingest_event", {
            p_event: {
              id: `reconcile:${intent.pagosya_checkout_id}`,
              event: "checkout.completed",
              affiliate_id: intent.affiliate_id,
              external_id: intent.reference_id,
              data: {
                checkout_id: intent.pagosya_checkout_id,
                payment_id: result.payment_id ?? result.id ?? null,
                amount: Number(intent.amount),
                currency: intent.currency,
              },
            },
          });
        }

        const { data: current } = await admin
          .from("payment_intents")
          .select("status")
          .eq("id", intent.id)
          .maybeSingle();

        return json(req, {
          intent_id: intent.id,
          provider_status: providerStatus || null,
          status: current?.status ?? intent.status,
          paid: current?.status === "paid",
        });
      }

      // órdenes de tickets
      if (!body.reference_id && !body.order_id) {
        throw new PagosyaError("REFERENCE_ID_REQUIRED", 400);
      }
      const orderId = body.reference_id ?? body.order_id!;

      const { data: order } = await admin
        .from("orders")
        .select(
          "id, user_id, status, total_amount, currency, order_number, " +
            "pagosya_checkout_id, events!inner(organization_id)",
        )
        .eq("id", orderId)
        .maybeSingle();

      if (!order || order.user_id !== user.id) {
        throw new PagosyaError("ORDER_NOT_FOUND", 404);
      }
      if (order.status === "paid" || order.status === "completed") {
        return json(req, { order_id: order.id, status: order.status, paid: true });
      }
      if (isSandboxCheckoutId(order.pagosya_checkout_id)) {
        // El sandbox no confirma pagos ni envía webhooks: sigue pendiente.
        return json(req, {
          order_id: order.id,
          provider_status: "sandbox",
          status: order.status,
          paid: false,
          sandbox: true,
        });
      }
      if (!order.pagosya_checkout_id) {
        throw new PagosyaError("CHECKOUT_NOT_CREATED", 409);
      }

      const organizationId = (order as any).events.organization_id as string;
      const affiliateId = await affiliateFor(admin, organizationId);

      const result = await pagosya("get_checkout_status", {
        affiliate_id: affiliateId,
        checkout_id: order.pagosya_checkout_id,
      });
      const providerStatus = String(result.status ?? result.checkout?.status ?? "");

      if (providerStatus === "completed" || providerStatus === "paid") {
        await admin.rpc("pagosya_ingest_event", {
          p_event: {
            id: `reconcile:${order.pagosya_checkout_id}`,
            event: "checkout.completed",
            affiliate_id: affiliateId,
            external_id: order.id,
            data: {
              checkout_id: order.pagosya_checkout_id,
              payment_id: result.payment_id ?? result.id ?? null,
              amount: Number(order.total_amount),
              currency: order.currency,
            },
          },
        });
      }

      const { data: current } = await admin
        .from("orders")
        .select("status")
        .eq("id", order.id)
        .maybeSingle();

      return json(req, {
        order_id: order.id,
        provider_status: providerStatus || null,
        status: current?.status ?? order.status,
        paid: current?.status === "paid" || current?.status === "completed",
      });
    }

    // ------------------------------------------- confirmación simulada sandbox
    // Solo disponible con PAGOSYA_MODE=sandbox y para checkouts `sandbox:`.
    // Sirve para probar tickets, butacas, pases, membresías y publicaciones
    // sin un pago real. Reutiliza el mismo camino que el webhook.
    if (action === "sandbox_confirm") {
      if (!sandboxMode()) throw new PagosyaError("SANDBOX_DISABLED", 403);
      if (!body.order_id && !body.intent_id) {
        throw new PagosyaError("REFERENCE_ID_REQUIRED", 400);
      }

      const platformAdmin = await isPlatformAdmin(admin, user.id);

      let checkoutId: string;
      let amount: number;
      let currency: string;
      let reference: Record<string, string>;

      if (body.intent_id) {
        const { data: intent } = await admin
          .from("payment_intents")
          .select(
            "id, user_id, kind, reference_id, amount, currency, status, pagosya_checkout_id",
          )
          .eq("id", body.intent_id)
          .maybeSingle();

        if (!intent) throw new PagosyaError("INTENT_NOT_FOUND", 404);
        if (intent.user_id !== user.id && !platformAdmin) {
          throw new PagosyaError("FORBIDDEN", 403);
        }
        if (!isSandboxCheckoutId(intent.pagosya_checkout_id)) {
          throw new PagosyaError("NOT_A_SANDBOX_CHECKOUT", 409);
        }
        if (intent.status === "paid") {
          return json(req, {
            intent_id: intent.id,
            status: "paid",
            paid: true,
            sandbox: true,
            already_paid: true,
          });
        }
        if (intent.status !== "pending") {
          throw new PagosyaError("INTENT_NOT_PENDING", 409);
        }

        checkoutId = String(intent.pagosya_checkout_id);
        amount = Number(intent.amount);
        currency = intent.currency;
        reference = { intent_id: intent.id, reference_id: intent.reference_id };
      } else {
        const { data: order } = await admin
          .from("orders")
          .select("id, user_id, status, total_amount, currency, pagosya_checkout_id")
          .eq("id", body.order_id!)
          .maybeSingle();

        if (!order) throw new PagosyaError("ORDER_NOT_FOUND", 404);
        if (order.user_id !== user.id && !platformAdmin) {
          throw new PagosyaError("FORBIDDEN", 403);
        }
        if (!isSandboxCheckoutId(order.pagosya_checkout_id)) {
          throw new PagosyaError("NOT_A_SANDBOX_CHECKOUT", 409);
        }
        if (order.status === "paid" || order.status === "completed") {
          return json(req, {
            order_id: order.id,
            status: order.status,
            paid: true,
            sandbox: true,
            already_paid: true,
          });
        }
        if (order.status !== "pending") {
          throw new PagosyaError("ORDER_NOT_PENDING", 409);
        }

        checkoutId = String(order.pagosya_checkout_id);
        amount = Number(order.total_amount);
        currency = order.currency;
        reference = { order_id: order.id };
      }

      // Sin affiliate_id: en sandbox no existe la fila de comercio y la
      // validación de afiliado se omite cuando el campo es null.
      const { data: applied, error } = await admin.rpc("pagosya_ingest_event", {
        p_event: {
          id: `sandbox-confirm:${checkoutId}`,
          event: "checkout.completed",
          external_id: reference.order_id ?? reference.reference_id,
          data: {
            checkout_id: checkoutId,
            payment_id: `sandbox-pay-${checkoutId.replace(/^sandbox:/, "")}`,
            amount,
            currency,
          },
        },
      });

      if (error) throw new PagosyaError("SANDBOX_CONFIRM_FAILED", 500);
      if (applied && applied.ok === false) {
        throw new PagosyaError("SANDBOX_CONFIRM_REJECTED", 409);
      }

      return json(req, {
        ...reference,
        status: "paid",
        paid: true,
        sandbox: true,
        applied: applied ?? null,
      });
    }

    // ------------------------------------------------------------- onboarding
    if (action === "merchant_create") {
      if (!body.organization_id) {
        throw new PagosyaError("ORGANIZATION_ID_REQUIRED", 400);
      }
      await requireOrgRole(admin, body.organization_id, user.id);

      const { data: org } = await admin
        .from("organizations")
        .select("id, name, email, phone_number")
        .eq("id", body.organization_id)
        .maybeSingle();
      if (!org) throw new PagosyaError("ORGANIZATION_NOT_FOUND", 404);

      const { data: existing } = await admin
        .from("organization_payment_accounts")
        .select("affiliate_id, branding_mode, payment_ui, bank_status")
        .eq("organization_id", org.id)
        .maybeSingle();

      if (existing) {
        return json(req, { organization_id: org.id, ...existing, reused: true });
      }

      const affiliateId = await createMerchant(admin, {
        externalId: org.id,
        displayName: org.name,
        email: org.email ?? user.email ?? undefined,
        brandingMode: body.branding_mode ?? "powered_by_pagosya",
        paymentUi: body.payment_ui ?? "both",
      });

      const { error } = await admin.from("organization_payment_accounts").insert({
        organization_id: org.id,
        affiliate_id: affiliateId,
        external_id: org.id,
        branding_mode: body.branding_mode ?? "powered_by_pagosya",
        payment_ui: body.payment_ui ?? "both",
      });
      if (error) throw new PagosyaError("MERCHANT_SAVE_FAILED", 500);

      return json(req, {
        organization_id: org.id,
        affiliate_id: affiliateId,
        bank_status: null,
      });
    }

    // Comercio de la propia plataforma (para membresías).
    if (action === "platform_merchant_create") {
      await requirePlatformAdmin(admin, user.id);

      const { data: config } = await admin
        .from("payment_platform_config")
        .select("affiliate_id")
        .eq("id", true)
        .maybeSingle();
      if (config?.affiliate_id) {
        return json(req, { affiliate_id: config.affiliate_id, reused: true });
      }

      const affiliateId = await createMerchant(admin, {
        externalId: "platform",
        displayName: "Academia Events",
        email: user.email ?? undefined,
        brandingMode: "powered_by_pagosya",
        paymentUi: "both",
      });

      const { error } = await admin
        .from("payment_platform_config")
        .upsert({ id: true, affiliate_id: affiliateId, external_id: "platform" });
      if (error) throw new PagosyaError("PLATFORM_MERCHANT_SAVE_FAILED", 500);

      return json(req, { affiliate_id: affiliateId });
    }

    // Banco del comercio de la plataforma (membresías y publicaciones).
    if (action === "platform_merchant_summary") {
      await requirePlatformAdmin(admin, user.id);

      const { data: config } = await admin
        .from("payment_platform_config")
        .select("affiliate_id")
        .eq("id", true)
        .maybeSingle();
      if (!config?.affiliate_id) {
        throw new PagosyaError("PLATFORM_MERCHANT_NOT_CONFIGURED", 409);
      }

      const summary = await pagosya("merchant_summary", {
        affiliate_id: config.affiliate_id,
      });
      return json(req, {
        affiliate_id: config.affiliate_id,
        bank_status: summary.bank?.status ?? summary.bank_status ?? null,
        summary,
      });
    }

    if (action === "platform_bank_session") {
      await requirePlatformAdmin(admin, user.id);

      const { data: config } = await admin
        .from("payment_platform_config")
        .select("affiliate_id")
        .eq("id", true)
        .maybeSingle();
      if (!config?.affiliate_id) {
        throw new PagosyaError("PLATFORM_MERCHANT_NOT_CONFIGURED", 409);
      }

      const session = await pagosya("create_session", {
        affiliate_id: config.affiliate_id,
        component: "bank",
        actor_ref: user.id,
      });

      if (!session.token) throw new PagosyaError("SESSION_WITHOUT_TOKEN", 502);

      return json(req, { url: `${BANK_URL}#${session.token}`, expires_in: 1800 });
    }

    if (action === "create_bank_session") {
      if (!body.organization_id) {
        throw new PagosyaError("ORGANIZATION_ID_REQUIRED", 400);
      }
      await requireOrgRole(admin, body.organization_id, user.id);

      const affiliateId = await affiliateFor(admin, body.organization_id);
      const session = await pagosya("create_session", {
        affiliate_id: affiliateId,
        component: "bank",
        actor_ref: user.id,
      });

      if (!session.token) throw new PagosyaError("SESSION_WITHOUT_TOKEN", 502);

      return json(req, { url: `${BANK_URL}#${session.token}`, expires_in: 1800 });
    }

    if (action === "create_commission_session") {
      if (!body.organization_id) {
        throw new PagosyaError("ORGANIZATION_ID_REQUIRED", 400);
      }
      await requireOrgRole(admin, body.organization_id, user.id);

      const affiliateId = await affiliateFor(admin, body.organization_id);
      const session = await pagosya("create_session", {
        affiliate_id: affiliateId,
        component: "commission",
        actor_ref: user.id,
      });

      if (!session.token) throw new PagosyaError("SESSION_WITHOUT_TOKEN", 502);

      return json(req, { url: `${BANK_URL}#${session.token}`, expires_in: 1800 });
    }

    if (action === "merchant_summary") {
      if (!body.organization_id) {
        throw new PagosyaError("ORGANIZATION_ID_REQUIRED", 400);
      }
      await requireOrgRole(admin, body.organization_id, user.id);

      const affiliateId = await affiliateFor(admin, body.organization_id);
      const summary = await pagosya("merchant_summary", { affiliate_id: affiliateId });

      const bankStatus = summary.bank?.status ?? summary.bank_status ?? null;
      if (bankStatus) {
        await admin
          .from("organization_payment_accounts")
          .update({ bank_status: bankStatus, bank_updated_at: new Date().toISOString() })
          .eq("organization_id", body.organization_id);
      }

      return json(req, summary);
    }

    // ------------------------------------------------------- administración
    if (action === "overview") {
      await requirePlatformAdmin(admin, user.id);
      return json(req, await pagosya("overview", { offset: body.offset ?? 0 }));
    }

    if (action === "webhook_get") {
      await requirePlatformAdmin(admin, user.id);
      return json(req, await pagosya("webhook_get", {}));
    }

    if (action === "webhook_set") {
      await requirePlatformAdmin(admin, user.id);
      if (!body.url) throw new PagosyaError("WEBHOOK_URL_REQUIRED", 400);

      let webhookUrl: URL;
      try {
        webhookUrl = new URL(body.url);
      } catch {
        throw new PagosyaError("INVALID_WEBHOOK_URL", 400);
      }
      if (webhookUrl.protocol !== "https:" || webhookUrl.search) {
        throw new PagosyaError("INVALID_WEBHOOK_URL", 400);
      }

      return json(
        req,
        await pagosya("webhook_set", {
          url: webhookUrl.toString(),
          enabled: body.enabled ?? true,
          rotate: body.rotate ?? false,
        }),
      );
    }

    if (action === "webhook_retry") {
      await requirePlatformAdmin(admin, user.id);
      if (!body.event_id) throw new PagosyaError("EVENT_ID_REQUIRED", 400);
      return json(req, await pagosya("webhook_retry", { event_id: body.event_id }));
    }

    throw new PagosyaError("UNKNOWN_ACTION", 400);
  } catch (err) {
    return errorResponse(req, err);
  }
});

// ---------------------------------------------------------------------------

async function affiliateFor(admin: any, organizationId: string): Promise<string> {
  const { data } = await admin
    .from("organization_payment_accounts")
    .select("affiliate_id, bank_status")
    .eq("organization_id", organizationId)
    .maybeSingle();

  if (!data) throw new PagosyaError("ORGANIZATION_NOT_ONBOARDED", 409);
  if (data.bank_status && data.bank_status !== "connected") {
    throw new PagosyaError("BANK_INTEGRATION_REQUIRED", 409);
  }
  return data.affiliate_id;
}

async function createMerchant(
  _admin: any,
  params: {
    externalId: string;
    displayName: string;
    email?: string;
    brandingMode: string;
    paymentUi: string;
  },
): Promise<string> {
  const result = await pagosya("merchant_create", {
    external_id: params.externalId,
    display_name: params.displayName,
    email: params.email,
    branding_mode: params.brandingMode,
    payment_ui: params.paymentUi,
  });

  const affiliateId = result.id ?? result.commerce?.id ?? result.affiliate_id;
  if (!affiliateId) throw new PagosyaError("MERCHANT_WITHOUT_ID", 502);
  return String(affiliateId);
}

async function startIntent(
  admin: any,
  params: {
    userId: string;
    organizationId: string;
    kind:
      | "class_pass"
      | "class_monthly"
      | "vip_membership"
      | "membership"
      | "event_publication"
      | "class_publication";
    referenceId: string;
    amount: number;
    currency: string;
    affiliateId: string;
    metadata: Record<string, unknown>;
  },
) {
  const { data: existing } = await admin
    .from("payment_intents")
    .select(
      "id, checkout_url, qr_data_url, pagosya_checkout_id, amount, currency, expires_at, metadata",
    )
    .eq("kind", params.kind)
    .eq("reference_id", params.referenceId)
    .eq("user_id", params.userId)
    .eq("status", "pending")
    .maybeSingle();

  const existingExpiresAt = existing?.expires_at
    ? Date.parse(existing.expires_at)
    : Number.NaN;
  const existingIsValid =
    Boolean(existing?.pagosya_checkout_id) &&
    Number.isFinite(existingExpiresAt) &&
    existingExpiresAt > Date.now();

  if (existingIsValid) {
    const incomingSessions = Array.isArray(params.metadata.session_ids)
      ? (params.metadata.session_ids as string[])
      : [];
    const existingSessions = Array.isArray((existing as any).metadata?.session_ids)
      ? ((existing as any).metadata.session_ids as string[])
      : [];

    const sameSessions =
      params.kind !== "class_pass" ||
      JSON.stringify([...existingSessions].sort()) ===
        JSON.stringify([...incomingSessions].sort());

    if (sameSessions) {
      return {
        kind: params.kind,
        reference_id: params.referenceId,
        intent_id: existing!.id,
        checkout_id: existing!.pagosya_checkout_id,
        checkout_url: existing!.checkout_url,
        qr_data_url: existing!.qr_data_url,
        total_amount: existing!.amount,
        currency: existing!.currency,
        reused: true,
        sandbox: isSandboxCheckoutId(existing!.pagosya_checkout_id),
        expires_at: checkoutExpiry(existing!.expires_at),
      };
    }
  }

  // Un cobro vencido (o con otras sesiones) ya no se puede reutilizar: se
  // cancela y se genera uno nuevo para que el QR no quede pegado en expirado.
  if (existing) {
    await admin
      .from("payment_intents")
      .update({
        status: "cancelled",
        pagosya_checkout_id: null,
        checkout_url: null,
        qr_data_url: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", existing.id);
  }

  const checkoutPayload = {
    amount: params.amount,
    currency: params.currency,
    // Las publicaciones reutilizan el id del evento; PagosYa necesita un
    // order_id distinto por intento para no devolver el checkout viejo.
    order_id: params.kind === "event_publication"
      ? `${params.referenceId}-${Date.now()}`
      : params.referenceId,
    expiration_minutes: 15,
    success_url: appUrl("/pago/confirmado"),
    cancel_url: appUrl("/pago/cancelado"),
  };

  const sandbox = sandboxMode();
  const result = sandbox
    ? await sandboxCheckout(checkoutPayload)
    : await pagosya("create_checkout", {
        affiliate_id: params.affiliateId,
        checkout: checkoutPayload,
      });

  const urls = checkoutUrls(result);
  if (!urls.checkoutId) throw new PagosyaError("PAGOSYA_WITHOUT_CHECKOUT_ID", 502);

  const expiresAt = checkoutExpiry(urls.expiresAt);

  const { data: intent, error } = await admin
    .from("payment_intents")
    .insert({
      kind: params.kind,
      reference_id: params.referenceId,
      user_id: params.userId,
      organization_id: params.organizationId,
      amount: params.amount,
      currency: params.currency,
      affiliate_id: params.affiliateId,
      pagosya_checkout_id: urls.checkoutId,
      checkout_url: urls.checkoutUrl,
      qr_data_url: urls.qrDataUrl,
      metadata: params.metadata,
      expires_at: expiresAt,
    })
    .select("id")
    .single();

  if (error || !intent) throw new PagosyaError("INTENT_SAVE_FAILED", 500);

  return {
    kind: params.kind,
    reference_id: params.referenceId,
    intent_id: intent.id,
    checkout_id: urls.checkoutId,
    checkout_url: urls.checkoutUrl,
    qr_data_url: urls.qrDataUrl,
    total_amount: params.amount,
    currency: params.currency,
    sandbox,
    expires_at: expiresAt,
  };
}
