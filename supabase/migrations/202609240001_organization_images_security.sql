-- Organization gallery access and performance
-- The organization_images table is created separately and is made safe here.

create index if not exists idx_organization_images_org_sort
  on public.organization_images(organization_id, sort_order, created_at);

grant select, insert, update, delete
  on public.organization_images to authenticated;

alter table public.organization_images enable row level security;
alter table public.organization_images force row level security;

drop policy if exists "organization_images_select_members"
  on public.organization_images;
create policy "organization_images_select_members"
  on public.organization_images
  for select to authenticated
  using (private.is_org_member(organization_id));

drop policy if exists "organization_images_insert_admins"
  on public.organization_images;
create policy "organization_images_insert_admins"
  on public.organization_images
  for insert to authenticated
  with check (private.is_org_admin(organization_id));

drop policy if exists "organization_images_update_admins"
  on public.organization_images;
create policy "organization_images_update_admins"
  on public.organization_images
  for update to authenticated
  using (private.is_org_admin(organization_id))
  with check (private.is_org_admin(organization_id));

drop policy if exists "organization_images_delete_admins"
  on public.organization_images;
create policy "organization_images_delete_admins"
  on public.organization_images
  for delete to authenticated
  using (private.is_org_admin(organization_id));
