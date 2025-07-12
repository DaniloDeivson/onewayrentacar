-- Fix inspection_items triggers - Disable all problematic triggers and recreate only working ones
-- This migration ensures that no trigger tries to access tenant_id directly in inspection_items

-- 1. Disable ALL triggers on inspection_items temporarily
DROP TRIGGER IF EXISTS trg_inspection_items_auto_service_order ON inspection_items;
DROP TRIGGER IF EXISTS trg_inspection_items_auto_damage_cost ON inspection_items;

-- 2. Recreate only the working trigger for auto service order (this one is correct)
CREATE OR REPLACE FUNCTION fn_auto_create_damage_service_order()
RETURNS TRIGGER AS $$
DECLARE
  v_inspection_record RECORD;
  v_service_note_id uuid;
  v_maintenance_type_id uuid;
BEGIN
  -- Só cria OS para CheckOut com danos que requerem reparo
  IF NEW.requires_repair = false THEN
    RETURN NEW;
  END IF;

  -- Busca informações da inspeção (incluindo tenant_id da tabela inspections)
  SELECT i.*, v.plate, v.model
  INTO v_inspection_record
  FROM inspections i
  JOIN vehicles v ON v.id = i.vehicle_id
  WHERE i.id = NEW.inspection_id;

  -- Só processa CheckOut (danos novos)
  IF v_inspection_record.inspection_type != 'CheckOut' THEN
    RETURN NEW;
  END IF;

  -- Busca ou cria tipo de manutenção "Funilaria"
  SELECT id INTO v_maintenance_type_id
  FROM maintenance_types
  WHERE tenant_id = v_inspection_record.tenant_id
    AND name = 'Funilaria'
  LIMIT 1;

  -- Se não existe, cria o tipo de manutenção
  IF v_maintenance_type_id IS NULL THEN
    INSERT INTO maintenance_types (tenant_id, name)
    VALUES (v_inspection_record.tenant_id, 'Funilaria')
    RETURNING id INTO v_maintenance_type_id;
  END IF;

  -- Cria ordem de serviço automaticamente
  INSERT INTO service_notes (
    tenant_id,
    vehicle_id,
    maintenance_type,
    start_date,
    mechanic,
    priority,
    description,
    observations,
    status,
    created_at
  )
  VALUES (
    v_inspection_record.tenant_id,
    v_inspection_record.vehicle_id,
    'Funilaria',
    CURRENT_DATE,
    'A definir', -- Será atribuído posteriormente
    CASE 
      WHEN NEW.severity = 'Alta' THEN 'Alta'
      WHEN NEW.severity = 'Média' THEN 'Média'
      ELSE 'Baixa'
    END,
    CONCAT('Reparo de dano detectado em inspeção - ', NEW.location, ': ', NEW.damage_type),
    CONCAT('Dano detectado em ', v_inspection_record.inspected_at::date, ' por ', v_inspection_record.inspected_by, '. Descrição: ', NEW.description),
    'Aberta',
    now()
  )
  RETURNING id INTO v_service_note_id;

  -- Cria custo estimado se fornecido
  IF NEW.cost_estimate IS NOT NULL AND NEW.cost_estimate > 0 THEN
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
      created_at
    )
    VALUES (
      v_inspection_record.tenant_id,
      'Funilaria',
      v_inspection_record.vehicle_id,
      CONCAT('Estimativa de reparo - ', NEW.location, ' (', NEW.damage_type, ')'),
      NEW.cost_estimate,
      CURRENT_DATE,
      'Pendente',
      CONCAT('INSP-', NEW.inspection_id, '-OS-', v_service_note_id),
      CONCAT('Custo estimado baseado em inspeção. Severidade: ', NEW.severity),
      now()
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger for auto service order
CREATE TRIGGER trg_inspection_items_auto_service_order
  AFTER INSERT ON inspection_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_create_damage_service_order();

-- 3. Recreate the working damage cost trigger (this one is also correct)
CREATE OR REPLACE FUNCTION fn_auto_create_damage_cost()
RETURNS TRIGGER AS $$
DECLARE
  inspection_record RECORD;
  vehicle_record RECORD;
  cost_description TEXT;
  cost_category TEXT;
  inspector_employee_id UUID;
  new_cost_id UUID;
  inspection_type_label TEXT;
BEGIN
  -- Get inspection details with employee lookup
  SELECT i.*, e.id as inspector_employee_id, e.name as inspector_name
  INTO inspection_record
  FROM inspections i
  LEFT JOIN employees e ON LOWER(e.name) = LOWER(i.inspected_by)
    AND e.tenant_id = i.tenant_id
    AND e.role = 'PatioInspector'
    AND e.active = true
  WHERE i.id = NEW.inspection_id;
  
  -- Get vehicle details
  SELECT * INTO vehicle_record
  FROM vehicles
  WHERE id = inspection_record.vehicle_id;
  
  -- Create costs for both CheckIn and CheckOut when damages require repair
  IF NEW.requires_repair = true THEN
    
    -- Set category and labels based on inspection type
    IF inspection_record.inspection_type = 'CheckIn' THEN
      cost_category := 'Funilaria';
      inspection_type_label := 'Check-In (Entrada)';
    ELSE
      cost_category := 'Funilaria';
      inspection_type_label := 'Check-Out (Saída)';
    END IF;
    
    -- Create description for the cost
    cost_description := format(
      'Dano detectado em %s - %s: %s (%s)',
      inspection_type_label,
      NEW.location,
      NEW.damage_type,
      NEW.description
    );
    
    -- Insert cost record with origin tracking
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
      created_at,
      updated_at
    ) VALUES (
      inspection_record.tenant_id,
      cost_category,
      inspection_record.vehicle_id,
      cost_description,
      0.00, -- Amount to be defined later (will show as "A Definir")
      CURRENT_DATE,
      'Pendente',
      format('PATIO-%s-%s-ITEM-%s', inspection_record.inspection_type, inspection_record.id, NEW.id),
      format(
        'Custo gerado automaticamente pelo controle de pátio (%s). ' ||
        'Veículo: %s - %s. Inspetor responsável: %s. Data da inspeção: %s. ' ||
        'Severidade: %s. Local: %s. Tipo: %s. ' ||
        'Descrição: %s. ' ||
        'Valor a ser definido após orçamento.',
        inspection_type_label,
        vehicle_record.plate,
        vehicle_record.model,
        inspection_record.inspected_by,
        inspection_record.inspected_at::date,
        NEW.severity,
        NEW.location,
        NEW.damage_type,
        NEW.description
      ),
      'Patio', -- Origin: Patio (controle de pátio)
      inspection_record.inspector_employee_id, -- Inspector who found the damage
      NEW.id, -- Reference to inspection item
      'inspection_item', -- Type of source reference
      NOW(),
      NOW()
    ) RETURNING id INTO new_cost_id;
    
    -- Create damage notification record
    INSERT INTO damage_notifications (
      tenant_id,
      cost_id,
      inspection_item_id,
      notification_data,
      status,
      created_at
    ) VALUES (
      inspection_record.tenant_id,
      new_cost_id,
      NEW.id,
      jsonb_build_object(
        'cost_id', new_cost_id,
        'vehicle_plate', vehicle_record.plate,
        'vehicle_model', vehicle_record.model,
        'damage_location', NEW.location,
        'damage_type', NEW.damage_type,
        'damage_description', NEW.description,
        'severity', NEW.severity,
        'inspection_type', inspection_record.inspection_type,
        'inspection_type_label', inspection_type_label,
        'inspection_date', inspection_record.inspected_at,
        'inspector', inspection_record.inspected_by,
        'inspector_employee_id', inspection_record.inspector_employee_id,
        'origin', 'Patio',
        'requires_repair', NEW.requires_repair
      ),
      'pending',
      NOW()
    );

    -- Log the automatic cost creation
    RAISE NOTICE 'CUSTO DE DANO CRIADO: ID=%, Tipo=%, Inspetor=%, Veículo=%, Valor=A Definir', 
      new_cost_id, inspection_type_label, inspection_record.inspected_by, vehicle_record.plate;
      
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger for auto damage cost
CREATE TRIGGER trg_inspection_items_auto_damage_cost
  AFTER INSERT ON inspection_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_create_damage_cost();

-- 4. Add a comment to prevent future issues
COMMENT ON TABLE inspection_items IS 'Table for inspection items. IMPORTANT: This table does NOT have tenant_id field. Always join with inspections table to check tenant_id.';

-- 5. Log the fix
DO $$
BEGIN
  RAISE NOTICE 'Fixed inspection_items triggers - removed any direct tenant_id references';
END $$; 