-- Organizations module migration
-- Tables: organizations, organization_members
-- RLS policies, storage bucket, helper functions

-- ─────────────────────────────────────────────────────────
-- 0. Private helper functions for RLS
-- ─────────────────────────────────────────────────────────

create schema if not exists private;

create or replace function private.is_org_member(org uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members m
    where m.user_id = (select auth.uid())
      and m.organization_id = org
      and m.is_active = true
  );
$$;

revoke all on function private.is_org_member(uuid) from public;
revoke all on function private.is_org_member(uuid) from authenticated;
revoke all on function private.is_org_member(uuid) from anon;

create or replace function private.is_org_admin(org uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members m
    where m.user_id = (select auth.uid())
      and m.organization_id = org
      and m.role in ('owner', 'manager')
      and m.is_active = true
  );
$$;

revoke all on function private.is_org_admin(uuid) from public;
revoke all on function private.is_org_admin(uuid) from authenticated;
revoke all on function private.is_org_admin(uuid) from anon;

create or replace function private.is_org_owner(org uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members m
    where m.user_id = (select auth.uid())
      and m.organization_id = org
      and m.role = 'owner'
      and m.is_active = true
  );
$$;

revoke all on function private.is_org_owner(uuid) from public;
revoke all on function private.is_org_owner(uuid) from authenticated;
revoke all on function private.is_org_owner(uuid) from anon;

-- Grants: authenticated necesita EXECUTE para que las RLS policies funcionen
grant usage on schema private to authenticated;
grant execute on function private.is_org_member(uuid) to authenticated;
grant execute on function private.is_org_admin(uuid) to authenticated;
grant execute on function private.is_org_owner(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────
-- 1. Organizations table
-- ─────────────────────────────────────────────────────────

alter table public.organizations
  add column if not exists legal_name text,
  add column if not exists description text,
  add column if not exists logo_url text,
  add column if not exists website_url text,
  add column if not exists email text,
  add column if not exists phone_number text,
  add column if not exists tax_identification_number text,
  add column if not exists is_active boolean not null default true,
  add column if not exists is_verified boolean not null default false,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists deleted_at timestamptz;

-- ─────────────────────────────────────────────────────────
-- 2. Organization members table
-- ─────────────────────────────────────────────────────────

do $$
begin
  if not exists (
    select 1 from pg_type where typname = 'member_role'
  ) then
    create type public.member_role as enum (
      'owner', 'manager', 'event_manager', 'check_in_staff'
    );
  end if;
end $$;

create table if not exists public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.member_role not null default 'check_in_staff',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

-- ─────────────────────────────────────────────────────────
-- 3. Indexes
-- ─────────────────────────────────────────────────────────

create index if not exists idx_org_members_org_id
  on public.organization_members(organization_id);

create index if not exists idx_org_members_user_id
  on public.organization_members(user_id);

create index if not exists idx_org_members_composite
  on public.organization_members(organization_id, user_id, is_active);

create index if not exists idx_org_members_role
  on public.organization_members(role);

create index if not exists idx_organizations_active
  on public.organizations(id)
  where is_active = true;

-- ─────────────────────────────────────────────────────────
-- 4. GRANTs
-- ─────────────────────────────────────────────────────────

grant select, insert, update, delete on public.organizations to authenticated;
grant select, insert, update, delete on public.organization_members to authenticated;

grant usage on all sequences in schema public to authenticated;

-- ─────────────────────────────────────────────────────────
-- 5. Triggers
-- ─────────────────────────────────────────────────────────

create trigger set_updated_at
  before update on public.organizations
  for each row
  execute function public.update_updated_at();

create trigger set_updated_at
  before update on public.organization_members
  for each row
  execute function public.update_updated_at();

-- ─────────────────────────────────────────────────────────
-- 6. RLS: Organizations
-- ─────────────────────────────────────────────────────────

alter table public.organizations enable row level security;
alter table public.organizations force row level security;

drop policy if exists "org_select_auth" on public.organizations;
create policy "org_select_auth" on public.organizations
  for select to authenticated
  using (is_active = true);

drop policy if exists "org_select_member" on public.organizations;
create policy "org_select_member" on public.organizations
  for select to authenticated
  using (private.is_org_member(id));

drop policy if exists "org_insert_auth" on public.organizations;
create policy "org_insert_auth" on public.organizations
  for insert to authenticated
  with check (true);

drop policy if exists "org_update_admin" on public.organizations;
create policy "org_update_admin" on public.organizations
  for update to authenticated
  using (private.is_org_admin(id))
  with check (private.is_org_admin(id));

drop policy if exists "org_delete_owner" on public.organizations;
create policy "org_delete_owner" on public.organizations
  for delete to authenticated
  using (private.is_org_owner(id));

-- ─────────────────────────────────────────────────────────
-- 7. RLS: Organization Members
-- ─────────────────────────────────────────────────────────

alter table public.organization_members enable row level security;
alter table public.organization_members force row level security;

drop policy if exists "org_members_select" on public.organization_members;
create policy "org_members_select" on public.organization_members
  for select to authenticated
  using (private.is_org_member(organization_id));

drop policy if exists "org_members_insert" on public.organization_members;
create policy "org_members_insert" on public.organization_members
  for insert to authenticated
  with check (private.is_org_admin(organization_id));

drop policy if exists "org_members_update" on public.organization_members;
create policy "org_members_update" on public.organization_members
  for update to authenticated
  using (private.is_org_owner(organization_id))
  with check (private.is_org_owner(organization_id));

drop policy if exists "org_members_delete" on public.organization_members;
create policy "org_members_delete" on public.organization_members
  for delete to authenticated
  using (private.is_org_admin(organization_id));

-- ─────────────────────────────────────────────────────────
-- 8. Storage: organization-logos bucket
-- ─────────────────────────────────────────────────────────

insert into storage.buckets (id, name, public)
values ('organization-logos', 'organization-logos', false)
on conflict (id) do update set public = excluded.public;

-- ─────────────────────────────────────────────────────────
-- 9. Storage RLS policies for organization-logos
-- ─────────────────────────────────────────────────────────

drop policy if exists "org_logos_select" on storage.objects;
create policy "org_logos_select" on storage.objects
for select to authenticated
using (
  bucket_id = 'organization-logos'
  and (storage.foldername(name))[1]::uuid in (
    select m.organization_id
    from public.organization_members m
    where m.user_id = (select auth.uid()) and m.is_active = true
  )
);

drop policy if exists "org_logos_insert" on storage.objects;
create policy "org_logos_insert" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'organization-logos'
  and (storage.foldername(name))[1]::uuid in (
    select m.organization_id
    from public.organization_members m
    where m.user_id = (select auth.uid())
      and m.role in ('owner', 'manager')
      and m.is_active = true
  )
);

