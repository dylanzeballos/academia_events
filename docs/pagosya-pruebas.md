# PagosYa · pruebas y homologación

> Estado verificado el **16-nov-2026** contra el proyecto `jhrtpaswcotnwiikdtop`.
> Este documento separa lo que se puede probar con la clave sandbox (`sk_test_`)
> de lo que PagosYa exige homologar en producción.

---

## 1. Estado actual de la configuración

| Elemento | Estado | Detalle |
|---|---|---|
| `PAGOSYA_SANDBOX_KEY` (Supabase + local) | ✅ | Clave `sk_test_` válida |
| `PAGOSYA_MODE` (Supabase + local) | ✅ `sandbox` | El cobro usa el sandbox |
| `pagosya-api` desplegada | ✅ v9 | Incluye `PAGOSYA_MODE`, `PAGOSYA_SANDBOX_KEY` y `sandbox-create-checkout` |
| `PAGOSYA_PLATFORM_KEY` (`spk_`) | ⚠️ **falta** | No está en los secrets de Supabase; el `.env` local tiene el placeholder `spk_xxx` |
| `PAGOSYA_WEBHOOK_SECRET` | ⚠️ **placeholder** | `whsec_xxx`; hay que generarlo al registrar el webhook |
| `organization_payment_accounts` | 0 filas | Ninguna organización está dada de alta como comercio |
| `payment_platform_config` | 0 filas | La plataforma no está registrada como comercio |
| `pagosya_webhook_events` | 0 filas | Nunca llegó un webhook |
| Cron `pagosya-reconcile` | ✅ activo | `*/5 * * * *` |
| Vault (`project_url`, `pagosya_cron_secret`) | ✅ | Presentes |

**Conclusión:** el sandbox está listo y probado. La homologación de producción
todavía no puede empezar porque faltan la clave de plataforma, el comercio de la
plataforma, el alta de organizaciones y el webhook.

---

## 2. Pruebas automáticas de sandbox (ya ejecutadas)

```bash
node scripts/pagosya-sandbox-smoke.mjs
```

Resultado de la última corrida: **9/9 PASS**.

| ID | Prueba | Resultado |
|---|---|---|
| T1 | Checkout válido devuelve QR ficticio (`201`, `environment=sandbox`, `livemode=false`) | PASS |
| T2 | `branding_mode=white_label` devuelve QR | PASS |
| T3 | `order_id` duplicado → `409 DUPLICATE_ORDER_ID` | PASS |
| T4 | Clave inválida → `401` | PASS |
| T5 | Falta `success_url` → `400` | PASS |
| T6 | Monto `0` → `400` | PASS |
| T7 | `metadata` propia aceptada | PASS |
| T8 | `expiration_minutes=60` aceptado | PASS |
| T9 | Headers de rate limit (`limit=60`) | PASS |

Evidencia generada (reporte + QR en PNG):

```
docs/pagosya-pruebas/<fecha>/report.md
docs/pagosya-pruebas/<fecha>/report.json
docs/pagosya-pruebas/<fecha>/qr-embedded.png
docs/pagosya-pruebas/<fecha>/qr-white-label.png
```

> El sandbox **no** confirma pagos ni envía webhooks: valida autenticación,
> validación de datos, respuestas y el QR ficticio. Así lo define PagosYa.

---

## 3. Pruebas del flujo dentro de la app (sandbox)

Todo el flujo de la app debe quedar cubierto con estas pruebas. No hace falta
que la organización tenga banco conectado ni `affiliate_id`.

### 3.0 Pantalla de pago: cuenta atrás y botones

- La pantalla muestra **"Vence en mm:ss"** calculado con el `expires_at` que
  devuelve el backend (el del proveedor; 15 min como respaldo). Al llegar a cero
  muestra **"Cobro expirado"** y deshabilita los botones.
- El sondeo automático cada 4 s ya **no redibuja** el QR ni muestra spinner.
- **"Ya pagué, verificar"** consulta el estado real. En sandbox siempre responde
  pendiente y avisa que hay que usar la simulación.
- **"Simular pago (sandbox)"** pide confirmación y recién ahí marca el pedido
  como pagado (sin cobro real).

### 3.1 Tickets de evento

1. Iniciar sesión con un usuario de prueba.
2. Crear/publicar un evento (la publicación también usa sandbox).
3. Comprar una entrada.
4. **Esperado:** se abre la pantalla de pago con un QR y el aviso
   *"Modo sandbox: este QR es ficticio…"*.
5. Tocar **"Simular pago (sandbox)"**.
   **Esperado:** la orden pasa a `paid` y se abre el QR de la entrada.
6. Ir a "Mis entradas" → la entrada aparece y es válida para check-in.

Verificación en base de datos:

```sql
select id, status, paid_confirmed_at, pagosya_checkout_id,
       pagosya_qr_data_url is not null as tiene_qr, created_at
from public.orders
where pagosya_checkout_id like 'sandbox:%'
order by created_at desc
limit 10;

-- tickets y butacas emitidos
select t.id, t.status, t.seat_id
from public.tickets t
join public.orders o on o.id = t.order_id
where o.pagosya_checkout_id like 'sandbox:%'
order by t.created_at desc
limit 10;
```

