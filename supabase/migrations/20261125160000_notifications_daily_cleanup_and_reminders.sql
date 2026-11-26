-- ============================================================================
-- Avisos: recordatorio solo 1 hora antes, limpieza diaria.
-- Fecha: 2026-11-25
-- ============================================================================
-- 1. Las clases notifican únicamente 1 hora antes (se quita el aviso "hoy").
-- 2. Los avisos se guardan solo para el día actual: un cron diario elimina los
--    anteriores a la medianoche de Bolivia.
-- 3. El job de la mañana deja de generar avisos de clase.

create or replace function public.fn_notify_upcoming_class_sessions()
returns void
language plpgsql
security definer
as $fn$
begin
  -- Recordatorio inmediato: empieza en 1 hora.
  insert into public.notifications (user_id, type, title, message, data, dedup_key)
  select distinct
    ce.user_id,
    'class_reminder_1h',
    '¡Tu clase comienza en 1 hora!',
    'La clase de "' || dc.title || '" inicia en breve a las '
      || to_char(s.start_at at time zone dc.timezone, 'HH24:MI')
      || '. ¡Nos vemos en la pista!',
    jsonb_build_object(
      'session_id', s.id,
      'dance_class_id', dc.id
    ),
    'class_1h_' || cst.id
  from public.class_session_tickets cst
  join public.dance_class_sessions s on s.id = cst.session_id
  join public.class_passes cp on cp.id = cst.class_pass_id
  join public.class_enrollments ce on ce.id = cp.enrollment_id
  join public.dance_classes dc on dc.id = s.dance_class_id
  where cst.status = 'issued'
    and s.status = 'scheduled'
    and s.start_at >= (now() + interval '45 minutes')
    and s.start_at <= (now() + interval '75 minutes')
  on conflict (dedup_key) do nothing;
end;
$fn$;

-- Avisos de días anteriores se eliminan automáticamente.
create or replace function public.fn_cleanup_daily_notifications()
returns void
language sql
security definer
set search_path = pg_catalog, public
as $fn$
  delete from public.notifications
   where created_at < (
     ((now() at time zone 'America/La_Paz')::date)
       at time zone 'America/La_Paz'
   );
$fn$;

revoke all on function public.fn_cleanup_daily_notifications()
  from public, anon, authenticated;

-- Quita los avisos "hoy" que ya se hayan generado.
delete from public.notifications
 where type = 'class_reminder_today';

-- El job de la mañana ya no toca avisos de clase.
select cron.unschedule(jobid) from cron.job where jobname = 'daily-morning-alerts';

select cron.schedule(
  'daily-morning-alerts',
  '0 12 * * *',
  $job$
    select public.fn_notify_subscription_expirations();
    select public.fn_notify_upcoming_events();
  $job$
);

-- Limpieza diaria a las 00:10 de Bolivia (04:10 UTC).
select cron.unschedule(jobid)
  from cron.job
 where jobname = 'cleanup-daily-notifications';

select cron.schedule(
  'cleanup-daily-notifications',
  '10 4 * * *',
  $job$select public.fn_cleanup_daily_notifications();$job$
);

-- Arranca limpio: solo quedan los avisos de hoy.
select public.fn_cleanup_daily_notifications();

notify pgrst, 'reload schema';
