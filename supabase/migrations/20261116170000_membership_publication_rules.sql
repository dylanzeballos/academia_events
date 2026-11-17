-- Reglas de membresía y publicación
--
-- 1. Crear eventos/clases exige una membresía activa vigente.
-- 2. Publicar exige el pago de publicación (QR) o ser admin de plataforma.
--    El pago de publicación NO exige membresía: una organización cuya
--    membresía venció puede publicar pagando el QR.
-- 3. El carrusel del calendario solo muestra organizaciones con membresía
--    activa (beneficio de publicidad).

-- ---------------------------------------------------------------------------
-- 1. Membresía activa
-- ---------------------------------------------------------------------------
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

create or replace function private.organization_can_create_events(
  p_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $fn$
  select private.organization_has_active_membership(p_organization_id);
$fn$;

create or replace function private.organization_can_create_classes(
  p_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $fn$
  select private.organization_has_active_membership(p_organization_id);
$fn$;

revoke all on function private.organization_can_create_classes(uuid)
  from public, anon;
grant execute on function private.organization_can_create_classes(uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Guardas de creación
-- ---------------------------------------------------------------------------
create or replace function private.guard_event_membership()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public, auth
as $fn$
begin
  if tg_op = 'INSERT'
     and not private.is_platform_admin()
     and not private.organization_can_create_events(new.organization_id)
  then
    raise exception 'Se requiere una membresía activa para crear eventos'
      using errcode = '42501';
  end if;
  return new;
end;
$fn$;

create or replace function private.guard_class_membership()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public, auth
as $fn$
begin
  if tg_op = 'INSERT'
     and not private.is_platform_admin()
     and not private.organization_can_create_classes(new.organization_id)
  then
    raise exception 'Se requiere una membresía activa para crear clases'
      using errcode = '42501';
  end if;
  return new;
end;
$fn$;

drop trigger if exists guard_event_membership on public.events;
create trigger guard_event_membership
  before insert on public.events
  for each row execute function private.guard_event_membership();

drop trigger if exists guard_class_membership on public.dance_classes;
create trigger guard_class_membership
  before insert on public.dance_classes
  for each row execute function private.guard_class_membership();

-- ---------------------------------------------------------------------------
-- 3. Guardas de publicación (pago)
--    No exigen membresía: la publicación se habilita con el pago del QR.
-- ---------------------------------------------------------------------------
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
     and not exists (
       select 1 from public.event_publication_payments p
       where p.event_id = new.id
     )
  then
    raise exception 'Se requiere el pago de publicación para publicar el evento'
      using errcode = '42501';
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
     and not exists (
       select 1 from public.dance_class_publication_payments p
       where p.dance_class_id = new.id
     )
  then
    raise exception 'Se requiere el pago de publicación para publicar la clase'
      using errcode = '42501';
  end if;
  return new;
end;
$fn$;

drop trigger if exists guard_event_publication_payment on public.events;
create trigger guard_event_publication_payment
  before update of status on public.events
  for each row execute function private.guard_event_publication_payment();

drop trigger if exists guard_class_publication_payment on public.dance_classes;
create trigger guard_class_publication_payment
  before update of status on public.dance_classes
  for each row execute function private.guard_class_publication_payment();

-- ---------------------------------------------------------------------------
-- 4. Consultas públicas para la app
-- ---------------------------------------------------------------------------
create or replace function public.organization_has_active_membership(
  p_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $fn$
  select private.organization_has_active_membership(p_organization_id);
$fn$;

revoke all on function public.organization_has_active_membership(uuid) from public;
grant execute on function public.organization_has_active_membership(uuid)
  to anon, authenticated;

create or replace function public.organizations_with_active_membership()
returns setof uuid
language sql
stable
security definer
set search_path = pg_catalog, public
as $fn$
  select o.id
  from public.organizations o
  where o.is_active
    and private.organization_has_active_membership(o.id);
$fn$;

revoke all on function public.organizations_with_active_membership() from public;
grant execute on function public.organizations_with_active_membership()
  to anon, authenticated;
