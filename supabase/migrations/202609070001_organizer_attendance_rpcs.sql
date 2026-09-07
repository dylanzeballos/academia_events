-- ============================================================================
-- Migración: Dashboard de asistencia del organizador (Eventos + Clases)
-- Fecha: 2026-09-07
-- Descripción:
--   - fetch_event_attendance(p_event_id): métricas de venta/check-in de un
--     evento + lista de asistentes con check-in y punto de acceso.
--   - fetch_class_attendance(p_class_id): métricas por sesión de una clase +
--     roster de estudiantes (asistencia acumulada y último check-in).
-- Ambos validan que el caller pertenezca a la organización (owner/admin/
-- instructor/check_in_staff) para garantizar que solo se consulta lo propio.
-- ============================================================================

-- ============================================================================
-- 1. fetch_event_attendance
-- ============================================================================

CREATE OR REPLACE FUNCTION fetch_event_attendance(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id      uuid;
  v_capacity    integer;
  v_sold        integer;
  v_checked_in  integer;
  v_by_type     jsonb;
  v_attendees   jsonb;
BEGIN
  SELECT organization_id, capacity
    INTO v_org_id, v_capacity
    FROM events
   WHERE id = p_event_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'El evento no existe';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM organization_members om
     WHERE om.organization_id = v_org_id
       AND om.user_id = auth.uid()
       AND om.is_active = true
       AND om.role IN ('owner', 'admin', 'instructor', 'check_in_staff')
  ) THEN
    RAISE EXCEPTION 'No tienes permiso para ver esta información';
  END IF;

  -- Entradas vendidas: tickets vigentes o usados del evento.
  SELECT count(*)
    INTO v_sold
    FROM tickets t
    JOIN ticket_types tt ON tt.id = t.ticket_type_id
   WHERE tt.event_id = p_event_id
     AND t.status IN ('active', 'used');

  -- Asistentes registrados (check-in reales, tickets únicos).
  SELECT count(DISTINCT ticket_id)
    INTO v_checked_in
    FROM check_ins
   WHERE event_id = p_event_id;

  -- Ventas y check-ins agrupados por tipo de entrada.
  SELECT COALESCE(jsonb_agg(row_to_json(x)::jsonb ORDER BY x.sold DESC), '[]'::jsonb)
    INTO v_by_type
    FROM (
      SELECT
        tt.name,
        count(t.id) AS sold,
        count(DISTINCT ci.ticket_id) AS checked_in
        FROM ticket_types tt
        LEFT JOIN tickets t ON t.ticket_type_id = tt.id
        LEFT JOIN check_ins ci ON ci.ticket_id = t.id
       WHERE tt.event_id = p_event_id
       GROUP BY tt.id, tt.name
    ) x;

  -- Lista de asistentes (por nombre).
  SELECT COALESCE(jsonb_agg(row_to_json(x)::jsonb ORDER BY x.last_name, x.first_name), '[]'::jsonb)
    INTO v_attendees
    FROM (
      SELECT
        p.id AS user_id,
        p.first_name,
        p.last_name,
        t.ticket_number,
        tt.name AS ticket_type,
        t.status AS ticket_status,
        (ci.id IS NOT NULL) AS checked_in,
        ci.scanned_at AS check_in_time,
        COALESCE(ci.metadata->>'access_point', ci.device_id) AS access_point
        FROM tickets t
        JOIN ticket_types tt ON tt.id = t.ticket_type_id
        JOIN profiles p ON p.id = t.user_id
        LEFT JOIN check_ins ci ON ci.ticket_id = t.id
       WHERE tt.event_id = p_event_id
         AND t.status IN ('active', 'used')
    ) x;

  RETURN jsonb_build_object(
    'capacity', v_capacity,
    'tickets_sold', v_sold,
    'tickets_available',
      CASE WHEN v_capacity IS NULL THEN NULL
           ELSE GREATEST(v_capacity - v_sold, 0) END,
    'checked_in', v_checked_in,
    'pending_entry', GREATEST(v_sold - v_checked_in, 0),
    'by_ticket_type', v_by_type,
    'attendees', v_attendees
  );
