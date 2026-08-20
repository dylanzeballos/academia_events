-- ============================================================================
-- Migración: Clases Recurrentes + Roles + Pagos
-- Fecha: 2026-08-19
-- Descripción: Agrega soporte para clases de baile recurrentes, roles de
--              instructor/staff, pagos por publicación de clases, y features
--              de planes de suscripción.
-- ============================================================================

-- ============================================================================
-- 1. NUEVOS ENUMs Y COLUMNAS
-- ============================================================================

-- 1a. Roles de organización
ALTER TYPE organization_member_role ADD VALUE IF NOT EXISTS 'instructor';
ALTER TYPE organization_member_role ADD VALUE IF NOT EXISTS 'staff';

-- 1b. Tipo de pago para publicación de clases
ALTER TYPE payment_type ADD VALUE IF NOT EXISTS 'class_publication';

-- 1c. Instructor en dance_classes
ALTER TABLE dance_classes
  ADD COLUMN instructor_id uuid REFERENCES profiles(id);

-- ============================================================================
-- 2. TABLA: dance_class_schedules
-- Horarios recurrentes de una clase (ej: Martes 19:00-20:30)
-- ============================================================================

CREATE TABLE dance_class_schedules (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dance_class_id uuid NOT NULL REFERENCES dance_classes(id) ON DELETE CASCADE,
  day_of_week   smallint NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time    time NOT NULL,
  end_time      time NOT NULL,
  instructor_id uuid REFERENCES profiles(id),
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CHECK (start_time < end_time)
);

CREATE UNIQUE INDEX idx_dance_class_schedules_class_day
  ON dance_class_schedules(dance_class_id, day_of_week) WHERE is_active;

-- ============================================================================
-- 3. TABLA: dance_class_sessions
-- Sesiones concretas generadas a partir de los horarios recurrentes
-- ============================================================================

CREATE TYPE class_session_status AS ENUM (
  'scheduled', 'cancelled', 'completed', 'rescheduled'
);

CREATE TABLE dance_class_sessions (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dance_class_id    uuid NOT NULL REFERENCES dance_classes(id) ON DELETE CASCADE,
  schedule_id       uuid REFERENCES dance_class_schedules(id) ON DELETE SET NULL,
  session_date      date NOT NULL,
  start_at          timestamptz NOT NULL,
  end_at            timestamptz NOT NULL,
  status            class_session_status NOT NULL DEFAULT 'scheduled',
  location_override jsonb,
  cancelled_reason  text,
  is_completed      boolean NOT NULL DEFAULT false,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (start_at < end_at)
);

CREATE UNIQUE INDEX idx_dance_class_sessions_class_date
  ON dance_class_sessions(dance_class_id, start_at);

CREATE INDEX idx_dance_class_sessions_date
  ON dance_class_sessions(session_date);

-- ============================================================================
-- 4. TABLA: dance_class_publication_payments
-- Registro de pagos para publicar clases en el calendario
-- ============================================================================

CREATE TABLE dance_class_publication_payments (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dance_class_id uuid NOT NULL UNIQUE REFERENCES dance_classes(id),
  payment_id    uuid NOT NULL UNIQUE REFERENCES payments(id),
  amount        numeric NOT NULL CHECK (amount >= 0),
  currency      bpchar NOT NULL DEFAULT 'BOB',
  paid_at       timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ============================================================================
-- 5. FEATURES DE SUSCRIPCIÓN
-- Columnas en subscription_plans para controlar qué puede hacer cada plan
-- ============================================================================

ALTER TABLE subscription_plans
  ADD COLUMN can_create_events    boolean NOT NULL DEFAULT false,
  ADD COLUMN can_create_classes   boolean NOT NULL DEFAULT false,
  ADD COLUMN show_in_calendar     boolean NOT NULL DEFAULT false,
  ADD COLUMN max_events_per_month integer,
  ADD COLUMN max_classes_per_month integer;

-- ============================================================================
-- 6. RLS POLICIES
-- ============================================================================

-- dance_class_schedules
ALTER TABLE dance_class_schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can view active schedules"
  ON dance_class_schedules FOR SELECT
  USING (is_active = true);

CREATE POLICY "Org members can manage schedules"
  ON dance_class_schedules FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      JOIN dance_classes dc ON dc.organization_id = om.organization_id
      WHERE dc.id = dance_class_schedules.dance_class_id
      AND om.user_id = auth.uid()
      AND om.is_active = true
      AND om.role IN ('owner', 'manager', 'instructor')
    )
  );

-- dance_class_sessions
ALTER TABLE dance_class_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can view scheduled sessions"
  ON dance_class_sessions FOR SELECT
  USING (status IN ('scheduled', 'completed'));

CREATE POLICY "Org members can manage sessions"
  ON dance_class_sessions FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      JOIN dance_classes dc ON dc.organization_id = om.organization_id
      WHERE dc.id = dance_class_sessions.dance_class_id
      AND om.user_id = auth.uid()
      AND om.is_active = true
      AND om.role IN ('owner', 'manager', 'instructor')
    )
  );

-- dance_class_publication_payments
ALTER TABLE dance_class_publication_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Org owners can view publication payments"
  ON dance_class_publication_payments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      JOIN dance_classes dc ON dc.organization_id = om.organization_id
      WHERE dc.id = dance_class_publication_payments.dance_class_id
      AND om.user_id = auth.uid()
      AND om.role = 'owner'
    )
  );
