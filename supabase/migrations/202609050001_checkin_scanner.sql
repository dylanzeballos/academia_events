-- ============================================================================
-- Migración: Check-in con QR (Eventos y Clases) + Compra de Pase de Clase
-- Fecha: 2026-09-05
-- Descripción:
--   - purchase_class_pass: el estudiante compra un pase de 30 días sobre una
--     inscripción. Genera class_passes + class_session_tickets + QRs.
--   - fetch_my_class_passes / fetch_my_class_tickets: consultas del estudiante.
--   - register_event_check_in: valida y registra una entrada a un evento.
--   - register_class_check_in: valida y registra la asistencia a una sesión.
--
--   REGLA CRÍTICA: TODA la validación ocurre server-side. El frontend solo
--   muestra el resultado. Un ticket solo puede producir UN check-in exitoso
--   (constraints UNIQUE + FOR UPDATE en la misma transacción).
-- ============================================================================

-- ============================================================================
-- 1. RPC: purchase_class_pass
-- Compra/pago simulado de un pase de 30 días. Genera los tickets diarios
-- de las sesiones programadas dentro de la ventana del pase y sus QRs.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.purchase_class_pass(p_enrollment_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_enrollment  record;
  v_class_id    uuid;
  v_pass_id     uuid;
  v_session     record;
  v_ticket_id   uuid;
  v_token       text;
  v_tickets     jsonb := '[]'::jsonb;
  v_count       integer := 0;
  v_starts_at   date;
  v_ends_at     date;
BEGIN
  -- Solo el dueño de la inscripción puede comprar su pase
  SELECT *
    INTO v_enrollment
    FROM class_enrollments
   WHERE id = p_enrollment_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'La inscripción no existe');
  END IF;

  IF v_enrollment.user_id <> auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'No tienes permiso para comprar este pase');
  END IF;

  IF v_enrollment.status NOT IN ('pending', 'approved', 'active') THEN
    RETURN jsonb_build_object('success', false, 'reason', 'La inscripción no está activa');
  END IF;

  -- Solo un pase activo por inscripción
  IF EXISTS (
    SELECT 1 FROM class_passes
     WHERE enrollment_id = p_enrollment_id
       AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Ya tienes un pase activo para esta clase');
  END IF;

  v_starts_at := current_date;
  v_ends_at   := current_date + interval '30 days';

  INSERT INTO class_passes (enrollment_id, starts_at, ends_at, status)
  VALUES (p_enrollment_id, v_starts_at, v_ends_at, 'active')
  RETURNING id INTO v_pass_id;

  SELECT ce.dance_class_id INTO v_class_id
    FROM class_enrollments ce
   WHERE ce.id = p_enrollment_id;

  -- Generar un ticket por cada sesión programada dentro de la ventana del pase
  FOR v_session IN
    SELECT s.id AS session_id, s.session_date
      FROM dance_class_sessions s
     WHERE s.dance_class_id = v_class_id
       AND s.status = 'scheduled'
       AND s.session_date BETWEEN v_starts_at AND v_ends_at
     ORDER BY s.session_date
  LOOP
    INSERT INTO class_session_tickets (class_pass_id, session_id, valid_date, status)
    VALUES (v_pass_id, v_session.session_id, v_session.session_date, 'issued')
    ON CONFLICT (class_pass_id, session_id) DO NOTHING
    RETURNING id INTO v_ticket_id;

    IF v_ticket_id IS NOT NULL THEN
      v_count := v_count + 1;
      v_token := encode(gen_random_bytes(24), 'hex');

      INSERT INTO class_ticket_qr_codes (ticket_id, token_hash, expires_at)
      VALUES (v_ticket_id, v_token, now() + interval '30 days')
      ON CONFLICT (ticket_id) DO NOTHING;

      v_tickets := v_tickets || jsonb_build_object(
        'ticket_id', v_ticket_id,
        'session_id', v_session.session_id,
        'session_date', v_session.session_date,
        'qr_token', v_token
      );
    END IF;

    v_ticket_id := NULL;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'pass_id', v_pass_id,
    'starts_at', v_starts_at,
    'ends_at', v_ends_at,
    'tickets_generated', v_count,
    'tickets', v_tickets
  );
END;
$$;

-- ============================================================================
-- 2. RPC: fetch_my_class_passes
-- Retorna los pases del usuario autenticado (para el botón "Comprar pase").
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fetch_my_class_passes()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
    INTO v_result
    FROM (
      SELECT cp.id,
             cp.starts_at,
             cp.ends_at,
             cp.status AS pass_status,
             ce.dance_class_id AS class_id,
             ce.id AS enrollment_id,
             dc.title AS class_title,
             o.name AS organization_name
        FROM class_passes cp
        JOIN class_enrollments ce ON ce.id = cp.enrollment_id
        JOIN dance_classes dc ON dc.id = ce.dance_class_id
        JOIN organizations o ON o.id = dc.organization_id
       WHERE ce.user_id = auth.uid()
       ORDER BY cp.created_at DESC
    ) t;

  RETURN v_result;
