-- ============================================================================
-- Precios de clases por sesión/mensual, pase VIP por organización y reglas
-- de publicación (membresía mensual + pago de publicación).
-- Fecha: 2026-11-17
-- ============================================================================
-- Modelo:
--   * dance_classes.price         = precio por sesión (se mantiene por compat.)
--   * dance_classes.price_monthly = precio del pase mensual de ESA clase
--                                   (0 = la clase no ofrece mensual)
--   * Pase VIP = plan mensual de la organización que da acceso a todas sus
--     clases publicadas o solo a los ritmos (categorías) configurados.
--   * class_passes.pass_type: 'session' | 'sessions' | 'monthly' | 'vip'
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Precios y ritmo de la clase
-- ---------------------------------------------------------------------------
alter table public.dance_classes
  add column if not exists price_monthly numeric not null default 0,
  add column if not exists dance_category_id uuid
    references public.dance_categories(id) on delete set null;

alter table public.dance_classes
  drop constraint if exists dance_classes_price_monthly_check;
alter table public.dance_classes
  add constraint dance_classes_price_monthly_check check (price_monthly >= 0);

create index if not exists idx_dance_classes_category
  on public.dance_classes(dance_category_id);

comment on column public.dance_classes.price is 'Precio por sesión';
comment on column public.dance_classes.price_monthly is
  'Precio del pase mensual de la clase (0 = no se ofrece mensual)';

-- ---------------------------------------------------------------------------
-- 2. Plan VIP de la organización
-- ---------------------------------------------------------------------------
create table if not exists public.organization_vip_plans (
  id                    uuid primary key default gen_random_uuid(),
  organization_id       uuid not null unique
    references public.organizations(id) on delete cascade,
  name                  text not null default 'Pase VIP',
  description           text,
  price_monthly         numeric not null check (price_monthly > 0),
  currency              character(3) not null default 'BOB',
  includes_all_classes  boolean not null default true,
  is_active             boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

comment on table public.organization_vip_plans is
  'Plan VIP mensual de una organización (uno por organización).';

create table if not exists public.organization_vip_plan_categories (
  plan_id           uuid not null
    references public.organization_vip_plans(id) on delete cascade,
  dance_category_id uuid not null
    references public.dance_categories(id) on delete cascade,
  primary key (plan_id, dance_category_id)
);

create table if not exists public.vip_memberships (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  plan_id         uuid references public.organization_vip_plans(id) on delete set null,
  status          text not null default 'active'
    check (status in ('active', 'expired', 'cancelled')),
  price           numeric not null default 0 check (price >= 0),
  currency        character(3) not null default 'BOB',
  starts_at       date not null default current_date,
  ends_at         date not null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (ends_at >= starts_at)
);

create unique index if not exists uq_vip_memberships_one_active
  on public.vip_memberships(organization_id, user_id)
  where status = 'active';

create index if not exists idx_vip_memberships_user
  on public.vip_memberships(user_id);
create index if not exists idx_vip_memberships_org
  on public.vip_memberships(organization_id);

-- ---------------------------------------------------------------------------
-- 3. Tipos de pase de clase
-- ---------------------------------------------------------------------------
alter table public.class_passes
  add column if not exists pass_type text not null default 'sessions',
  add column if not exists vip_membership_id uuid
    references public.vip_memberships(id) on delete cascade;

alter table public.class_passes
  drop constraint if exists class_passes_pass_type_check;
alter table public.class_passes
  add constraint class_passes_pass_type_check
  check (pass_type in ('session', 'sessions', 'monthly', 'vip'));

-- Los pases por sesión pueden acumularse; el mensual y el VIP no.
drop index if exists public.uq_class_passes_one_active_per_enrollment;

create unique index if not exists uq_class_passes_one_active_monthly
  on public.class_passes(enrollment_id)
  where status = 'active' and pass_type = 'monthly';

create index if not exists idx_class_passes_vip
  on public.class_passes(vip_membership_id)
  where vip_membership_id is not null;

-- ---------------------------------------------------------------------------
-- 4. RLS
-- ---------------------------------------------------------------------------
alter table public.organization_vip_plans enable row level security;
alter table public.organization_vip_plan_categories enable row level security;
alter table public.vip_memberships enable row level security;

drop policy if exists org_vip_plans_select on public.organization_vip_plans;
create policy org_vip_plans_select on public.organization_vip_plans
  for select to anon, authenticated
  using (true);

drop policy if exists org_vip_plans_write on public.organization_vip_plans;
create policy org_vip_plans_write on public.organization_vip_plans
  for all to authenticated
  using (
    exists (
      select 1 from public.organization_members m
      where m.organization_id = organization_vip_plans.organization_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role::text in ('owner', 'admin', 'manager')
    )
  )
  with check (
    exists (
      select 1 from public.organization_members m
      where m.organization_id = organization_vip_plans.organization_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role::text in ('owner', 'admin', 'manager')
    )
  );

drop policy if exists org_vip_plan_categories_select
  on public.organization_vip_plan_categories;
create policy org_vip_plan_categories_select
  on public.organization_vip_plan_categories
  for select to anon, authenticated
  using (true);

drop policy if exists org_vip_plan_categories_write
  on public.organization_vip_plan_categories;
create policy org_vip_plan_categories_write
  on public.organization_vip_plan_categories
  for all to authenticated
  using (
    exists (
      select 1
      from public.organization_vip_plans p
      join public.organization_members m
        on m.organization_id = p.organization_id
      where p.id = organization_vip_plan_categories.plan_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role::text in ('owner', 'admin', 'manager')
    )
  )
  with check (
    exists (
      select 1
      from public.organization_vip_plans p
      join public.organization_members m
        on m.organization_id = p.organization_id
      where p.id = organization_vip_plan_categories.plan_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role::text in ('owner', 'admin', 'manager')
    )
  );

drop policy if exists vip_memberships_select on public.vip_memberships;
create policy vip_memberships_select on public.vip_memberships
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1 from public.organization_members m
      where m.organization_id = vip_memberships.organization_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role::text in ('owner', 'admin', 'manager', 'instructor', 'check_in_staff')
    )
  );

