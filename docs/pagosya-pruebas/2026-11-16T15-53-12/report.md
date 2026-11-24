# PagosYa · pruebas de sandbox

- Fecha: 2026-11-16T15:53:14.846Z
- Endpoint: https://nbjwpakpimrqfocsxkda.supabase.co/functions/v1/sandbox-create-checkout
- Modo configurado: sandbox
- Clave: sk_test_… (51 caracteres)
- Resultado: **9/9 pruebas OK**

| ID | Prueba | Esperado | Estado | HTTP | Detalle |
|---|---|---|---|---|---|
| T1 | Checkout válido devuelve QR ficticio | 201 + environment=sandbox, livemode=false, status=pending, QR data URL | PASS | 201 | checkout_id=69ebdf18-5d3c-4b6f-840c-cec8f394ed67 · expires_at=2026-11-16T16:23:12.837+00:00 · QR guardado en C:\Users\zeballos\Documents\programas\academia\academia_events\docs\pagosya-pruebas\2026-11-16T15-53-12\qr-embedded.png |
| T2 | White-label devuelve QR sin sello | 201 + QR data URL | PASS | 201 | QR guardado en C:\Users\zeballos\Documents\programas\academia\academia_events\docs\pagosya-pruebas\2026-11-16T15-53-12\qr-white-label.png (revisar visualmente que no tenga sello) |
| T3 | order_id duplicado se rechaza | 409 DUPLICATE_ORDER_ID | PASS | 409 | primera=201 · segunda=409 · error=DUPLICATE_ORDER_ID |
| T4 | Clave inválida se rechaza | 401 | PASS | 401 | error=Invalid or revoked sandbox API key |
| T5 | Falta success_url | 400 | PASS | 400 | error=success_url and cancel_url are required |
| T6 | Monto inválido (0) se rechaza | 400 | PASS | 400 | error=Invalid amount |
| T7 | Metadatos propios se aceptan | 201 | PASS | 201 | error=- |
| T8 | Expiración dentro del rango sandbox | 201 con expiration_minutes=60 | PASS | 201 | expires_at=2026-11-16T16:53:14.71+00:00 |
| T9 | Headers de rate limit presentes | X-RateLimit-Limit / Remaining | PASS | 201 | limit=60 · remaining=59 |

> El sandbox no confirma pagos ni envía webhooks: estas pruebas validan
> autenticación, validación de datos, respuestas y generación del QR ficticio.

## Verificación visual

- `qr-embedded.png`: incluye el sello **PagosYa / pagosya.com.bo**.
- `qr-white-label.png`: **no** incluye el sello (white-label correcto).
