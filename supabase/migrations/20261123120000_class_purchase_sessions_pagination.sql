-- ============================================================================
-- Compra de sesiones: paginación real y horizonte de tiempo.
-- Fecha: 2026-11-23
-- ============================================================================
-- `list_class_purchase_sessions` devolvía todas las sesiones futuras de la
-- clase: para una clase 3 veces por semana durante un año son ~150 filas, y el
-- modal de compra las renderizaba todas.
--
-- Ahora acepta:
--   * p_limit / p_offset → paginación en la base (null = sin límite).
--   * p_weeks            → horizonte en semanas desde hoy (null = todas).
--
-- La firma anterior se elimina para que no queden dos versiones de la función
-- (PostgREST resolvería de forma ambigua).

drop function if exists public.list_class_purchase_sessions(uuid);

create or replace function public.list_class_purchase_sessions(
  p_class_id uuid,
  p_limit integer default null,
  p_offset integer default 0,
  p_weeks integer default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $fn$
declare
  v_result jsonb;
begin
  select coalesce(
           jsonb_agg(row_to_json(t)::jsonb order by t.session_date),
           '[]'::jsonb
         )
    into v_result
    from (
      select s.id,
             s.session_date,
             s.start_at,
             s.end_at,
             c.capacity,
             c.price as price_per_session,
             c.currency,
             (
               select count(*)
                 from public.class_session_tickets cst
                 join public.class_passes cp on cp.id = cst.class_pass_id
                where cst.session_id = s.id
                  and cst.status in ('issued', 'used')
                  and cp.status = 'active'
             ) as occupied,
             exists (
               select 1
                 from public.class_session_tickets cst
                 join public.class_passes cp on cp.id = cst.class_pass_id
                 join public.class_enrollments ce on ce.id = cp.enrollment_id
                where cst.session_id = s.id
                  and cst.status in ('issued', 'used')
                  and ce.dance_class_id = s.dance_class_id
                  and ce.user_id = auth.uid()
             ) as already_purchased
        from public.dance_class_sessions s
        join public.dance_classes c on c.id = s.dance_class_id
       where s.dance_class_id = p_class_id
         and s.status = 'scheduled'::public.class_session_status
         and s.session_date >= current_date
         and (
           p_weeks is null
           or s.session_date < current_date + (p_weeks * 7)
         )
       order by s.session_date
       limit p_limit
      offset p_offset
    ) t;

  return v_result;
end;
$fn$;

revoke all on function public.list_class_purchase_sessions(
  uuid, integer, integer, integer
) from public, anon;

grant execute on function public.list_class_purchase_sessions(
  uuid, integer, integer, integer
) to authenticated, service_role;

notify pgrst, 'reload schema';
