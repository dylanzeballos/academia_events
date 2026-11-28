-- ============================================================================
-- Migración: Pase de clase por sesiones programadas (precio calculado + cupos)
-- Fecha: 2026-09-05
-- Descripción:
--   - Fix 42P10: constraint UNIQUE(class_pass_id, session_id) en
--     class_session_tickets (exigido por el ON CONFLICT de la compra).
--   - El pase ya NO es una ventana fija de 30 días: cubre TODAS las sesiones
--     programadas de la clase (status='scheduled') desde hoy hasta la última.
--   - El precio se calcula server-side: total = price * cantidad de sesiones,
--     y se persiste en class_passes (session_count/price/currency/total_amount).
--   - Cupos: la compra es una sola transacción que bloquea la fila de la clase
--     (FOR UPDATE), valida el cupo de TODAS sus sesiones ANTES de insertar
--     cualquier ticket, y un índice único parcial impide dos pases activos por
--     inscripción incluso bajo concurrencia (inmutable ante errores/colas).
--   - Nuevo RPC preview_class_pass para que el front muestre precio/sesiones
--     antes de confirmar la compra.
-- ============================================================================

-- ============================================================================
-- 1. Constraints / columnas
-- ============================================================================

-- Hace funcionar el ON CONFLICT (class_pass_id, session_id) de la compra
-- y garantiza un solo ticket por (pase, sesión).
ALTER TABLE public.class_session_tickets
  ADD CONSTRAINT class_session_tickets_pass_session_key
  UNIQUE (class_pass_id, session_id);

-- Garantiza a nivel de esquema un único pase activo por inscripción
-- (inmutable ante compras simultáneas).
CREATE UNIQUE INDEX uq_class_passes_one_active_per_enrollment
  ON public.class_passes(enrollment_id)
  WHERE status = 'active';

-- Datos de precio persistidos en el pase comprado.
ALTER TABLE public.class_passes
  ADD COLUMN session_count integer NOT NULL DEFAULT 0,
  ADD COLUMN price         numeric NOT NULL DEFAULT 0,
  ADD COLUMN currency      char(3) NOT NULL DEFAULT 'BOB',
  ADD COLUMN total_amount  numeric NOT NULL DEFAULT 0;

-- ============================================================================
-- 2. RPC: preview_class_pass
-- Devuelve la cotización (cantidad de sesiones, precio unitario y total)
-- SIN crear nada, para mostrar el precio antes de confirmar.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.preview_class_pass(p_enrollment_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_enrollment    record;
  v_class         record;
  v_count         integer;
  v_last_date     date;
BEGIN
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

  SELECT *
    INTO v_class
    FROM dance_classes
   WHERE id = v_enrollment.dance_class_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'La clase no existe');
  END IF;

  SELECT count(*), max(s.session_date)
    INTO v_count, v_last_date
    FROM dance_class_sessions s
   WHERE s.dance_class_id = v_class.id
     AND s.status = 'scheduled'
     AND s.session_date >= current_date;

  RETURN jsonb_build_object(
    'success', true,
    'session_count', v_count,
    'last_session_date', v_last_date,
    'price', v_class.price,
    'currency', v_class.currency,
    'total_amount', v_class.price * v_count
  );
END;
$$;

