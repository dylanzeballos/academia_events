-- Identificador público y analítica de visitas de organizaciones.

alter table public.organizations
  add column if not exists qr_code_hash text,
  add column if not exists views_count bigint not null default 0;

update public.organizations
set qr_code_hash = encode(gen_random_bytes(16), 'hex')
where qr_code_hash is null;

create unique index if not exists idx_organizations_qr_code_hash
  on public.organizations(qr_code_hash);

alter table public.organizations
  alter column qr_code_hash set default encode(gen_random_bytes(16), 'hex');

grant select on public.organizations to anon;
drop policy if exists "org_select_public" on public.organizations;
create policy "org_select_public" on public.organizations
  for select to anon
  using (is_active = true);

create table if not exists public.organization_views (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  source text not null default 'app',
  viewed_at timestamptz not null default now()
);

create index if not exists idx_org_views_org_date
  on public.organization_views(organization_id, viewed_at);

alter table public.organization_views enable row level security;
alter table public.organization_views force row level security;
revoke all on public.organization_views from anon, authenticated;

create or replace function public.record_organization_view(
  p_org_id uuid,
  p_source text default 'app'
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.organizations
  set views_count = views_count + 1
  where id = p_org_id and is_active = true;

  if found then
    insert into public.organization_views (organization_id, user_id, source)
    values (
      p_org_id,
      auth.uid(),
      case when p_source in ('app', 'qr', 'whatsapp_link', 'web')
        then p_source else 'app' end
    );
  end if;
end;
$$;

revoke all on function public.record_organization_view(uuid, text) from public;
grant execute on function public.record_organization_view(uuid, text)
  to anon, authenticated;