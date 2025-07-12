-- Add 'Usuario' as a valid origin value for costs
-- This migration updates the origin check constraint to include 'Usuario'

BEGIN;

-- First, update any existing 'Manual' origins to 'Usuario' for consistency
UPDATE costs 
SET origin = 'Usuario' 
WHERE origin = 'Manual';

-- Drop the existing constraint
ALTER TABLE costs DROP CONSTRAINT IF EXISTS costs_origin_check;

-- Add the new constraint with 'Usuario' included
ALTER TABLE costs ADD CONSTRAINT costs_origin_check 
  CHECK (origin = ANY (ARRAY['Usuario'::text, 'Patio'::text, 'Manutencao'::text, 'Sistema'::text, 'Compras'::text]));

-- Update the view to handle the new 'Usuario' origin
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
        WHEN c.document_ref LIKE '%PART%' THEN 'Manutenção (Peças)'
        WHEN c.document_ref LIKE '%OS%' THEN 'Manutenção (Ordem de Serviço)'
        ELSE 'Manutenção'
      END
    WHEN c.origin = 'Usuario' THEN 'Usuário'
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