-- ============================================================================
-- Migración: Asistencia a clases + Inscripción (RLS y RPCs)
-- Fecha: 2026-09-03
-- Descripción: Reusa la tabla class_enrollments existente y agrega:
--              - Tabla attendances (asistencia por sesión de clase)
--              - RPC enroll_in_class (capacidad segura con FOR UPDATE)
--              - RPC record_attendance (registro de asistencia por la academia)
--              - RPC cancel_enrollment
--              - Políticas RLS para class_enrollments y attendances
--              - Índices para consultas de asistencia/inscripción
-- ============================================================================

-- ============================================================================
-- 1. TABLA: attendances
-- Asistencia concreta a una sesión de una clase, registrada por la academia.
-- NOTA: class_enrollments ya existe en el proyecto objetivo (enum
--       enrollment_status = pending/approved/active/cancelled/rejected/completed);
--       aquí NO se recrea, solo se agregan políticas e índices.
-- ============================================================================

CREATE TABLE attendances (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  enrollment_id uuid NOT NULL REFERENCES class_enrollments(id) ON DELETE CASCADE,
  session_id    uuid NOT NULL REFERENCES dance_class_sessions(id) ON DELETE CASCADE,
  status        text NOT NULL DEFAULT 'present'
    CHECK (status IN ('present', 'absent', 'late')),
  notes         text,
  recorded_by   uuid NOT NULL REFERENCES profiles(id),
  recorded_at   timestamptz NOT NULL DEFAULT now(),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (enrollment_id, session_id)
);

CREATE INDEX idx_attendances_session
  ON attendances(session_id);

CREATE INDEX idx_attendances_enrollment
  ON attendances(enrollment_id);

-- ============================================================================
-- 2. ÍNDICES ADICIONALES PARA class_enrollments (la tabla ya existe)
-- ============================================================================

CREATE INDEX idx_class_enrollments_user
  ON class_enrollments(user_id);

CREATE INDEX idx_class_enrollments_class
  ON class_enrollments(dance_class_id);

-- Impide inscripciones duplicadas activas del mismo usuario a la misma clase
CREATE UNIQUE INDEX idx_class_enrollments_unique_active
  ON class_enrollments(dance_class_id, user_id)
  WHERE status IN ('pending', 'approved', 'active');

-- ============================================================================
-- 3. RPC: enroll_in_class
-- Securiza el conteo de capacidad y evita race conditions mediante un
-- SELECT ... FOR UPDATE sobre la fila de dance_classes en la misma transacción.
-- ============================================================================

