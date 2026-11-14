-- PagosYa · pagos de publicación de eventos y clases
-- La plataforma (no el comercio) cobra la publicación. El admin genera el QR
-- desde el panel y recibe una notificación cuando se paga.

alter table public.payment_intents
  drop constraint if exists payment_intents_kind_check;

alter table public.payment_intents
  add constraint payment_intents_kind_check
  check (kind in ('class_pass','membership','event_publication','class_publication'));

create index if not exists payment_intents_reference_idx
  on public.payment_intents (kind, reference_id);

create or replace function private.fulfill_publication(
  p_intent_id uuid,
  p_kind text,
  p_reference_id uuid,
  p_user_id uuid,
  p_organization_id uuid,
  p_amount numeric,
  p_currency char(3),
  p_payment_id text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $fn$
declare
  v_payment_id uuid;
  v_title      text;
  v_org        uuid;
begin
  if p_kind = 'event_publication' then
    select e.title, e.organization_id into v_title, v_org
    from public.events e where e.id = p_reference_id;
    if not found then raise exception 'Evento no encontrado'; end if;

    insert into public.payments
      (payment_type, user_id, organization_id, amount, currency, status,
       provider, provider_payment_id, payment_method, paid_at, metadata)
    values
      ('event_publication', p_user_id, coalesce(p_organization_id, v_org),
       p_amount, p_currency, 'paid', 'pagosya', p_payment_id, 'qr', now(),
       jsonb_build_object('intent_id', p_intent_id, 'event_id', p_reference_id))
    returning id into v_payment_id;

    insert into public.event_publication_payments
      (event_id, payment_id, amount, currency, paid_at)
    values (p_reference_id, v_payment_id, p_amount, p_currency, now());

    -- Publicación automática al confirmar el pago (salvo suspensión explícita).
    update public.events
       set moderation_status = 'approved',
           moderation_updated_at = now(),
           moderation_updated_by = p_user_id,
           moderation_reason = null,
           status = case
             when status in ('draft','pending','rejected') then 'published'::public.event_status
             else status
           end,
           published_at = coalesce(published_at, now()),
           updated_at = now()
     where id = p_reference_id
       and moderation_status is distinct from 'suspended';

    if found then
      insert into public.event_moderation (event_id, admin_user_id, action, reason)
      values (p_reference_id, p_user_id, 'approved', 'Pago de publicación recibido');
    end if;

  elsif p_kind = 'class_publication' then
    select dc.title, dc.organization_id into v_title, v_org
    from public.dance_classes dc where dc.id = p_reference_id;
    if not found then raise exception 'Clase no encontrada'; end if;

    insert into public.payments
      (payment_type, user_id, organization_id, amount, currency, status,
       provider, provider_payment_id, payment_method, paid_at, metadata)
    values
      ('class_publication', p_user_id, coalesce(p_organization_id, v_org),
       p_amount, p_currency, 'paid', 'pagosya', p_payment_id, 'qr', now(),
       jsonb_build_object('intent_id', p_intent_id, 'dance_class_id', p_reference_id))
    returning id into v_payment_id;

    insert into public.dance_class_publication_payments
      (dance_class_id, payment_id, amount, currency, paid_at)
    values (p_reference_id, v_payment_id, p_amount, p_currency, now());

    update public.dance_classes
       set status = 'published'::public.class_status,
           updated_at = now()
     where id = p_reference_id
       and status in ('draft','pending','rejected');

  else
    raise exception 'Tipo de publicación no soportado: %', p_kind;
  end if;

  insert into public.audit_logs (user_id, action, entity_type, entity_id, new_values)
  values (p_user_id, 'publication_paid_auto_published',
          case when p_kind = 'event_publication' then 'event' else 'dance_class' end,
          p_reference_id,
          jsonb_build_object('intent_id', p_intent_id, 'amount', p_amount,
                             'currency', p_currency, 'provider', 'pagosya'));

  insert into public.notifications (user_id, type, title, message, data, dedup_key)
  select ur.user_id,
         'publication_paid',
         'Publicación pagada y publicada',
         format('%s: %s pagó %s %s.', p_kind, coalesce(v_title, 'publicación'), p_amount, p_currency),
         jsonb_build_object('intent_id', p_intent_id, 'kind', p_kind, 'reference_id', p_reference_id,
                            'amount', p_amount, 'currency', p_currency),
         'publication:' || p_intent_id::text || ':' || ur.user_id::text
  from public.user_roles ur
  where ur.role = 'admin'
  on conflict (dedup_key) do nothing;

  return jsonb_build_object('ok', true, 'payment_id', v_payment_id,
                            'published', true);
end;
$fn$;

revoke all on function private.fulfill_publication(uuid, text, uuid, uuid, uuid, numeric, char, text)
  from public, anon, authenticated;
grant execute on function private.fulfill_publication(uuid, text, uuid, uuid, uuid, numeric, char, text)
  to service_role;

-- Despacho: igual que 20261112130000 + rama de publicaciones.
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

    elsif v_intent.kind in ('event_publication','class_publication') then
      v_result := private.fulfill_publication(
        v_intent.id, v_intent.kind, v_intent.reference_id, v_intent.user_id,
        v_intent.organization_id, v_intent.amount, v_intent.currency, v_payment_id
      );

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
