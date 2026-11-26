-- ============================================================================
-- Invitaciones: RLS por cuenta y limpieza de vencidas.
-- Fecha: 2026-11-25
-- ============================================================================
-- `organization_invitations` tenía RLS desactivado y cualquier usuario podía
-- leer invitaciones de otros emails. Los RPC de aceptar/rechazar ya validaban
-- la pertenencia, pero la lista mostraba invitaciones ajenas y al intentar
-- rechazarlas fallaba (correctamente) con "no te pertenece".
--
-- Políticas:
--   - Cada usuario ve solo las invitaciones dirigidas a su email.
--   - Owner/admin de la organización ve todas las de su organización.
--   - Owner/admin puede invitar y cancelar invitaciones de su organización.
-- Aceptar/rechazar siguen pasando por los RPC SECURITY DEFINER existentes.

alter table public.organization_invitations enable row level security;

drop policy if exists invitations_select_own on public.organization_invitations;
create policy invitations_select_own on public.organization_invitations
  for select to authenticated
  using (
    lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists invitations_select_org_admin on public.organization_invitations;
create policy invitations_select_org_admin on public.organization_invitations
  for select to authenticated
  using (
    exists (
      select 1
        from public.organization_members m
       where m.organization_id = organization_invitations.organization_id
         and m.user_id = auth.uid()
         and m.is_active
         and m.role in ('owner', 'admin')
    )
    or private.is_platform_admin()
  );

drop policy if exists invitations_insert_org_admin on public.organization_invitations;
create policy invitations_insert_org_admin on public.organization_invitations
  for insert to authenticated
  with check (
    invited_by = auth.uid()
    and (
      exists (
        select 1
          from public.organization_members m
         where m.organization_id = organization_invitations.organization_id
           and m.user_id = auth.uid()
           and m.is_active
           and m.role in ('owner', 'admin')
      )
      or private.is_platform_admin()
    )
  );

drop policy if exists invitations_delete_org_admin on public.organization_invitations;
create policy invitations_delete_org_admin on public.organization_invitations
  for delete to authenticated
  using (
    exists (
      select 1
        from public.organization_members m
       where m.organization_id = organization_invitations.organization_id
         and m.user_id = auth.uid()
         and m.is_active
         and m.role in ('owner', 'admin')
    )
    or private.is_platform_admin()
  );

-- Limpieza de invitaciones pendientes ya vencidas.
update public.organization_invitations
   set status = 'expired',
       updated_at = now()
 where status = 'pending'
   and expires_at < now();

notify pgrst, 'reload schema';