### 3.2 Pase de clase y membresía

1. Inscribirse a una clase y comprar el pase.
2. Solicitar una membresía.
3. **Esperado:** mismo QR ficticio y aviso sandbox.
4. Tocar **"Simular pago (sandbox)"**.
   **Esperado:** el pase/membresía se activa y vuelve a la pantalla anterior.

> Si la organización **no activó los cobros QR**, la hoja de compra muestra el
> mensaje explícito *"La organización todavía no activó los cobros QR…"* en
> lugar del genérico de permisos.
> "Mis clases" ahora filtra por `user_id`, así el staff no ve inscripciones de
> otros alumnos con el botón de compra.

```sql
select id, kind, status, affiliate_id, pagosya_checkout_id,
       qr_data_url is not null as tiene_qr, paid_at, created_at
from public.payment_intents
where pagosya_checkout_id like 'sandbox:%'
order by created_at desc
limit 10;
```

### 3.2b Datos de prueba ya cargados (16-nov-2026)

| Organización | Plan | Estado | Pago |
|---|---|---|---|
| `kintun` | Plan Sandbox · Mensual (Bs 1) | `pending` | `pending` (`manual_pending`) |
| `lala` | Plan Sandbox · Anual (Bs 10) | `active` (06-11-2026 → 06-11-2027) | `paid` |
| `dancec`, `la clave` | — | sin membresía | — |

Recorrido recomendado:

- **kintun**: abrir *Membresía* → **Solicitar** el plan mensual → reutiliza la
  solicitud pendiente → QR sandbox → **Simular pago (sandbox)** → queda `active`.
- **lala**: comprobar que se muestra una membresía vigente.
- **dancec / la clave**: probar la solicitud desde cero (crea suscripción
  `pending` + pago `pending`).

Aprobación administrativa (solo admin de plataforma, vía RPC):

```sql
select public.admin_verify_subscription('<subscription-id>', true);  -- activar
select public.admin_verify_subscription('<subscription-id>', false); -- rechazar
```

> No existe un endpoint HTTP de admin para *crear* membresías: se crean con
> `request_organization_membership` (admin de la organización) o con
> `admin_verify_subscription` (aprobar/rechazar). El seed anterior se cargó
> directamente en la base con fines de prueba.

### 3.3 Publicaciones (admin de plataforma)

1. Administración → Eventos/Clases → **QR publicación**.
2. Ingresar un monto.
3. **Esperado:** QR ficticio.
4. Para confirmar la publicación de prueba, llamar a la acción
   `sandbox_confirm` con el `intent_id` (el diálogo de QR todavía no tiene el
   botón de simulación):

```bash
curl -X POST https://jhrtpaswcotnwiikdtop.supabase.co/functions/v1/pagosya-api \
  -H "Authorization: Bearer $USER_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"sandbox_confirm","intent_id":"<intent-id>"}'
```

### Criterios de aceptación

- [ ] El QR se genera en las cuatro rutas (ticket, pase, membresía, publicación).
- [ ] El aviso de sandbox es visible.
- [ ] El polling no produce errores y nunca marca `paid`.
- [ ] Los registros quedan `pending` y con `pagosya_checkout_id` prefijado `sandbox:`.
- [ ] "Simular pago (sandbox)" confirma y emite tickets/butacas/QR.
- [ ] El pase y la membresía se activan tras simular el pago.
- [ ] Un segundo `sandbox_confirm` responde `already_paid` sin duplicar.
- [ ] Con `PAGOSYA_MODE=live`, `sandbox_confirm` responde `403 SANDBOX_DISABLED`.
- [ ] `pagosya_expire_stale_payments(30)` cancela los pendientes sin simular.

---

## 4. Homologación en producción (lo que PagosYa pide)

PagosYa **no** homologa con `sk_test_`: el sandbox no procesa pagos ni callbacks.
La homologación se hace con clave de producción y un pago controlado de
**Bs 0,10 o Bs 1**.

### 4.1 Requisitos previos (faltan hoy)

| # | Requisito | Cómo se obtiene |
|---|---|---|
| 1 | Plan SaaS activo o activación por comisión | PagosYa → `/planes` |
| 2 | Clave de plataforma `spk_` | PagosYa → Integración API |
| 3 | Plataforma registrada como comercio | `platform_merchant_create` o panel **Administración → PagosYa** |
| 4 | Comercio por organización + `affiliate_id` | **COBROS → Activar cobros QR** |
| 5 | Banco del comercio `connected` | **COBROS → Conectar banco** |
| 6 | Webhook HTTPS público en 443 | Registrar y guardar su secreto |

### 4.2 Configurar secretos de producción

```bash
supabase secrets set PAGOSYA_MODE=live
supabase secrets set PAGOSYA_PLATFORM_KEY=spk_...
# después de registrar el webhook:
supabase secrets set PAGOSYA_WEBHOOK_SECRET=whsec_...
```

