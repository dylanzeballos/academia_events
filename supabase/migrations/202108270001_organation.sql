-- 1. Eliminar la relación obsoleta con cities
ALTER TABLE public.organizations
  DROP CONSTRAINT IF EXISTS organizations_city_id_fkey,
  DROP COLUMN IF EXISTS city_id;

-- 2. Agregar portada/banner y jerarquía geográfica completa con coordenadas
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS cover_image_url text,
  ADD COLUMN IF NOT EXISTS department_id uuid REFERENCES public.departments(id),
  ADD COLUMN IF NOT EXISTS province_id uuid REFERENCES public.provinces(id),
  ADD COLUMN IF NOT EXISTS municipality_id uuid REFERENCES public.municipalities(id),
  ADD COLUMN IF NOT EXISTS location_name character varying,
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS latitude numeric CHECK (latitude IS NULL OR (latitude >= -90 AND latitude <= 90)),
  ADD COLUMN IF NOT EXISTS longitude numeric CHECK (longitude IS NULL OR (longitude >= -180 AND longitude <= 180));

-- 3. Índices de rendimiento para filtros rápidos
CREATE INDEX IF NOT EXISTS idx_organizations_department_id ON public.organizations(department_id);
CREATE INDEX IF NOT EXISTS idx_organizations_municipality_id ON public.organizations(municipality_id);