-- ============================================================================
-- 3. RPC: purchase_class_pass
-- Compra/pago simulado de un pase de clase. Genera un ticket por CADA sesión
-- programada pendiente (desde hoy hasta la última) y sus QRs.
--
-- Atomicidad / cupos:
--   - Bloquea la fila de dance_classes (FOR UPDATE) para serializar compras.
--   - Verifica el cupo de TODAS las sesiones antes de escribir nada.
--   - Si cualquier sesión está llena o no quedan pases, no inserta nada.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.purchase_class_pass(p_enrollment_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_enrollment    record;
  v_class         record;
  v_pass_id       uuid;
  v_session       record;
  v_ticket_id     uuid;
  v_token         text;
  v_tickets       jsonb := '[]'::jsonb;
  v_count         integer := 0;
  v_last_date     date;
  v_occupied      integer;
  v_total         numeric;
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

  -- Bloquear la clase para serializar compras de la misma clase
  -- (impide que dos compras simultáneas excedan el cupo).
  SELECT *
    INTO v_class
    FROM dance_classes
   WHERE id = v_enrollment.dance_class_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'La clase no existe');
  END IF;

  -- Solo un pase activo por inscripción (además del índice único parcial)
  IF EXISTS (
    SELECT 1 FROM class_passes
     WHERE enrollment_id = p_enrollment_id
       AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Ya tienes un pase activo para esta clase');
  END IF;

  -- Paso 1: validar cupo de TODAS las sesiones pendientes ANTES de insertar.
  IF v_class.capacity IS NOT NULL THEN
    FOR v_session IN
      SELECT s.id, s.session_date
        FROM dance_class_sessions s
       WHERE s.dance_class_id = v_class.id
         AND s.status = 'scheduled'
         AND s.session_date >= current_date
       ORDER BY s.session_date
    LOOP
      SELECT count(*)
        INTO v_occupied
        FROM class_session_tickets cst
        JOIN class_passes cp ON cp.id = cst.class_pass_id
       WHERE cst.session_id = v_session.id
         AND cst.status IN ('issued', 'used')
         AND cp.status = 'active';

      IF v_occupied >= v_class.capacity THEN
        RETURN jsonb_build_object(
          'success', false,
          'reason', format('La sesión del %s está llena', to_char(v_session.session_date, 'YYYY-MM-DD'))
        );
      END IF;
    END LOOP;
  END IF;

  -- Paso 2: contar sesiones, fecha límite del pase y precio total.
  SELECT count(*), max(s.session_date)
    INTO v_count, v_last_date
    FROM dance_class_sessions s
   WHERE s.dance_class_id = v_class.id
     AND s.status = 'scheduled'
     AND s.session_date >= current_date;

  IF v_count = 0 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'La clase no tiene sesiones programadas');
  END IF;

  v_total := v_class.price * v_count;

  INSERT INTO class_passes
    (enrollment_id, starts_at, ends_at, status, session_count, price, currency, total_amount)
  VALUES
    (p_enrollment_id, current_date, v_last_date, 'active', v_count,
     v_class.price, v_class.currency, v_total)
  RETURNING id INTO v_pass_id;

  -- Paso 3: generar un ticket + QR por cada sesión pendiente.
  FOR v_session IN
    SELECT s.id AS session_id, s.session_date, s.end_at
      FROM dance_class_sessions s
     WHERE s.dance_class_id = v_class.id
       AND s.status = 'scheduled'
       AND s.session_date >= current_date
     ORDER BY s.session_date
  LOOP
    INSERT INTO class_session_tickets (class_pass_id, session_id, valid_date, status)
    VALUES (v_pass_id, v_session.session_id, v_session.session_date, 'issued')
    ON CONFLICT (class_pass_id, session_id) DO NOTHING
    RETURNING id INTO v_ticket_id;

    IF v_ticket_id IS NOT NULL THEN
      v_token := encode(gen_random_bytes(24), 'hex');

      INSERT INTO class_ticket_qr_codes (ticket_id, token_hash, expires_at)
      VALUES (v_ticket_id, v_token, v_session.end_at)
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
    'starts_at', current_date,
    'ends_at', v_last_date,
    'session_count', v_count,
    'price', v_class.price,
    'currency', v_class.currency,
    'total_amount', v_total,
    'tickets_generated', v_count,
    'tickets', v_tickets
  );
END;
$$;

-- ============================================================================
-- 4. RPC: fetch_my_class_passes (ahora incluye precio y sesiones del pase)
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
             cp.session_count,
             cp.price,
             cp.currency,
             cp.total_amount,
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