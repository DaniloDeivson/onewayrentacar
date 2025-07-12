-- Migration to update costs table schema
-- Add missing enum values for category, origin, and status

-- First, check if we're using enums or text columns
DO $$ 
BEGIN
    -- For text-based columns (most likely case), we'll just ensure the table can accept all values
    
    -- Ensure all new columns exist
    ALTER TABLE public.costs 
      ADD COLUMN IF NOT EXISTS department text,
      ADD COLUMN IF NOT EXISTS customer_id text,
      ADD COLUMN IF NOT EXISTS customer_name text,
      ADD COLUMN IF NOT EXISTS contract_id text,
      ADD COLUMN IF NOT EXISTS source_reference_id text,
      ADD COLUMN IF NOT EXISTS source_reference_type text;
    
    -- Add check constraints to validate enum-like values
    ALTER TABLE public.costs 
      DROP CONSTRAINT IF EXISTS costs_category_check,
      ADD CONSTRAINT costs_category_check CHECK (category IN ('Multa', 'Funilaria', 'Seguro', 'Avulsa', 'Compra', 'Excesso Km', 'Diária Extra', 'Combustível', 'Avaria'));
    
    ALTER TABLE public.costs 
      DROP CONSTRAINT IF EXISTS costs_origin_check,
      ADD CONSTRAINT costs_origin_check CHECK (origin IN ('Manual', 'Patio', 'Manutencao', 'Sistema', 'Compras'));
    
    ALTER TABLE public.costs 
      DROP CONSTRAINT IF EXISTS costs_status_check,
      ADD CONSTRAINT costs_status_check CHECK (status IN ('Pendente', 'Pago', 'Autorizado'));
    
    -- Update existing costs with 'Autorizado' status where needed
    UPDATE public.costs 
    SET status = 'Autorizado'
    WHERE status = 'Approved' OR status = 'Authorized';
    
    -- Comment to document the migration
    COMMENT ON TABLE public.costs IS 'Updated schema to support new categories, origins, and status values for comprehensive cost management';
    
END $$; 