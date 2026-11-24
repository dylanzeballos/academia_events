-- PagosYa · pagos unificados (tickets, pases de clase y membresías)
-- Este archivo reproduce los cambios aplicados después de la migración base
-- 20261112120000_pagosya_saas_integration.sql. Todo es idempotente.

-- ---------------------------------------------------------------------------
-- 1. Intents genéricos + comercio de la plataforma
-- ---------------------------------------------------------------------------
create table if not exists public.payment_intents (
  id                  uuid primary key default gen_random_uuid(),
  kind                text not null check (kind in ('class_pass','membership')),
  reference_id        uuid not null,
  user_id             uuid not null references public.profiles(id) on delete cascade,
  organization_id     uuid references public.organizations(id) on delete cascade,
  amount              numeric not null check (amount > 0),
  currency            character(3) not null default 'BOB',
  status              public.payment_status not null default 'pending',
  provider            varchar(40) not null default 'pagosya',
  provider_payment_id varchar(120),
  pagosya_checkout_id text unique,
  checkout_url        text,
  qr_data_url         text,
  affiliate_id        text not null,
  metadata            jsonb not null default '{}'::jsonb,
  expires_at          timestamptz,
  paid_at             timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create unique index if not exists payment_intents_active_uidx
  on public.payment_intents (kind, reference_id)
  where status = 'pending';

create index if not exists payment_intents_pending_idx
  on public.payment_intents (status, created_at)
  where status = 'pending';

alter table public.payment_intents enable row level security;

drop policy if exists payment_intent_owner_read on public.payment_intents;
create policy payment_intent_owner_read on public.payment_intents
for select to authenticated
using (
  user_id = (select auth.uid())
  or (select private.is_platform_admin())
  or (organization_id is not null and exists (
    select 1 from public.organization_members om
    where om.organization_id = payment_intents.organization_id
      and om.user_id = (select auth.uid())
      and om.is_active
      and om.role::text in ('owner','admin')
  ))
);

revoke insert, update, delete on public.payment_intents from anon, authenticated;
grant select on public.payment_intents to authenticated;

create table if not exists public.payment_platform_config (
  id           boolean primary key default true check (id),
  affiliate_id text not null,
  external_id  text not null default 'platform',
  updated_at   timestamptz not null default now()
);

alter table public.payment_platform_config enable row level security;

drop policy if exists platform_payment_config_read on public.payment_platform_config;
create policy platform_payment_config_read on public.payment_platform_config
for select to authenticated
using ((select private.is_platform_admin()));

revoke insert, update, delete on public.payment_platform_config from anon, authenticated;
grant select on public.payment_platform_config to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Pases de clase: cotización y cumplimiento en servidor
-- ---------------------------------------------------------------------------
create or replace function public.pagosya_class_pass_quote(p_enrollment_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $fn$
declare
  v_enrollment record;
  v_class      record;
  v_count      integer;
begin
  select * into v_enrollment from public.class_enrollments where id = p_enrollment_id;
  if not found then
    return jsonb_build_object('success', false, 'reason', 'La inscripción no existe');
  end if;
  if v_enrollment.user_id <> p_user_id then
    return jsonb_build_object('success', false, 'reason', 'No tienes permiso para comprar este pase');
  end if;
  if v_enrollment.status not in ('pending','approved','active') then
    return jsonb_build_object('success', false, 'reason', 'La inscripción no está activa');
  end if;
  if exists (select 1 from public.class_passes where enrollment_id = p_enrollment_id and status = 'active') then
    return jsonb_build_object('success', false, 'reason', 'Ya tienes un pase activo para esta clase');
  end if;

  select * into v_class from public.dance_classes where id = v_enrollment.dance_class_id;
  if not found then
    return jsonb_build_object('success', false, 'reason', 'La clase no existe');
  end if;

  select count(*) into v_count
  from public.dance_class_sessions s
  where s.dance_class_id = v_class.id
    and s.status = 'scheduled'
    and s.session_date >= current_date;

  if v_count = 0 then
    return jsonb_build_object('success', false, 'reason', 'La clase no tiene sesiones programadas');
  end if;

  return jsonb_build_object(
    'success', true,
    'enrollment_id', p_enrollment_id,
    'dance_class_id', v_class.id,
    'organization_id', v_class.organization_id,
    'session_count', v_count,
    'price', v_class.price,
    'currency', v_class.currency,
    'total_amount', v_class.price * v_count
  );
end;
$fn$;

revoke all on function public.pagosya_class_pass_quote(uuid, uuid) from public, anon, authenticated;
grant execute on function public.pagosya_class_pass_quote(uuid, uuid) to service_role;

create or replace function private.purchase_class_pass_for_user(p_enrollment_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $fn$
declare
  v_enrollment    record;
  v_class         record;
  v_pass_id       uuid;
  v_session       record;
  v_ticket_id     uuid;
  v_token         text;
  v_tickets       jsonb := '[]'::jsonb;
  v_count         integer := 0;
  v_last_date     date;
  v_occupied      integer;
  v_total         numeric;
begin
  select * into v_enrollment from public.class_enrollments where id = p_enrollment_id;
  if not found then
    return jsonb_build_object('success', false, 'reason', 'La inscripción no existe');
  end if;
  if v_enrollment.user_id <> p_user_id then
    return jsonb_build_object('success', false, 'reason', 'No tienes permiso para comprar este pase');
  end if;
  if v_enrollment.status not in ('pending','approved','active') then
    return jsonb_build_object('success', false, 'reason', 'La inscripción no está activa');
  end if;

  select * into v_class from public.dance_classes where id = v_enrollment.dance_class_id for update;
  if not found then
    return jsonb_build_object('success', false, 'reason', 'La clase no existe');
  end if;

  if exists (select 1 from public.class_passes where enrollment_id = p_enrollment_id and status = 'active') then
    return jsonb_build_object('success', false, 'reason', 'Ya tienes un pase activo para esta clase');
  end if;

  if v_class.capacity is not null then
    for v_session in
      select s.id, s.session_date
      from public.dance_class_sessions s
      where s.dance_class_id = v_class.id
        and s.status = 'scheduled'
        and s.session_date >= current_date
      order by s.session_date
    loop
      select count(*) into v_occupied
      from public.class_session_tickets cst
      join public.class_passes cp on cp.id = cst.class_pass_id
      where cst.session_id = v_session.id
        and cst.status in ('issued','used')
        and cp.status = 'active';

      if v_occupied >= v_class.capacity then
        return jsonb_build_object('success', false,
          'reason', format('La sesión del %s está llena', to_char(v_session.session_date, 'YYYY-MM-DD')));
      end if;
    end loop;
  end if;

  select count(*), max(s.session_date) into v_count, v_last_date
  from public.dance_class_sessions s
  where s.dance_class_id = v_class.id
    and s.status = 'scheduled'
    and s.session_date >= current_date;

  if v_count = 0 then
    return jsonb_build_object('success', false, 'reason', 'La clase no tiene sesiones programadas');
  end if;

  v_total := v_class.price * v_count;

  insert into public.class_passes
    (enrollment_id, starts_at, ends_at, status, session_count, price, currency, total_amount)
  values
    (p_enrollment_id, current_date, v_last_date, 'active', v_count,
     v_class.price, v_class.currency, v_total)
  returning id into v_pass_id;

  for v_session in
    select s.id as session_id, s.session_date, s.end_at
    from public.dance_class_sessions s
    where s.dance_class_id = v_class.id
      and s.status = 'scheduled'
      and s.session_date >= current_date
    order by s.session_date
  loop
    insert into public.class_session_tickets (class_pass_id, session_id, valid_date, status)
    values (v_pass_id, v_session.session_id, v_session.session_date, 'issued')
    on conflict (class_pass_id, session_id) do nothing
    returning id into v_ticket_id;

    if v_ticket_id is not null then
      v_token := encode(gen_random_bytes(24), 'hex');
      insert into public.class_ticket_qr_codes (ticket_id, token_hash, expires_at)
      values (v_ticket_id, v_token, v_session.end_at)
      on conflict (ticket_id) do nothing;

      v_tickets := v_tickets || jsonb_build_object(
        'ticket_id', v_ticket_id,
        'session_id', v_session.session_id,
        'session_date', v_session.session_date,
        'qr_token', v_token
      );
    end if;
    v_ticket_id := null;
  end loop;

  return jsonb_build_object(
    'success', true,
    'pass_id', v_pass_id,
    'starts_at', current_date,
    'ends_at', v_last_date,
    'session_count', v_count,
    'price', v_class.price,
    'currency', v_class.currency,
    'total_amount', v_total,
    'tickets_generated', v_count,
    'tickets', v_tickets
  );
end;
$fn$;

revoke all on function private.purchase_class_pass_for_user(uuid, uuid) from public, anon, authenticated;
grant execute on function private.purchase_class_pass_for_user(uuid, uuid) to service_role;

-- El cliente ya no compra pases sin pagar.
create or replace function public.purchase_class_pass(p_enrollment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $fn$
begin
  if auth.uid() is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;
  raise exception 'Los pases de clase se compran con la pasarela de pagos'
    using errcode = 'P0001';
end;
$fn$;

revoke all on function public.purchase_class_pass(uuid) from public, anon, authenticated;
grant execute on function public.purchase_class_pass(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 3. Membresías
-- ---------------------------------------------------------------------------
create or replace function private.fulfill_membership(
  p_subscription_id uuid,
  p_user_id uuid,
  p_provider_payment_id text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $fn$
declare
  v_sub      record;
  v_plan     record;
  v_interval interval;
begin
  select s.* into v_sub
  from public.subscriptions s
  where s.id = p_subscription_id
  for update;

  if not found then
    raise exception 'Suscripción no encontrada';
  end if;

  if v_sub.status = 'active' then
    return jsonb_build_object('ok', true, 'already_active', true);
  end if;

  if v_sub.status not in ('pending','past_due') then
    raise exception 'La suscripción está en estado %', v_sub.status;
  end if;

  select * into v_plan from public.subscription_plans where id = v_sub.plan_id;
  v_interval := case when v_sub.billing_interval = 'year' then interval '1 year' else interval '1 month' end;

  update public.subscriptions
     set status = 'active',
         current_period_start = coalesce(current_period_start, now()),
         current_period_end = coalesce(current_period_end, now() + v_interval),
         verified_at = now(),
         updated_at = now()
   where id = p_subscription_id;

  update public.payments
     set status = 'paid',
         provider = 'pagosya',
         provider_payment_id = p_provider_payment_id,
         paid_at = coalesce(paid_at, now()),
         updated_at = now()
   where subscription_id = p_subscription_id
     and payment_type = 'subscription'
     and status in ('pending','processing');

  if not found and v_plan.id is not null then
    insert into public.payments
      (payment_type, user_id, organization_id, subscription_id, amount, currency,
       status, provider, provider_payment_id, payment_method, paid_at, metadata)
    values
      ('subscription', p_user_id, v_sub.organization_id, p_subscription_id,
       v_plan.price, v_plan.currency, 'paid', 'pagosya', p_provider_payment_id,
       'qr', now(), jsonb_build_object('source','pagosya'));
  end if;

  insert into public.audit_logs (user_id, action, entity_type, entity_id, new_values)
  values (p_user_id, 'membership_activated', 'subscription', p_subscription_id,
          jsonb_build_object('provider','pagosya','provider_payment_id',p_provider_payment_id));

  return jsonb_build_object('ok', true, 'subscription_id', p_subscription_id);
end;
$fn$;

revoke all on function private.fulfill_membership(uuid, uuid, text) from public, anon, authenticated;
grant execute on function private.fulfill_membership(uuid, uuid, text) to service_role;

-- ---------------------------------------------------------------------------
-- 4. Expiración de cobros abandonados (libera stock y butacas)
-- ---------------------------------------------------------------------------
create or replace function public.pagosya_expire_stale_payments(p_minutes integer default 30)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $fn$
declare
  v_order    record;
  v_orders   int := 0;
  v_intents  int := 0;
  v_tickets  int := 0;
begin
  update public.payment_intents
     set status = 'cancelled', updated_at = now()
   where status = 'pending'
     and created_at < now() - make_interval(mins => p_minutes);
  get diagnostics v_intents = row_count;

  for v_order in
    select o.id, o.user_id, o.event_id
    from public.orders o
    where o.status = 'pending'
      and o.paid_confirmed_at is null
      and o.created_at < now() - make_interval(mins => p_minutes)
    for update skip locked
  loop
    update public.ticket_types tt
       set sold_quantity = greatest(0, tt.sold_quantity - x.qty)
      from (
        select ticket_type_id, count(*)::int as qty
        from public.tickets
        where order_id = v_order.id
        group by ticket_type_id
      ) x
     where tt.id = x.ticket_type_id;

    update public.tickets
       set status = 'cancelled', cancelled_at = now(), updated_at = now()
     where order_id = v_order.id and status = 'active';
    get diagnostics v_tickets = row_count;

    update public.ticket_qr_codes q
       set is_active = false
      from public.tickets t
     where t.order_id = v_order.id and q.ticket_id = t.id;

    delete from public.purchased_seats where order_id = v_order.id;
    delete from public.seat_holds
     where user_id = v_order.user_id
       and seat_id in (select id from public.event_seats where event_id = v_order.event_id);

    update public.orders
       set status = 'cancelled', updated_at = now()
     where id = v_order.id;

    v_orders := v_orders + 1;
  end loop;

  return jsonb_build_object(
    'cancelled_intents', v_intents,
    'cancelled_orders', v_orders,
    'cancelled_tickets', v_tickets
  );
end;
$fn$;

revoke all on function public.pagosya_expire_stale_payments(integer) from public, anon, authenticated;
grant execute on function public.pagosya_expire_stale_payments(integer) to service_role;

-- ---------------------------------------------------------------------------
-- 5. Despacho de checkout.completed: intents primero, órdenes después
-- ---------------------------------------------------------------------------
create or replace function public.pagosya_apply_checkout_completed(p_event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $fn$
declare
  v_data        jsonb := coalesce(p_event->'data', '{}'::jsonb);
  v_checkout_id text;
  v_order_ref   text;
  v_payment_id  text;
  v_amount      numeric;
  v_currency    text;
  v_affiliate   text := p_event->>'affiliate_id';
  v_order       record;
  v_intent      record;
  v_result      jsonb;
begin
  v_checkout_id := nullif(coalesce(
    v_data->>'checkout_id', v_data->'checkout'->>'checkout_id', v_data->'checkout'->>'id'
  ), '');
  v_order_ref := nullif(coalesce(v_data->>'order_id', p_event->>'external_id'), '');
  v_payment_id := nullif(coalesce(
    v_data->>'payment_id', v_data->'payment'->>'id', v_data->>'id', p_event->>'id'
  ), '');
  v_amount := nullif(coalesce(v_data->>'amount', v_data->'checkout'->>'amount'), '')::numeric;
  v_currency := nullif(coalesce(v_data->>'currency', v_data->'checkout'->>'currency'), '');

  if v_checkout_id is null then
    raise exception 'checkout.completed sin checkout_id';
  end if;

  select * into v_intent
  from public.payment_intents
  where pagosya_checkout_id = v_checkout_id
  for update;

  if found then
    if v_affiliate is not null and v_affiliate <> v_intent.affiliate_id then
      raise exception 'affiliate_id % no corresponde al intent', v_affiliate;
    end if;
    if v_currency is not null and upper(trim(v_currency)) <> upper(trim(v_intent.currency)) then
      raise exception 'Moneda no coincide: % vs %', v_currency, v_intent.currency;
    end if;
    if v_amount is not null and v_amount <> v_intent.amount then
      raise exception 'Monto no coincide: % vs %', v_amount, v_intent.amount;
    end if;

    if v_intent.status = 'paid' then
      return jsonb_build_object('ok', true, 'already_paid', true, 'intent_id', v_intent.id);
    end if;
    if v_intent.status in ('cancelled','failed','refunded') then
      raise exception 'El intent % está en estado %', v_intent.id, v_intent.status;
    end if;

    if v_intent.kind = 'class_pass' then
      v_result := private.purchase_class_pass_for_user(v_intent.reference_id, v_intent.user_id);
      if coalesce((v_result->>'success')::boolean, false) is not true then
        raise exception '%', coalesce(v_result->>'reason', 'No se pudo crear el pase de clase');
      end if;

      insert into public.payments
        (payment_type, user_id, organization_id, amount, currency, status,
         provider, provider_payment_id, payment_method, paid_at, metadata)
      values
        ('other', v_intent.user_id, v_intent.organization_id,
         v_intent.amount, v_intent.currency, 'paid', 'pagosya', v_payment_id,
         'qr', now(),
         jsonb_build_object('kind', 'class_pass', 'enrollment_id', v_intent.reference_id,
                            'intent_id', v_intent.id));

    elsif v_intent.kind = 'membership' then
      v_result := private.fulfill_membership(v_intent.reference_id, v_intent.user_id, v_payment_id);
      if coalesce((v_result->>'ok')::boolean, false) is not true then
        raise exception 'No se pudo activar la membresía';
      end if;

    else
      raise exception 'Tipo de pago no soportado: %', v_intent.kind;
    end if;

    update public.payment_intents
       set status = 'paid',
           provider_payment_id = v_payment_id,
           paid_at = now(),
           updated_at = now()
     where id = v_intent.id;

    return jsonb_build_object('ok', true, 'kind', v_intent.kind,
                              'reference_id', v_intent.reference_id,
                              'intent_id', v_intent.id);
  end if;

  -- órdenes de tickets
  select o.*, e.organization_id
    into v_order
  from public.orders o
  join public.events e on e.id = o.event_id
  where o.pagosya_checkout_id = v_checkout_id
     or (v_order_ref ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
         and o.id = v_order_ref::uuid)
  order by (o.pagosya_checkout_id = v_checkout_id) desc
  limit 1
  for update of o;

  if not found then
    raise exception 'Orden no encontrada para checkout %', v_checkout_id;
  end if;

  if v_affiliate is not null and not exists (
    select 1 from public.organization_payment_accounts a
    where a.organization_id = v_order.organization_id
      and a.affiliate_id = v_affiliate
  ) then
    raise exception 'affiliate_id % no corresponde a la organización', v_affiliate;
  end if;

  if v_currency is not null and upper(trim(v_currency)) <> upper(trim(v_order.currency)) then
    raise exception 'Moneda no coincide: % vs %', v_currency, v_order.currency;
  end if;

  if v_amount is not null and v_amount <> v_order.total_amount then
    raise exception 'Monto no coincide: % vs %', v_amount, v_order.total_amount;
  end if;

  if v_order.status in ('paid','completed') then
    return jsonb_build_object('ok', true, 'already_paid', true, 'order_id', v_order.id);
  end if;
  if v_order.status <> 'pending' then
    raise exception 'La orden % está en estado %', v_order.id, v_order.status;
  end if;

  perform public.confirm_event_order_payment_without_owner_check(v_order.id, 'pagosya', v_payment_id);

  update public.orders
     set paid_confirmed_at = now(), updated_at = now()
   where id = v_order.id;

  if v_order.pagosya_seat_ids is not null then
    perform public.pagosya_assign_seats(v_order.id, v_order.pagosya_seat_ids);
  end if;

  return jsonb_build_object('ok', true, 'kind', 'ticket', 'order_id', v_order.id);
end;
$fn$;

revoke all on function public.pagosya_apply_checkout_completed(jsonb) from public, anon, authenticated;
grant execute on function public.pagosya_apply_checkout_completed(jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- 6. Solicitud de membresía idempotente (permite reintentar el pago)
-- ---------------------------------------------------------------------------
create or replace function public.request_organization_membership(
  p_organization_id uuid,
  p_plan_id uuid,
  p_payment_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $fn$
declare
  v_subscription_id uuid;
  v_payment_id      uuid;
  v_amount          numeric;
  v_currency        char(3);
  v_interval        text;
  v_existing        record;
begin
  if auth.uid() is null or not exists (
    select 1 from public.organization_members om
    where om.organization_id = p_organization_id
      and om.user_id = auth.uid()
      and om.is_active
      and om.role::text in ('owner','admin','manager')
  ) then
    raise exception 'Solo un administrador de la organización puede solicitar membresía'
      using errcode = '42501';
  end if;

  select price, currency, interval::text
    into v_amount, v_currency, v_interval
  from public.subscription_plans
  where id = p_plan_id and is_active;

  if not found then
    raise exception 'El plan no existe o está inactivo';
  end if;

  select s.id, s.plan_id, s.status
    into v_existing
  from public.subscriptions s
  where s.organization_id = p_organization_id
    and s.status in ('pending','active','past_due')
  order by s.created_at desc
  limit 1;

  if found then
    if v_existing.status = 'pending' and not exists (
      select 1 from public.payments p
      where p.subscription_id = v_existing.id
        and p.payment_type = 'subscription'
        and p.status = 'paid'
    ) then
      select id into v_payment_id
      from public.payments
      where subscription_id = v_existing.id and payment_type = 'subscription'
      order by created_at desc limit 1;

      return jsonb_build_object(
        'subscription_id', v_existing.id,
        'payment_id', v_payment_id,
        'amount', v_amount,
        'currency', v_currency,
        'payment_status', 'pending',
        'reused', true
      );
    end if;

    raise exception 'La organización ya tiene una membresía pendiente o vigente';
  end if;

  insert into public.subscriptions (organization_id, plan_id, status, requested_at, billing_interval)
  values (p_organization_id, p_plan_id, 'pending', now(),
          case when v_interval = 'yearly' then 'year' else 'month' end)
  returning id into v_subscription_id;

  insert into public.payments
    (payment_type, user_id, organization_id, subscription_id, amount, currency,
     status, provider, payment_method, metadata)
  values
    ('subscription', auth.uid(), p_organization_id, v_subscription_id, v_amount,
     v_currency, 'pending', 'manual_pending', 'manual',
     jsonb_build_object('payment_note', nullif(trim(p_payment_note), '')))
  returning id into v_payment_id;

  insert into public.audit_logs (user_id, action, entity_type, entity_id, new_values)
  values (auth.uid(), 'membership_requested', 'subscription', v_subscription_id,
          jsonb_build_object('payment_id', v_payment_id, 'plan_id', p_plan_id, 'amount', v_amount));

  return jsonb_build_object(
    'subscription_id', v_subscription_id,
    'payment_id', v_payment_id,
    'amount', v_amount,
    'currency', v_currency,
    'payment_status', 'pending'
  );
end;
$fn$;