CREATE OR REPLACE FUNCTION enroll_in_class(p_class_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_organization_id  uuid;
  v_status           class_status;
  v_capacity         integer;
  v_enrolled_count   integer;
  v_enrolled_count_actual integer;
  v_new_enrollment   uuid;
BEGIN
  -- Bloquea la fila de la clase para evitar que dos usuarios se inscriban
  -- al mismo tiempo superando la capacidad (race condition).
  SELECT organization_id, status, capacity
    INTO v_organization_id, v_status, v_capacity
    FROM dance_classes
   WHERE id = p_class_id
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La clase no existe';
  END IF;

  IF v_status <> 'published' THEN
    RAISE EXCEPTION 'La clase no está publicada';
  END IF;

  -- No puede inscribirse a una clase sin vacantes
  IF v_capacity IS NOT NULL THEN
    SELECT count(*) INTO v_enrolled_count_actual
      FROM class_enrollments
     WHERE dance_class_id = p_class_id
       AND status IN ('pending', 'approved', 'active');

    IF v_enrolled_count_actual >= v_capacity THEN
      RAISE EXCEPTION 'La clase está llena';
    END IF;
  END IF;

  -- Evita inscripciones duplicadas del mismo usuario
  -- (protección extra además del índice único parcial)
  SELECT count(*) INTO v_enrolled_count
    FROM class_enrollments
   WHERE dance_class_id = p_class_id
     AND user_id = auth.uid()
     AND status IN ('pending', 'approved', 'active');

  IF v_enrolled_count > 0 THEN
    RAISE EXCEPTION 'Ya estás inscrito en esta clase';
  END IF;

  INSERT INTO class_enrollments (dance_class_id, user_id, status)
  VALUES (p_class_id, auth.uid(), 'active')
  RETURNING id INTO v_new_enrollment;

  RETURN v_new_enrollment;
END;
$$;

-- ============================================================================
-- 4. RPC: cancel_enrollment
-- Permite al estudiante cancelar su propia inscripción activa.
-- ============================================================================

CREATE OR REPLACE FUNCTION cancel_enrollment(p_enrollment_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner uuid;
BEGIN
  SELECT user_id INTO v_owner
    FROM class_enrollments
   WHERE id = p_enrollment_id
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La inscripción no existe';
  END IF;

  IF v_owner <> auth.uid() THEN
    RAISE EXCEPTION 'No tienes permiso para cancelar esta inscripción';
  END IF;

  UPDATE class_enrollments
     SET status = 'cancelled',
         cancelled_at = now(),
         updated_at = now()
   WHERE id = p_enrollment_id
     AND status IN ('pending', 'approved', 'active');
END;
$$;

-- ============================================================================
-- 5. RPC: record_attendance
-- Registra la asistencia de un estudiante a una sesión. Solo la academia
-- (owner/manager/instructor) puede registrar asistencia.
-- ============================================================================

CREATE OR REPLACE FUNCTION record_attendance(
  p_enrollment_id uuid,
  p_session_id    uuid,
  p_status        text DEFAULT 'present',
  p_notes         text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id       uuid;
  v_user_id      uuid;
  p_att_status   text;
BEGIN
  IF p_status NOT IN ('present', 'absent', 'late') THEN
    RAISE EXCEPTION 'Estado de asistencia inválido';
  END IF;

  -- Solo el propietario/manager/instructor de la organización puede registrar
  SELECT dc.organization_id INTO v_org_id
    FROM class_enrollments ce
    JOIN dance_classes dc ON dc.id = ce.dance_class_id
   WHERE ce.id = p_enrollment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La inscripción no existe';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM organization_members om
     WHERE om.organization_id = v_org_id
       AND om.user_id = auth.uid()
       AND om.is_active = true
       AND om.role IN ('owner', 'admin', 'instructor')
  ) THEN
    RAISE EXCEPTION 'No tienes permiso para registrar asistencia';
  END IF;

  -- Validar la sesión
  IF NOT EXISTS (SELECT 1 FROM dance_class_sessions WHERE id = p_session_id) THEN
    RAISE EXCEPTION 'La sesión no existe';
  END IF;

  -- Garantizar que el estudiante tenga una inscripción activa
  SELECT user_id INTO v_user_id
    FROM class_enrollments
   WHERE id = p_enrollment_id
     AND status IN ('active', 'approved');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'El estudiante no tiene una inscripción activa';
  END IF;

  -- Insertar o actualizar asistencia (upsert por UNIQUE(enrollment_id, session_id))
  INSERT INTO attendances (enrollment_id, session_id, status, notes, recorded_by)
  VALUES (p_enrollment_id, p_session_id, p_status, p_notes, auth.uid())
  ON CONFLICT (enrollment_id, session_id)
  DO UPDATE SET
    status = EXCLUDED.status,
    notes  = EXCLUDED.notes,
    recorded_by = EXCLUDED.recorded_by,
    updated_at = now();
END;
$$;

-- ============================================================================
-- 6. RLS POLICIES
-- ============================================================================

-- ----- class_enrollments -----
ALTER TABLE class_enrollments ENABLE ROW LEVEL SECURITY;

-- El estudiante ve y gestiona sus propias inscripciones
CREATE POLICY "Users manage own enrollments"
  ON class_enrollments FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- La academia (owner/manager/instructor) puede gestionar las inscripciones
-- de sus clases
CREATE POLICY "Org staff manage enrollments"
  ON class_enrollments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      JOIN dance_classes dc ON dc.organization_id = om.organization_id
      WHERE dc.id = class_enrollments.dance_class_id
      AND om.user_id = auth.uid()
      AND om.is_active = true
      AND om.role IN ('owner', 'admin', 'instructor')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organization_members om
      JOIN dance_classes dc ON dc.organization_id = om.organization_id
      WHERE dc.id = class_enrollments.dance_class_id
      AND om.user_id = auth.uid()
      AND om.is_active = true
      AND om.role IN ('owner', 'admin', 'instructor')
    )
  );

-- ----- attendances -----
ALTER TABLE attendances ENABLE ROW LEVEL SECURITY;

-- El estudiante puede ver sus propias asistencias
CREATE POLICY "Students view own attendances"
  ON attendances FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM class_enrollments ce
      WHERE ce.id = attendances.enrollment_id
      AND ce.user_id = auth.uid()
    )
  );

-- La academia puede gestionar las asistencias de sus clases
CREATE POLICY "Org staff manage attendances"
  ON attendances FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM class_enrollments ce
      JOIN dance_classes dc ON dc.id = ce.dance_class_id
      WHERE ce.id = attendances.enrollment_id
      AND dc.organization_id IN (
        SELECT om.organization_id FROM organization_members om
        WHERE om.user_id = auth.uid()
        AND om.is_active = true
        AND om.role IN ('owner', 'admin', 'instructor')
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM class_enrollments ce
      JOIN dance_classes dc ON dc.id = ce.dance_class_id
      WHERE ce.id = attendances.enrollment_id
      AND dc.organization_id IN (
        SELECT om.organization_id FROM organization_members om
        WHERE om.user_id = auth.uid()
        AND om.is_active = true
        AND om.role IN ('owner', 'admin', 'instructor')
      )
    )
  );
