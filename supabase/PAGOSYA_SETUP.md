# PagosYa SaaS · puesta en marcha (este repositorio)

Implementación de la pasarela PagosYa (producto **SaaS / Plataformas**): cada
organización cobra en su propio banco y la plataforma usa una sola clave `spk_`.

## Qué quedó implementado

| Pieza | Archivo |
|---|---|
| Migración (tablas, RPCs, RLS, revokes) | `supabase/migrations/20261112120000_pagosya_saas_integration.sql` |
| Cliente compartido (firma, API, CORS) | `supabase/functions/_shared/pagosya.ts` |
| API autenticada (checkout, onboarding, resumen) | `supabase/functions/pagosya-api/index.ts` |
| Webhook público | `supabase/functions/pagosya-webhook/index.ts` |
| Reconciliación + limpieza (cron) | `supabase/functions/pagosya-reconcile/index.ts` |
| Cliente Flutter (servicio + pantalla) | `lib/data/services/pagosya_service.dart`, `lib/features/tickets/views/pagosya_checkout_screen.dart` |

Cubre **tres tipos de cobro** con el mismo flujo:

| `kind` | Referencia | Se activa al confirmar |
|---|---|---|
| `ticket` | `orders.id` | tickets + QR + butacas |
| `class_pass` | `class_enrollments.id` | `class_passes` + tickets de sesión + QR |
| `membership` | `subscriptions.id` | suscripción `active` + pago |
| `event_publication` | `events.id` | pago de publicación + notificación al admin |
| `class_publication` | `dance_classes.id` | pago de publicación + notificación al admin |

Flujo:

```
Flutter ──create_event_order / request_organization_membership──► Postgres
Flutter ──pagosya-api (kind + reference_id)──► PagosYa (QR / URL)
PagosYa ──webhook──► pagosya-webhook ──► pagosya_apply_checkout_completed()
Flutter ──polling refresh_checkout──► confirma y muestra el resultado
```

La app **nunca** puede confirmar un pago: `confirm_event_order_payment` y
`purchase_class_pass` ya no son ejecutables por `anon`/`authenticated`. Solo
`service_role` (webhook/cron) puede confirmar.

---

## 1. Secretos

Crea `supabase/functions/.env` (está en `.gitignore`) a partir de
`supabase/functions/.env.example` y cárgalos:

```bash
supabase secrets set --env-file supabase/functions/.env
```

| Secreto | Origen |
|---|---|
| `PAGOSYA_PLATFORM_KEY` | PagosYa → Integración API (empieza con `spk_`) |
| `PAGOSYA_WEBHOOK_SECRET` | Se muestra **solo** al crear/rotar el webhook |
| `PAGOSYA_CRON_SECRET` | Lo generas tú (32+ caracteres aleatorios) |
| `PAGOSYA_ALLOWED_ORIGINS` | Orígenes de tu web separados por coma; `*` en desarrollo |
| `APP_BASE_URL` | Base para `success_url` / `cancel_url` |

## 2. Registrar el webhook en PagosYa

```bash
curl -X POST https://nbjwpakpimrqfocsxkda.supabase.co/functions/v1/saas-platform \
  -H "Authorization: Bearer $PAGOSYA_PLATFORM_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "webhook_set",
    "payload": {
      "url": "https://jhrtpaswcotnwiikdtop.supabase.co/functions/v1/pagosya-webhook",
      "enabled": true,
      "rotate": true
    }
  }'
```

Guarda el secreto devuelto como `PAGOSYA_WEBHOOK_SECRET` y vuelve a desplegar o
solo actualiza el secreto (`supabase secrets set` tiene efecto inmediato).

## 3. Alta del comercio (organización)

La organización debe existir en `organization_payment_accounts`. El dueño o un
admin de la organización puede hacerlo **desde la app**: pestaña **COBROS** en la
ficha de la organización → *"Activar cobros QR"*. Eso llama a `merchant_create`
en el backend.

También se puede llamar a la función autenticada directamente:

```bash
curl -X POST https://jhrtpaswcotnwiikdtop.supabase.co/functions/v1/pagosya-api \
  -H "Authorization: Bearer $USER_ACCESS_TOKEN" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"action":"merchant_create","organization_id":"<uuid>","payment_ui":"both"}'
```

Esto crea el comercio (`external_id` = id de la organización) y guarda el
`affiliate_id`. Es idempotente: si ya existe, devuelve el vínculo actual.

## 4. Conectar el banco

Desde la app: pestaña **COBROS** → *"Conectar banco"*. Abre el enlace temporal de
PagosYa en el navegador. La sesión vence en 30 minutos y se genera una nueva en
cada apertura.

También se puede llamar a la función autenticada:

```bash
curl -X POST .../pagosya-api \
  -H "Authorization: Bearer $USER_ACCESS_TOKEN" \
  -d '{"action":"create_bank_session","organization_id":"<uuid>"}'
```

Devuelve `{ "url": "https://www.pagosya.com.bo/plataformas/componente#<token>" }`.
Ábrela como redirección (no iframe).

Para consultar el avance y sincronizar `bank_status`:

```json
{ "action": "merchant_summary", "organization_id": "<uuid>" }
```

Solo `bank.status === "connected"` habilita cobros (`create_checkout` rechaza el
resto con `BANK_INTEGRATION_REQUIRED`).

## 4b. Cobros de la plataforma (membresías)

