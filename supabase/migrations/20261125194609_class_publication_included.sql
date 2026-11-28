-- ============================================================================
-- Publicar clases: incluido en la suscripción.
-- Fecha: 2026-11-25
-- ============================================================================
-- La publicación de clases ya no se cobra aparte: si la organización tiene su
-- suscripción mensual activa, la clase se publica sin pago adicional.
-- La publicación de eventos sigue exigiendo el pago único.

-- Guarda de publicación de clases: solo valida la suscripción mensual vigente.
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
  end if;
  return new;
end;
$fn$;

-- Estado de publicación de la clase: ya no hay precio ni pago pendiente.
-- Se conserva `already_paid` para detectar pagos de publicación anteriores a
-- este cambio (no se reembolsan ni se vuelven a cobrar).
create or replace function public.class_publication_status(p_class_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $fn$
declare
  v_organization_id uuid;
  v_paid boolean;
  v_monthly boolean;
  v_allowed boolean;
begin
  select dc.organization_id into v_organization_id
    from public.dance_classes dc
   where dc.id = p_class_id;

  if v_organization_id is null then
    raise exception 'Clase no encontrada' using errcode = 'P0002';
  end if;

  select private.is_platform_admin()
         or exists (
           select 1
             from public.organization_members m
            where m.organization_id = v_organization_id
              and m.user_id = auth.uid()
              and m.is_active
              and m.role in ('owner', 'admin')
         )
    into v_allowed;

  if not coalesce(v_allowed, false) then
    raise exception 'No autorizado' using errcode = '42501';
  end if;

  select exists (
    select 1 from public.dance_class_publication_payments p
     where p.dance_class_id = p_class_id
  ) into v_paid;

  v_monthly := private.organization_has_active_monthly_membership(
    v_organization_id
  );

  return jsonb_build_object(
    'already_paid', coalesce(v_paid, false),
    'monthly_membership', coalesce(v_monthly, false),
    'requires_payment', false
  );
end;
$fn$;

revoke all on function public.class_publication_status(uuid) from public, anon;
grant execute on function public.class_publication_status(uuid)
  to authenticated, service_role;

notify pgrst, 'reload schema';
