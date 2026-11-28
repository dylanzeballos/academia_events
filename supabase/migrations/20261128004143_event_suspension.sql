-- ============================================================================
-- Eventos: publicación automática y suspensión por organización o admin.
-- Fecha: 2026-11-27
-- ============================================================================
-- Ya no hay aprobación/rechazo manual: el evento nace sin moderación pendiente
-- y se publica cuando se paga el QR. El admin o la organización (owner/admin/
-- manager) solo pueden suspenderlo o reactivarlo.

alter table public.events
  alter column moderation_status set default 'approved';

update public.events
set moderation_status = 'approved',
    moderation_updated_at = now()
where moderation_status = 'pending_approval';

create or replace function public.set_event_suspension(
  p_event_id uuid,
  p_suspended boolean
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth, private
as $fn$
declare
  v_uid uuid := auth.uid();
  v_org uuid;
  v_paid boolean;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión' using errcode = '42501';
  end if;

  select organization_id into v_org
  from public.events
  where id = p_event_id;

  if v_org is null then
    raise exception 'Evento no encontrado' using errcode = 'P0002';
  end if;

  if not (
    private.is_platform_admin()
    or exists (
      select 1
      from public.organization_members m
      where m.organization_id = v_org
        and m.user_id = v_uid
        and m.is_active
        and m.role in ('owner', 'admin')
    )
  ) then
    raise exception 'No autorizado para modificar este evento'
      using errcode = '42501';
  end if;

  if p_suspended then
    update public.events
    set moderation_status = 'suspended',
        moderation_updated_at = now(),
        moderation_updated_by = v_uid,
        status = 'draft'::public.event_status,
        published_at = null,
        updated_at = now()
    where id = p_event_id;

    insert into public.event_moderation (event_id, admin_user_id, action)
    values (p_event_id, v_uid, 'unpublished');

    insert into public.audit_logs (user_id, action, entity_type, entity_id)
    values (v_uid, 'event_suspended', 'event', p_event_id);
  else
    select exists (
      select 1 from public.event_publication_payments p
      where p.event_id = p_event_id
    ) into v_paid;

    if not private.is_platform_admin() and not coalesce(v_paid, false) then
      raise exception 'Se requiere el pago de publicación para reactivar el evento'
        using errcode = '42501';
    end if;

    update public.events
    set moderation_status = 'approved',
        moderation_updated_at = now(),
        moderation_updated_by = v_uid,
        status = 'published'::public.event_status,
        published_at = coalesce(published_at, now()),
        updated_at = now()
    where id = p_event_id;

    insert into public.event_moderation (event_id, admin_user_id, action)
    values (p_event_id, v_uid, 'approved');

    insert into public.audit_logs (user_id, action, entity_type, entity_id)
    values (v_uid, 'event_reactivated', 'event', p_event_id);
  end if;
end;
$fn$;

revoke all on function public.set_event_suspension(uuid, boolean)
  from public, anon;
grant execute on function public.set_event_suspension(uuid, boolean)
  to authenticated;

notify pgrst, 'reload schema';
