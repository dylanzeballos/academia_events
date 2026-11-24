-- Conserva la confirmación simulada de tickets, pero impide que un usuario
-- anónimo o un comprador confirme las órdenes de otra cuenta.
alter function public.confirm_event_order_payment(uuid, text, text)
  rename to confirm_event_order_payment_without_owner_check;
revoke all on function public.confirm_event_order_payment_without_owner_check(uuid, text, text)
  from public, anon, authenticated;

create or replace function public.confirm_event_order_payment(
  p_order_id uuid,
  p_provider text default 'simulated',
  p_provider_payment_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_order_user_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión para confirmar esta orden'
      using errcode = '42501';
  end if;

  select user_id into v_order_user_id
    from public.orders where id = p_order_id;
  if not found then raise exception 'Orden no encontrada'; end if;
  if v_order_user_id <> auth.uid() then
    raise exception 'No puedes confirmar una orden que pertenece a otra cuenta'
      using errcode = '42501';
  end if;

  return public.confirm_event_order_payment_without_owner_check(
    p_order_id, p_provider, p_provider_payment_id
  );
end;
$$;
revoke all on function public.confirm_event_order_payment(uuid, text, text) from public, anon;
grant execute on function public.confirm_event_order_payment(uuid, text, text) to authenticated;
