-- Remove 'Avaria' category from costs table constraint
-- This migration simplifies the category constraint by removing 'Avaria'
-- and keeping only 'Peças' for maintenance-related costs

BEGIN;

-- First, update any existing costs with 'Avaria' category to 'Peças'
UPDATE costs 
SET category = 'Peças'
WHERE category = 'Avaria';

-- Drop the existing constraint
ALTER TABLE costs DROP CONSTRAINT IF EXISTS costs_category_check;

-- Add the new constraint without 'Avaria'
ALTER TABLE costs ADD CONSTRAINT costs_category_check 
  CHECK (category = ANY (ARRAY['Multa'::text, 'Funilaria'::text, 'Seguro'::text, 'Avulsa'::text, 'Compra'::text, 'Excesso Km'::text, 'Diária Extra'::text, 'Combustível'::text, 'Peças'::text]));

-- Update the view to reflect the change
DROP VIEW IF EXISTS vw_costs_detailed;
CREATE VIEW vw_costs_detailed AS
SELECT 
  c.id,
  c.tenant_id,
  c.category,
  c.vehicle_id,
  v.plate as vehicle_plate,
  v.model as vehicle_model,
  c.description,
  c.amount,
  c.cost_date,
  c.status,
  c.document_ref,
  c.observations,
  c.origin,
  c.source_reference_type,
  c.source_reference_id,
  c.department,
  c.customer_id,
  c.customer_name,
  c.contract_id,
  COALESCE(e.name, 'Sistema') as created_by_name,
  COALESCE(e.role, 'Sistema') as created_by_role,
  e.employee_code as created_by_code,
  CASE 
    WHEN c.origin = 'Patio' THEN 
      CASE 
        WHEN c.document_ref LIKE '%CheckIn%' THEN 'Controle de Pátio (Check-In)'
        WHEN c.document_ref LIKE '%CheckOut%' THEN 'Controle de Pátio (Check-Out)'
        WHEN c.document_ref LIKE '%checkout%' THEN 'Controle de Pátio (Check-Out)'
        ELSE 'Controle de Pátio'
      END
    WHEN c.origin = 'Manutencao' THEN 
      CASE 
        WHEN c.category = 'Peças' THEN 'Manutenção (Peças)'
        WHEN c.document_ref LIKE '%OS%' THEN 'Manutenção (Ordem de Serviço)'
        ELSE 'Manutenção'
      END
    WHEN c.origin = 'Usuario' THEN 'Lançamento Manual'
    WHEN c.origin = 'Sistema' THEN 'Sistema'
    WHEN c.origin = 'Compras' THEN 'Compras'
    ELSE c.origin
  END as origin_description,
  CASE 
    WHEN c.amount = 0 AND c.status = 'Pendente' THEN true
    ELSE false
  END as is_amount_to_define,
  c.created_at,
  c.updated_at
FROM costs c
LEFT JOIN vehicles v ON v.id = c.vehicle_id
LEFT JOIN employees e ON e.id = c.created_by_employee_id
ORDER BY c.created_at DESC;

COMMIT;

-- Verify the changes
SELECT 
  'Categories after update:' as info,
  category,
  COUNT(*) as count
FROM costs 
GROUP BY category 
ORDER BY category; 