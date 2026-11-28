-- ============================================================================
-- Migración: Rangos por horario + ubicación por horario + múltiples franjas por día
-- Fecha: 2026-09-03
-- Descripción:
--   * Permite a cada dance_class_schedule definir su propio rango de fechas
--     (start_date / end_date) para que "las clases muestren sus horarios
--     recurrentes" con inicio/fin por schedule.
--   * Permite a cada schedule tener una ubicación propia (location_override)
--     que se hereda a las sesiones generadas.
--   * Elimina el índice único (dance_class_id, day_of_week) para permitir
--     varias franjas en el mismo día (ej: Lunes 09:00 y Lunes 19:00).
-- ============================================================================

ALTER TABLE dance_class_schedules
  ADD COLUMN IF NOT EXISTS start_date date,
  ADD COLUMN IF NOT EXISTS end_date   date,
  ADD COLUMN IF NOT EXISTS location_override jsonb;

-- Índices para consultas por rango de fechas (calendario).
CREATE INDEX IF NOT EXISTS idx_dance_class_schedules_dates
  ON dance_class_schedules(start_date, end_date);

-- Permitir múltiples franjas por día: quitar el índice único (class_id, day_of_week).
DROP INDEX IF EXISTS idx_dance_class_schedules_class_day;

-- Índice no único para agrupar por clase + día (mantiene el orden del listado).
CREATE INDEX IF NOT EXISTS idx_dance_class_schedules_class_day
  ON dance_class_schedules(dance_class_id, day_of_week);