END;
$$;

-- ============================================================================
-- 3. RPC: fetch_my_class_tickets
-- Retorna los tickets diarios del usuario autenticado con su token QR.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fetch_my_class_tickets()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
    INTO v_result
    FROM (
      SELECT cst.id,
             cst.session_id,
             cst.valid_date,
             cst.status,
             cst.used_at,
             cqc.token_hash AS qr_token,
             cqc.is_active AS qr_active,
             cqc.expires_at AS qr_expires_at,
             dc.id AS class_id,
             dc.title AS class_title,
             o.name AS organization_name,
             dcs.start_at AS session_start_at,
             dcs.end_at AS session_end_at,
             cp.status AS pass_status
        FROM class_session_tickets cst
        JOIN class_ticket_qr_codes cqc ON cqc.ticket_id = cst.id
        JOIN class_passes cp ON cp.id = cst.class_pass_id
        JOIN class_enrollments ce ON ce.id = cp.enrollment_id
        JOIN dance_classes dc ON dc.id = ce.dance_class_id
        JOIN organizations o ON o.id = dc.organization_id
        JOIN dance_class_sessions dcs ON dcs.id = cst.session_id
       WHERE ce.user_id = auth.uid()
       ORDER BY cst.valid_date DESC
    ) t;

  RETURN v_result;
END;
$$;

-- ============================================================================
-- 4. RPC: register_event_check_in
-- Valida el QR de un ticket de evento y registra el check-in.
--
-- Validaciones (todas server-side):
--   - QR válido (token existe en ticket_qr_codes, activo y vigente)
--   - Ticket existe y su estado es 'active'
--   - Orden pagada (orders.status IN 'paid'/'completed')
--   - El ticket pertenece al evento indicado
--   - El usuario autenticado es staff autorizado de la organización
--   - El ticket no fue usado previamente (FOR UPDATE + UNIQUE en check_ins)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.register_event_check_in(
  p_token_hash text,
  p_event_id uuid,
  p_device_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_qr         record;
  v_ticket     record;
  v_ticket_type record;
  v_event      record;
  v_checked_in boolean;
  v_attendee_name text;
BEGIN
  -- QR válido
  SELECT *
    INTO v_qr
    FROM ticket_qr_codes
   WHERE token_hash = p_token_hash;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'QR no reconocido');
  END IF;

  IF v_qr.is_active = false THEN
    RETURN jsonb_build_object('success', false, 'reason', 'El QR fue desactivado');
  END IF;

  IF v_qr.expires_at IS NOT NULL AND v_qr.expires_at < now() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'El QR ha expirado');
  END IF;

  -- Bloquear el ticket para evitar doble check-in (race condition)
  SELECT *
    INTO v_ticket
    FROM tickets
   WHERE id = v_qr.ticket_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'El ticket no existe');
  END IF;

  IF v_ticket.status <> 'active' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'El ticket no está activo');
  END IF;

  -- Orden pagada
  IF EXISTS (
    SELECT 1 FROM orders o
     WHERE o.id = v_ticket.order_id
       AND o.status NOT IN ('paid', 'completed')
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'El pago del ticket no está confirmado');
  END IF;

  -- Ticket pertenece al evento
  SELECT *
    INTO v_ticket_type
    FROM ticket_types
   WHERE id = v_ticket.ticket_type_id;

  IF FOUND AND v_ticket_type.event_id <> p_event_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'El ticket no pertenece a este evento');
  END IF;

  -- Evento existe
  SELECT *
    INTO v_event
    FROM events
   WHERE id = p_event_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'El evento no existe');
  END IF;

  -- Staff autorizado (owner/admin/instructor/check_in_staff de la organización)
  IF NOT EXISTS (
    SELECT 1 FROM organization_members om
     WHERE om.organization_id = v_event.organization_id
       AND om.user_id = auth.uid()
       AND om.is_active = true
       AND om.role IN ('owner', 'admin', 'instructor', 'check_in_staff')
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'No tienes autorización para escanear este evento');
  END IF;

  -- Nombre del asistente
  SELECT COALESCE(NULLIF(trim(concat(p.first_name, ' ', p.last_name)), ''), 'Asistente')
    INTO v_attendee_name
    FROM profiles p
   WHERE p.id = v_ticket.user_id;

  -- Ticket no usado previamente (constraint UNIQUE(ticket_id) como salvaguarda final)
  SELECT EXISTS (SELECT 1 FROM check_ins WHERE ticket_id = v_qr.ticket_id)
    INTO v_checked_in;

  IF v_checked_in THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Este ticket ya fue utilizado');
  END IF;

  -- Registrar check-in y marcar ticket usado (misma transacción)
  INSERT INTO check_ins (ticket_id, event_id, scanned_by_user_id, device_id, metadata)
  VALUES (v_qr.ticket_id, p_event_id, auth.uid(), p_device_id,
          jsonb_build_object('order_id', v_ticket.order_id, 'ticket_number', v_ticket.ticket_number))
  ON CONFLICT (ticket_id) DO NOTHING
  RETURNING true INTO v_checked_in;

  IF NOT v_checked_in THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Este ticket ya fue utilizado');
  END IF;

  UPDATE tickets
     SET status = 'used', updated_at = now()
   WHERE id = v_ticket.id;

  RETURN jsonb_build_object(
    'success', true,
    'ticket_number', v_ticket.ticket_number,
    'event_title', v_event.title,
    'attendee_name', v_attendee_name,
    'checked_in_at', now()
  );
