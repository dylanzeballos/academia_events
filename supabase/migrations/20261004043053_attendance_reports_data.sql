-- Amplía los RPC de asistencia para generar los reportes tipo Excel:
--   * fetch_class_attendance: añade precio/moneda/título de la clase y el
--     detalle de asistencia por sesión de cada estudiante (fecha y estado),
--     para construir las columnas "N CHECK-IN" y el ingreso económico.
--   * fetch_event_attendance: añade el precio y moneda de la entrada de cada
--     asistente para el reporte de ingresos.

create or replace function public.fetch_class_attendance(p_class_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_org_id   uuid;
  v_capacity integer;
  v_enrolled integer;
  v_title    text;
  v_price    numeric;
  v_currency text;
  v_sessions jsonb;
  v_students jsonb;
begin
  select organization_id, capacity, title, price, currency
    into v_org_id, v_capacity, v_title, v_price, v_currency
    from public.dance_classes
   where id = p_class_id;

  if not found then
    raise exception 'La clase no existe';
  end if;

  if not exists (
    select 1 from public.organization_members om
     where om.organization_id = v_org_id
       and om.user_id = auth.uid()
       and om.is_active = true
       and om.role::text in ('owner', 'admin', 'instructor', 'check_in_staff')
  ) then
    raise exception 'No tienes permiso para ver esta información';
  end if;

  select count(*)
    into v_enrolled
    from public.class_enrollments
   where dance_class_id = p_class_id
     and status::text in ('pending', 'approved', 'active');

  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.session_date, x.start_at), '[]'::jsonb)
    into v_sessions
    from (
      select
        s.id as session_id,
        s.session_date,
        s.start_at,
        s.end_at,
        s.status,
        count(a.id) filter (where a.status = 'present') as present,
        count(a.id) filter (where a.status = 'late') as late,
        count(a.id) filter (where a.status = 'absent') as absent,
        greatest(
          v_enrolled
            - count(a.id) filter (where a.status in ('present', 'late', 'absent')),
          0
        ) as pending
        from public.dance_class_sessions s
        left join public.attendances a on a.session_id = s.id
       where s.dance_class_id = p_class_id
       group by s.id, s.session_date, s.start_at, s.end_at, s.status
    ) x;

  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.last_name, x.first_name), '[]'::jsonb)
    into v_students
    from (
      select
        ce.id as enrollment_id,
        ce.user_id,
        p.first_name,
        p.last_name,
        ce.status as enrollment_status,
        count(a.id) as sessions_attended,
        (select count(*) from public.dance_class_sessions s2
          where s2.dance_class_id = p_class_id) as sessions_total,
        (select a2.status from public.attendances a2
          where a2.enrollment_id = ce.id
          order by a2.recorded_at desc limit 1) as last_attendance_status,
        (select a2.recorded_at from public.attendances a2
          where a2.enrollment_id = ce.id
          order by a2.recorded_at desc limit 1) as last_check_in_time,
        coalesce((
          select jsonb_agg(jsonb_build_object(
            'session_id', a3.session_id,
            'session_date', s3.session_date,
            'start_at', s3.start_at,
            'status', a3.status,
            'recorded_at', a3.recorded_at
          ) order by s3.session_date, s3.start_at)
          from public.attendances a3
          join public.dance_class_sessions s3 on s3.id = a3.session_id
          where a3.enrollment_id = ce.id
        ), '[]'::jsonb) as attendance
        from public.class_enrollments ce
        join public.profiles p on p.id = ce.user_id
        left join public.attendances a on a.enrollment_id = ce.id
       where ce.dance_class_id = p_class_id
         and ce.status::text in ('pending', 'approved', 'active')
       group by ce.id, ce.user_id, p.first_name, p.last_name, ce.status
    ) x;

  return jsonb_build_object(
    'capacity', v_capacity,
    'enrolled', v_enrolled,
    'class_title', v_title,
    'price', v_price,
    'currency', v_currency,
    'sessions', v_sessions,
    'students', v_students
  );
end;
$$;

create or replace function public.fetch_event_attendance(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_org_id     uuid;
  v_capacity   integer;
  v_sold       integer;
  v_checked_in integer;
  v_by_type    jsonb;
  v_attendees  jsonb;
begin
  select organization_id, capacity
    into v_org_id, v_capacity
    from public.events
   where id = p_event_id;

  if not found then
    raise exception 'El evento no existe';
  end if;

  if not exists (
    select 1 from public.organization_members om
     where om.organization_id = v_org_id
       and om.user_id = auth.uid()
       and om.is_active = true
       and om.role::text in ('owner', 'admin', 'instructor', 'check_in_staff')
  ) then
    raise exception 'No tienes permiso para ver esta información';
  end if;

  select count(*)
    into v_sold
    from public.tickets t
    join public.ticket_types tt on tt.id = t.ticket_type_id
   where tt.event_id = p_event_id
     and t.status in ('active', 'used');

  select count(distinct ticket_id)
    into v_checked_in
    from public.check_ins
   where event_id = p_event_id;

  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.sold desc), '[]'::jsonb)
    into v_by_type
    from (
      select
        tt.name,
        count(t.id) as sold,
        count(distinct ci.ticket_id) as checked_in
        from public.ticket_types tt
        left join public.tickets t on t.ticket_type_id = tt.id
        left join public.check_ins ci on ci.ticket_id = t.id
       where tt.event_id = p_event_id
       group by tt.id, tt.name
    ) x;

  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.last_name, x.first_name), '[]'::jsonb)
    into v_attendees
    from (
      select
        p.id as user_id,
        p.first_name,
        p.last_name,
        t.ticket_number,
        tt.name as ticket_type,
        tt.price as ticket_price,
        tt.currency as currency,
        t.status as ticket_status,
        (ci.id is not null) as checked_in,
        ci.scanned_at as check_in_time,
        coalesce(ci.metadata->>'access_point', ci.device_id) as access_point
        from public.tickets t
        join public.ticket_types tt on tt.id = t.ticket_type_id
        join public.profiles p on p.id = t.user_id
        left join public.check_ins ci on ci.ticket_id = t.id
       where tt.event_id = p_event_id
         and t.status in ('active', 'used')
    ) x;

  return jsonb_build_object(
    'capacity', v_capacity,
    'tickets_sold', v_sold,
    'tickets_available',
      case when v_capacity is null then null
           else greatest(v_capacity - v_sold, 0) end,
    'checked_in', v_checked_in,
    'pending_entry', greatest(v_sold - v_checked_in, 0),
    'by_ticket_type', v_by_type,
    'attendees', v_attendees
  );
end;
$$;
