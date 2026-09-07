-- ============================================================================
-- Seed: Categorías de Baile (dance_categories)
-- Usadas por el filtro de categorías de baile en calendario/clases.
-- Idempotente: re-ejecutable sin duplicar datos (ON CONFLICT).
-- ============================================================================

-- Garantiza que la tabla exista en caso de un reset desde cero.
CREATE TABLE IF NOT EXISTS public.dance_categories (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL UNIQUE,
  is_active  boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.dance_categories (id, name, is_active) VALUES
  ('00000000-0000-4000-8000-000000000001', 'Salsa',              true),
  ('00000000-0000-4000-8000-000000000002', 'Bachata',            true),
  ('00000000-0000-4000-8000-000000000003', 'Reggaeton',          true),
  ('00000000-0000-4000-8000-000000000004', 'Hip Hop / Urbano',   true),
  ('00000000-0000-4000-8000-000000000005', 'K-Pop',              true),
  ('00000000-0000-4000-8000-000000000006', 'Tango',              true),
  ('00000000-0000-4000-8000-000000000007', 'Ballet',             true),
  ('00000000-0000-4000-8000-000000000008', 'Contemporáneo',      true),
  ('00000000-0000-4000-8000-000000000009', 'Jazz',               true),
  ('00000000-0000-4000-8000-000000000010', 'Folklore',           true)
ON CONFLICT (id) DO NOTHING;

-- Si el nombre ya existe con otro id, no duplica (idempotencia por nombre).
INSERT INTO public.dance_categories (name, is_active) VALUES
  ('Salsa',            true),
  ('Bachata',          true),
  ('Reggaeton',        true),
  ('Hip Hop / Urbano', true),
  ('K-Pop',            true),
  ('Tango',            true),
  ('Ballet',           true),
  ('Contemporáneo',    true),
  ('Jazz',             true),
  ('Folklore',         true)
ON CONFLICT (name) DO NOTHING;
