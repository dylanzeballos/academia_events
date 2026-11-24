-- Plataforma: moderación, accesos por evento, membresías y auditoría.
-- Esta migración es aditiva: conserva event_status/status legacy y payment data.

create schema if not exists private;

create or replace function private.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select auth.uid() is not null and exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid() and ur.role = 'admin'
  );
$$;

revoke all on function private.is_platform_admin() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.is_platform_admin() to authenticated;

-- El rol de plataforma solo puede asignarse mediante un canal confiable (SQL/servidor).
alter table public.user_roles enable row level security;
drop policy if exists user_roles_read_self_or_admin on public.user_roles;
create policy user_roles_read_self_or_admin on public.user_roles
  for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_platform_admin()));
revoke insert, update, delete on public.user_roles from anon, authenticated;
grant select on public.user_roles to authenticated;

-- El estado de moderación queda separado del ciclo operativo legado del evento.
alter table public.events
  add column if not exists moderation_status text not null default 'pending_approval',
  add column if not exists moderation_updated_at timestamptz,
  add column if not exists moderation_updated_by uuid references public.profiles(id),
  add column if not exists moderation_reason text;

alter table public.events drop constraint if exists events_moderation_status_check;
alter table public.events add constraint events_moderation_status_check
  check (moderation_status in ('pending_approval', 'approved', 'rejected', 'suspended'));
update public.events set moderation_status = 'approved'
 where status = 'published' and moderation_status = 'pending_approval';
alter table public.events alter column moderation_status set default 'pending_approval';

create or replace function private.guard_event_moderation_fields()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  if (new.moderation_status, new.moderation_updated_at,
      new.moderation_updated_by, new.moderation_reason)
     is distinct from
     (old.moderation_status, old.moderation_updated_at,
      old.moderation_updated_by, old.moderation_reason)
     and not (select private.is_platform_admin()) then
    raise exception 'Solo un administrador puede cambiar la moderación del evento'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_event_moderation_fields on public.events;
create trigger guard_event_moderation_fields
  before update on public.events
  for each row execute function private.guard_event_moderation_fields();

create or replace function private.guard_event_membership()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public, auth
as $$
declare v_requires_membership boolean;
begin
  v_requires_membership := tg_op = 'INSERT';
  if tg_op = 'UPDATE' then
    v_requires_membership :=
      (new.status = 'published'::public.event_status and old.status is distinct from new.status)
      or (new.moderation_status = 'approved' and old.moderation_status is distinct from new.moderation_status);
  end if;
  if v_requires_membership then
    if not private.organization_can_create_events(new.organization_id) then
      raise exception 'Se requiere una membresía activa para crear o publicar eventos'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.organization_can_create_events(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.organizations o
    join public.subscriptions s on s.organization_id = o.id
    where o.id = p_organization_id and o.is_active
      and s.status = 'active'::public.subscription_status
      and (s.current_period_start is null or s.current_period_start <= now())
      and (s.current_period_end is null or s.current_period_end > now())
  );
$$;
revoke all on function private.organization_can_create_events(uuid) from public, anon;
grant execute on function private.organization_can_create_events(uuid) to authenticated;
drop trigger if exists guard_event_membership on public.events;
create trigger guard_event_membership
  before insert or update of status, moderation_status on public.events
  for each row execute function private.guard_event_membership();

create table if not exists public.event_access_points (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 100),
  description text,
  is_active boolean not null default true,
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (event_id, name)
);

create table if not exists public.event_access_point_staff (
  access_point_id uuid not null references public.event_access_points(id) on delete cascade,
  organization_member_id uuid not null references public.organization_members(id) on delete cascade,
  assigned_by uuid not null default auth.uid() references public.profiles(id),
  assigned_at timestamptz not null default now(),
  primary key (access_point_id, organization_member_id)
);

create index if not exists idx_event_access_points_event_active
  on public.event_access_points(event_id, is_active);
