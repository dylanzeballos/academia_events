-- Notificaciones push: al insertar una fila en public.notifications se invoca
-- la Edge Function send-push-notification mediante pg_net.
--
-- Requiere los secretos de Vault:
--   project_url          -> URL del proyecto (https://<ref>.supabase.co)
--   push_webhook_secret  -> mismo valor que el secreto PUSH_WEBHOOK_SECRET
--                           de las Edge Functions.
--
-- Se usa pg_net (asíncrono) para no bloquear ni romper la inserción de la
-- notificación si la función falla.

create or replace function private.dispatch_push_notification()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_project_url text;
  v_secret      text;
begin
  select decrypted_secret into v_project_url
    from vault.decrypted_secrets
   where name = 'project_url';

  select decrypted_secret into v_secret
    from vault.decrypted_secrets
   where name = 'push_webhook_secret';

  -- Sin configuración no se intenta enviar nada.
  if v_project_url is null or v_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := rtrim(v_project_url, '/') || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret
    ),
    body := jsonb_build_object('record', to_jsonb(new)),
    timeout_milliseconds := 5000
  );

  return new;
exception
  when others then
    -- El push nunca debe impedir que se registre la notificación in-app.
    raise warning 'dispatch_push_notification falló: %', sqlerrm;
    return new;
end;
$$;

revoke all on function private.dispatch_push_notification()
  from public, anon, authenticated;

drop trigger if exists trg_notifications_send_push on public.notifications;

create trigger trg_notifications_send_push
  after insert on public.notifications
  for each row
  execute function private.dispatch_push_notification();
