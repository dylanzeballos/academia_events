-- ============================================================================
-- Backfill del ritmo de clases existentes.
-- Fecha: 2026-11-17
-- ============================================================================
-- Igual que el backfill de organization_dance_categories: infiere el ritmo
-- desde el título para que los pases VIP por ritmo incluyan clases ya creadas.

update public.dance_classes dc
   set dance_category_id = c.id
  from public.dance_categories c
 where dc.dance_category_id is null
   and c.is_active
   and (
        position(lower(c.name) in lower(dc.title)) > 0
     or (c.name = 'Hip Hop / Urbano' and position('urbano' in lower(dc.title)) > 0)
     or (c.name = 'Folklore' and position('folclor' in lower(dc.title)) > 0)
     or (c.name = 'Contemporáneo' and position('contempor' in lower(dc.title)) > 0)
   );

notify pgrst, 'reload schema';
