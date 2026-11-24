-- ============================================================================
-- La suscripción de la organización debe ser mensual.
-- Fecha: 2026-11-17
-- ============================================================================
-- Se exige para crear eventos/clases y para publicar (además del pago de
-- publicación). Una suscripción anual ya no habilita estos beneficios.

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
      and s.billing_interval = 'month'
      and (s.current_period_start is null or s.current_period_start <= now())
      and (s.current_period_end is null or s.current_period_end > now())
  );
$fn$;

revoke all on function private.organization_has_active_membership(uuid)
  from public, anon, authenticated;
grant execute on function private.organization_has_active_membership(uuid)
  to service_role;

notify pgrst, 'reload schema';
