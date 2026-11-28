-- ============================================================================
-- Precio único de publicación de eventos.
-- Fecha: 2026-11-27
-- ============================================================================
-- `payment_platform_config.event_publication_price` define cuánto paga
-- cualquier organización para publicar un evento. La tabla solo tiene política
-- de lectura, así que la escritura pasa por esta función de plataforma.

create or replace function public.admin_set_event_publication_price(
  p_price numeric
)
returns numeric
language plpgsql
security definer
set search_path = pg_catalog, public, auth, private
as $fn$
declare
  v_price numeric;
begin
  if not private.is_platform_admin() then
    raise exception 'Acceso administrativo requerido' using errcode = '42501';
  end if;

  if p_price is null or p_price <= 0 then
    raise exception 'El precio debe ser mayor a cero' using errcode = '22023';
  end if;

  update public.payment_platform_config
  set event_publication_price = p_price,
      updated_at = now()
  where id = true
  returning event_publication_price into v_price;

  if v_price is null then
    raise exception 'No existe la configuración de pagos de la plataforma'
      using errcode = 'P0002';
  end if;

  insert into public.audit_logs
    (user_id, action, entity_type, new_values)
  values (
    auth.uid(),
    'event_publication_price_updated',
    'payment_platform_config',
    jsonb_build_object('event_publication_price', v_price)
  );

  return v_price;
end;
$fn$;

revoke all on function public.admin_set_event_publication_price(numeric)
  from public, anon;
grant execute on function public.admin_set_event_publication_price(numeric)
  to authenticated;

-- Precio único para todas las organizaciones.
update public.payment_platform_config
set event_publication_price = 30,
    updated_at = now()
where id = true;
