-- ============================================================================
-- Renovación anticipada de la membresía.
-- Fecha: 2026-11-23
-- ============================================================================
-- `request_organization_membership` rechaza crear otra membresía si ya hay una
-- activa. Para permitir renovar antes del vencimiento (ventana de 7 días) se
-- crea una suscripción pendiente cuyo período **arranca cuando termina el
-- actual**, sin tocar la vigente. Al pagarse, `fulfill_membership` la activa
-- respetando esas fechas.

create or replace function public.renew_organization_membership(
  p_organization_id uuid,
  p_plan_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $fn$
declare
  v_active       record;
  v_plan         record;
  v_existing     uuid;
  v_interval     interval;
  v_start        timestamptz;
  v_end          timestamptz;
  v_new_id       uuid;
  v_payment_id   uuid;
begin
  if auth.uid() is null or not exists (
    select 1
      from public.organization_members om
     where om.organization_id = p_organization_id
       and om.user_id = auth.uid()
       and om.is_active
       and om.role::text in ('owner', 'admin')
  ) then
    raise exception 'Solo un administrador de la organización puede renovar la membresía'
      using errcode = '42501';
  end if;

  select * into v_plan
    from public.subscription_plans
   where id = p_plan_id and is_active;

  if not found then
    raise exception 'El plan no existe o está inactivo';
  end if;

  select * into v_active
    from public.subscriptions s
   where s.organization_id = p_organization_id
     and s.status = 'active'
     and (s.current_period_end is null or s.current_period_end > now())
   order by s.current_period_end desc nulls last
   limit 1;

  if not found then
    raise exception 'No hay una membresía activa para renovar';
  end if;

  if v_active.current_period_end is not null
     and v_active.current_period_end - now() > interval '7 days' then
    raise exception 'La renovación se habilita 7 días antes del vencimiento'
      using errcode = '42501';
  end if;

  -- Si ya hay un pago pendiente, se reutiliza para no duplicar.
  select s.id into v_existing
    from public.subscriptions s
   where s.organization_id = p_organization_id
     and s.status = 'pending'
   order by s.created_at desc
   limit 1;

  if v_existing is not null then
    return jsonb_build_object(
      'subscription_id', v_existing,
      'reused', true
    );
  end if;

  v_interval := case
    when v_active.billing_interval = 'year' then interval '1 year'
    else interval '1 month'
  end;

  v_start := coalesce(v_active.current_period_end, now());
  v_end := v_start + v_interval;

  insert into public.subscriptions
    (organization_id, plan_id, status, requested_at, billing_interval,
     current_period_start, current_period_end)
  values
    (p_organization_id, p_plan_id, 'pending', now(), v_active.billing_interval,
     v_start, v_end)
  returning id into v_new_id;

  insert into public.payments
    (payment_type, user_id, organization_id, subscription_id, amount, currency,
     status, provider, payment_method, metadata)
  values
    ('subscription', auth.uid(), p_organization_id, v_new_id, v_plan.price,
     v_plan.currency, 'pending', 'manual_pending', 'manual',
     jsonb_build_object('renewal', true, 'previous_subscription_id', v_active.id))
  returning id into v_payment_id;

  insert into public.audit_logs
    (user_id, action, entity_type, entity_id, new_values)
  values
    (auth.uid(), 'membership_renewal_requested', 'subscription', v_new_id,
     jsonb_build_object('payment_id', v_payment_id, 'plan_id', p_plan_id,
                        'period_start', v_start, 'period_end', v_end));

  return jsonb_build_object(
    'subscription_id', v_new_id,
    'payment_id', v_payment_id,
    'period_start', v_start,
    'period_end', v_end
  );
end;
$fn$;

revoke all on function public.renew_organization_membership(uuid, uuid)
  from public, anon;
grant execute on function public.renew_organization_membership(uuid, uuid)
  to authenticated, service_role;

notify pgrst, 'reload schema';
