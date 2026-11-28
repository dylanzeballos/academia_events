-- ============================================================================
-- Panel administrativo: eventos próximos y ordenados para el admin.
-- Fecha: 2026-11-27
-- ============================================================================
-- Las secciones de eventos (resumen y eventos) muestran solo los que todavía
-- no terminaron: `end_at >= now()`. Se mantiene la paginación real y el resto
-- de las secciones sin cambios.

create or replace function public.admin_fetch_section_page(
  p_section text,
  p_limit integer default 25,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, private
as $fn$
declare
  v_rows jsonb;
  v_total bigint := 0;
  v_counts jsonb := '{}'::jsonb;
  v_limit integer := least(greatest(coalesce(p_limit, 25), 1), 200);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
begin
  if not private.is_platform_admin() then
    raise exception 'Acceso administrativo requerido' using errcode = '42501';
  end if;

  case p_section
    when 'dashboard' then
      select count(*) into v_total
      from public.events e
      where e.deleted_at is null
        and e.end_at >= now();

      select jsonb_build_object(
        'pending_approval', count(*) filter (
          where e.moderation_status = 'pending_approval'
        ),
        'approved', count(*) filter (
          where e.moderation_status = 'approved'
        )
      )
      into v_counts
      from public.events e
      where e.deleted_at is null
        and e.end_at >= now();

      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows
      from (
        select e.id, e.title, e.moderation_status, e.created_at,
          jsonb_build_object('name', o.name) as organizations
        from public.events e
        left join public.organizations o on o.id = e.organization_id
        where e.deleted_at is null
          and e.end_at >= now()
        order by e.start_at asc
        limit v_limit offset v_offset
      ) r;

    when 'events' then
      select count(*) into v_total
      from public.events e
      where e.deleted_at is null
        and e.end_at >= now();

      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows
      from (
        select e.id, e.title, e.status, e.moderation_status,
          e.moderation_reason, e.start_at, e.organization_id, e.created_at,
          ec.name as category_name,
          exists (
            select 1 from public.event_publication_payments ep
            where ep.event_id = e.id
          ) as publication_paid,
          jsonb_build_object('name', o.name) as organizations,
          jsonb_build_object('name', ec.name) as event_categories
        from public.events e
        left join public.organizations o on o.id = e.organization_id
        left join public.event_categories ec on ec.id = e.category_id
        where e.deleted_at is null
          and e.end_at >= now()
        order by e.start_at asc
        limit v_limit offset v_offset
      ) r;

    when 'organizations' then
      select count(*) into v_total
      from public.organizations o
      where o.deleted_at is null;

      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows
      from (
        select o.id, o.name, o.logo_url, o.email, o.phone_number,
          o.location_name, o.is_active, o.is_verified, o.created_at,
          (
            select jsonb_build_object(
              'name', sp.name,
              'status', s.status,
              'interval', sp.interval,
              'price', sp.price,
              'currency', sp.currency,
              'period_end', s.current_period_end
            )
            from public.subscriptions s
            join public.subscription_plans sp on sp.id = s.plan_id
            where s.organization_id = o.id and s.status = 'active'
            order by s.created_at desc
            limit 1
          ) as membership,
          (
            select count(*) from public.events e
            where e.organization_id = o.id and e.deleted_at is null
          ) as events_count,
          (
            select count(*) from public.dance_classes dc
            where dc.organization_id = o.id
          ) as classes_count
        from public.organizations o
        where o.deleted_at is null
        order by o.created_at desc
        limit v_limit offset v_offset
      ) r;

    when 'users' then
      select count(*) into v_total
      from public.profiles p
      where p.deleted_at is null;

      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows
      from (
        select p.id, p.first_name, p.last_name, p.phone_number,
          p.is_active, p.created_at,
          (select u.email from auth.users u where u.id = p.id) as email,
          coalesce(
            (
              select jsonb_agg(ur.role)
              from public.user_roles ur
              where ur.user_id = p.id
            ),
            '[]'::jsonb
          ) as roles
        from public.profiles p
        where p.deleted_at is null
        order by p.created_at desc
        limit v_limit offset v_offset
      ) r;

    when 'memberships' then
      select count(*) into v_total
      from public.subscriptions s;

      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows
      from (
        select s.id, s.organization_id, s.plan_id, s.status,
          s.billing_interval, s.current_period_start, s.current_period_end,
          s.created_at,
          jsonb_build_object('name', o.name) as organizations,
          jsonb_build_object(
            'name', sp.name,
            'interval', sp.interval,
            'price', sp.price,
            'currency', sp.currency
          ) as subscription_plans,
          (
            select p.status from public.payments p
            where p.subscription_id = s.id
            order by p.created_at desc
            limit 1
          ) as payment_status
        from public.subscriptions s
        left join public.organizations o on o.id = s.organization_id
        left join public.subscription_plans sp on sp.id = s.plan_id
        order by s.created_at desc
        limit v_limit offset v_offset
      ) r;

    when 'payments' then
      select count(*) into v_total
      from public.payments p;

      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows
      from (
        select p.id, p.payment_type, p.organization_id, p.order_id,
          p.subscription_id, p.amount, p.currency, p.status, p.provider,
          p.payment_method, p.paid_at, p.created_at,
          jsonb_build_object('name', o.name) as organizations,
          ord.order_number,
          jsonb_build_object('name', sp.name) as subscription_plans
        from public.payments p
        left join public.organizations o on o.id = p.organization_id
        left join public.orders ord on ord.id = p.order_id
        left join public.subscriptions sub on sub.id = p.subscription_id
        left join public.subscription_plans sp on sp.id = sub.plan_id
        order by p.created_at desc
        limit v_limit offset v_offset
      ) r;

    when 'publicationPayments' then
      select count(*) into v_total
      from public.event_publication_payments ep;

      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows
      from (
        select ep.id, ep.event_id, ep.payment_id, ep.amount, ep.currency,
          ep.paid_at, ep.created_at,
          jsonb_build_object('title', e.title) as events,
          jsonb_build_object(
            'status', p.status,
            'provider', p.provider
          ) as payments
        from public.event_publication_payments ep
        left join public.events e on e.id = ep.event_id
        left join public.payments p on p.id = ep.payment_id
        order by ep.created_at desc
        limit v_limit offset v_offset
      ) r;

    when 'sales' then
      select count(*) into v_total
      from public.orders o;

      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows
      from (
        select o.id, o.order_number, o.event_id, o.user_id, o.status,
          o.subtotal, o.discount_amount, o.platform_fee, o.total_amount,
          o.currency, o.created_at,
          jsonb_build_object('title', e.title) as events,
          jsonb_build_object(
            'first_name', pr.first_name,
            'last_name', pr.last_name
          ) as profiles
        from public.orders o
        left join public.events e on e.id = o.event_id
        left join public.profiles pr on pr.id = o.user_id
        order by o.created_at desc
        limit v_limit offset v_offset
      ) r;

    when 'payouts' then
      select count(*) into v_total
      from public.payouts p;

      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows
      from (
        select p.id, p.organization_id, p.amount, p.currency, p.status,
          p.provider, p.period_start, p.period_end, p.processed_at,
          p.created_at, p.metadata,
          jsonb_build_object('name', o.name) as organizations
        from public.payouts p
        left join public.organizations o on o.id = p.organization_id
        order by p.created_at desc
        limit v_limit offset v_offset
      ) r;

    when 'audit' then
      select count(*) into v_total
      from public.audit_logs a;

      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows
      from (
        select a.id, a.user_id, a.action, a.entity_type, a.entity_id,
          a.old_values, a.new_values, a.created_at,
          jsonb_build_object(
            'first_name', pr.first_name,
            'last_name', pr.last_name
          ) as profiles
        from public.audit_logs a
        left join public.profiles pr on pr.id = a.user_id
        order by a.created_at desc
        limit v_limit offset v_offset
      ) r;

    when 'categories' then
      select count(*) into v_total
      from public.event_categories c;

      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows
      from (
        select c.id, c.name, c.is_active, c.created_at,
          (
            select count(*) from public.events e
            where e.category_id = c.id and e.deleted_at is null
          ) as events_count
        from public.event_categories c
        order by c.name
        limit v_limit offset v_offset
      ) r;

    when 'classes' then
      select count(*) into v_total
      from public.dance_classes dc;

      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows
      from (
        select dc.id, dc.title, dc.status, dc.organization_id, dc.created_at,
          dc.start_at, dc.end_at, dc.price, dc.price_monthly, dc.currency,
          jsonb_build_object('name', o.name) as organizations,
          jsonb_build_object('name', cat.name) as dance_categories
        from public.dance_classes dc
        left join public.organizations o on o.id = dc.organization_id
        left join public.dance_categories cat on cat.id = dc.dance_category_id
        order by dc.created_at desc
        limit v_limit offset v_offset
      ) r;

    else
      raise exception 'Módulo administrativo no reconocido';
  end case;

  return jsonb_build_object(
    'items', coalesce(v_rows, '[]'::jsonb),
    'total', v_total,
    'limit', v_limit,
    'offset', v_offset,
    'counts', v_counts
  );
end;
$fn$;

revoke all on function public.admin_fetch_section_page(text, integer, integer)
  from public, anon;
grant execute on function public.admin_fetch_section_page(text, integer, integer)
  to authenticated;