create index if not exists idx_event_access_staff_member
  on public.event_access_point_staff(organization_member_id);

alter table public.check_ins
  add column if not exists access_point_id uuid
    references public.event_access_points(id) on delete set null;

alter table public.event_access_points enable row level security;
alter table public.event_access_point_staff enable row level security;
drop policy if exists access_points_read_org on public.event_access_points;
create policy access_points_read_org on public.event_access_points
  for select to authenticated using (
    exists (
      select 1 from public.events e
      join public.organization_members om on om.organization_id = e.organization_id
      where e.id = event_id and om.user_id = (select auth.uid()) and om.is_active
    ) or (select private.is_platform_admin())
  );
drop policy if exists access_points_manage_org on public.event_access_points;
create policy access_points_manage_org on public.event_access_points
  for all to authenticated
  using (
    (select private.is_platform_admin()) or exists (
      select 1 from public.events e
      join public.organization_members om on om.organization_id = e.organization_id
      where e.id = event_id and om.user_id = (select auth.uid())
        and om.is_active and om.role::text in ('owner', 'admin', 'manager')
    )
  )
  with check (
    (select private.is_platform_admin()) or exists (
      select 1 from public.events e
      join public.organization_members om on om.organization_id = e.organization_id
      where e.id = event_id and om.user_id = (select auth.uid())
        and om.is_active and om.role::text in ('owner', 'admin', 'manager')
    )
  );
drop policy if exists access_point_staff_read on public.event_access_point_staff;
create policy access_point_staff_read on public.event_access_point_staff
  for select to authenticated using (
    (select private.is_platform_admin()) or exists (
      select 1 from public.event_access_points ap
      join public.events e on e.id = ap.event_id
      join public.organization_members om on om.organization_id = e.organization_id
      where ap.id = access_point_id and om.user_id = (select auth.uid()) and om.is_active
    )
  );
drop policy if exists access_point_staff_manage on public.event_access_point_staff;
create policy access_point_staff_manage on public.event_access_point_staff
  for all to authenticated
  using (
    (select private.is_platform_admin()) or exists (
      select 1 from public.event_access_points ap
      join public.events e on e.id = ap.event_id
      join public.organization_members om on om.organization_id = e.organization_id
      where ap.id = access_point_id and om.user_id = (select auth.uid())
        and om.is_active and om.role::text in ('owner', 'admin', 'manager')
    )
  )
  with check (
    (select private.is_platform_admin()) or exists (
      select 1 from public.event_access_points ap
      join public.events e on e.id = ap.event_id
      join public.organization_members manager on manager.organization_id = e.organization_id
      join public.organization_members staff on staff.id = organization_member_id
      where ap.id = access_point_id and manager.user_id = (select auth.uid())
        and manager.is_active and manager.role::text in ('owner', 'admin', 'manager')
        and staff.organization_id = e.organization_id and staff.is_active
    )
  );