revoke insert, update, delete on public.organization_vip_plans
  from anon, authenticated;
revoke insert, update, delete on public.organization_vip_plan_categories
  from anon, authenticated;
revoke insert, update, delete on public.vip_memberships
  from anon, authenticated;

grant select on public.organization_vip_plans to anon, authenticated;
grant insert, update, delete on public.organization_vip_plans to authenticated;
grant select on public.organization_vip_plan_categories to anon, authenticated;
grant insert, delete on public.organization_vip_plan_categories to authenticated;
grant select on public.vip_memberships to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Helpers de emisión de tickets
-- ---------------------------------------------------------------------------
create or replace function private.issue_class_ticket(
  p_pass_id    uuid,
  p_session_id uuid,
  p_valid_date date,
  p_expires_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $fn$
declare
  v_ticket_id uuid;
  v_token     text;
begin
  insert into public.class_session_tickets
    (class_pass_id, session_id, valid_date, status)
  values
    (p_pass_id, p_session_id, p_valid_date, 'issued')
  on conflict (class_pass_id, session_id) do nothing
  returning id into v_ticket_id;

  if v_ticket_id is null then
    return null;
  end if;

  v_token := encode(gen_random_bytes(24), 'hex');

  insert into public.class_ticket_qr_codes
    (ticket_id, token_hash, expires_at)
  values
    (v_ticket_id, v_token, p_expires_at)
  on conflict (ticket_id) do nothing;

  return v_ticket_id;
end;
$fn$;

revoke all on function private.issue_class_ticket(uuid, uuid, date, timestamptz)
  from public, anon, authenticated;
grant execute on function private.issue_class_ticket(uuid, uuid, date, timestamptz)
  to service_role;

-- Los pases mensuales/VIP cubren también sesiones generadas después de la
-- compra (p. ej. la academia genera un nuevo mes de sesiones).
create or replace function private.issue_tickets_for_new_session()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $fn$
declare
  v_pass record;
begin
  if new.status <> 'scheduled'::public.class_session_status then
    return new;
  end if;

  for v_pass in
    select cp.id, cp.ends_at
      from public.class_passes cp
      join public.class_enrollments ce on ce.id = cp.enrollment_id
     where ce.dance_class_id = new.dance_class_id
       and cp.status = 'active'
       and cp.pass_type in ('monthly', 'vip')
       and new.session_date between cp.starts_at and cp.ends_at
       and not exists (
         select 1
           from public.class_session_tickets cst
          where cst.session_id = new.id
            and cst.class_pass_id in (
              select cp2.id
                from public.class_passes cp2
               where cp2.enrollment_id = cp.enrollment_id
            )
            and cst.status in ('issued', 'used')
       )
  loop
    perform private.issue_class_ticket(
      v_pass.id, new.id, new.session_date, new.end_at
    );
  end loop;

  return new;
end;
$fn$;

drop trigger if exists issue_tickets_for_new_session
  on public.dance_class_sessions;
create trigger issue_tickets_for_new_session
  after insert on public.dance_class_sessions
  for each row execute function private.issue_tickets_for_new_session();

-- ---------------------------------------------------------------------------
-- 6. Cotizaciones
-- ---------------------------------------------------------------------------
create or replace function public.list_class_purchase_sessions(p_class_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $fn$
declare
  v_result jsonb;
begin
  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.session_date), '[]'::jsonb)
    into v_result
    from (
      select s.id,
             s.session_date,
             s.start_at,
             s.end_at,
             c.capacity,
             c.price as price_per_session,
             c.currency,
             (
               select count(*)
                 from public.class_session_tickets cst
                 join public.class_passes cp on cp.id = cst.class_pass_id
                where cst.session_id = s.id
                  and cst.status in ('issued', 'used')
                  and cp.status = 'active'
             ) as occupied,
             exists (
               select 1
                 from public.class_session_tickets cst
                 join public.class_passes cp on cp.id = cst.class_pass_id
                 join public.class_enrollments ce on ce.id = cp.enrollment_id
                where cst.session_id = s.id
                  and cst.status in ('issued', 'used')
                  and ce.dance_class_id = s.dance_class_id
                  and ce.user_id = auth.uid()
             ) as already_purchased
        from public.dance_class_sessions s
        join public.dance_classes c on c.id = s.dance_class_id
       where s.dance_class_id = p_class_id
         and s.status = 'scheduled'::public.class_session_status
         and s.session_date >= current_date
    ) t;

  return v_result;
