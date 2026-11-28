-- ============================================================================
-- Administración de categorías de eventos desde el panel de plataforma.
-- Fecha: 2026-11-25
-- ============================================================================
-- `event_categories` no tiene RLS (deuda conocida), así que la escritura desde
-- la app pasa por funciones `security definer` que exigen
-- `private.is_platform_admin()`. No se eliminan categorías: se desactivan para
-- no romper eventos históricos que las referencian.

create or replace function public.admin_save_event_category(
  p_id uuid default null,
  p_name text default null,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, auth, private
as $fn$
declare
  v_id uuid;
begin
  if not private.is_platform_admin() then
    raise exception 'Acceso administrativo requerido' using errcode = '42501';
  end if;

  if coalesce(btrim(p_name), '') = '' then
    raise exception 'El nombre de la categoría es obligatorio'
      using errcode = '22023';
  end if;

  if p_id is null then
    insert into public.event_categories (name, is_active)
    values (btrim(p_name), coalesce(p_is_active, true))
    returning id into v_id;
  else
    update public.event_categories
    set name = btrim(p_name),
        is_active = coalesce(p_is_active, is_active),
        updated_at = now()
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'La categoría no existe' using errcode = 'P0002';
    end if;
  end if;

  return v_id;
end;
$fn$;

create or replace function public.admin_set_event_category_active(
  p_id uuid,
  p_active boolean
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth, private
as $fn$
begin
  if not private.is_platform_admin() then
    raise exception 'Acceso administrativo requerido' using errcode = '42501';
  end if;

  update public.event_categories
  set is_active = coalesce(p_active, is_active),
      updated_at = now()
  where id = p_id;

  if not found then
    raise exception 'La categoría no existe' using errcode = 'P0002';
  end if;
end;
$fn$;

revoke all on function public.admin_save_event_category(uuid, text, boolean)
  from public, anon;
revoke all on function public.admin_set_event_category_active(uuid, boolean)
  from public, anon;

grant execute on function public.admin_save_event_category(uuid, text, boolean)
  to authenticated;
grant execute on function public.admin_set_event_category_active(uuid, boolean)
  to authenticated;
