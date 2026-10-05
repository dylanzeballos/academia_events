-- Los avatares se resuelven con `getPublicUrl` en el cliente, por lo que el
-- bucket debe ser público. Antes estaba privado y las imágenes devolvían 403.

update storage.buckets
   set public = true
 where id = 'profile-avatars';

-- Lectura pública de avatares (el cliente arma URLs públicas permanentes).
drop policy if exists "avatars_select_own" on storage.objects;
drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'profile-avatars');