-- Las entradas nuevas quedan pendientes de revisión; eventos ya publicados conservan
-- aprobación para no ocultar publicaciones existentes tras desplegar la migración.
create or replace function public.admin_set_event_moderation(
  p_event_id uuid, p_status text, p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth, private
as $$
begin
  if not private.is_platform_admin() then
    raise exception 'Acceso administrativo requerido' using errcode = '42501';
  end if;
  if p_status not in ('pending_approval', 'approved', 'rejected', 'suspended') then
    raise exception 'Estado de moderación inválido';
  end if;
  update public.events
     set moderation_status = p_status,
         moderation_updated_at = now(), moderation_updated_by = auth.uid(),
         moderation_reason = nullif(trim(p_reason), ''),
         status = case
           when p_status = 'approved' then 'published'::public.event_status
           when p_status = 'rejected' then 'rejected'::public.event_status
           else status
         end,
         published_at = case when p_status = 'approved' then coalesce(published_at, now()) else published_at end,
         updated_at = now()
   where id = p_event_id;
  if not found then raise exception 'Evento no encontrado'; end if;
  insert into public.event_moderation(event_id, admin_user_id, action, reason)
  values (p_event_id, auth.uid(),
    case p_status when 'approved' then 'approved'::public.moderation_action
      when 'rejected' then 'rejected'::public.moderation_action
      when 'suspended' then 'unpublished'::public.moderation_action
      else 'submitted'::public.moderation_action end,
    nullif(trim(p_reason), ''));
  insert into public.audit_logs(user_id, action, entity_type, entity_id, new_values)
  values (auth.uid(), 'event_moderation_' || p_status, 'event', p_event_id,
    jsonb_build_object('status', p_status, 'reason', nullif(trim(p_reason), '')));
end;
$$;
revoke all on function public.admin_set_event_moderation(uuid, text, text) from public, anon;
grant execute on function public.admin_set_event_moderation(uuid, text, text) to authenticated;

create or replace function public.admin_set_organization_active(p_organization_id uuid, p_active boolean)
returns void
language plpgsql security definer
set search_path = pg_catalog, public, auth, private
as $$
begin
  if not private.is_platform_admin() then
    raise exception 'Acceso administrativo requerido' using errcode = '42501';
  end if;
  update public.organizations set is_active = p_active, updated_at = now()
   where id = p_organization_id;
  if not found then raise exception 'Organización no encontrada'; end if;
  insert into public.audit_logs(user_id, action, entity_type, entity_id, new_values)
  values (auth.uid(), case when p_active then 'organization_activated' else 'organization_suspended' end,
    'organization', p_organization_id, jsonb_build_object('is_active', p_active));
end;
$$;
revoke all on function public.admin_set_organization_active(uuid, boolean) from public, anon;
grant execute on function public.admin_set_organization_active(uuid, boolean) to authenticated;

-- Se reutilizan subscriptions/payments/payouts existentes; el proveedor de pago queda
-- como referencia, sin lógica automática ni credenciales de pasarela en el cliente.
alter table public.subscriptions
  add column if not exists billing_interval text not null default 'month'
    check (billing_interval in ('month', 'year', 'one_time')),
  add column if not exists requested_at timestamptz,
  add column if not exists verified_by uuid references public.profiles(id),
  add column if not exists verified_at timestamptz;

create or replace function public.request_organization_membership(
  p_organization_id uuid, p_plan_id uuid, p_payment_note text default null
)
returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_subscription_id uuid;
  v_payment_id uuid;
  v_amount numeric;
  v_currency char(3);
  v_interval text;
begin
  if auth.uid() is null or not exists (
    select 1 from public.organization_members om
    where om.organization_id = p_organization_id and om.user_id = auth.uid()
      and om.is_active and om.role::text in ('owner', 'admin', 'manager')
  ) then
    raise exception 'Solo un administrador de la organización puede solicitar membresía'
      using errcode = '42501';
  end if;
  select price, currency, interval::text into v_amount, v_currency, v_interval
    from public.subscription_plans where id = p_plan_id and is_active;
  if not found then raise exception 'El plan no existe o está inactivo'; end if;
  if exists (select 1 from public.subscriptions s where s.organization_id = p_organization_id
      and s.status in ('pending', 'active', 'past_due')) then
    raise exception 'La organización ya tiene una membresía pendiente o vigente';
  end if;
  insert into public.subscriptions(organization_id, plan_id, status, requested_at, billing_interval)
  values (p_organization_id, p_plan_id, 'pending', now(),
    case when v_interval = 'yearly' then 'year' else 'month' end)
  returning id into v_subscription_id;
  insert into public.payments(payment_type, user_id, organization_id, subscription_id,
    amount, currency, status, provider, payment_method, metadata)
  values ('subscription', auth.uid(), p_organization_id, v_subscription_id,
    v_amount, v_currency, 'pending', 'manual_pending', 'manual',
    jsonb_build_object('payment_note', nullif(trim(p_payment_note), '')))
  returning id into v_payment_id;
  insert into public.audit_logs(user_id, action, entity_type, entity_id, new_values)
  values (auth.uid(), 'membership_requested', 'subscription', v_subscription_id,
    jsonb_build_object('payment_id', v_payment_id, 'plan_id', p_plan_id, 'amount', v_amount));
  return jsonb_build_object('subscription_id', v_subscription_id,
    'payment_id', v_payment_id, 'amount', v_amount, 'currency', v_currency,
    'payment_status', 'pending');
end;
$$;
revoke all on function public.request_organization_membership(uuid, uuid, text) from public, anon;
grant execute on function public.request_organization_membership(uuid, uuid, text) to authenticated;

alter table public.event_moderation enable row level security;
alter table public.audit_logs enable row level security;
alter table public.orders enable row level security;
alter table public.payments enable row level security;
alter table public.subscriptions enable row level security;
alter table public.payouts enable row level security;
alter table public.event_publication_payments enable row level security;
alter table public.dance_class_publication_payments enable row level security;

drop policy if exists platform_admin_event_moderation_read on public.event_moderation;
create policy platform_admin_event_moderation_read on public.event_moderation
  for select to authenticated using ((select private.is_platform_admin()));
drop policy if exists order_owner_or_admin_read on public.orders;
create policy order_owner_or_admin_read on public.orders
  for select to authenticated using (
    user_id = (select auth.uid())
    or (select private.is_platform_admin())
    or exists (
      select 1 from public.events e
      join public.organization_members om on om.organization_id=e.organization_id
      where e.id=orders.event_id and om.user_id=(select auth.uid())
        and om.is_active and om.role::text in ('owner', 'admin', 'manager')
    )
  );
drop policy if exists platform_admin_audit_read on public.audit_logs;
create policy platform_admin_audit_read on public.audit_logs
  for select to authenticated using ((select private.is_platform_admin()));
drop policy if exists platform_admin_payments_read on public.payments;
create policy platform_admin_payments_read on public.payments
  for select to authenticated using ((select private.is_platform_admin()));
drop policy if exists org_admin_payments_read on public.payments;
create policy org_admin_payments_read on public.payments
  for select to authenticated using (
    organization_id is not null and exists (
      select 1 from public.organization_members om
      where om.organization_id = payments.organization_id
        and om.user_id = (select auth.uid()) and om.is_active
        and om.role::text in ('owner', 'admin', 'manager')
    )
  );
drop policy if exists platform_admin_subscriptions_read on public.subscriptions;
create policy platform_admin_subscriptions_read on public.subscriptions
  for select to authenticated using ((select private.is_platform_admin()));
drop policy if exists org_admin_subscriptions_read on public.subscriptions;
create policy org_admin_subscriptions_read on public.subscriptions
  for select to authenticated using (exists (
    select 1 from public.organization_members om
    where om.organization_id = subscriptions.organization_id
      and om.user_id = (select auth.uid()) and om.is_active and om.role::text in ('owner', 'admin', 'manager')
  ));
drop policy if exists platform_admin_payouts_read on public.payouts;
create policy platform_admin_payouts_read on public.payouts
  for select to authenticated using ((select private.is_platform_admin()));
drop policy if exists org_admin_payouts_read on public.payouts;
create policy org_admin_payouts_read on public.payouts
  for select to authenticated using (exists (
    select 1 from public.organization_members om
    where om.organization_id = payouts.organization_id
      and om.user_id = (select auth.uid()) and om.is_active and om.role::text in ('owner', 'admin', 'manager')
  ));
drop policy if exists platform_admin_publication_payments_read on public.event_publication_payments;
create policy platform_admin_publication_payments_read on public.event_publication_payments
  for select to authenticated using ((select private.is_platform_admin()));
drop policy if exists platform_admin_class_publication_payments_read on public.dance_class_publication_payments;
create policy platform_admin_class_publication_payments_read on public.dance_class_publication_payments
  for select to authenticated using ((select private.is_platform_admin()));
drop policy if exists org_owner_class_publication_payments_read on public.dance_class_publication_payments;
create policy org_owner_class_publication_payments_read on public.dance_class_publication_payments
  for select to authenticated using (exists (
    select 1 from public.organization_members om
    join public.dance_classes dc on dc.organization_id = om.organization_id
    where dc.id = dance_class_publication_payments.dance_class_id
      and om.user_id = (select auth.uid()) and om.role::text in ('owner', 'admin', 'manager') and om.is_active
  ));

-- Los montos no se pueden modificar con operaciones directas del cliente.
revoke insert, update, delete on public.payments, public.subscriptions,
  public.payouts, public.event_publication_payments from anon, authenticated;
revoke insert, update, delete on public.dance_class_publication_payments from anon, authenticated;
revoke insert, update, delete on public.orders from anon, authenticated;
grant select on public.payments, public.subscriptions, public.payouts,
  public.event_publication_payments, public.dance_class_publication_payments to authenticated;
grant select on public.orders to authenticated;

-- Lectura del panel también se valida en backend. La función solo expone un
-- conjunto fijo de columnas y no acepta nombres de tablas/columnas del cliente.
create or replace function public.admin_fetch_section(p_section text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, private
as $$
declare v_rows jsonb;
begin
  if not private.is_platform_admin() then
    raise exception 'Acceso administrativo requerido' using errcode = '42501';
  end if;
  case p_section
    when 'dashboard' then
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
        select e.id, e.title, e.moderation_status, e.created_at,
          jsonb_build_object('name', o.name) as organizations
        from public.events e left join public.organizations o on o.id=e.organization_id
        order by e.created_at desc limit 100
      ) r;
    when 'events' then
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
        select e.id, e.title, e.status, e.moderation_status, e.moderation_reason,
          e.start_at, e.organization_id, e.created_at,
          jsonb_build_object('name', o.name) as organizations
        from public.events e left join public.organizations o on o.id=e.organization_id
        order by e.created_at desc limit 100
      ) r;
    when 'organizations' then
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
        select id, name, is_active, is_verified, created_at from public.organizations
        order by created_at desc limit 100
      ) r;
    when 'users' then
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
        select id, first_name, last_name, phone_number, is_active, created_at
        from public.profiles order by created_at desc limit 100
      ) r;
    when 'memberships' then
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
        select s.id, s.organization_id, s.plan_id, s.status, s.current_period_start,
          s.current_period_end, s.created_at,
          jsonb_build_object('name', o.name) as organizations,
          jsonb_build_object('name', sp.name) as subscription_plans
        from public.subscriptions s
        left join public.organizations o on o.id=s.organization_id
        left join public.subscription_plans sp on sp.id=s.plan_id
        order by s.created_at desc limit 100
      ) r;
    when 'payments' then
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
        select id, payment_type, organization_id, order_id, amount, currency, status,
          provider, provider_payment_id, paid_at, created_at from public.payments
        order by created_at desc limit 100
      ) r;
    when 'publicationPayments' then
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
        select ep.id, ep.event_id, ep.payment_id, ep.amount, ep.currency, ep.paid_at,
          jsonb_build_object('title', e.title) as events
        from public.event_publication_payments ep
        left join public.events e on e.id=ep.event_id
        order by ep.created_at desc limit 100
      ) r;
    when 'classPublicationPayments' then
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
        select cp.id, cp.dance_class_id, cp.payment_id, cp.amount, cp.currency, cp.paid_at,
          jsonb_build_object('title', dc.title) as dance_classes
        from public.dance_class_publication_payments cp
        left join public.dance_classes dc on dc.id=cp.dance_class_id
        order by cp.created_at desc limit 100
      ) r;
    when 'sales' then
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
        select o.id, o.order_number, o.event_id, o.user_id, o.status, o.subtotal,
          o.platform_fee, o.total_amount, o.currency, o.created_at,
          jsonb_build_object('title', e.title) as events
        from public.orders o left join public.events e on e.id=o.event_id
        order by o.created_at desc limit 100
      ) r;
    when 'payouts' then
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
        select p.id, p.organization_id, p.amount, p.currency, p.status, p.provider,
          p.processed_at, p.created_at, jsonb_build_object('name', o.name) as organizations
        from public.payouts p left join public.organizations o on o.id=p.organization_id
        order by p.created_at desc limit 100
      ) r;
    when 'audit' then
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
        select a.id, a.user_id, a.action, a.entity_type, a.entity_id,
          a.old_values, a.new_values, a.created_at,
          jsonb_build_object('first_name', pr.first_name, 'last_name', pr.last_name) as profiles
        from public.audit_logs a left join public.profiles pr on pr.id=a.user_id
        order by a.created_at desc limit 100
      ) r;
    when 'categories' then
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
        select id, name, is_active, created_at from public.event_categories
        order by name limit 100
      ) r;
    when 'classes' then
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
        select dc.id, dc.title, dc.status, dc.organization_id, dc.created_at,
          jsonb_build_object('name', o.name) as organizations
        from public.dance_classes dc left join public.organizations o on o.id=dc.organization_id
        order by dc.created_at desc limit 100
      ) r;
    else
      raise exception 'Módulo administrativo no reconocido';
  end case;
  return coalesce(v_rows, '[]'::jsonb);
