-- ============================================================================
-- Solo membresías mensuales.
-- Fecha: 2026-11-17
-- ============================================================================
-- La publicación y la creación de eventos/clases exigen una suscripción
-- mensual activa. Para evitar planes anuales inconsistentes, se bloquea la
-- creación de suscripciones con planes que no sean mensuales.

create or replace function private.guard_monthly_subscription()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $fn$
declare
  v_interval public.subscription_interval;
begin
  select sp.interval into v_interval
    from public.subscription_plans sp
   where sp.id = new.plan_id;

  if v_interval is not null
     and v_interval <> 'monthly'::public.subscription_interval then
    raise exception 'Solo se permiten membresías mensuales'
      using errcode = '42501';
  end if;

  return new;
end;
$fn$;

drop trigger if exists guard_monthly_subscription on public.subscriptions;
create trigger guard_monthly_subscription
  before insert or update of plan_id on public.subscriptions
  for each row execute function private.guard_monthly_subscription();

notify pgrst, 'reload schema';
