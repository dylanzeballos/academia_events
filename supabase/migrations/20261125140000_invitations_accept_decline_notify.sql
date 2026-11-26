-- ============================================================================
-- Invitaciones: aceptar/rechazar + aviso in-app y push.
-- Fecha: 2026-11-25
-- ============================================================================
-- La app llamaba a `accept_invitation` y `decline_invitation`, pero los RPC no
-- existían en la base. Se crean con validación de pertenencia por email.
-- Además, al insertar una invitación se crea una notificación para el usuario
-- invitado (si ya tiene cuenta); el trigger existente de `notifications`
-- dispara el push automáticamente.

create or replace function public.accept_invitation(p_invitation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $fn$
declare
  v_uid       uuid := auth.uid();
  v_email     text;
  v_inv       public.organization_invitations%rowtype;
  v_member_id uuid;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión para aceptar la invitación'
      using errcode = '42501';
  end if;

  select lower(email) into v_email
    from auth.users
   where id = v_uid;

  if v_email is null then
    raise exception 'No se encontró tu correo' using errcode = 'P0002';
  end if;

  select * into v_inv
    from public.organization_invitations
   where id = p_invitation_id
     for update;

  if not found then
    raise exception 'Invitación no encontrada' using errcode = 'P0002';
  end if;

  if lower(v_inv.email) <> v_email then
    raise exception 'Esta invitación no te pertenece' using errcode = '42501';
  end if;

  if v_inv.status = 'accepted' then
    return jsonb_build_object(
      'success', true,
      'organization_id', v_inv.organization_id,
      'role', v_inv.role,
      'already_member', true
    );
  end if;

  if v_inv.status <> 'pending' then
    raise exception 'La invitación ya no está pendiente' using errcode = 'P0001';
  end if;

  if v_inv.expires_at < now() then
    update public.organization_invitations
       set status = 'expired',
           updated_at = now()
     where id = p_invitation_id;
    raise exception 'La invitación expiró' using errcode = 'P0001';
  end if;

  select id into v_member_id
    from public.organization_members
   where organization_id = v_inv.organization_id
     and user_id = v_uid
   limit 1;

  if v_member_id is null then
    insert into public.organization_members
      (organization_id, user_id, role, is_active)
    values
      (v_inv.organization_id, v_uid, v_inv.role, true);
  else
    update public.organization_members
       set role = v_inv.role,
           is_active = true,
           updated_at = now()
     where id = v_member_id;
  end if;

  update public.organization_invitations
     set status = 'accepted',
         updated_at = now()
   where id = p_invitation_id;

  return jsonb_build_object(
    'success', true,
    'organization_id', v_inv.organization_id,
    'role', v_inv.role,
    'already_member', false
  );
end;
$fn$;

revoke all on function public.accept_invitation(uuid) from public, anon;
grant execute on function public.accept_invitation(uuid)
  to authenticated, service_role;

create or replace function public.decline_invitation(p_invitation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $fn$
declare
  v_uid   uuid := auth.uid();
  v_email text;
  v_inv   public.organization_invitations%rowtype;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión para rechazar la invitación'
      using errcode = '42501';
  end if;

  select lower(email) into v_email
    from auth.users
   where id = v_uid;

  select * into v_inv
    from public.organization_invitations
   where id = p_invitation_id
     for update;

  if not found then
    raise exception 'Invitación no encontrada' using errcode = 'P0002';
  end if;

  if lower(v_inv.email) <> v_email then
    raise exception 'Esta invitación no te pertenece' using errcode = '42501';
  end if;

  if v_inv.status = 'rejected' then
    return jsonb_build_object('success', true, 'already_declined', true);
  end if;

  if v_inv.status <> 'pending' then
    raise exception 'La invitación ya no está pendiente' using errcode = 'P0001';
  end if;

  update public.organization_invitations
     set status = 'rejected',
         updated_at = now()
   where id = p_invitation_id;

  return jsonb_build_object('success', true, 'already_declined', false);
end;
$fn$;

revoke all on function public.decline_invitation(uuid) from public, anon;
grant execute on function public.decline_invitation(uuid)
  to authenticated, service_role;

-- Aviso para el invitado cuando ya tiene cuenta.
create or replace function private.notify_organization_invitation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $fn$
declare
  v_user_id   uuid;
  v_org_name  text;
  v_inviter   text;
  v_role      text;
begin
  select id into v_user_id
    from auth.users
   where lower(email) = lower(new.email)
   limit 1;

  -- Si todavía no tiene cuenta, no hay a quién notificar.
  if v_user_id is null then
    return new;
  end if;

  select name into v_org_name
    from public.organizations
   where id = new.organization_id;

  select coalesce(
           nullif(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
           u.email
         )
    into v_inviter
    from auth.users u
    left join public.profiles p on p.id = u.id
   where u.id = new.invited_by;

  v_role := case new.role::text
    when 'owner' then 'Propietario'
    when 'admin' then 'Administrador'
    when 'instructor' then 'Instructor'
    when 'check_in_staff' then 'Personal de check-in'
    when 'member' then 'Miembro'
    else new.role::text
  end;

  insert into public.notifications
    (user_id, type, title, message, data, dedup_key)
  values (
    v_user_id,
    'organization_invitation',
    'Nueva invitación',
    format(
      '%s te invitó a unirte a %s como %s.',
      coalesce(v_inviter, 'La academia'),
      coalesce(v_org_name, 'una organización'),
      v_role
    ),
    jsonb_build_object(
      'invitation_id', new.id,
      'organization_id', new.organization_id,
      'route', 'my_invitations'
    ),
    'organization_invitation:' || new.id::text
  )
  on conflict (dedup_key) do nothing;

  return new;
end;
$fn$;

revoke all on function private.notify_organization_invitation()
  from public, anon, authenticated;

drop trigger if exists trg_organization_invitations_notify
  on public.organization_invitations;

create trigger trg_organization_invitations_notify
  after insert on public.organization_invitations
  for each row
  execute function private.notify_organization_invitation();

notify pgrst, 'reload schema';