drop policy if exists "org_logos_update" on storage.objects;
create policy "org_logos_update" on storage.objects
for update to authenticated
using (
  bucket_id = 'organization-logos'
  and (storage.foldername(name))[1]::uuid in (
    select m.organization_id
    from public.organization_members m
    where m.user_id = (select auth.uid())
      and m.role in ('owner', 'manager')
      and m.is_active = true
  )
)
with check (
  bucket_id = 'organization-logos'
  and (storage.foldername(name))[1]::uuid in (
    select m.organization_id
    from public.organization_members m
    where m.user_id = (select auth.uid())
      and m.role in ('owner', 'manager')
      and m.is_active = true
  )
);

drop policy if exists "org_logos_delete" on storage.objects;
create policy "org_logos_delete" on storage.objects
for delete to authenticated
using (
  bucket_id = 'organization-logos'
  and (storage.foldername(name))[1]::uuid in (
    select m.organization_id
    from public.organization_members m
    where m.user_id = (select auth.uid())
      and m.role in ('owner', 'manager')
      and m.is_active = true
  )
);

-- ─────────────────────────────────────────────────────────
-- 10. SECURITY DEFINER function: crear org + owner en una transacción
-- ─────────────────────────────────────────────────────────
-- Resuelve el chicken-and-egg: RLS requiere ser admin para insertar miembros,
-- pero al crear la org el usuario todavía no es miembro.
-- Esta función corre como postgres y bypass RLS de forma segura.

create or replace function public.create_organization_with_owner(
  p_name text,
  p_legal_name text default null,
  p_description text default null,
  p_email text default null,
  p_phone_number text default null,
  p_website_url text default null
)
returns public.organizations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org public.organizations;
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'No authenticated user';
  end if;

  insert into public.organizations (name, legal_name, description, email, phone_number, website_url)
  values (p_name, p_legal_name, p_description, p_email, p_phone_number, p_website_url)
  returning * into v_org;

  insert into public.organization_members (organization_id, user_id, role)
  values (v_org.id, v_user_id, 'owner');

  return v_org;
end;
$$;

revoke all on function public.create_organization_with_owner(text, text, text, text, text, text) from public;
revoke all on function public.create_organization_with_owner(text, text, text, text, text, text) from anon;
grant execute on function public.create_organization_with_owner(text, text, text, text, text, text) to authenticated;
