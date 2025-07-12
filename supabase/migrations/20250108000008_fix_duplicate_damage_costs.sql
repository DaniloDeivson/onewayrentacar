-- Fix duplicate damage costs issue
-- This migration ensures that only one trigger creates costs for inspection items

-- Drop all existing damage cost triggers to prevent duplicates
DROP TRIGGER IF EXISTS trg_inspection_items_auto_damage_cost ON inspection_items;
DROP TRIGGER IF EXISTS trg_generate_damage_cost ON inspection_items;

-- Drop all existing damage cost functions
DROP FUNCTION IF EXISTS fn_auto_create_damage_cost() CASCADE;
DROP FUNCTION IF EXISTS fn_generate_damage_cost() CASCADE;

-- Create a single, unified function for creating damage costs
CREATE OR REPLACE FUNCTION fn_create_damage_cost()
RETURNS TRIGGER AS $$
DECLARE
  inspection_record RECORD;
  vehicle_record RECORD;
  contract_record RECORD;
  customer_record RECORD;
  cost_description TEXT;
  inspector_employee_id UUID;
  new_cost_id UUID;
  cost_category TEXT;
  inspection_type_label TEXT;
BEGIN
  -- Get inspection details
  SELECT * INTO inspection_record
  FROM inspections
  WHERE id = NEW.inspection_id;
  
  -- Get vehicle details
  SELECT * INTO vehicle_record
  FROM vehicles
  WHERE id = inspection_record.vehicle_id;
  
  -- Get contract and customer details if available
  IF inspection_record.contract_id IS NOT NULL THEN
    SELECT * INTO contract_record
    FROM contracts
    WHERE id = inspection_record.contract_id;
    
    SELECT * INTO customer_record
    FROM customers
    WHERE id = contract_record.customer_id;
  END IF;
  
  -- Only create costs for damages that require repair
  IF NEW.requires_repair = true THEN
    
    -- Try to find employee by name (inspector)
    SELECT id INTO inspector_employee_id
    FROM employees 
    WHERE LOWER(name) = LOWER(inspection_record.inspected_by)
      AND tenant_id = inspection_record.tenant_id
      AND active = true
    LIMIT 1;
    
    -- Set category and labels based on inspection type
    IF inspection_record.inspection_type = 'CheckIn' THEN
      inspection_type_label := 'Check-In (Entrada)';
    ELSE
      inspection_type_label := 'Check-Out (Saída)';
    END IF;
    
    -- Create description for the cost
    cost_description := CONCAT(
      'Dano detectado em ', inspection_type_label, ' - ', NEW.location, ': ', NEW.damage_type,
      CASE WHEN customer_record.name IS NOT NULL THEN ' — Cliente: ' || customer_record.name ELSE '' END
    );
    
    -- Insert cost record with origin tracking and customer/contract info if available
    INSERT INTO costs (
      tenant_id,
      category,
      vehicle_id,
      description,
      amount,
      cost_date,
      status,
      document_ref,
      observations,
      origin,
      created_by_employee_id,
      source_reference_id,
      source_reference_type,
      department,
      customer_id,
      customer_name,
      contract_id,
      created_at,
      updated_at
    ) VALUES (
      inspection_record.tenant_id,
      'Funilaria',
      inspection_record.vehicle_id,
      cost_description,
      0.00, -- Amount to be defined later
      CURRENT_DATE,
      'Pendente',
      CONCAT('Inspeção ', inspection_record.inspection_type, ' - ', inspection_record.id),
      CONCAT(
        'Custo gerado automaticamente a partir da inspeção ', inspection_record.id, 
        '. Severidade: ', NEW.severity, ' | Tipo: ', NEW.damage_type, 
        ' | Requer reparo: ', CASE WHEN NEW.requires_repair THEN 'Sim' ELSE 'Não' END
      ),
      'Patio',
      inspector_employee_id,
      NEW.id,
      'inspection_item',
      'Patio',
      customer_record.id,
      customer_record.name,
      contract_record.id,
      NOW(),
      NOW()
    );
    
    -- Get the ID of the newly created cost
    SELECT id INTO new_cost_id FROM costs 
    WHERE source_reference_id = NEW.id 
    AND source_reference_type = 'inspection_item'
    ORDER BY created_at DESC LIMIT 1;
    
    -- Create damage notification record if cost was created successfully
    IF new_cost_id IS NOT NULL THEN
      INSERT INTO damage_notifications (
        tenant_id,
        cost_id,
        inspection_item_id,
        notification_data,
        status,
        created_at,
        updated_at
      ) VALUES (
        inspection_record.tenant_id,
        new_cost_id,
        NEW.id,
        jsonb_build_object(
          'vehicle_plate', vehicle_record.plate,
          'vehicle_model', vehicle_record.model,
          'damage_location', NEW.location,
          'damage_type', NEW.damage_type,
          'damage_description', NEW.description,
          'severity', NEW.severity,
          'inspection_date', inspection_record.inspected_at,
          'inspector', inspection_record.inspected_by,
          'inspection_type', inspection_record.inspection_type
        ),
        'pending',
        NOW(),
        NOW()
      );
    END IF;
  END IF;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Erro ao criar custo de dano: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a single trigger for creating damage costs
CREATE TRIGGER trg_create_damage_cost
  AFTER INSERT ON inspection_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_create_damage_cost();

-- Ensure vehicle mileage update trigger is working correctly
CREATE OR REPLACE FUNCTION fn_update_vehicle_mileage_on_inspection()
RETURNS TRIGGER AS $$
BEGIN
  -- Update vehicle mileage if inspection has mileage data
  IF NEW.mileage IS NOT NULL THEN
    UPDATE vehicles
    SET mileage = NEW.mileage,
        updated_at = NOW()
    WHERE id = NEW.vehicle_id
    AND (mileage IS NULL OR mileage < NEW.mileage);
  END IF;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Erro ao atualizar quilometragem do veículo: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Ensure the vehicle mileage update trigger exists
DROP TRIGGER IF EXISTS tr_update_vehicle_mileage_on_inspection ON inspections;
CREATE TRIGGER tr_update_vehicle_mileage_on_inspection
  AFTER INSERT OR UPDATE ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_mileage_on_inspection();

-- Mark duplicate costs as inactive instead of deleting them
-- This will mark costs that have the same source_reference_id and source_reference_type as duplicates
UPDATE costs 
SET status = 'Cancelado',
    observations = CONCAT(COALESCE(observations, ''), ' [DUPLICADO - Mantido apenas o primeiro registro]'),
    updated_at = NOW()
WHERE id NOT IN (
  SELECT id 
  FROM (
    SELECT id, 
           ROW_NUMBER() OVER (PARTITION BY source_reference_id, source_reference_type ORDER BY created_at) as rn
    FROM costs 
    WHERE source_reference_type = 'inspection_item'
  ) ranked_costs
  WHERE rn = 1
)
AND source_reference_type = 'inspection_item'
AND status != 'Cancelado';

-- Log the cleanup
DO $$
DECLARE
  updated_count INTEGER;
BEGIN
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE 'Marcados % custos duplicados como cancelados', updated_count;
END $$; 