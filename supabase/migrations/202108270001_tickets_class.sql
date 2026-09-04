-- ============================================================================
-- Migración: Sistema de Tickets QR para Clases Regulares
-- Fecha: 2026-08-27
-- Descripción: Agrega el pase de 30 días (class_passes), el ticket diario de
--              un solo uso por sesión (class_session_tickets) y su QR seguro
--              (class_ticket_qr_codes), replicando el patrón de seguridad ya
--              usado en ticket_qr_codes pero para el flujo de clases.
-- ============================================================================

-- ============================================================================
-- 1. TABLA: class_passes
-- El pase/"tarjeta" de 30 días que compra el alumno sobre una inscripción
-- ============================================================================

CREATE TABLE class_passes (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  enrollment_id  uuid NOT NULL REFERENCES class_enrollments(id) ON DELETE CASCADE,
  starts_at      date NOT NULL,
  ends_at        date NOT NULL,
  status         text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'cancelled')),
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CHECK (ends_at >= starts_at)
);

CREATE INDEX idx_class_passes_enrollment_id ON class_passes(enrollment_id);
CREATE INDEX idx_class_passes_status ON class_passes(status);

-- ============================================================================
-- 2. TABLA: class_session_tickets
-- Ticket de un solo día, uno por sesión concreta dentro de un pase
-- ============================================================================

CREATE TABLE class_session_tickets (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_pass_id uuid NOT NULL REFERENCES class_passes(id) ON DELETE CASCADE,
  session_id    uuid NOT NULL REFERENCES dance_class_sessions(id) ON DELETE CASCADE,
  valid_date    date NOT NULL,
  status        text NOT NULL DEFAULT 'issued' CHECK (status IN ('issued', 'used', 'expired', 'cancelled')),
  used_at       timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (class_pass_id, session_id)
);

CREATE INDEX idx_class_session_tickets_class_pass_id ON class_session_tickets(class_pass_id);
CREATE INDEX idx_class_session_tickets_session_id ON class_session_tickets(session_id);
CREATE INDEX idx_class_session_tickets_valid_date ON class_session_tickets(valid_date);

-- ============================================================================
-- 3. TABLA: class_ticket_qr_codes
-- Token seguro del QR de cada ticket diario (solo hash, nunca en claro)
-- ============================================================================

CREATE TABLE class_ticket_qr_codes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id   uuid NOT NULL UNIQUE REFERENCES class_session_tickets(id) ON DELETE CASCADE,
  token_hash  text NOT NULL UNIQUE,
  expires_at  timestamptz NOT NULL,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_class_ticket_qr_codes_ticket_id ON class_ticket_qr_codes(ticket_id);

-- ============================================================================
-- 4. RLS POLICIES
-- ============================================================================

-- class_passes
ALTER TABLE class_passes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students can view their own passes"
  ON class_passes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM class_enrollments ce
      WHERE ce.id = class_passes.enrollment_id
      AND ce.user_id = auth.uid()
    )
  );

CREATE POLICY "Org members can manage passes"
  ON class_passes FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM class_enrollments ce
      JOIN dance_classes dc ON dc.id = ce.dance_class_id
      JOIN organization_members om ON om.organization_id = dc.organization_id
      WHERE ce.id = class_passes.enrollment_id
      AND om.user_id = auth.uid()
      AND om.is_active = true
      AND om.role IN ('owner', 'manager', 'instructor')
    )
  );

-- class_session_tickets
ALTER TABLE class_session_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students can view their own session tickets"
  ON class_session_tickets FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM class_passes cp
      JOIN class_enrollments ce ON ce.id = cp.enrollment_id
      WHERE cp.id = class_session_tickets.class_pass_id
      AND ce.user_id = auth.uid()
    )
  );

CREATE POLICY "Org staff can manage session tickets"
  ON class_session_tickets FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM class_passes cp
      JOIN class_enrollments ce ON ce.id = cp.enrollment_id
      JOIN dance_classes dc ON dc.id = ce.dance_class_id
      JOIN organization_members om ON om.organization_id = dc.organization_id
      WHERE cp.id = class_session_tickets.class_pass_id
      AND om.user_id = auth.uid()
      AND om.is_active = true
      AND om.role IN ('owner', 'manager', 'instructor', 'staff')
    )
  );

-- class_ticket_qr_codes
ALTER TABLE class_ticket_qr_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students can view their own QR codes"
  ON class_ticket_qr_codes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM class_session_tickets cst
      JOIN class_passes cp ON cp.id = cst.class_pass_id
      JOIN class_enrollments ce ON ce.id = cp.enrollment_id
      WHERE cst.id = class_ticket_qr_codes.ticket_id
      AND ce.user_id = auth.uid()
    )
  );

CREATE POLICY "Org staff can manage QR codes"
  ON class_ticket_qr_codes FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM class_session_tickets cst
      JOIN class_passes cp ON cp.id = cst.class_pass_id
      JOIN class_enrollments ce ON ce.id = cp.enrollment_id
      JOIN dance_classes dc ON dc.id = ce.dance_class_id
      JOIN organization_members om ON om.organization_id = dc.organization_id
      WHERE cst.id = class_ticket_qr_codes.ticket_id
      AND om.user_id = auth.uid()
      AND om.is_active = true
      AND om.role IN ('owner', 'manager', 'instructor', 'staff')
    )
  );