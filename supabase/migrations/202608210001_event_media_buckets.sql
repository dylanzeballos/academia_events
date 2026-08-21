-- ─────────────────────────────────────────────────────────────────────
-- Buckets para imágenes de eventos:
--   event-banners → afiche/portada del evento (<event_id>/banner.<ext>)
--   event-qrs     → código QR de pago     (<event_id>/qr.<ext>)
-- ─────────────────────────────────────────────────────────────────────

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('event-banners', 'event-banners', true, 10485760, array['image/jpeg', 'image/png', 'image/webp']),
  ('event-qrs', 'event-qrs', true, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Helper: verifica que el usuario autenticado sea miembro activo de la
-- organización dueña del evento. La primera carpeta del path es el event id.
create or replace function public.is_event_media_owner(p_bucket_id text, p_name text)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select p_bucket_id in ('event-banners', 'event-qrs')
    and exists (
      select 1
      from public.events e
      join public.organization_members m on m.organization_id = e.organization_id
      where e.id::text = (storage.foldername(p_name))[1]
        and m.user_id = (select auth.uid())
        and m.is_active
    )
$$;

revoke execute on function public.is_event_media_owner(text, text) from anon;

-- ─── Lectura pública (los buckets son públicos) ───

drop policy if exists "event_banners_public_read" on storage.objects;
create policy "event_banners_public_read"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'event-banners');

drop policy if exists "event_qrs_public_read" on storage.objects;
create policy "event_qrs_public_read"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'event-qrs');

-- ─── Escritura solo para miembros activos de la organización ───

drop policy if exists "event_banners_org_insert" on storage.objects;
create policy "event_banners_org_insert"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'event-banners'
  and public.is_event_media_owner(bucket_id, name)
);

drop policy if exists "event_banners_org_update" on storage.objects;
create policy "event_banners_org_update"
on storage.objects for update
to authenticated
using (
  bucket_id = 'event-banners'
  and public.is_event_media_owner(bucket_id, name)
)
with check (
  bucket_id = 'event-banners'
  and public.is_event_media_owner(bucket_id, name)
);

drop policy if exists "event_banners_org_delete" on storage.objects;
create policy "event_banners_org_delete"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'event-banners'
  and public.is_event_media_owner(bucket_id, name)
);

drop policy if exists "event_qrs_org_insert" on storage.objects;
create policy "event_qrs_org_insert"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'event-qrs'
  and public.is_event_media_owner(bucket_id, name)
);

drop policy if exists "event_qrs_org_update" on storage.objects;
create policy "event_qrs_org_update"
on storage.objects for update
to authenticated
using (
  bucket_id = 'event-qrs'
  and public.is_event_media_owner(bucket_id, name)
)
with check (
  bucket_id = 'event-qrs'
  and public.is_event_media_owner(bucket_id, name)
);

drop policy if exists "event_qrs_org_delete" on storage.objects;
create policy "event_qrs_org_delete"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'event-qrs'
  and public.is_event_media_owner(bucket_id, name)
);
