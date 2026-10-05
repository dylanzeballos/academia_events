-- Informe VIP mensual: alumnos con pase de clase activo (class_passes) de la
-- organización, con su check-in por clase dentro del mes solicitado.
-- Devuelve clases incluidas, alumnos VIP y marcas (user_id, class_id, fecha),
-- que el cliente pivota para construir la matriz tipo Excel.

create or replace function public.fetch_org_vip_attendance(
  p_organization_id uuid,
  p_month date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_start    date := date_trunc('month', p_month)::date;
  v_end      date := (date_trunc('month', p_month) + interval '1 month')::date;
  v_vip      uuid[];
  v_classes  jsonb;
  v_students jsonb;
  v_marks    jsonb;
begin
  if not exists (
    select 1 from public.organization_members om
     where om.organization_id = p_organization_id
       and om.user_id = auth.uid()
       and om.is_active = true
       and om.role::text in ('owner', 'admin', 'instructor', 'check_in_staff')
  ) then
    raise exception 'No tienes permiso para ver esta información';
  end if;

  -- Alumnos VIP: con un pase de clase activo vigente en el mes.
  v_vip := array(
    select distinct ce.user_id
      from public.class_passes cp
      join public.class_enrollments ce on ce.id = cp.enrollment_id
      join public.dance_classes dc on dc.id = ce.dance_class_id
     where dc.organization_id = p_organization_id
       and cp.status = 'active'
       and cp.starts_at < v_end
       and cp.ends_at >= v_start
  );

  select coalesce(jsonb_agg(
           jsonb_build_object(
             'id', c.id,
             'title', c.title,
             'price', c.price,
             'currency', c.currency,
             'sessions', c.sessions
           ) order by c.title), '[]'::jsonb)
    into v_classes
    from (
      select distinct dc.id, dc.title, dc.price, dc.currency,
        (select count(*) from public.dance_class_sessions s2
          where s2.dance_class_id = dc.id) as sessions
        from public.dance_classes dc
        join public.dance_class_sessions s on s.dance_class_id = dc.id
        join public.attendances a on a.session_id = s.id
        join public.class_enrollments ce on ce.id = a.enrollment_id
       where dc.organization_id = p_organization_id
         and s.session_date >= v_start
         and s.session_date < v_end
         and ce.user_id = any(v_vip)
    ) c;

  select coalesce(jsonb_agg(
           jsonb_build_object(
             'user_id', u.user_id,
             'first_name', p.first_name,
             'last_name', p.last_name
           ) order by p.last_name, p.first_name), '[]'::jsonb)
    into v_students
    from (select distinct unnest(v_vip) as user_id) u
    join public.profiles p on p.id = u.user_id;

  select coalesce(jsonb_agg(row_to_json(m)), '[]'::jsonb)
    into v_marks
    from (
      select ce.user_id, dc.id as class_id, max(a.recorded_at) as recorded_at
        from public.attendances a
        join public.class_enrollments ce on ce.id = a.enrollment_id
        join public.dance_classes dc on dc.id = ce.dance_class_id
        join public.dance_class_sessions s on s.id = a.session_id
       where dc.organization_id = p_organization_id
         and s.session_date >= v_start
         and s.session_date < v_end
         and ce.user_id = any(v_vip)
       group by ce.user_id, dc.id
    ) m;

  return jsonb_build_object(
    'month_start', v_start,
    'classes', v_classes,
    'students', v_students,
    'marks', v_marks
  );
end;
$$;

grant execute on function public.fetch_org_vip_attendance(uuid, date) to authenticated;