Las membresías se cobran a la cuenta de la **propia plataforma**, no al banco del
comercio. Primero registra la plataforma como comercio (una sola vez, desde
**Administración → PagosYa → Registrar plataforma**, o como administrador de
plataforma):

```bash
curl -X POST .../pagosya-api \
  -H "Authorization: Bearer $ADMIN_ACCESS_TOKEN" \
  -d '{"action":"platform_merchant_create"}'
```

Guarda el `affiliate_id` en `payment_platform_config`. Sin este paso,
`create_checkout` de una membresía responde `PLATFORM_MERCHANT_NOT_CONFIGURED`
y la app mantiene la solicitud pendiente.

Para pases de clase se usa el `affiliate_id` de la organización dueña de la
clase (requiere banco conectado).

## 4c. Publicaciones de eventos y clases

Desde **Administración → Eventos** o **Clases**, cada registro tiene el botón
**"QR publicación"**:

1. El admin ingresa el monto a cobrar.
2. Se genera un checkout en la cuenta de la plataforma y se muestra el QR y el
   enlace para compartir con la organización.
3. Cuando la organización paga, el webhook registra:
   - una fila en `payments` (`event_publication` / `class_publication`),
   - una fila en `event_publication_payments` / `dance_class_publication_payments`,
   - una **notificación** para todos los administradores de plataforma,
   - y **publica automáticamente**: el evento pasa a `approved` + `published`
     (salvo que esté `suspended`), y la clase pasa a `published`.

No se puede generar dos veces el mismo cobro: si la publicación ya fue pagada,
responde `PUBLICATION_ALREADY_PAID`.

## 4d. Liberación de stock (compras abandonadas)

`pagosya_expire_stale_payments(30)`:

- cancela `payment_intents` pendientes de más de 30 minutos,
- cancela órdenes `pending` sin pago, anula sus tickets/QR, devuelve
  `ticket_types.sold_quantity` y libera butacas.

Se ejecuta automáticamente dentro de `pagosya-reconcile` (cada 5 minutos). Si el
cron no está programado, puedes ejecutarla a mano desde SQL:

```sql
select public.pagosya_expire_stale_payments(30);
```

## 4e. Panel de administración PagosYa

En **Administración → PagosYa** el admin de plataforma tiene:

- **Plataforma**: registrar la plataforma como comercio (una vez) y ver su
  `affiliate_id`.
- **Plan y cartera**: comercios afiliados, cupo del plan y `capacity_used`
  (`overview`).
- **Webhook global**: URL, activar/pausar, y rotar el secreto (se muestra una
  sola vez; hay que guardarlo como `PAGOSYA_WEBHOOK_SECRET`).
- **Comercios afiliados**: organizaciones con su `bank_status`.
- **Últimos eventos**: estado de los eventos recibidos y opción de reintentar los
  fallidos (`webhook_retry`).

Sin `PAGOSYA_PLATFORM_KEY`, las tarjetas de plan y webhook muestran el error de
configuración, pero el panel carga igual.

## 5. Reconciliación automática + limpieza (ya programada)

El job `pagosya-reconcile` está activo con frecuencia `*/5 * * * *` (cada 5
minutos). Usa `PAGOSYA_CRON_SECRET` y los secretos de Vault `project_url` y
`pagosya_cron_secret`.

Para verificarlo:

```sql
select jobid, jobname, schedule, active from cron.job where jobname = 'pagosya-reconcile';
```

Para reprogramarlo (por ejemplo, cada 10 minutos):

```sql
select cron.unschedule(jobid) from cron.job where jobname = 'pagosya-reconcile';

select cron.schedule('pagosya-reconcile', '*/10 * * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/pagosya-reconcile',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'pagosya_cron_secret')
    ),
    body := '{}'::jsonb
  );
$$);
```

Si cambiás `PAGOSYA_CRON_SECRET`, actualizá también el secreto de Vault
`pagosya_cron_secret` con el mismo valor.

## 6. Probar

1. `select * from organization_payment_accounts;` → debe existir el affiliate.
2. Compra de prueba con un monto autorizado (Bs 0,10 o Bs 1).
3. Verifica `orders.status = 'paid'` y `paid_confirmed_at`.
4. Envía el mismo evento dos veces (PagosYa reintenta): debe devolver
   `duplicate` sin duplicar tickets ni pagos.
5. Prueba con firma inválida: el webhook responde **401**.
6. Prueba cerrar la app durante el pago: al reabrir, "Mis entradas" debe
   mostrarlas (la confirmación no depende del cliente).

## 7. Notas y pendientes

- **Órdenes abandonadas:** resuelto con `pagosya_expire_stale_payments(30)`,
  que corre dentro del cron `pagosya-reconcile` cada 5 minutos.
- **Butacas:** se asignan en el servidor al confirmar el pago
  (`pagosya_assign_seats`), no en el cliente.
- **Clases y membresías:** ya usan el mismo checkout (`kind: class_pass` /
  `kind: membership`). Las publicaciones usan `event_publication` /
  `class_publication` desde el panel admin.
- **`purchased_seats`** tiene políticas de escritura públicas heredadas; conviene
  revisarlas en una tarea aparte.
- **Webhook:** si un evento no se puede aplicar (monto/afiliado no coinciden) se
  registra el error y se responde 200 para no entrar en bucle; revisa
  `pagosya_webhook_events.status = 'failed'`.
