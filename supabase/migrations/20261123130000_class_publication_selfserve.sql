-- ============================================================================
-- Publicación de clases: pago por QR desde la organización.
-- Fecha: 2026-11-23
-- ============================================================================
-- Hasta ahora solo el admin de plataforma generaba el QR de publicación (con
-- el monto que escribía a mano). Para que la academia pueda pagar directamente
-- desde el detalle de la clase hacen falta:
--   1. Un precio de publicación configurable por la plataforma.
--   2. Una consulta segura del estado de publicación de una clase.

alter table public.payment_platform_config
  add column if not exists class_publication_price numeric,
  add column if not exists event_publication_price numeric;

-- Estado de publicación de una clase para su organización.
-- Devuelve: si ya está pago, el precio vigente y si tiene membresía mensual.
create or replace function public.class_publication_status(p_class_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $fn$
declare
  v_organization_id uuid;
  v_price numeric;
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

  select class_publication_price into v_price
    from public.payment_platform_config
   where id = true;

  select exists (
    select 1 from public.dance_class_publication_payments p
     where p.dance_class_id = p_class_id
  ) into v_paid;

  v_monthly := private.organization_has_active_monthly_membership(
    v_organization_id
  );

  return jsonb_build_object(
    'already_paid', coalesce(v_paid, false),
    'price', v_price,
    'monthly_membership', coalesce(v_monthly, false)
  );
end;
$fn$;

revoke all on function public.class_publication_status(uuid) from public, anon;
grant execute on function public.class_publication_status(uuid)
  to authenticated, service_role;

notify pgrst, 'reload schema';