end;
$$;
revoke all on function public.admin_fetch_section(text) from public, anon;
grant execute on function public.admin_fetch_section(text) to authenticated;

create or replace function public.admin_verify_subscription(p_subscription_id uuid, p_approve boolean)
returns void
language plpgsql security definer
set search_path = pg_catalog, public, auth, private
as $$
declare v_status public.subscription_status;
begin
  if not private.is_platform_admin() then
    raise exception 'Acceso administrativo requerido' using errcode = '42501';
  end if;
  if p_approve and not exists (
    select 1 from public.payments p where p.subscription_id = p_subscription_id
      and p.payment_type = 'subscription' and p.status in ('pending', 'paid')
  ) then
    raise exception 'No existe un pago verificable asociado a la solicitud';
  end if;
  update public.payments
     set status = case when p_approve then 'paid'::public.payment_status
                       else 'failed'::public.payment_status end,
         paid_at = case when p_approve then coalesce(paid_at, now()) else paid_at end,
         provider = case when provider = 'manual_pending' then 'manual_verified' else provider end,
         updated_at = now()
   where subscription_id = p_subscription_id and payment_type = 'subscription'
     and status in ('pending', 'paid');
  update public.subscriptions
     set status = case when p_approve then 'active'::public.subscription_status
                       else 'expired'::public.subscription_status end,
         current_period_start = case when p_approve then coalesce(current_period_start, now()) else current_period_start end,
          current_period_end = case when p_approve then coalesce(current_period_end,
            now() + case when billing_interval = 'year' then interval '1 year' else interval '1 month' end)
            else current_period_end end,
         verified_by = auth.uid(), verified_at = now(), updated_at = now()
   where id = p_subscription_id and status in ('pending', 'past_due');
  if not found then raise exception 'Solicitud pendiente no encontrada'; end if;
  insert into public.audit_logs(user_id, action, entity_type, entity_id, new_values)
  values (auth.uid(), case when p_approve then 'membership_activated' else 'membership_rejected' end,
    'subscription', p_subscription_id, jsonb_build_object('approved', p_approve));
