-- ============================================================================
-- Precio de publicación de eventos para las organizaciones.
-- Fecha: 2026-11-27
-- ============================================================================
-- `payment_platform_config` solo permite lectura al admin de plataforma. Esta
-- función expone únicamente el precio de publicación a cualquier usuario
-- autenticado, para mostrarlo antes de generar el QR.

create or replace function public.event_publication_price()
returns numeric
language sql
stable
security definer
set search_path = pg_catalog, public
as $fn$
  select event_publication_price
  from public.payment_platform_config
  where id = true;
$fn$;

revoke all on function public.event_publication_price() from public, anon;
grant execute on function public.event_publication_price() to authenticated;

notify pgrst, 'reload schema';