END;
$$;

-- ============================================================================
-- 5. RPC: register_class_check_in
-- Valida el QR de un ticket de sesión de clase y registra la asistencia.
--
-- Validaciones (todas server-side):
--   - QR válido (token existe en class_ticket_qr_codes, activo y vigente)
--   - Ticket de sesión existe y su estado es 'issued'
--   - La sesión escaneada coincide con la del ticket
--   - La clase pertenece a una organización donde el usuario es staff autorizado
--   - El ticket no fue usado previamente (estado 'issued' + FOR UPDATE)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.register_class_check_in(
  p_token_hash text,
  p_session_id uuid,
  p_device_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_qr          record;
  v_ticket      record;
  v_pass        record;
  v_enrollment  record;
  v_class       record;
  v_session     record;
  v_attendee_name text;
BEGIN
  -- QR válido
  SELECT *
    INTO v_qr
    FROM class_ticket_qr_codes
   WHERE token_hash = p_token_hash;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'QR no reconocido');
  END IF;

  IF v_qr.is_active = false THEN
    RETURN jsonb_build_object('success', false, 'reason', 'El QR fue desactivado');
  END IF;

  IF v_qr.expires_at < now() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'El QR ha expirado');
  END IF;

  -- Bloquear el ticket para evitar doble uso (race condition)
  SELECT *
    INTO v_ticket
    FROM class_session_tickets
   WHERE id = v_qr.ticket_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'El ticket no existe');
  END IF;

  IF v_ticket.status <> 'issued' THEN
    IF v_ticket.status = 'used' THEN
      RETURN jsonb_build_object('success', false, 'reason', 'Este ticket ya fue utilizado');
    END IF;
    RETURN jsonb_build_object('success', false, 'reason', 'El ticket no está vigente');
  END IF;

  -- La sesión escaneada debe coincidir con la del ticket
  IF v_ticket.session_id <> p_session_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'El ticket no corresponde a esta sesión');
  END IF;

  -- Sesión debe existir y estar programada
  SELECT *
    INTO v_session
    FROM dance_class_sessions
   WHERE id = p_session_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'La sesión no existe');
  END IF;

  IF v_session.status <> 'scheduled' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Esta sesión no está disponible');
  END IF;

  -- Pase activo
  SELECT *
    INTO v_pass
    FROM class_passes
   WHERE id = v_ticket.class_pass_id;

  IF v_pass.status <> 'active' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'El pase no está activo');
  END IF;

  -- Inscripción + clase + organización
  SELECT *
    INTO v_enrollment
    FROM class_enrollments
   WHERE id = v_pass.enrollment_id;

  SELECT *
    INTO v_class
    FROM dance_classes
   WHERE id = v_enrollment.dance_class_id;

  -- Staff autorizado (owner/admin/instructor/check_in_staff de la organización)
  IF NOT EXISTS (
    SELECT 1 FROM organization_members om
     WHERE om.organization_id = v_class.organization_id
       AND om.user_id = auth.uid()
       AND om.is_active = true
       AND om.role IN ('owner', 'admin', 'instructor', 'check_in_staff')
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'No tienes autorización para escanear esta clase');
  END IF;

  -- Nombre del estudiante
  SELECT COALESCE(NULLIF(trim(concat(p.first_name, ' ', p.last_name)), ''), 'Estudiante')
    INTO v_attendee_name
    FROM profiles p
   WHERE p.id = v_enrollment.user_id;

  -- Marcar ticket usado (misma transacción → impide doble check-in)
  UPDATE class_session_tickets
     SET status = 'used', used_at = now(), updated_at = now()
   WHERE id = v_ticket.id;

  -- Registrar asistencia presente (upsert por UNIQUE(enrollment_id, session_id))
  INSERT INTO attendances (enrollment_id, session_id, status, recorded_by)
  VALUES (v_enrollment.id, p_session_id, 'present', auth.uid())
  ON CONFLICT (enrollment_id, session_id)
  DO UPDATE SET
    status = EXCLUDED.status,
    recorded_by = EXCLUDED.recorded_by,
    updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'class_title', v_class.title,
    'session_date', v_session.session_date,
    'attendee_name', v_attendee_name,
    'checked_in_at', now()
  );
END;
$$;