end;
$$;
revoke all on function public.admin_verify_subscription(uuid, boolean) from public, anon;
grant execute on function public.admin_verify_subscription(uuid, boolean) to authenticated;

create or replace function public.admin_register_payout(
  p_organization_id uuid, p_amount numeric, p_currency text default 'BOB',
  p_reference text default null, p_period_start timestamptz default null,
  p_period_end timestamptz default null
)
returns uuid
language plpgsql security definer
set search_path = pg_catalog, public, auth, private
as $$
declare v_id uuid; v_available numeric;
begin
  if not private.is_platform_admin() then
    raise exception 'Acceso administrativo requerido' using errcode = '42501';
  end if;
  if p_amount <= 0 or p_currency !~ '^[A-Z]{3}$' then
    raise exception 'Importe o moneda inválidos';
  end if;
  perform 1 from public.organizations where id = p_organization_id for update;
  if not found then raise exception 'Organización no encontrada'; end if;
  select greatest(
    coalesce(sum(o.subtotal - o.platform_fee), 0)
      - coalesce((select sum(p.amount) from public.payouts p
          where p.organization_id = p_organization_id and p.currency = p_currency
            and p.status not in ('failed', 'cancelled')), 0),
    0
  ) into v_available
  from public.orders o
  join public.events e on e.id = o.event_id
  where e.organization_id = p_organization_id
    and o.currency = p_currency and o.status in ('paid', 'completed');
  if p_amount > v_available then
    raise exception 'La liquidación supera el saldo disponible (% %)', v_available, p_currency;
  end if;
  insert into public.payouts(organization_id, amount, currency, status, provider,
    period_start, period_end, metadata)
  values (p_organization_id, p_amount, p_currency, 'pending', 'manual',
    p_period_start, p_period_end, jsonb_build_object('reference', nullif(trim(p_reference), '')))
  returning id into v_id;
  insert into public.audit_logs(user_id, action, entity_type, entity_id, new_values)
  values (auth.uid(), 'payout_registered', 'payout', v_id,
    jsonb_build_object('organization_id', p_organization_id, 'amount', p_amount,
      'currency', p_currency, 'reference', nullif(trim(p_reference), '')));
  return v_id;
