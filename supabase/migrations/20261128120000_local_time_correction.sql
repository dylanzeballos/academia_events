-- ============================================================================
-- Corrección de horarios guardados como UTC (hora local Bolivia).
-- Fecha: 2026-11-28
-- ============================================================================
-- Antes de este fix la app enviaba `DateTime.now()` / valores de pickers (hora
-- local, Bolivia UTC-4) con `toIso8601String()` SIN offset. PostgREST los
-- interpretaba como UTC, así que cada fecha quedaba 4 horas antes de la
-- intención real (19:00 local se guardaba como 19:00Z = 15:00 Bolivia).
--
-- La expresión `(col AT TIME ZONE 'UTC') AT TIME ZONE 'America/La_Paz'`
-- reinterpreta el reloj guardado como hora Bolivia: 19:00Z → 23:00Z, que en
-- pantalla vuelve a mostrar 19:00.
--
-- IMPORTANTE
--   * Ejecutar SOLO si todas las fechas afectadas se cargaron desde la app en
--     hora Bolivia. Si alguna se insertó a mano con SQL como UTC real, también
--     se correría 4 horas y quedaría mal.
--   * `created_at`, `published_at`, `paid_at` y demás marcas del servidor NO se
--     tocan: esas usan `now()` y están bien.
--   * `session_date`, `start_date` y `end_date` son columnas `date` (sin hora):
--     no se tocan.

begin;

-- Eventos creados desde el formulario de la app.
update public.events
set start_at = (start_at at time zone 'UTC') at time zone 'America/La_Paz',
    end_at = (end_at at time zone 'UTC') at time zone 'America/La_Paz'
where start_at is not null
  and end_at is not null;

-- Clases y sus sesiones.
update public.dance_classes
set start_at = (start_at at time zone 'UTC') at time zone 'America/La_Paz',
    end_at = (end_at at time zone 'UTC') at time zone 'America/La_Paz'
where start_at is not null
  and end_at is not null;

update public.dance_class_sessions
set start_at = (start_at at time zone 'UTC') at time zone 'America/La_Paz',
    end_at = (end_at at time zone 'UTC') at time zone 'America/La_Paz'
where start_at is not null
  and end_at is not null;

-- Ventanas de venta de entradas.
update public.ticket_types
set sales_start_at = (sales_start_at at time zone 'UTC')
      at time zone 'America/La_Paz',
    sales_end_at = (sales_end_at at time zone 'UTC')
      at time zone 'America/La_Paz'
where sales_start_at is not null
  and sales_end_at is not null;

-- Marca de lectura (se enviaba sin offset; solo afecta el "hace X tiempo").
update public.notifications
set read_at = (read_at at time zone 'UTC') at time zone 'America/La_Paz'
where read_at is not null;

commit;
