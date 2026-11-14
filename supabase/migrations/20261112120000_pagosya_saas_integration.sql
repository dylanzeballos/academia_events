-- Integración PagosYa (producto SaaS / Plataformas)
-- Cada organización actúa como comercio (affiliate) con su propio banco.
-- La confirmación de pagos SOLO puede ocurrir desde el backend (service_role):
-- el webhook o el reconciliador, nunca desde el cliente.

-- ---------------------------------------------------------------------------
-- 1. Cuentas de pago por organización
-- ---------------------------------------------------------------------------
create table if not exists public.organization_payment_accounts (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  affiliate_id    text not null unique,
  external_id     text not null,
  branding_mode   text not null default 'powered_by_pagosya'
                  check (branding_mode in ('powered_by_pagosya', 'white_label')),
  payment_ui      text not null default 'both'
                  check (payment_ui in ('merchant', 'provider', 'both')),
  bank_status     text,
  bank_updated_at timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.organization_payment_accounts enable row level security;

drop policy if exists org_admin_payment_account_read on public.organization_payment_accounts;
create policy org_admin_payment_account_read on public.organization_payment_accounts
for select to authenticated
using (
  (select private.is_platform_admin())
  or exists (
    select 1 from public.organization_members om
    where om.organization_id = organization_payment_accounts.organization_id
      and om.user_id = (select auth.uid())
      and om.is_active
      and om.role::text in ('owner', 'admin')
  )
);

revoke insert, update, delete on public.organization_payment_accounts from anon, authenticated;
grant select on public.organization_payment_accounts to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Inbox de eventos del webhook (idempotencia + auditoría)
-- ---------------------------------------------------------------------------
create table if not exists public.pagosya_webhook_events (
  event_id      text primary key,
  event_type    text not null,
  affiliate_id  text,
  external_id   text,
  payload       jsonb not null,
  signature_ok  boolean not null default true,
  status        text not null default 'processing'
                check (status in ('processing', 'processed', 'ignored', 'failed')),
  error         text,
  received_at   timestamptz not null default now(),
  processed_at  timestamptz
);

create index if not exists pagosya_webhook_events_received_idx
  on public.pagosya_webhook_events (received_at desc);

alter table public.pagosya_webhook_events enable row level security;

drop policy if exists platform_admin_webhook_events_read on public.pagosya_webhook_events;
create policy platform_admin_webhook_events_read on public.pagosya_webhook_events
for select to authenticated
using ((select private.is_platform_admin()));

revoke insert, update, delete on public.pagosya_webhook_events from anon, authenticated;
grant select on public.pagosya_webhook_events to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Datos de checkout en la orden
-- ---------------------------------------------------------------------------
alter table public.orders
  add column if not exists pagosya_checkout_id text,
  add column if not exists pagosya_checkout_url text,
  add column if not exists pagosya_qr_data_url text,
  add column if not exists pagosya_seat_ids uuid[],
  add column if not exists paid_confirmed_at timestamptz;

create unique index if not exists orders_pagosya_checkout_id_uidx
  on public.orders (pagosya_checkout_id)
  where pagosya_checkout_id is not null;

create unique index if not exists payments_provider_reference_uidx
  on public.payments (provider, provider_payment_id)
  where provider_payment_id is not null;

-- ---------------------------------------------------------------------------
-- 4. Asignación de butacas sin auth.uid (la usa el webhook)
-- ---------------------------------------------------------------------------
create or replace function public.pagosya_assign_seats(
  p_order_id uuid,
  p_seat_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_order_user uuid;
  v_event      uuid;
  v_n          int := coalesce(array_length(p_seat_ids, 1), 0);
  v_tickets    uuid[];
begin
  if v_n = 0 then return; end if;

  select user_id, event_id into v_order_user, v_event
  from public.orders where id = p_order_id;

  if v_order_user is null then
    raise exception 'Orden no encontrada';
  end if;

  if (select count(distinct id) from public.event_seats
      where id = any(p_seat_ids) and event_id = v_event) <> v_n then
    raise exception 'Butacas inválidas para esta orden';
  end if;

  -- ya asignadas: no repetir
  if exists (select 1 from public.purchased_seats where order_id = p_order_id) then
    return;
  end if;

  select array_agg(id order by created_at, id) into v_tickets
  from public.tickets
  where order_id = p_order_id and seat_id is null;

  if coalesce(array_length(v_tickets, 1), 0) <> v_n then
    raise exception 'Tickets (%) no coinciden con butacas (%)',
      coalesce(array_length(v_tickets, 1), 0), v_n;
  end if;

  for i in 1..v_n loop
    insert into public.purchased_seats (seat_id, order_id, ticket_id, user_id)
    values (p_seat_ids[i], p_order_id, v_tickets[i], v_order_user);
    update public.tickets set seat_id = p_seat_ids[i] where id = v_tickets[i];
  end loop;

  delete from public.seat_holds
  where seat_id = any(p_seat_ids) and user_id = v_order_user;
end;
$$;

revoke all on function public.pagosya_assign_seats(uuid, uuid[]) from public, anon, authenticated;
grant execute on function public.pagosya_assign_seats(uuid, uuid[]) to service_role;

-- ---------------------------------------------------------------------------
-- 5. Aplicar checkout.completed (valida y confirma la orden)
-- ---------------------------------------------------------------------------
create or replace function public.pagosya_apply_checkout_completed(p_event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_data        jsonb := coalesce(p_event->'data', '{}'::jsonb);
  v_checkout_id text;
  v_order_ref   text;
  v_payment_id  text;
  v_amount      numeric;
  v_currency    text;
  v_affiliate   text := p_event->>'affiliate_id';
  v_order       record;
begin
  v_checkout_id := nullif(coalesce(
    v_data->>'checkout_id',
    v_data->'checkout'->>'checkout_id',
    v_data->'checkout'->>'id'
  ), '');

  v_order_ref := nullif(coalesce(v_data->>'order_id', p_event->>'external_id'), '');

  v_payment_id := nullif(coalesce(
    v_data->>'payment_id',
    v_data->'payment'->>'id',
    v_data->>'id',
    p_event->>'id'
  ), '');

  v_amount := nullif(coalesce(
    v_data->>'amount',
    v_data->'checkout'->>'amount'
  ), '')::numeric;

  v_currency := nullif(coalesce(
    v_data->>'currency',
    v_data->'checkout'->>'currency'
  ), '');

  if v_checkout_id is not null then
    select o.*, e.organization_id
      into v_order
    from public.orders o
    join public.events e on e.id = o.event_id
    where o.pagosya_checkout_id = v_checkout_id
    for update of o;
  elsif v_order_ref ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select o.*, e.organization_id
      into v_order
    from public.orders o
    join public.events e on e.id = o.event_id
    where o.id = v_order_ref::uuid
    for update of o;
  else
    raise exception 'checkout.completed sin checkout_id ni order_id reconocible';
  end if;

  if not found then
    raise exception 'Orden no encontrada para checkout %', coalesce(v_checkout_id, v_order_ref);
  end if;

  -- el affiliate debe corresponder a la organización dueña del evento
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

  if v_order.status in ('paid', 'completed') then
    return jsonb_build_object('ok', true, 'already_paid', true, 'order_id', v_order.id);
  end if;

  if v_order.status <> 'pending' then
    raise exception 'La orden % está en estado %', v_order.id, v_order.status;
  end if;

  perform public.confirm_event_order_payment_without_owner_check(
    v_order.id, 'pagosya', v_payment_id
  );

  update public.orders
     set paid_confirmed_at = now(),
         updated_at = now()
   where id = v_order.id;

  if v_order.pagosya_seat_ids is not null then
    perform public.pagosya_assign_seats(v_order.id, v_order.pagosya_seat_ids);
  end if;

  return jsonb_build_object('ok', true, 'order_id', v_order.id);
end;
$$;

revoke all on function public.pagosya_apply_checkout_completed(jsonb) from public, anon, authenticated;
grant execute on function public.pagosya_apply_checkout_completed(jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- 6. Ingesta idempotente del evento (una sola transacción)
-- ---------------------------------------------------------------------------
create or replace function public.pagosya_ingest_event(p_event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_event_id text := nullif(coalesce(p_event->>'id', p_event->>'event_id'), '');
  v_type     text := nullif(p_event->>'event', '');
  v_aff      text := nullif(p_event->>'affiliate_id', '');
  v_ext      text := nullif(p_event->>'external_id', '');
  v_status   text;
  v_result   jsonb;
begin
  if v_event_id is null or v_type is null then
    raise exception 'Evento inválido: falta id o event';
  end if;

  insert into public.pagosya_webhook_events (event_id, event_type, affiliate_id, external_id, payload)
  values (v_event_id, v_type, v_aff, v_ext, p_event)
  on conflict (event_id) do nothing;

  if not found then
    select status into v_status
    from public.pagosya_webhook_events
    where event_id = v_event_id
    for update;

    -- solo se reintenta un evento que falló antes
    if v_status is distinct from 'failed' then
      return jsonb_build_object('ok', true, 'duplicate', true);
    end if;

    update public.pagosya_webhook_events
       set status = 'processing', error = null
     where event_id = v_event_id;
  end if;

  begin
    if v_type = 'checkout.completed' then
      v_result := public.pagosya_apply_checkout_completed(p_event);

    elsif v_type = 'bank.integration_updated' then
      update public.organization_payment_accounts
         set bank_status = coalesce(
               p_event->'data'->>'bank_status',
               p_event->'data'->>'status',
               bank_status
             ),
             bank_updated_at = now(),
             updated_at = now()
       where affiliate_id = v_aff;
      v_result := jsonb_build_object('ok', true);

    else
      v_result := jsonb_build_object('ok', true, 'ignored', v_type);
    end if;

    update public.pagosya_webhook_events
       set status = case when v_result ? 'ignored' then 'ignored' else 'processed' end,
           processed_at = now()
     where event_id = v_event_id;

    return v_result;

  exception
    -- errores de negocio (P0001): se guardan y no se reintentan
    when sqlstate 'P0001' then
      update public.pagosya_webhook_events
         set status = 'failed', error = sqlerrm, processed_at = now()
       where event_id = v_event_id;
      return jsonb_build_object('ok', false, 'error', 'EVENT_REJECTED', 'message', sqlerrm);
    when others then
      raise;
  end;
end;
$$;

revoke all on function public.pagosya_ingest_event(jsonb) from public, anon, authenticated;
grant execute on function public.pagosya_ingest_event(jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- 7. Consultas para la app (solo el dueño de la orden)
-- ---------------------------------------------------------------------------
create or replace function public.get_order_tickets(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_uid     uuid := auth.uid();
  v_order   record;
  v_event   text;
  v_ticket  record;
  v_qr      text;
  v_tickets jsonb := '[]'::jsonb;
  v_count   int := 0;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;

  select * into v_order from public.orders
  where id = p_order_id and user_id = v_uid;

  if not found then
    raise exception 'Orden no encontrada' using errcode = '42501';
  end if;

  if v_order.status not in ('paid', 'completed') then
    raise exception 'El pago aún no está confirmado' using errcode = 'P0001';
  end if;

  select title into v_event from public.events where id = v_order.event_id;

  for v_ticket in select * from public.tickets where order_id = v_order.id loop
    v_count := v_count + 1;

    select token_hash into v_qr
    from public.ticket_qr_codes where ticket_id = v_ticket.id limit 1;

    if v_qr is null then
      v_qr := encode(gen_random_bytes(24), 'hex');
      insert into public.ticket_qr_codes (ticket_id, token_hash, expires_at)
      values (v_ticket.id, v_qr, now() + interval '30 days');
    end if;

    v_tickets := v_tickets || jsonb_build_object(
      'ticket_id', v_ticket.id,
      'qr_token', v_qr,
      'attendee_name', v_ticket.attendee_name
    );
  end loop;

  return jsonb_build_object(
    'order_id', v_order.id,
    'order_number', v_order.order_number,
    'quantity', v_count,
    'subtotal', coalesce(v_order.subtotal, v_order.total_amount, 0),
    'event_title', coalesce(v_event, 'Evento'),
    'tickets', v_tickets
  );
end;
$$;

revoke all on function public.get_order_tickets(uuid) from public, anon;
grant execute on function public.get_order_tickets(uuid) to authenticated;

-- Estado del checkout para el polling de la app (no confirma nada).
create or replace function public.get_order_checkout_status(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_uid   uuid := auth.uid();
  v_order record;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;

  select id, status, total_amount, currency, order_number,
         pagosya_checkout_id, pagosya_checkout_url, pagosya_qr_data_url
    into v_order
  from public.orders
  where id = p_order_id and user_id = v_uid;

  if not found then
    raise exception 'Orden no encontrada' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'order_id', v_order.id,
    'order_number', v_order.order_number,
    'status', v_order.status,
    'total_amount', v_order.total_amount,
    'currency', v_order.currency,
    'checkout_id', v_order.pagosya_checkout_id,
    'checkout_url', v_order.pagosya_checkout_url,
    'qr_data_url', v_order.pagosya_qr_data_url,
    'paid', v_order.status in ('paid', 'completed')
  );
end;
$$;

revoke all on function public.get_order_checkout_status(uuid) from public, anon;
grant execute on function public.get_order_checkout_status(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Cerrar la confirmación simulada desde el cliente
-- ---------------------------------------------------------------------------
revoke all on function public.confirm_event_order_payment(uuid, text, text)
  from public, anon, authenticated;

revoke all on function public.confirm_event_order_payment_without_owner_check(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.confirm_event_order_payment_without_owner_check(uuid, text, text)
  to service_role;

comment on function public.confirm_event_order_payment(uuid, text, text) is
  'OBSOLETO. La confirmación de pagos la realiza el backend (pagosya_ingest_event). No otorgar EXECUTE a anon/authenticated.';

-- Endurecer la función interna que ahora usa el webhook.
alter function public.confirm_event_order_payment_without_owner_check(uuid, text, text)
  set search_path = pg_catalog, public;
