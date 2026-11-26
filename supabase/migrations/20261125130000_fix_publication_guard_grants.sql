-- ============================================================================
-- Publicación: corregir permiso de la guarda de membresía mensual.
-- Fecha: 2026-11-25
-- ============================================================================
-- Las guardas de publicación son SECURITY INVOKER (corren como el usuario que
-- publica) y llamaban a `private.organization_has_active_monthly_membership`,
-- que solo tiene EXECUTE para service_role. La organización recibía
-- "permission denied" al publicar. Usamos el wrapper público, que sí está
-- habilitado para authenticated.

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
    if not public.organization_has_active_monthly_membership(new.organization_id) then
      raise exception 'Se requiere una suscripción mensual activa para publicar la clase'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$fn$;

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
    if not public.organization_has_active_monthly_membership(new.organization_id) then
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

notify pgrst, 'reload schema';
