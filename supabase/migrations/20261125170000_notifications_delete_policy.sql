-- ============================================================================
-- Avisos: permitir que cada usuario elimine sus propios avisos.
-- Fecha: 2026-11-25
-- ============================================================================
-- La pantalla de avisos ahora permite eliminar uno o todos, pero
-- `notifications` tenía RLS con políticas de SELECT/UPDATE y ninguna de DELETE,
-- así que los borrados se descartaban silenciosamente.

drop policy if exists "Users can delete own notifications"
  on public.notifications;

create policy "Users can delete own notifications"
  on public.notifications
  for delete to authenticated
  using (auth.uid() = user_id);

notify pgrst, 'reload schema';
