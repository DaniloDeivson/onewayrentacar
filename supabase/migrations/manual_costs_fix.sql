-- EXECUTE THIS SQL DIRECTLY IN SUPABASE SQL EDITOR
-- This will fix the costs table to accept all new categories, origins, and status values

-- Add missing columns
ALTER TABLE public.costs 
  ADD COLUMN IF NOT EXISTS department text,
  ADD COLUMN IF NOT EXISTS customer_id text,
  ADD COLUMN IF NOT EXISTS customer_name text,
  ADD COLUMN IF NOT EXISTS contract_id text,
  ADD COLUMN IF NOT EXISTS source_reference_id text,
  ADD COLUMN IF NOT EXISTS source_reference_type text;

-- Remove existing constraints if they exist
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_category_check;
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_origin_check;
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_status_check;

-- Add new constraints to validate enum values
ALTER TABLE public.costs 
  ADD CONSTRAINT costs_category_check CHECK (category IN (
    'Multa', 'Funilaria', 'Seguro', 'Avulsa', 'Compra', 
    'Excesso Km', 'Diária Extra', 'Combustível', 'Avaria'
  ));

ALTER TABLE public.costs 
  ADD CONSTRAINT costs_origin_check CHECK (origin IN (
    'Manual', 'Patio', 'Manutencao', 'Sistema', 'Compras'
  ));

ALTER TABLE public.costs 
  ADD CONSTRAINT costs_status_check CHECK (status IN (
    'Pendente', 'Pago', 'Autorizado'
  ));

-- Update any existing records with incorrect status values
UPDATE public.costs 
SET status = 'Autorizado'
WHERE status IN ('Approved', 'Authorized');

-- Add comment for documentation
COMMENT ON TABLE public.costs IS 'Updated schema to support new categories, origins, and status values for comprehensive cost management';

-- Verify the changes
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'costs' AND table_schema = 'public'
ORDER BY ordinal_position; 