end;
$$;
revoke all on function public.admin_register_payout(uuid, numeric, text, text, timestamptz, timestamptz) from public, anon;
grant execute on function public.admin_register_payout(uuid, numeric, text, text, timestamptz, timestamptz) to authenticated;

create or replace function public.admin_set_payout_status(p_payout_id uuid, p_status text)
returns void
language plpgsql security definer
set search_path = pg_catalog, public, auth, private
as $$
begin
  if not private.is_platform_admin() then
    raise exception 'Acceso administrativo requerido' using errcode = '42501';
  end if;
  if p_status not in ('processing', 'paid', 'failed', 'cancelled') then
    raise exception 'Estado de liquidación inválido';
  end if;
  update public.payouts set status = p_status::public.payout_status,
    processed_at = case when p_status = 'paid' then coalesce(processed_at, now()) else processed_at end,
    updated_at = now()
    where id = p_payout_id and status in ('pending', 'processing');
  if not found then raise exception 'Liquidación pendiente no encontrada'; end if;
  insert into public.audit_logs(user_id, action, entity_type, entity_id, new_values)
  values (auth.uid(), 'payout_' || p_status, 'payout', p_payout_id,
    jsonb_build_object('status', p_status));
end;
$$;
revoke all on function public.admin_set_payout_status(uuid, text) from public, anon;
grant execute on function public.admin_set_payout_status(uuid, text) to authenticated;

