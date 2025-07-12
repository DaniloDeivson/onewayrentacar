-- Script to add missing columns to fix 400 errors
-- Execute this in the Supabase SQL Editor

-- Add location column to inspections table
ALTER TABLE public.inspections 
ADD COLUMN IF NOT EXISTS location text NULL;

-- Add missing columns to inspections table (from migrations)
ALTER TABLE public.inspections 
ADD COLUMN IF NOT EXISTS mileage integer NULL;

ALTER TABLE public.inspections 
ADD COLUMN IF NOT EXISTS fuel_level numeric(3,2) NULL;

ALTER TABLE public.inspections 
ADD COLUMN IF NOT EXISTS contract_id uuid NULL;

ALTER TABLE public.inspections 
ADD COLUMN IF NOT EXISTS customer_id uuid NULL;

-- Add foreign key constraints
ALTER TABLE public.inspections 
ADD CONSTRAINT fk_inspections_contract_id 
FOREIGN KEY (contract_id) REFERENCES public.contracts(id);

ALTER TABLE public.inspections 
ADD CONSTRAINT fk_inspections_customer_id 
FOREIGN KEY (customer_id) REFERENCES public.customers(id);

-- Add missing columns to costs table
ALTER TABLE public.costs 
ADD COLUMN IF NOT EXISTS department text NULL;

ALTER TABLE public.costs 
ADD COLUMN IF NOT EXISTS customer_id uuid NULL;

ALTER TABLE public.costs 
ADD COLUMN IF NOT EXISTS customer_name text NULL;

ALTER TABLE public.costs 
ADD COLUMN IF NOT EXISTS contract_id uuid NULL;

-- Add foreign key constraints for costs
ALTER TABLE public.costs 
ADD CONSTRAINT fk_costs_customer_id 
FOREIGN KEY (customer_id) REFERENCES public.customers(id);

ALTER TABLE public.costs 
ADD CONSTRAINT fk_costs_contract_id 
FOREIGN KEY (contract_id) REFERENCES public.contracts(id);

-- Add missing columns to contracts table
ALTER TABLE public.contracts 
ADD COLUMN IF NOT EXISTS km_limit integer NULL;

ALTER TABLE public.contracts 
ADD COLUMN IF NOT EXISTS price_per_excess_km numeric(12,2) NULL;

ALTER TABLE public.contracts 
ADD COLUMN IF NOT EXISTS price_per_liter numeric(12,2) NULL;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_inspections_location ON public.inspections(location);
CREATE INDEX IF NOT EXISTS idx_inspections_contract ON public.inspections(contract_id);
CREATE INDEX IF NOT EXISTS idx_inspections_customer ON public.inspections(customer_id);
CREATE INDEX IF NOT EXISTS idx_costs_department ON public.costs(department);
CREATE INDEX IF NOT EXISTS idx_costs_customer ON public.costs(customer_id);
CREATE INDEX IF NOT EXISTS idx_costs_contract ON public.costs(contract_id);

-- Verify the columns were created
SELECT 'inspections' as table_name, column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'inspections' AND column_name IN ('location', 'mileage', 'fuel_level', 'contract_id', 'customer_id')
UNION ALL
SELECT 'costs' as table_name, column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'costs' AND column_name IN ('department', 'customer_id', 'customer_name', 'contract_id')
UNION ALL
SELECT 'contracts' as table_name, column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'contracts' AND column_name IN ('km_limit', 'price_per_excess_km', 'price_per_liter')
ORDER BY table_name, column_name; 