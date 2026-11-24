-- ============================================================================
-- Publicación: suscripción mensual obligatoria.
-- Fecha: 2026-11-17
-- ============================================================================
-- La creación de eventos/clases mantiene la regla previa (cualquier
-- suscripción activa). La PUBLICACIÓN exige además que la suscripción sea
-- mensual, junto con el pago de publicación.

create or replace function private.organization_has_active_membership(
  p_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $fn$
  select exists (
    select 1
    from public.organizations o
    join public.subscriptions s on s.organization_id = o.id
    where o.id = p_organization_id
      and o.is_active
      and s.status = 'active'::public.subscription_status
      and (s.current_period_start is null or s.current_period_start <= now())
      and (s.current_period_end is null or s.current_period_end > now())
  );
$fn$;

revoke all on function private.organization_has_active_membership(uuid)
  from public, anon, authenticated;
grant execute on function private.organization_has_active_membership(uuid)
  to service_role;

create or replace function private.organization_has_active_monthly_membership(
  p_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $fn$
  select exists (
    select 1
    from public.organizations o
    join public.subscriptions s on s.organization_id = o.id
    where o.id = p_organization_id
      and o.is_active
      and s.status = 'active'::public.subscription_status
      and s.billing_interval = 'month'
      and (s.current_period_start is null or s.current_period_start <= now())
      and (s.current_period_end is null or s.current_period_end > now())
  );
$fn$;

revoke all on function private.organization_has_active_monthly_membership(uuid)
  from public, anon, authenticated;
grant execute on function private.organization_has_active_monthly_membership(uuid)
  to service_role;

create or replace function public.organization_has_active_monthly_membership(
  p_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $fn$
  select private.organization_has_active_monthly_membership(p_organization_id);
$fn$;

revoke all on function public.organization_has_active_monthly_membership(uuid)
  from public;
grant execute on function public.organization_has_active_monthly_membership(uuid)
  to anon, authenticated;

-- Guardas de publicación con membresía mensual.
create or replace function private.guard_event_publication_payment()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public, auth
as $fn$
begin
  if new.status = 'published'::public.event_status
     and old.status is distinct from new.status
     and not private.is_platform_admin()
  then
    if not private.organization_has_active_monthly_membership(new.organization_id) then
      raise exception 'Se requiere una suscripción mensual activa para publicar el evento'
        using errcode = '42501';
    end if;

    if not exists (
      select 1 from public.event_publication_payments p
      where p.event_id = new.id
    ) then
      raise exception 'Se requiere el pago de publicación para publicar el evento'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$fn$;

create or replace function private.guard_class_publication_payment()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public, auth
as $fn$
begin
  if new.status = 'published'::public.class_status
     and old.status is distinct from new.status
     and not private.is_platform_admin()
  then
    if not private.organization_has_active_monthly_membership(new.organization_id) then
      raise exception 'Se requiere una suscripción mensual activa para publicar la clase'
        using errcode = '42501';
    end if;

    if not exists (
      select 1 from public.dance_class_publication_payments p
      where p.dance_class_id = new.id
    ) then
      raise exception 'Se requiere el pago de publicación para publicar la clase'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$fn$;

-- Los planes anuales siguen siendo válidos para otros beneficios; solo no
-- habilitan la publicación.
drop trigger if exists guard_monthly_subscription on public.subscriptions;
drop function if exists private.guard_monthly_subscription();

notify pgrst, 'reload schema';