end;
$fn$;

revoke all on function public.list_class_purchase_sessions(uuid)
  from public, anon;
grant execute on function public.list_class_purchase_sessions(uuid)
  to authenticated;

-- Cotización de N sesiones concretas.
create or replace function public.quote_class_sessions(
  p_enrollment_id uuid,
  p_session_ids   uuid[],
  p_user_id       uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $fn$
declare
  v_enrollment record;
  v_class      record;
  v_count      integer;
  v_session    record;
  v_occupied   integer;
begin
  select * into v_enrollment
    from public.class_enrollments
   where id = p_enrollment_id;

  if not found then
    return jsonb_build_object('success', false, 'reason', 'La inscripción no existe');
  end if;

  if v_enrollment.user_id <> coalesce(p_user_id, auth.uid()) then
    return jsonb_build_object('success', false, 'reason', 'No tienes permiso para comprar estas sesiones');
  end if;

  if v_enrollment.status not in ('pending', 'approved', 'active') then
    return jsonb_build_object('success', false, 'reason', 'La inscripción no está activa');
  end if;

  select * into v_class
    from public.dance_classes
   where id = v_enrollment.dance_class_id;

  if not found then
    return jsonb_build_object('success', false, 'reason', 'La clase no existe');
  end if;

  if coalesce(v_class.price, 0) <= 0 then
    return jsonb_build_object('success', false, 'reason', 'La clase no tiene precio por sesión configurado');
  end if;

  p_session_ids := array(
    select distinct x from unnest(coalesce(p_session_ids, '{}'::uuid[])) x
  );

  v_count := coalesce(array_length(p_session_ids, 1), 0);
  if v_count = 0 then
    return jsonb_build_object('success', false, 'reason', 'Selecciona al menos una sesión');
  end if;

  if exists (
    select 1
      from public.class_session_tickets cst
      join public.class_passes cp on cp.id = cst.class_pass_id
     where cp.enrollment_id = p_enrollment_id
       and cst.session_id = any(p_session_ids)
       and cst.status in ('issued', 'used')
  ) then
    return jsonb_build_object('success', false, 'reason', 'Ya compraste una de las sesiones seleccionadas');
  end if;

  for v_session in
    select s.id, s.session_date, s.end_at
      from public.dance_class_sessions s
     where s.id = any(p_session_ids)
       and s.dance_class_id = v_class.id
       and s.status = 'scheduled'::public.class_session_status
       and s.session_date >= current_date
  loop
    if v_class.capacity is not null then
      select count(*) into v_occupied
        from public.class_session_tickets cst
        join public.class_passes cp on cp.id = cst.class_pass_id
       where cst.session_id = v_session.id
         and cst.status in ('issued', 'used')
         and cp.status = 'active';

      if v_occupied >= v_class.capacity then
        return jsonb_build_object(
          'success', false,
          'reason', format('La sesión del %s está llena', to_char(v_session.session_date, 'YYYY-MM-DD'))
        );
      end if;
    end if;
  end loop;

  if (
    select count(*)
      from public.dance_class_sessions s
     where s.id = any(p_session_ids)
       and s.dance_class_id = v_class.id
       and s.status = 'scheduled'::public.class_session_status
       and s.session_date >= current_date
  ) <> v_count then
    return jsonb_build_object('success', false, 'reason', 'Alguna sesión seleccionada no está disponible');
  end if;

  return jsonb_build_object(
    'success', true,
    'enrollment_id', p_enrollment_id,
    'dance_class_id', v_class.id,
    'organization_id', v_class.organization_id,
    'session_ids', to_jsonb(p_session_ids),
    'session_count', v_count,
    'price', v_class.price,
    'currency', v_class.currency,
    'total_amount', v_class.price * v_count
  );
end;
$fn$;

revoke all on function public.quote_class_sessions(uuid, uuid[], uuid)
  from public, anon;
grant execute on function public.quote_class_sessions(uuid, uuid[], uuid)
  to authenticated;

-- Cotización del pase mensual de una clase.
create or replace function public.quote_class_monthly(
  p_enrollment_id uuid,
  p_user_id       uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $fn$
declare
  v_enrollment  record;
  v_class       record;
  v_start       date := current_date;
  v_end         date := (current_date + interval '1 month - 1 day')::date;
  v_count       integer;
begin
  select * into v_enrollment
    from public.class_enrollments
   where id = p_enrollment_id;

  if not found then
    return jsonb_build_object('success', false, 'reason', 'La inscripción no existe');
  end if;

  if v_enrollment.user_id <> coalesce(p_user_id, auth.uid()) then
    return jsonb_build_object('success', false, 'reason', 'No tienes permiso para comprar este pase');
  end if;

  if v_enrollment.status not in ('pending', 'approved', 'active') then
    return jsonb_build_object('success', false, 'reason', 'La inscripción no está activa');
  end if;

  select * into v_class
    from public.dance_classes
   where id = v_enrollment.dance_class_id;

  if not found then
    return jsonb_build_object('success', false, 'reason', 'La clase no existe');
  end if;

  if coalesce(v_class.price_monthly, 0) <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Esta clase no ofrece pase mensual');
  end if;

  if exists (
    select 1 from public.class_passes
     where enrollment_id = p_enrollment_id
       and status = 'active'
       and pass_type = 'monthly'
  ) then
    return jsonb_build_object('success', false, 'reason', 'Ya tienes un pase mensual activo para esta clase');
  end if;

  select count(*) into v_count
    from public.dance_class_sessions s
   where s.dance_class_id = v_class.id
     and s.status = 'scheduled'::public.class_session_status
     and s.session_date between v_start and v_end;

  return jsonb_build_object(
    'success', true,
    'enrollment_id', p_enrollment_id,
    'dance_class_id', v_class.id,
    'organization_id', v_class.organization_id,
    'period_start', v_start,
    'period_end', v_end,
    'session_count', v_count,
    'price', v_class.price_monthly,
    'currency', v_class.currency,
    'total_amount', v_class.price_monthly
  );
end;
$fn$;

revoke all on function public.quote_class_monthly(uuid, uuid)
  from public, anon;
grant execute on function public.quote_class_monthly(uuid, uuid)
  to authenticated;

-- Cotización del pase VIP de la organización.
create or replace function public.quote_vip_membership(
  p_organization_id uuid,
  p_user_id         uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $fn$
declare
  v_plan     record;
  v_classes  jsonb;
  v_cats     jsonb;
  v_count    integer;
  v_uid      uuid := coalesce(p_user_id, auth.uid());
begin
  select * into v_plan
    from public.organization_vip_plans
   where organization_id = p_organization_id
     and is_active;

  if not found then
    return jsonb_build_object('success', false, 'reason', 'La organización no ofrece pase VIP');
  end if;

  if v_uid is not null and exists (
    select 1 from public.vip_memberships
     where organization_id = p_organization_id
       and user_id = v_uid
       and status = 'active'
       and ends_at >= current_date
  ) then
    return jsonb_build_object('success', false, 'reason', 'Ya tienes un pase VIP activo');
  end if;

  select coalesce(jsonb_agg(
           jsonb_build_object(
             'id', c.id,
             'title', c.title,
             'price_per_session', c.price,
             'price_monthly', c.price_monthly,
             'category_id', c.dance_category_id
           ) order by c.title), '[]'::jsonb), count(*)
    into v_classes, v_count
    from public.dance_classes c
   where c.organization_id = p_organization_id
     and c.status = 'published'::public.class_status
     and (
       v_plan.includes_all_classes
       or c.dance_category_id in (
         select dance_category_id
           from public.organization_vip_plan_categories
          where plan_id = v_plan.id
       )
     );

  select coalesce(jsonb_agg(dance_category_id), '[]'::jsonb)
    into v_cats
    from public.organization_vip_plan_categories
   where plan_id = v_plan.id;

  return jsonb_build_object(
    'success', true,
    'plan_id', v_plan.id,
    'organization_id', p_organization_id,
    'name', v_plan.name,
    'description', v_plan.description,
    'price_monthly', v_plan.price_monthly,
    'currency', v_plan.currency,
    'includes_all_classes', v_plan.includes_all_classes,
    'category_ids', v_cats,
    'class_count', v_count,
    'classes', v_classes,
    'period_start', current_date,
    'period_end', (current_date + interval '1 month - 1 day')::date
  );
end;
$fn$;

revoke all on function public.quote_vip_membership(uuid, uuid)
  from public, anon;
grant execute on function public.quote_vip_membership(uuid, uuid)
  to authenticated;

-- Compatibilidad con la UI anterior: cotiza todas las sesiones restantes.
create or replace function public.preview_class_pass(p_enrollment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $fn$
declare
  v_quote jsonb;
  v_ids   uuid[];
begin
  select array_agg(s.id)
    into v_ids
    from public.dance_class_sessions s
    join public.class_enrollments ce on ce.dance_class_id = s.dance_class_id
   where ce.id = p_enrollment_id
     and s.status = 'scheduled'::public.class_session_status
     and s.session_date >= current_date;

  v_quote := public.quote_class_sessions(p_enrollment_id, coalesce(v_ids, '{}'::uuid[]));
  return v_quote;
end;
$fn$;

grant execute on function public.preview_class_pass(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Compras (solo service_role / pasarela)
-- ---------------------------------------------------------------------------
create or replace function private.purchase_class_sessions_for_user(
  p_enrollment_id uuid,
  p_user_id       uuid,
  p_session_ids   uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $fn$
declare
  v_enrollment record;
  v_class      record;
  v_pass_id    uuid;
  v_count      integer;
  v_total      numeric;
  v_session    record;
  v_occupied   integer;
  v_tickets    jsonb := '[]'::jsonb;
  v_ticket_id  uuid;
begin
  select * into v_enrollment
    from public.class_enrollments
   where id = p_enrollment_id;

  if not found then
    return jsonb_build_object('success', false, 'reason', 'La inscripción no existe');
  end if;

  if v_enrollment.user_id <> p_user_id then
    return jsonb_build_object('success', false, 'reason', 'No tienes permiso para comprar este pase');
  end if;

  if v_enrollment.status not in ('pending', 'approved', 'active') then
    return jsonb_build_object('success', false, 'reason', 'La inscripción no está activa');
  end if;

  select * into v_class
    from public.dance_classes
   where id = v_enrollment.dance_class_id
   for update;

  if not found then
    return jsonb_build_object('success', false, 'reason', 'La clase no existe');
  end if;

  if coalesce(v_class.price, 0) <= 0 then
    return jsonb_build_object('success', false, 'reason', 'La clase no tiene precio por sesión configurado');
  end if;

  p_session_ids := array(
    select distinct x from unnest(coalesce(p_session_ids, '{}'::uuid[])) x
  );
  v_count := coalesce(array_length(p_session_ids, 1), 0);

  if v_count = 0 then
    return jsonb_build_object('success', false, 'reason', 'Selecciona al menos una sesión');
  end if;

  for v_session in
    select s.id, s.session_date, s.end_at
      from public.dance_class_sessions s
     where s.id = any(p_session_ids)
       and s.dance_class_id = v_class.id
       and s.status = 'scheduled'::public.class_session_status
       and s.session_date >= current_date
  loop
    if exists (
      select 1
        from public.class_session_tickets cst
        join public.class_passes cp on cp.id = cst.class_pass_id
       where cp.enrollment_id = p_enrollment_id
         and cst.session_id = v_session.id
         and cst.status in ('issued', 'used')
    ) then
      return jsonb_build_object(
        'success', false,
        'reason', format('Ya compraste un ticket para la sesión del %s', to_char(v_session.session_date, 'YYYY-MM-DD'))
      );
    end if;

    if v_class.capacity is not null then
      select count(*) into v_occupied
        from public.class_session_tickets cst
        join public.class_passes cp on cp.id = cst.class_pass_id
       where cst.session_id = v_session.id
         and cst.status in ('issued', 'used')
         and cp.status = 'active';

      if v_occupied >= v_class.capacity then
        return jsonb_build_object(
          'success', false,
          'reason', format('La sesión del %s está llena', to_char(v_session.session_date, 'YYYY-MM-DD'))
        );
      end if;
    end if;
  end loop;

  if (
    select count(*)
      from public.dance_class_sessions s
     where s.id = any(p_session_ids)
       and s.dance_class_id = v_class.id
       and s.status = 'scheduled'::public.class_session_status
       and s.session_date >= current_date
  ) <> v_count then
    return jsonb_build_object('success', false, 'reason', 'Alguna sesión seleccionada no está disponible');
  end if;

  v_total := v_class.price * v_count;

  insert into public.class_passes
    (enrollment_id, starts_at, ends_at, status, session_count, price,
     currency, total_amount, pass_type)
  values
    (p_enrollment_id, current_date, current_date, 'active', v_count,
     v_class.price, v_class.currency, v_total,
     case when v_count = 1 then 'session' else 'sessions' end)
  returning id into v_pass_id;

  for v_session in
    select s.id, s.session_date, s.end_at
      from public.dance_class_sessions s
     where s.id = any(p_session_ids)
     order by s.session_date
  loop
    v_ticket_id := private.issue_class_ticket(
      v_pass_id, v_session.id, v_session.session_date, v_session.end_at
    );

    if v_ticket_id is not null then
      v_tickets := v_tickets || jsonb_build_object(
        'ticket_id', v_ticket_id,
        'session_id', v_session.id,
        'session_date', v_session.session_date
      );
    end if;
  end loop;

  return jsonb_build_object(
    'success', true,
    'pass_id', v_pass_id,
    'pass_type', case when v_count = 1 then 'session' else 'sessions' end,
    'session_ids', to_jsonb(p_session_ids),
    'session_count', v_count,
    'price', v_class.price,
    'currency', v_class.currency,
    'total_amount', v_total,
    'tickets_generated', jsonb_array_length(v_tickets),
    'tickets', v_tickets
  );
end;
$fn$;

revoke all on function private.purchase_class_sessions_for_user(uuid, uuid, uuid[])
  from public, anon, authenticated;
grant execute on function private.purchase_class_sessions_for_user(uuid, uuid, uuid[])
  to service_role;

create or replace function private.purchase_class_monthly_for_user(
  p_enrollment_id uuid,
  p_user_id       uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $fn$
declare
  v_enrollment record;
  v_class      record;
  v_pass_id    uuid;
  v_start      date := current_date;
  v_end        date := (current_date + interval '1 month - 1 day')::date;
  v_count      integer := 0;
  v_session    record;
  v_ticket_id  uuid;
begin
  select * into v_enrollment
    from public.class_enrollments
   where id = p_enrollment_id;

  if not found then
    return jsonb_build_object('success', false, 'reason', 'La inscripción no existe');
  end if;

  if v_enrollment.user_id <> p_user_id then
    return jsonb_build_object('success', false, 'reason', 'No tienes permiso para comprar este pase');
  end if;

  if v_enrollment.status not in ('pending', 'approved', 'active') then
    return jsonb_build_object('success', false, 'reason', 'La inscripción no está activa');
  end if;

  select * into v_class
    from public.dance_classes
   where id = v_enrollment.dance_class_id
   for update;

  if not found then
    return jsonb_build_object('success', false, 'reason', 'La clase no existe');
  end if;

  if coalesce(v_class.price_monthly, 0) <= 0 then
    return jsonb_build_object('success', false, 'reason', 'Esta clase no ofrece pase mensual');
  end if;

  if exists (
    select 1 from public.class_passes
     where enrollment_id = p_enrollment_id
       and status = 'active'
       and pass_type = 'monthly'
  ) then
    return jsonb_build_object('success', false, 'reason', 'Ya tienes un pase mensual activo para esta clase');
  end if;

  insert into public.class_passes
    (enrollment_id, starts_at, ends_at, status, session_count, price,
     currency, total_amount, pass_type)
  values
    (p_enrollment_id, v_start, v_end, 'active', 0, v_class.price_monthly,
     v_class.currency, v_class.price_monthly, 'monthly')
  returning id into v_pass_id;

  for v_session in
    select s.id, s.session_date, s.end_at
      from public.dance_class_sessions s
     where s.dance_class_id = v_class.id
       and s.status = 'scheduled'::public.class_session_status
       and s.session_date between v_start and v_end
       and not exists (
         select 1
           from public.class_session_tickets cst
           join public.class_passes cp on cp.id = cst.class_pass_id
          where cp.enrollment_id = p_enrollment_id
            and cst.session_id = s.id
            and cst.status in ('issued', 'used')
       )
     order by s.session_date
  loop
    v_ticket_id := private.issue_class_ticket(
      v_pass_id, v_session.id, v_session.session_date, v_session.end_at
    );
    if v_ticket_id is not null then
      v_count := v_count + 1;
    end if;
  end loop;

  update public.class_passes
     set session_count = v_count,
         updated_at = now()
   where id = v_pass_id;

  return jsonb_build_object(
    'success', true,
    'pass_id', v_pass_id,
    'pass_type', 'monthly',
    'period_start', v_start,
    'period_end', v_end,
    'session_count', v_count,
    'price', v_class.price_monthly,
    'currency', v_class.currency,
    'total_amount', v_class.price_monthly,
    'tickets_generated', v_count
  );
end;
$fn$;

revoke all on function private.purchase_class_monthly_for_user(uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.purchase_class_monthly_for_user(uuid, uuid)
  to service_role;

create or replace function private.purchase_vip_for_user(
  p_organization_id uuid,
  p_user_id         uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $fn$
declare
  v_plan       record;
  v_vip_id     uuid;
  v_start      date := current_date;
  v_end        date := (current_date + interval '1 month - 1 day')::date;
  v_class      record;
  v_enrollment uuid;
  v_pass_id    uuid;
  v_count      integer;
  v_total_sessions integer := 0;
  v_classes    jsonb := '[]'::jsonb;
begin
  select * into v_plan
    from public.organization_vip_plans
   where organization_id = p_organization_id
     and is_active
   for update;

  if not found then
    return jsonb_build_object('success', false, 'reason', 'La organización no ofrece pase VIP');
  end if;

  if exists (
    select 1 from public.vip_memberships
     where organization_id = p_organization_id
       and user_id = p_user_id
       and status = 'active'
       and ends_at >= current_date
  ) then
    return jsonb_build_object('success', false, 'reason', 'Ya tienes un pase VIP activo');
  end if;

  insert into public.vip_memberships
    (organization_id, user_id, plan_id, status, price, currency, starts_at, ends_at)
  values
    (p_organization_id, p_user_id, v_plan.id, 'active',
     v_plan.price_monthly, v_plan.currency, v_start, v_end)
  returning id into v_vip_id;

  for v_class in
    select c.id, c.title, c.price, c.currency
      from public.dance_classes c
     where c.organization_id = p_organization_id
       and c.status = 'published'::public.class_status
       and (
         v_plan.includes_all_classes
         or c.dance_category_id in (
           select dance_category_id
             from public.organization_vip_plan_categories
            where plan_id = v_plan.id
         )
       )
     order by c.title
  loop
    select ce.id into v_enrollment
      from public.class_enrollments ce
     where ce.dance_class_id = v_class.id
       and ce.user_id = p_user_id
       and ce.status in ('pending', 'approved', 'active')
     limit 1;

    if v_enrollment is null then
      insert into public.class_enrollments (dance_class_id, user_id, status)
      values (v_class.id, p_user_id, 'active')
      returning id into v_enrollment;
    end if;

    v_count := 0;

    insert into public.class_passes
      (enrollment_id, starts_at, ends_at, status, session_count, price,
       currency, total_amount, pass_type, vip_membership_id)
    values
      (v_enrollment, v_start, v_end, 'active', 0, 0,
       v_plan.currency, 0, 'vip', v_vip_id)
    returning id into v_pass_id;

    perform private.issue_class_ticket(
      v_pass_id, s.id, s.session_date, s.end_at
    )
      from public.dance_class_sessions s
     where s.dance_class_id = v_class.id
       and s.status = 'scheduled'::public.class_session_status
       and s.session_date between v_start and v_end
       and not exists (
         select 1
           from public.class_session_tickets cst
           join public.class_passes cp on cp.id = cst.class_pass_id
          where cp.enrollment_id = v_enrollment
            and cst.session_id = s.id
            and cst.status in ('issued', 'used')
       );

    select count(*) into v_count
      from public.class_session_tickets
     where class_pass_id = v_pass_id;

    update public.class_passes
       set session_count = v_count, updated_at = now()
     where id = v_pass_id;

    v_total_sessions := v_total_sessions + v_count;
    v_classes := v_classes || jsonb_build_object(
      'class_id', v_class.id,
      'title', v_class.title,
      'enrollment_id', v_enrollment,
      'pass_id', v_pass_id,
      'session_count', v_count
    );
  end loop;

  return jsonb_build_object(
    'success', true,
    'vip_membership_id', v_vip_id,
    'organization_id', p_organization_id,
    'plan_id', v_plan.id,
    'period_start', v_start,
    'period_end', v_end,
    'class_count', jsonb_array_length(v_classes),
    'session_count', v_total_sessions,
    'price', v_plan.price_monthly,
    'currency', v_plan.currency,
    'total_amount', v_plan.price_monthly,
    'classes', v_classes
  );
end;
$fn$;

revoke all on function private.purchase_vip_for_user(uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.purchase_vip_for_user(uuid, uuid)
  to service_role;

-- Compatibilidad: el webhook antiguo llama purchase_class_pass_for_user con
-- todas las sesiones restantes.
create or replace function private.purchase_class_pass_for_user(
  p_enrollment_id uuid,
  p_user_id       uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $fn$
declare
  v_ids uuid[];
begin
  select array_agg(s.id)
    into v_ids
    from public.dance_class_sessions s
    join public.class_enrollments ce on ce.dance_class_id = s.dance_class_id
   where ce.id = p_enrollment_id
     and s.status = 'scheduled'::public.class_session_status
     and s.session_date >= current_date;

  return private.purchase_class_sessions_for_user(
    p_enrollment_id, p_user_id, coalesce(v_ids, '{}'::uuid[])
  );
end;
$fn$;

revoke all on function private.purchase_class_pass_for_user(uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.purchase_class_pass_for_user(uuid, uuid)
  to service_role;

-- El cliente sigue comprando solo con la pasarela.
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

revoke all on function public.purchase_class_pass(uuid)
  from public, anon, authenticated;
grant execute on function public.purchase_class_pass(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 8. Consultas del estudiante
-- ---------------------------------------------------------------------------
create or replace function public.fetch_my_class_passes()
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_result jsonb;
begin
  select coalesce(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
    into v_result
    from (
      select cp.id,
             cp.starts_at,
             cp.ends_at,
             cp.status as pass_status,
             cp.pass_type,
             cp.session_count,
             cp.price,
             cp.currency,
             cp.total_amount,
             cp.vip_membership_id,
             ce.dance_class_id as class_id,
             ce.id as enrollment_id,
             dc.title as class_title,
             o.id as organization_id,
             o.name as organization_name
        from public.class_passes cp
        join public.class_enrollments ce on ce.id = cp.enrollment_id
        join public.dance_classes dc on dc.id = ce.dance_class_id
        join public.organizations o on o.id = dc.organization_id
       where ce.user_id = auth.uid()
       order by cp.created_at desc
    ) t;

  return v_result;
end;
$fn$;

grant execute on function public.fetch_my_class_passes() to authenticated;

create or replace function public.fetch_my_vip_memberships()
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_result jsonb;
begin
  select coalesce(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
    into v_result
    from (
      select vm.id,
             vm.organization_id,
             o.name as organization_name,
             vm.status,
             vm.price,
             vm.currency,
             vm.starts_at,
             vm.ends_at,
             p.name as plan_name
        from public.vip_memberships vm
        join public.organizations o on o.id = vm.organization_id
        left join public.organization_vip_plans p on p.id = vm.plan_id
       where vm.user_id = auth.uid()
       order by vm.created_at desc
    ) t;

  return v_result;
end;
$fn$;

grant execute on function public.fetch_my_vip_memberships() to authenticated;

-- ---------------------------------------------------------------------------
-- 9. Publicación: membresía mensual activa + pago de publicación
-- ---------------------------------------------------------------------------
create or replace function private.guard_event_publication_payment()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public, auth
as $fn$
begin
  if new.status = 'published'::public.event_status
     and old.status is distinct from new.status
     and not private.is_platform_admin()
  then
    if not private.organization_has_active_membership(new.organization_id) then
      raise exception 'Se requiere una suscripción mensual activa para publicar el evento'
        using errcode = '42501';
    end if;

    if not exists (
      select 1 from public.event_publication_payments p
      where p.event_id = new.id
    ) then
      raise exception 'Se requiere el pago de publicación para publicar el evento'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$fn$;

create or replace function private.guard_class_publication_payment()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public, auth
as $fn$
begin
  if new.status = 'published'::public.class_status
     and old.status is distinct from new.status
     and not private.is_platform_admin()
  then
    if not private.organization_has_active_membership(new.organization_id) then
      raise exception 'Se requiere una suscripción mensual activa para publicar la clase'
        using errcode = '42501';
    end if;

    if not exists (
      select 1 from public.dance_class_publication_payments p
      where p.dance_class_id = new.id
    ) then
      raise exception 'Se requiere el pago de publicación para publicar la clase'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$fn$;

drop trigger if exists guard_event_publication_payment on public.events;
create trigger guard_event_publication_payment
  before update of status on public.events
  for each row execute function private.guard_event_publication_payment();

drop trigger if exists guard_class_publication_payment on public.dance_classes;
create trigger guard_class_publication_payment
  before update of status on public.dance_classes
  for each row execute function private.guard_class_publication_payment();

-- Un evento/clase no puede nacer publicado sin membresía y pago.
-- Nota: los borradores se crean en 'draft'/'pending'; la publicación siempre
-- pasa por los triggers de UPDATE de arriba.

-- ---------------------------------------------------------------------------
-- 10. payment_intents: nuevos tipos y unicidad por usuario
-- ---------------------------------------------------------------------------
alter table public.payment_intents
  drop constraint if exists payment_intents_kind_check;

alter table public.payment_intents
  add constraint payment_intents_kind_check
  check (kind in (
    'class_pass', 'class_monthly', 'vip_membership',
    'membership', 'event_publication', 'class_publication'
  ));

drop index if exists public.payment_intents_active_uidx;
create unique index payment_intents_active_uidx
  on public.payment_intents (kind, reference_id, user_id)
  where status = 'pending';

-- ---------------------------------------------------------------------------
-- 11. Despacho del webhook: ramas para pase por sesiones, mensual y VIP
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
  v_session_ids uuid[];
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
      select array_agg(x::uuid)
        into v_session_ids
        from jsonb_array_elements_text(
          coalesce(v_intent.metadata->'session_ids', '[]'::jsonb)
        ) x;

      v_result := private.purchase_class_sessions_for_user(
        v_intent.reference_id, v_intent.user_id, coalesce(v_session_ids, '{}'::uuid[])
      );
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
                            'intent_id', v_intent.id, 'session_count', v_result->'session_count'));

    elsif v_intent.kind = 'class_monthly' then
      v_result := private.purchase_class_monthly_for_user(
        v_intent.reference_id, v_intent.user_id
      );
      if coalesce((v_result->>'success')::boolean, false) is not true then
        raise exception '%', coalesce(v_result->>'reason', 'No se pudo crear el pase mensual');
      end if;

      insert into public.payments
        (payment_type, user_id, organization_id, amount, currency, status,
         provider, provider_payment_id, payment_method, paid_at, metadata)
      values
        ('other', v_intent.user_id, v_intent.organization_id,
         v_intent.amount, v_intent.currency, 'paid', 'pagosya', v_payment_id,
         'qr', now(),
         jsonb_build_object('kind', 'class_monthly', 'enrollment_id', v_intent.reference_id,
                            'intent_id', v_intent.id));

    elsif v_intent.kind = 'vip_membership' then
      v_result := private.purchase_vip_for_user(
        v_intent.reference_id, v_intent.user_id
      );
      if coalesce((v_result->>'success')::boolean, false) is not true then
        raise exception '%', coalesce(v_result->>'reason', 'No se pudo activar el pase VIP');
      end if;

      insert into public.payments
        (payment_type, user_id, organization_id, amount, currency, status,
         provider, provider_payment_id, payment_method, paid_at, metadata)
      values
        ('other', v_intent.user_id, v_intent.organization_id,
         v_intent.amount, v_intent.currency, 'paid', 'pagosya', v_payment_id,
         'qr', now(),
         jsonb_build_object('kind', 'vip_membership', 'organization_id', v_intent.reference_id,
                            'vip_membership_id', v_result->'vip_membership_id',
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

  -- Órdenes de tickets
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

revoke all on function public.pagosya_apply_checkout_completed(jsonb)
  from public, anon, authenticated;
grant execute on function public.pagosya_apply_checkout_completed(jsonb)
  to service_role;

-- ---------------------------------------------------------------------------
-- 12. Refrescar el caché de PostgREST
-- ---------------------------------------------------------------------------
notify pgrst, 'reload schema';
