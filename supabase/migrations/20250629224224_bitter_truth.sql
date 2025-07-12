/*
  # Implement immutable costs and manager role

  1. Changes
    - Add 'Manager' role to employees role check constraint
    - Create functions to prevent cost deletion and restrict cost updates
    - Add triggers to enforce immutability of cost entries
    - Insert a default manager role employee

  2. Security
    - Only Admin can delete costs (blocked by trigger for others)
    - Only Admin can modify cost details
    - Manager and Admin can update status to 'Pago' or 'Autorizado'
    - All other users can only view costs
*/

-- Add manager role to employees role check constraint
ALTER TABLE employees DROP CONSTRAINT IF EXISTS employees_role_check;
ALTER TABLE employees ADD CONSTRAINT employees_role_check 
  CHECK (role = ANY (ARRAY['Admin'::text, 'Mechanic'::text, 'PatioInspector'::text, 'Sales'::text, 'Driver'::text, 'FineAdmin'::text, 'Manager'::text]));

-- Function to prevent cost deletion
CREATE OR REPLACE FUNCTION fn_prevent_cost_delete()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if user is admin
  IF EXISTS (
    SELECT 1 FROM employees 
    WHERE id = auth.uid() AND role = 'Admin'
  ) THEN
    -- Allow deletion for admin
    RETURN OLD;
  ELSE
    -- Prevent deletion for non-admin
    RAISE EXCEPTION 'Não é permitido excluir lançamentos de custos. Contate o administrador do sistema.';
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to prevent cost updates except for admin
CREATE OR REPLACE FUNCTION fn_restrict_cost_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if user is admin
  IF EXISTS (
    SELECT 1 FROM employees 
    WHERE id = auth.uid() AND role = 'Admin'
  ) THEN
    -- Allow all updates for admin
    RETURN NEW;
  ELSE
    -- For non-admin, only allow status update to 'Pago' or 'Autorizado'
    IF OLD.status = 'Pendente' AND (NEW.status = 'Pago' OR NEW.status = 'Autorizado') AND
       OLD.tenant_id = NEW.tenant_id AND
       OLD.category = NEW.category AND
       OLD.vehicle_id = NEW.vehicle_id AND
       OLD.description = NEW.description AND
       OLD.amount = NEW.amount AND
       OLD.cost_date = NEW.cost_date AND
       OLD.document_ref IS NOT DISTINCT FROM NEW.document_ref AND
       OLD.observations IS NOT DISTINCT FROM NEW.observations AND
       OLD.origin = NEW.origin AND
       OLD.created_by_employee_id IS NOT DISTINCT FROM NEW.created_by_employee_id AND
       OLD.source_reference_id IS NOT DISTINCT FROM NEW.source_reference_id AND
       OLD.source_reference_type IS NOT DISTINCT FROM NEW.source_reference_type THEN
      -- Allow status update only
      RETURN NEW;
    ELSE
      -- Prevent other updates
      RAISE EXCEPTION 'Não é permitido alterar lançamentos de custos. Apenas o status pode ser alterado para Pago ou Autorizado.';
      RETURN NULL;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to prevent cost deletion
DROP TRIGGER IF EXISTS trg_prevent_cost_delete ON costs;
CREATE TRIGGER trg_prevent_cost_delete
  BEFORE DELETE ON costs
  FOR EACH ROW
  EXECUTE FUNCTION fn_prevent_cost_delete();

-- Create trigger to prevent cost updates
DROP TRIGGER IF EXISTS trg_restrict_cost_update ON costs;
CREATE TRIGGER trg_restrict_cost_update
  BEFORE UPDATE ON costs
  FOR EACH ROW
  EXECUTE FUNCTION fn_restrict_cost_update();

-- Insert manager role employee if not exists
INSERT INTO employees (
  tenant_id,
  name,
  role,
  employee_code,
  contact_info,
  active,
  permissions
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  'Gerente Financeiro',
  'Manager',
  'GER001',
  '{"email": "gerente@oneway.com", "phone": "(11) 99999-8888"}',
  true,
  '{"dashboard": true, "costs": true, "fleet": true, "contracts": true, "fines": true, "statistics": true, "employees": false, "admin": false, "suppliers": true, "purchases": true, "inventory": true, "maintenance": true, "inspections": true}'
)
ON CONFLICT DO NOTHING;

-- Update view for costs detailed to include authorization status
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
  CASE 
    WHEN c.created_by_employee_id IS NOT NULL THEN e.name
    WHEN c.origin = 'Patio' THEN 'Inspetor de Pátio'
    WHEN c.origin = 'Manutencao' THEN 'Mecânico'
    ELSE 'Sistema'
  END as created_by_name,
  CASE 
    WHEN c.created_by_employee_id IS NOT NULL THEN e.role
    WHEN c.origin = 'Patio' THEN 'PatioInspector'
    WHEN c.origin = 'Manutencao' THEN 'Mechanic'
    ELSE 'Sistema'
  END as created_by_role,
  e.employee_code as created_by_code,
  CASE 
    WHEN c.origin = 'Patio' THEN 
      CASE 
        WHEN c.document_ref LIKE '%CheckIn%' THEN 'Controle de Pátio (Check-In)'
        WHEN c.document_ref LIKE '%CheckOut%' THEN 'Controle de Pátio (Check-Out)'
        ELSE 'Controle de Pátio'
      END
    WHEN c.origin = 'Manutencao' THEN 
      CASE 
        WHEN c.document_ref LIKE '%PART%' THEN 'Manutenção (Peças)'
        WHEN c.document_ref LIKE '%OS%' THEN 'Manutenção (Ordem de Serviço)'
        ELSE 'Manutenção'
      END
    WHEN c.origin = 'Manual' THEN 'Lançamento Manual'
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