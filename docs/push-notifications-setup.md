# Notificaciones push (FCM)

Flujo completo:

```
insert en public.notifications
  → trigger private.dispatch_push_notification()  (pg_net, asíncrono)
  → Edge Function send-push-notification
  → FCM v1 (Firebase)
  → Android / iOS
```

## Backend (ya configurado en el proyecto)

1. **Secreto de la Edge Function**: `PUSH_WEBHOOK_SECRET`.
   ```bash
   supabase secrets set PUSH_WEBHOOK_SECRET=<valor-aleatorio>
   ```
2. **Secreto de Vault** (lo lee el trigger): `push_webhook_secret` con el mismo
   valor. También se usa `project_url`.
   ```sql
   select vault.create_secret('<mismo-valor>', 'push_webhook_secret',
     'Header secret para send-push-notification');
   ```
3. **Credencial de Firebase**: `FIREBASE_SERVICE_ACCOUNT` (JSON de la cuenta de
   servicio con permiso *Firebase Cloud Messaging API*).
4. **Migración**: `supabase/migrations/20261116180000_push_notifications_webhook.sql`
   crea el trigger sobre `public.notifications`.
5. **Deploy de la función**:
   ```bash
   supabase functions deploy send-push-notification --no-verify-jwt
   ```

La función usa `SUPABASE_SERVICE_ROLE_KEY` para leer `user_fcm_tokens`, borra
tokens inválidos (`UNREGISTERED`) y devuelve un resumen
`{status, count, sent, failed, removed}`.

### Verificar el flujo

```sql
-- Respuestas de pg_net (200 = la función respondió)
select id, status_code, error_msg, content, created
  from net._http_response order by id desc limit 5;
```

```sql
-- Simular un aviso para un usuario sin tokens: debe responder "skipped"
insert into public.notifications (user_id, type, title, message)
values ('<uuid-de-un-usuario>', 'push_test', 'Prueba', 'Mensaje');
```

Si el trigger no está configurado, la función no recibe nada y en los logs de
`send-push-notification` no aparece ninguna ejecución.

## Android

- `google-services.json` en `android/app/` y plugin `com.google.gms.google-services`.
- Canal `academia_notifications` creado en `MainActivity.kt`
  (`IMPORTANCE_HIGH` → banner en pantalla).
- Permiso `POST_NOTIFICATIONS` en `AndroidManifest.xml` (Android 13+).
- Con la app abierta, FCM no muestra la notificación del sistema: la app muestra
  un aviso flotante con acción **Ver** que abre la pantalla correspondiente.
- Al tocar el push (app en segundo plano o cerrada) se navega según el `data`
  de la notificación: `route=my_invitations` abre **Mis invitaciones**; el resto
  abre la pestaña de Avisos.
- El token se elimina de `user_fcm_tokens` al cerrar sesión.

## Invitaciones

Al insertar una fila en `organization_invitations` (migración
`20261125140000_invitations_accept_decline_notify.sql`) se crea un aviso para el
usuario invitado, si ya tiene cuenta:

- `type = 'organization_invitation'`
- `data = { invitation_id, organization_id, route: 'my_invitations' }`

El trigger de `notifications` dispara el push automáticamente, con el mismo
`route`, así que tocar la notificación lleva a **Mis invitaciones** para
aceptar o rechazar.

## Vigencia y recordatorios

- Las clases generan **un solo recordatorio, 1 hora antes** (`class_reminder_1h`,
  job `frequent-class-1h-alerts` cada 15 minutos). Ya no existe el aviso
  `class_reminder_today`.
- Los avisos se muestran solo durante **el día en que se generan** (hora de
  Bolivia).
- El job `cleanup-daily-notifications` (04:10 UTC = 00:10 Bolivia) elimina los
  avisos de días anteriores con `public.fn_cleanup_daily_notifications()`.

## iOS (pendiente de configuración manual)

El código Dart ya soporta iOS, pero falta la configuración nativa:

1. Registrar la app iOS en Firebase con el bundle id
   (`com.example.academiaEvents`, ver `ios/Runner.xcodeproj`).
2. Descargar `GoogleService-Info.plist` y agregarlo al target `Runner` en Xcode.
   **Sin este archivo `Firebase.initializeApp()` falla al iniciar en iOS.**
3. En Firebase Console → *Project Settings → Cloud Messaging*: subir la
   **APNs Authentication Key** (`.p8`) con el Key ID y el Team ID de Apple.
4. En Xcode → target `Runner` → *Signing & Capabilities*:
   - agregar **Push Notifications**;
   - agregar **Background Modes → Remote notifications**.
5. Generar un build en un dispositivo físico (los simuladores no reciben push
   APNs).

## Limitaciones conocidas

- Las notificaciones al insertarlas en un bloque que luego hace rollback pueden
  enviarse igualmente: `pg_net` es asíncrono y no participa de la transacción.
- Si el usuario deniega el permiso de notificaciones, no se vuelve a pedir
  automáticamente; debe habilitarlo desde los ajustes del sistema.
