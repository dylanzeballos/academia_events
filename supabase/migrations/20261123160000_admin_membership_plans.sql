-- ============================================================================
-- Administración de planes de membresía desde el panel de plataforma.
-- Fecha: 2026-11-23
-- ============================================================================
-- El panel necesita crear/editar planes y activarlos sin acceso directo a la
-- tabla. `subscription_plans` no tiene RLS (deuda conocida), así que estas
-- funciones `security definer` son el único camino de escritura desde la app y
-- exigen `private.is_platform_admin()`.
--
-- Notas:
-- - La app solo ofrece planes `interval = 'monthly'` para comprar.
-- - El plan anual existe pero no habilita publicar clases/eventos (la regla
--   exige membresía mensual).
-- - No se borran planes: se desactivan, porque `subscriptions.plan_id` los
--   referencia.

create or replace function public.admin_list_membership_plans()
returns setof public.subscription_plans
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth, private
as $fn$
begin
  if not private.is_platform_admin() then
    raise exception 'Acceso administrativo requerido' using errcode = '42501';
  end if;

  return query
    select *
    from public.subscription_plans
    order by interval, price, created_at;
end;
$fn$;

create or replace function public.admin_save_membership_plan(
  p_id uuid default null,
  p_name text default null,
  p_description text default null,
  p_price numeric default null,
  p_currency text default 'BOB',
  p_interval text default 'monthly',
  p_is_active boolean default true,
  p_can_create_events boolean default false,
  p_can_create_classes boolean default false,
  p_show_in_calendar boolean default false,
  p_max_events_per_month integer default null,
  p_max_classes_per_month integer default null
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
    raise exception 'El nombre del plan es obligatorio' using errcode = '22023';
  end if;

  if p_price is null or p_price <= 0 then
    raise exception 'El precio debe ser mayor a cero' using errcode = '22023';
  end if;

  if p_interval not in ('monthly', 'yearly') then
    raise exception 'El intervalo debe ser monthly o yearly' using errcode = '22023';
  end if;

  if coalesce(p_currency, '') !~ '^[A-Za-z]{3}$' then
    raise exception 'La moneda debe tener 3 letras (por ejemplo BOB)' using errcode = '22023';
  end if;

  if p_max_events_per_month is not null and p_max_events_per_month < 0 then
    raise exception 'El máximo de eventos no puede ser negativo' using errcode = '22023';
  end if;

  if p_max_classes_per_month is not null and p_max_classes_per_month < 0 then
    raise exception 'El máximo de clases no puede ser negativo' using errcode = '22023';
  end if;

  if p_id is null then
    insert into public.subscription_plans (
      name, description, price, currency, interval, is_active,
      can_create_events, can_create_classes, show_in_calendar,
      max_events_per_month, max_classes_per_month
    )
    values (
      btrim(p_name), nullif(btrim(p_description), ''), p_price,
      upper(p_currency)::char(3), p_interval::public.subscription_interval,
      coalesce(p_is_active, true), coalesce(p_can_create_events, false),
      coalesce(p_can_create_classes, false), coalesce(p_show_in_calendar, false),
      p_max_events_per_month, p_max_classes_per_month
    )
    returning id into v_id;
  else
    update public.subscription_plans
    set name = btrim(p_name),
        description = nullif(btrim(p_description), ''),
        price = p_price,
        currency = upper(p_currency)::char(3),
        interval = p_interval::public.subscription_interval,
        is_active = coalesce(p_is_active, is_active),
        can_create_events = coalesce(p_can_create_events, can_create_events),
        can_create_classes = coalesce(p_can_create_classes, can_create_classes),
        show_in_calendar = coalesce(p_show_in_calendar, show_in_calendar),
        max_events_per_month = p_max_events_per_month,
        max_classes_per_month = p_max_classes_per_month,
        updated_at = now()
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'El plan no existe' using errcode = 'P0002';
    end if;
  end if;

  return v_id;
end;
$fn$;

create or replace function public.admin_set_membership_plan_active(
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

  update public.subscription_plans
  set is_active = coalesce(p_active, is_active),
      updated_at = now()
  where id = p_id;

  if not found then
    raise exception 'El plan no existe' using errcode = 'P0002';
  end if;
end;
$fn$;

revoke all on function public.admin_list_membership_plans() from public, anon;
revoke all on function public.admin_save_membership_plan(
  uuid, text, text, numeric, text, text, boolean, boolean, boolean, boolean,
  integer, integer
) from public, anon;
revoke all on function public.admin_set_membership_plan_active(uuid, boolean)
  from public, anon;

grant execute on function public.admin_list_membership_plans() to authenticated;
grant execute on function public.admin_save_membership_plan(
  uuid, text, text, numeric, text, text, boolean, boolean, boolean, boolean,
  integer, integer
) to authenticated;
grant execute on function public.admin_set_membership_plan_active(uuid, boolean)
  to authenticated;