grant select, insert, update, delete on public.event_access_points,
  public.event_access_point_staff to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- Mantiene compatibilidad con la validación actual de tickets, añadiendo
-- autorización de acceso de manera obligatoria cuando el evento define accesos.
alter function public.register_event_check_in(text, uuid, text)
  rename to register_event_check_in_without_access_point;
revoke all on function public.register_event_check_in_without_access_point(text, uuid, text)
  from public, anon, authenticated;
create or replace function public.register_event_check_in(
  p_token_hash text, p_event_id uuid, p_device_id text default null,
  p_access_point_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, private
as $$
declare
  v_qr record;
  v_ticket record;
  v_ticket_type record;
  v_event record;
  v_checked_in boolean;
  v_attendee_name text;
begin
  if exists (select 1 from public.event_access_points ap
      where ap.event_id = p_event_id) then
    if p_access_point_id is null or not exists (
      select 1
      from public.event_access_points ap
      join public.event_access_point_staff aps on aps.access_point_id = ap.id
      join public.organization_members om on om.id = aps.organization_member_id
      where ap.id = p_access_point_id and ap.event_id = p_event_id and ap.is_active
        and om.user_id = auth.uid() and om.is_active
    ) then
      return jsonb_build_object('success', false,
        'reason', 'No tienes autorización para utilizar este acceso');
    end if;
  elsif p_access_point_id is not null then
    return jsonb_build_object('success', false, 'reason', 'El acceso indicado no existe o está inactivo');
  end if;

  select * into v_qr from public.ticket_qr_codes where token_hash = p_token_hash;
  if not found then return jsonb_build_object('success', false, 'reason', 'QR no reconocido'); end if;
  if not v_qr.is_active then return jsonb_build_object('success', false, 'reason', 'El QR fue desactivado'); end if;
  if v_qr.expires_at is not null and v_qr.expires_at < now() then
    return jsonb_build_object('success', false, 'reason', 'El QR ha expirado');
  end if;

  select * into v_ticket from public.tickets where id = v_qr.ticket_id for update;
  if not found then return jsonb_build_object('success', false, 'reason', 'El ticket no existe'); end if;
  if v_ticket.status <> 'active' then
    return jsonb_build_object('success', false, 'reason', 'El ticket no está activo');
  end if;
  if exists (select 1 from public.orders o where o.id = v_ticket.order_id
      and o.status not in ('paid', 'completed')) then
    return jsonb_build_object('success', false, 'reason', 'El pago del ticket no está confirmado');
  end if;
  select * into v_ticket_type from public.ticket_types where id = v_ticket.ticket_type_id;
  if found and v_ticket_type.event_id <> p_event_id then
    return jsonb_build_object('success', false, 'reason', 'El ticket no pertenece a este evento');
  end if;
  select * into v_event from public.events where id = p_event_id;
  if not found then return jsonb_build_object('success', false, 'reason', 'El evento no existe'); end if;

  if not exists (select 1 from public.event_access_points ap where ap.event_id = p_event_id)
     and not exists (
       select 1 from public.organization_members om
       where om.organization_id = v_event.organization_id and om.user_id = auth.uid()
         and om.is_active and om.role::text in ('owner', 'admin', 'manager', 'instructor', 'check_in_staff')
     ) then
    return jsonb_build_object('success', false,
      'reason', 'No tienes autorización para escanear este evento');
  end if;

  select coalesce(nullif(trim(concat(p.first_name, ' ', p.last_name)), ''), 'Asistente')
    into v_attendee_name from public.profiles p where p.id = v_ticket.user_id;
  select exists(select 1 from public.check_ins where ticket_id = v_qr.ticket_id)
    into v_checked_in;
  if v_checked_in then
    return jsonb_build_object('success', false, 'reason', 'Este ticket ya fue utilizado');
  end if;

  insert into public.check_ins(ticket_id, event_id, scanned_by_user_id, device_id, metadata, access_point_id)
  values (v_qr.ticket_id, p_event_id, auth.uid(), p_device_id,
    jsonb_build_object('order_id', v_ticket.order_id, 'ticket_number', v_ticket.ticket_number),
    p_access_point_id)
  on conflict (ticket_id) do nothing returning true into v_checked_in;
  if not v_checked_in then
    return jsonb_build_object('success', false, 'reason', 'Este ticket ya fue utilizado');
  end if;

  update public.tickets set status = 'used', updated_at = now() where id = v_ticket.id;
  return jsonb_build_object('success', true, 'ticket_number', v_ticket.ticket_number,
    'event_title', v_event.title, 'attendee_name', v_attendee_name, 'checked_in_at', now());
end;
$$;
revoke all on function public.register_event_check_in(text, uuid, text, uuid) from public, anon;
grant execute on function public.register_event_check_in(text, uuid, text, uuid) to authenticated;
