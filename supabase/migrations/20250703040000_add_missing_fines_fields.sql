-- Add missing fields to fines table
-- Fields: severity and points (contract_id, customer_id, customer_name already exist)

-- Add severity field
ALTER TABLE public.fines 
ADD COLUMN IF NOT EXISTS severity TEXT;

-- Add points field  
ALTER TABLE public.fines 
ADD COLUMN IF NOT EXISTS points INTEGER DEFAULT 0;

-- Add check constraint for severity
ALTER TABLE public.fines 
DROP CONSTRAINT IF EXISTS fines_severity_check;

ALTER TABLE public.fines 
ADD CONSTRAINT fines_severity_check 
CHECK (severity IN ('Baixa', 'Média', 'Alta') OR severity IS NULL);

-- Add check constraint for points
ALTER TABLE public.fines 
DROP CONSTRAINT IF EXISTS fines_points_check;

ALTER TABLE public.fines 
ADD CONSTRAINT fines_points_check 
CHECK (points >= 0 OR points IS NULL);

-- Update existing records to have default values
UPDATE public.fines 
SET severity = 'Média', points = 0 
WHERE severity IS NULL OR points IS NULL; 