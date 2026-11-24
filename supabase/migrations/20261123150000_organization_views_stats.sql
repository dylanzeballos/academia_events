-- ============================================================================
-- Estadísticas de visitas de una organización.
-- Fecha: 2026-11-23
-- ============================================================================
-- `get_organization_views_stats` devuelve en un solo jsonb: el total histórico,
-- las visitas y usuarios únicos del mes actual (hora de Bolivia), el historial
-- de los últimos 12 meses y el desglose por origen del mes actual.
--
-- Autorización: miembro activo de la organización (salvo `check_in_staff`) o
-- admin de plataforma. Cualquier otro usuario recibe 42501.
--
-- Nota: la función ya existía en la base remota sin migración (drift); esta
-- migración la formaliza. Es idempotente (`create or replace`).

create or replace function public.get_organization_views_stats(
  p_org_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_uid uuid := auth.uid();
  v_total bigint;
  v_month integer;
  v_unique_month integer;
  v_history jsonb;
  v_sources jsonb;
  v_month_start timestamptz :=
    date_trunc('month', now() AT TIME ZONE 'America/La_Paz') AT TIME ZONE 'America/La_Paz';
  v_month_end timestamptz :=
    (date_trunc('month', now() AT TIME ZONE 'America/La_Paz') + interval '1 month') AT TIME ZONE 'America/La_Paz';
begin
  -- Autorización: miembro activo (que no sea check_in_staff) o admin de plataforma
  if v_uid is null then
    raise exception 'No autenticado' using errcode = '28000';
  end if;

  if not (
    exists (
      select 1
      from public.organization_members m
      where m.organization_id = p_org_id
        and m.user_id = v_uid
        and m.is_active
        and m.role::text <> 'check_in_staff'
    )
    or exists (
      select 1
      from public.user_roles ur
      where ur.user_id = v_uid
        and ur.role::text = 'admin'
    )
  ) then
    raise exception 'No autorizado para ver las estadísticas de esta organización'
      using errcode = '42501';
  end if;

  -- Total histórico
  select greatest(
    coalesce(o.views_count, 0),
    (select count(*) from public.organization_views ov where ov.organization_id = p_org_id)
  )
  into v_total
  from public.organizations o
  where o.id = p_org_id;

  -- Visitas del mes actual (hora de Bolivia)
  select count(*)::integer, count(distinct user_id)::integer
  into v_month, v_unique_month
  from public.organization_views
  where organization_id = p_org_id
    and viewed_at >= v_month_start
    and viewed_at < v_month_end;

  -- Historial de los últimos 12 meses
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'year_month', ym,
        'views_count', cnt,
        'unique_users', uniq
      ) order by ym desc
    ),
    '[]'::jsonb
  )
  into v_history
  from (
    select
      to_char(viewed_at AT TIME ZONE 'America/La_Paz', 'YYYY-MM') as ym,
      count(*)::integer as cnt,
      count(distinct user_id)::integer as uniq
    from public.organization_views
    where organization_id = p_org_id
    group by ym
    order by ym desc
    limit 12
  ) sub;

  -- Desglose por origen del mes actual
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'source', coalesce(source, 'app'),
        'count', cnt
      ) order by cnt desc
    ),
    '[]'::jsonb
  )
  into v_sources
  from (
    select source, count(*)::integer as cnt
    from public.organization_views
    where organization_id = p_org_id
      and viewed_at >= v_month_start
      and viewed_at < v_month_end
    group by source
  ) src;

  return jsonb_build_object(
    'total_views', coalesce(v_total, 0),
    'current_month_views', coalesce(v_month, 0),
    'unique_month_users', coalesce(v_unique_month, 0),
    'monthly_history', v_history,
    'month_sources', v_sources
  );
end;
$fn$;

revoke all on function public.get_organization_views_stats(uuid) from public;
revoke all on function public.get_organization_views_stats(uuid) from anon;
grant execute on function public.get_organization_views_stats(uuid)
  to authenticated, service_role;
