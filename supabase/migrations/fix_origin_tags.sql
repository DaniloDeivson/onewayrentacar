-- Fix origin tags for costs - standardize checkout to check-out
-- Update the view to display consistent origin descriptions

-- First, let's fix the view to standardize the origin descriptions
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

-- Update any document_ref that contains 'checkout' to 'CheckOut' for consistency
UPDATE costs 
SET document_ref = REPLACE(document_ref, 'checkout', 'CheckOut')
WHERE document_ref LIKE '%checkout%';

-- Update any descriptions that contain 'checkout' to 'check-out' for better readability
UPDATE costs 
SET description = REPLACE(description, 'checkout', 'check-out'),
    observations = REPLACE(observations, 'checkout', 'check-out')
WHERE description LIKE '%checkout%' OR observations LIKE '%checkout%';

-- Update inspection type labels in existing cost descriptions
UPDATE costs 
SET description = REPLACE(description, 'CheckOut', 'Check-Out'),
    observations = REPLACE(observations, 'CheckOut', 'Check-Out')
WHERE description LIKE '%CheckOut%' OR observations LIKE '%CheckOut%';

UPDATE costs 
SET description = REPLACE(description, 'CheckIn', 'Check-In'),
    observations = REPLACE(observations, 'CheckIn', 'Check-In')
WHERE description LIKE '%CheckIn%' OR observations LIKE '%CheckIn%';

-- Update the function that creates costs from damage items to use consistent naming
CREATE OR REPLACE FUNCTION fn_auto_create_damage_cost()
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
  
  -- Create costs for both CheckIn and CheckOut when damages require repair
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
      0.00, -- Amount to be defined
      inspection_record.inspected_at::date,
      'Pendente',
      CONCAT('INS-', inspection_record.inspection_type, '-', inspection_record.id),
      CONCAT(
        'Custo gerado automaticamente pela detecção de dano em ', inspection_type_label, '. ',
        'Inspetor: ', inspection_record.inspected_by, '. ',
        'Localização: ', NEW.location, '. ',
        'Tipo: ', NEW.damage_type, '. ',
        'Severidade: ', NEW.severity, '. ',
        'Descrição: ', NEW.description, '. ',
        'Veículo: ', vehicle_record.plate, ' - ', vehicle_record.model, '.',
        CASE WHEN customer_record.name IS NOT NULL THEN ' Cliente: ' || customer_record.name || '.' ELSE '' END
      ),
      'Patio',
      inspector_employee_id,
      NEW.id,
      'inspection_item',
      'Pátio',
      CASE WHEN inspection_record.contract_id IS NOT NULL THEN contract_record.customer_id ELSE NULL END,
      CASE WHEN inspection_record.contract_id IS NOT NULL THEN customer_record.name ELSE NULL END,
      inspection_record.contract_id,
      NOW(),
      NOW()
    ) RETURNING id INTO new_cost_id;

    -- Log the automatic cost creation
    RAISE NOTICE 'Custo de dano criado: ID=%, Tipo=%, Valor=A Definir', new_cost_id, inspection_type_label;

    -- Create notification for damage cost
    INSERT INTO damage_notifications (
      tenant_id,
      cost_id,
      item_id,
      notification_data,
      status,
      created_at
    ) VALUES (
      inspection_record.tenant_id,
      new_cost_id,
      NEW.id,
      jsonb_build_object(
        'cost_id', new_cost_id,
        'item_id', NEW.id,
        'inspection_id', NEW.inspection_id,
        'vehicle_plate', vehicle_record.plate,
        'vehicle_model', vehicle_record.model,
        'damage_location', NEW.location,
        'damage_type', NEW.damage_type,
        'severity', NEW.severity,
        'description', NEW.description,
        'requires_repair', NEW.requires_repair,
        'timestamp', NOW(),
        'customer_id', CASE WHEN inspection_record.contract_id IS NOT NULL THEN contract_record.customer_id ELSE NULL END,
        'customer_name', CASE WHEN inspection_record.contract_id IS NOT NULL THEN customer_record.name ELSE NULL END,
        'contract_id', inspection_record.contract_id
      ),
      'pending',
      NOW()
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Also update the trigger function to use consistent naming
CREATE OR REPLACE FUNCTION fn_auto_create_maintenance_cost()
RETURNS TRIGGER AS $$
DECLARE
  mechanic_employee_id UUID;
  new_cost_id UUID;
  cost_description TEXT;
  vehicle_plate TEXT;
BEGIN
  -- Only create cost when service note is completed
  IF NEW.status = 'Concluída' AND (OLD.status IS NULL OR OLD.status != 'Concluída') THEN
    
    -- Get vehicle plate
    SELECT plate INTO vehicle_plate
    FROM vehicles 
    WHERE id = NEW.vehicle_id;
    
    -- Try to find mechanic employee
    SELECT id INTO mechanic_employee_id
    FROM employees 
    WHERE name = NEW.mechanic 
      AND tenant_id = NEW.tenant_id
      AND active = true
    LIMIT 1;
    
    -- Create description
    cost_description := format(
      'Manutenção realizada - %s: %s',
      NEW.maintenance_type,
      NEW.description
    );
    
    -- Insert cost record
    INSERT INTO costs (
      tenant_id,
      category,
      vehicle_id,
      description,
      amount,
      cost_date,
      status,
      observations,
      origin,
      created_by_employee_id,
      source_reference_id,
      source_reference_type,
      created_at
    ) VALUES (
      NEW.tenant_id,
      'Avulsa', -- Maintenance costs as "Avulsa"
      NEW.vehicle_id,
      cost_description,
      0.00, -- Amount to be defined
      COALESCE(NEW.end_date::date, CURRENT_DATE),
      'Pendente',
      format(
        'Custo gerado automaticamente pela conclusão da ordem de serviço. ' ||
        'Mecânico: %s. Prioridade: %s. Quilometragem: %s km. ' ||
        'Valor a ser definido com base nos custos de mão de obra e peças utilizadas.',
        NEW.mechanic,
        NEW.priority,
        COALESCE(NEW.mileage::text, 'N/A')
      ),
      'Manutencao', -- Origin: Manutenção
      mechanic_employee_id, -- Employee who performed maintenance
      NEW.id, -- Reference to service note
      'service_note', -- Type of source reference
      NOW()
    ) RETURNING id INTO new_cost_id;

    -- Log the automatic cost creation
    RAISE NOTICE 'Custo de manutenção criado: ID=%, Origem=Manutenção, Responsável=%, Veículo=%', 
      new_cost_id, COALESCE(mechanic_employee_id::text, 'Sistema'), vehicle_plate;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT SELECT ON vw_costs_detailed TO authenticated;
GRANT SELECT ON vw_costs_detailed TO anon; 