END;
$$;

-- ============================================================================
-- 2. fetch_class_attendance
-- ============================================================================

CREATE OR REPLACE FUNCTION fetch_class_attendance(p_class_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id     uuid;
  v_capacity   integer;
  v_enrolled   integer;
  v_sessions   jsonb;
  v_students   jsonb;
BEGIN
  SELECT organization_id, capacity
    INTO v_org_id, v_capacity
    FROM dance_classes
   WHERE id = p_class_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La clase no existe';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM organization_members om
     WHERE om.organization_id = v_org_id
       AND om.user_id = auth.uid()
       AND om.is_active = true
       AND om.role IN ('owner', 'admin', 'instructor', 'check_in_staff')
  ) THEN
    RAISE EXCEPTION 'No tienes permiso para ver esta información';
  END IF;

  -- Inscritos activos/validados (pending/approved/active).
  SELECT count(*)
    INTO v_enrolled
    FROM class_enrollments
   WHERE dance_class_id = p_class_id
     AND status IN ('pending', 'approved', 'active');

  -- Métricas por sesión.
  SELECT COALESCE(jsonb_agg(row_to_json(x)::jsonb ORDER BY x.session_date, x.start_at), '[]'::jsonb)
    INTO v_sessions
    FROM (
      SELECT
        s.id AS session_id,
        s.session_date,
        s.start_at,
        s.status,
        count(a.id) FILTER (WHERE a.status = 'present') AS present,
        count(a.id) FILTER (WHERE a.status = 'late') AS late,
        count(a.id) FILTER (WHERE a.status = 'absent') AS absent,
        GREATEST(
          v_enrolled
            - count(a.id) FILTER (WHERE a.status = 'present')
            - count(a.id) FILTER (WHERE a.status = 'late')
            - count(a.id) FILTER (WHERE a.status = 'absent'),
          0
        ) AS pending
        FROM dance_class_sessions s
        LEFT JOIN attendances a ON a.session_id = s.id
       WHERE s.dance_class_id = p_class_id
       GROUP BY s.id, s.session_date, s.start_at, s.status
    ) x;

  -- Roster: estudiantes inscritos con asistencia acumulada.
  SELECT COALESCE(jsonb_agg(row_to_json(x)::jsonb ORDER BY x.last_name, x.first_name), '[]'::jsonb)
    INTO v_students
    FROM (
      SELECT
        ce.id AS enrollment_id,
        ce.user_id,
        p.first_name,
        p.last_name,
        ce.status AS enrollment_status,
        count(a.id) AS sessions_attended,
        (SELECT count(*) FROM dance_class_sessions s2
          WHERE s2.dance_class_id = p_class_id) AS sessions_total,
        (SELECT a2.status FROM attendances a2
          WHERE a2.enrollment_id = ce.id
          ORDER BY a2.recorded_at DESC LIMIT 1) AS last_attendance_status,
        (SELECT a2.recorded_at FROM attendances a2
          WHERE a2.enrollment_id = ce.id
          ORDER BY a2.recorded_at DESC LIMIT 1) AS last_check_in_time
        FROM class_enrollments ce
        JOIN profiles p ON p.id = ce.user_id
        LEFT JOIN attendances a ON a.enrollment_id = ce.id
       WHERE ce.dance_class_id = p_class_id
         AND ce.status IN ('pending', 'approved', 'active')
       GROUP BY ce.id, ce.user_id, p.first_name, p.last_name, ce.status
    ) x;

  RETURN jsonb_build_object(
    'capacity', v_capacity,
    'enrolled', v_enrolled,
    'sessions', v_sessions,
    'students', v_students
  );
END;
$$;