### 4.3 Registrar el webhook y obtener el secreto

```bash
curl -X POST https://nbjwpakpimrqfocsxkda.supabase.co/functions/v1/saas-platform \
  -H "Authorization: Bearer spk_..." \
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

El secreto se muestra **una sola vez**: guardarlo en `PAGOSYA_WEBHOOK_SECRET` y
verificar con `webhook_get`.

### 4.4 Alta de comercios

- Plataforma: **Administración → PagosYa → Registrar plataforma** (una vez).
- Cada organización: **COBROS → Activar cobros QR** → **Conectar banco**.
- Comprobar:

```sql
select organization_id, affiliate_id, bank_status, bank_updated_at
from public.organization_payment_accounts;

select affiliate_id, external_id
from public.payment_platform_config;
```

### 4.5 Pago controlado de Bs 0,10 / Bs 1

1. Crear una compra real con monto mínimo autorizado.
2. Pagar el QR desde la banca del comercio.
3. Verificar que el webhook llegue y confirme **una sola vez**:

```sql
select id, status, paid_confirmed_at, pagosya_checkout_id
from public.orders
where id = '<order-id>';

select event_id, event_type, status, error, received_at
from public.pagosya_webhook_events
order by received_at desc
limit 10;
```

4. Verificar que `checkout_id` sea el real (sin prefijo `sandbox:`).

### 4.6 Firma e idempotencia

- Enviar el mismo evento dos veces: la segunda debe registrar `duplicate` sin
  duplicar tickets ni pagos.
- Enviar con `X-PagosYa-Signature` inválida: el webhook debe responder **401**.

```bash
curl -i -X POST https://jhrtpaswcotnwiikdtop.supabase.co/functions/v1/pagosya-webhook \
  -H "Content-Type: application/json" \
  -H "X-PagosYa-Signature: t=1,v1=0000000000000000000000000000000000000000000000000000000000000000" \
  -d '{"id":"test","event":"checkout.completed"}'
# Esperado: HTTP 401
```

### 4.7 Checklist final de PagosYa

- [ ] `bank.status = connected` y `checkout_allowed = true`.
- [ ] Venta de Bs 0,10/1 confirmada con la página cerrada.
- [ ] Firma, empresa, referencia, monto y moneda validados.
- [ ] Evento duplicado no duplica la entrega.
- [ ] Eventos fallidos visibles y reintentables (`pagosya_webhook_events`).
- [ ] Separación entre organizaciones comprobada.
- [ ] Liquidación de comisión probada con las cuentas acordadas.

---

## 5. Reglas de membresía y publicación (activas)

Implementadas en `supabase/migrations/20261116170000_membership_publication_rules.sql`.

| Regla | Cómo se aplica |
|---|---|
| Crear evento | Trigger `guard_event_membership` exige membresía activa vigente |
| Crear clase | Trigger `guard_class_membership` exige membresía activa vigente |
| Publicar evento/clase | Trigger de pago: exige fila en `event_publication_payments` / `dance_class_publication_payments` (o admin de plataforma) |
| Publicar sin membresía | Permitido si el pago de publicación existe (la membresía pudo vencer después de crear) |
| Carrusel del calendario | Solo organizaciones con `organization_has_active_membership(id) = true` |
| Aviso en la app | Las pantallas de creación muestran el bloqueo y el botón **Ver membresías** |

Flujo nuevo:

1. La organización con membresía activa crea el evento/clase → queda en **`draft`**.
2. El admin de plataforma genera el **QR publicación** (Administración → Eventos/Clases).
3. Al confirmarse el pago, `fulfill_publication` publica automáticamente (`published` + `approved`) sin volver a exigir membresía.
4. Solo las organizaciones con membresía activa aparecen en el carrusel del calendario principal.

Verificación:

```sql
select o.name, public.organization_has_active_membership(o.id) as membresia
from public.organizations o order by o.name;

select o.name from public.organizations o
where o.id in (select public.organizations_with_active_membership())
order by o.name;
```

Estado actual de los datos de prueba: `dancec` y `lala` tienen membresía activa; `kintun` tiene una solicitud pendiente; `la clave` no tiene ninguna.

## 6. Evidencia para enviar a PagosYa

- `docs/pagosya-pruebas/<fecha>/report.md` y `report.json`.
- Capturas del QR ficticio y del aviso de sandbox.
- Resultado de las consultas SQL de la sección 3.
- (Producción) comprobante del pago de Bs 0,10/1, filas de `orders` y
  `pagosya_webhook_events`, y logs de la Edge Function.

---

## 7. Comandos útiles

```bash
# Ejecutar las pruebas de sandbox
node scripts/pagosya-sandbox-smoke.mjs

# Ver qué secreto está cargado (nombres, no valores)
supabase secrets list --project-ref jhrtpaswcotnwiikdtop

# Estado de las funciones
supabase functions list --project-ref jhrtpaswcotnwiikdtop

# Volver a desplegar tras cambiar el código
supabase functions deploy pagosya-api --project-ref jhrtpaswcotnwiikdtop
```
