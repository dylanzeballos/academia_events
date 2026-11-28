-- Organization dance categories
-- Cada academia declara los estilos de baile que ofrece de forma explícita,
-- sin depender de que tenga eventos o clases publicadas. Así el filtro de
-- estilo funciona aunque la academia no tenga actividad.

create table if not exists public.organization_dance_categories (
  organization_id uuid not null
    references public.organizations(id) on delete cascade,
  dance_category_id uuid not null
    references public.dance_categories(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (organization_id, dance_category_id)
);

-- La PK ya indexa organization_id; falta el lado de dance_category_id (FK).
create index if not exists idx_org_dance_categories_category
  on public.organization_dance_categories(dance_category_id);

-- ── Seguridad (RLS) ──────────────────────────────────────────────
alter table public.organization_dance_categories enable row level security;
alter table public.organization_dance_categories force row level security;

-- Lectura pública: el carrusel y las páginas públicas la necesitan.
drop policy if exists "org_dance_categories_select"
  on public.organization_dance_categories;
create policy "org_dance_categories_select"
  on public.organization_dance_categories
  for select to anon, authenticated
  using (true);

-- Solo un owner/admin activo de la organización puede modificarlas.
drop policy if exists "org_dance_categories_insert"
  on public.organization_dance_categories;
create policy "org_dance_categories_insert"
  on public.organization_dance_categories
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.organization_members m
      where m.organization_id = organization_dance_categories.organization_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role in ('owner', 'admin')
    )
  );

drop policy if exists "org_dance_categories_delete"
  on public.organization_dance_categories;
create policy "org_dance_categories_delete"
  on public.organization_dance_categories
  for delete to authenticated
  using (
    exists (
      select 1
      from public.organization_members m
      where m.organization_id = organization_dance_categories.organization_id
        and m.user_id = (select auth.uid())
        and m.is_active
        and m.role in ('owner', 'admin')
    )
  );

grant select on public.organization_dance_categories to anon;
grant select, insert, delete on public.organization_dance_categories
  to authenticated;

-- ── Backfill para academias existentes ───────────────────────────
-- 1) Estilos tomados directamente de los eventos publicados.
insert into public.organization_dance_categories
  (organization_id, dance_category_id)
select distinct e.organization_id, edc.dance_category_id
from public.events e
join public.event_dance_categories edc on edc.event_id = e.id
where e.status = 'published'
on conflict (organization_id, dance_category_id) do nothing;

-- 2) Estilos inferidos de los títulos de las clases publicadas (best effort)
--    para no dejar sin estilos a las academias que aún no los declararon.
insert into public.organization_dance_categories
  (organization_id, dance_category_id)
select distinct dc.organization_id, c.id
from public.dance_classes dc
join public.dance_categories c
  on (
       position(lower(c.name) in lower(dc.title)) > 0
    or (c.name = 'Hip Hop / Urbano' and position('urbano' in lower(dc.title)) > 0)
    or (c.name = 'Folklore' and position('folclor' in lower(dc.title)) > 0)
    or (c.name = 'Contemporáneo' and position('contempor' in lower(dc.title)) > 0)
  )
where c.is_active
  and dc.status = 'published'
on conflict (organization_id, dance_category_id) do nothing;

-- Refrescar el caché de esquema de PostgREST.
notify pgrst, 'reload schema';
