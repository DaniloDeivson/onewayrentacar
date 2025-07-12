-- Fix fn_generate_damage_cost function - Remove direct NEW.tenant_id reference
-- This function was incorrectly trying to access NEW.tenant_id in inspection_items table

-- Drop the problematic trigger first
DROP TRIGGER IF EXISTS trg_generate_damage_cost ON inspection_items;

-- Fix the function to get tenant_id from inspections table instead of NEW.tenant_id
CREATE OR REPLACE FUNCTION public.fn_generate_damage_cost()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_vehicle_id uuid;
  v_contract_id uuid;
  v_customer_id uuid;
  v_tenant_id uuid;
BEGIN
  -- Get vehicle ID and tenant_id from inspection (NOT from NEW.tenant_id)
  SELECT vehicle_id, contract_id, customer_id, tenant_id 
  INTO v_vehicle_id, v_contract_id, v_customer_id, v_tenant_id 
  FROM inspections 
  WHERE id = NEW.inspection_id;
  
  -- Insert cost record with amount 0 (to be defined later)
  INSERT INTO costs (
    tenant_id,
    category,
    vehicle_id,
    description,
    amount,
    cost_date,
    status,
    origin,
    source_reference_id,
    source_reference_type,
    contract_id,
    customer_id,
    created_by_name
  ) VALUES (
    v_tenant_id, -- Use tenant_id from inspections table, not NEW.tenant_id
    'Funilaria',
    v_vehicle_id,
    'Danos identificados em inspeção: ' || NEW.description || ' (Severidade: ' || NEW.severity || ')',
    0, -- Valor 0 para orçamento a definir
    NOW()::date,
    'Pendente',
    'Patio',
    NEW.id,
    'inspection_item',
    v_contract_id,
    v_customer_id,
    'Sistema'
  );
  
  RETURN NEW;
END;
$function$;

-- Recreate the trigger
CREATE TRIGGER trg_generate_damage_cost
  AFTER INSERT ON inspection_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_generate_damage_cost();

-- Log the fix
DO $$
BEGIN
  RAISE NOTICE 'Fixed fn_generate_damage_cost - removed direct NEW.tenant_id reference';
END $$; 