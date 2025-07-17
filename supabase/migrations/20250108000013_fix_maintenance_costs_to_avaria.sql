-- ============================================================================
-- CORREÇÃO: CUSTOS DE MANUTENÇÃO SEMPRE COMO "AVARIA"
-- ============================================================================
-- Data: 2025-01-08 00:00:13
-- Descrição: Garantir que todos os custos de manutenção sejam criados com categoria "Avaria"
-- independentemente do tipo de manutenção selecionado

-- ============================================================================
-- 1. CORRIGIR FUNÇÃO DE CUSTOS DE MANUTENÇÃO PRINCIPAL
-- ============================================================================

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
    
    -- Insert cost record with FIXED category "Avaria"
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
      'Avaria', -- CORRIGIDO: Sempre usar "Avaria" independente do tipo de manutenção
      NEW.vehicle_id,
      cost_description,
      0.00, -- Amount to be defined
      COALESCE(NEW.end_date::date, CURRENT_DATE),
      'Pendente',
      format(
        'Custo gerado automaticamente pela conclusão da ordem de serviço. ' ||
        'Tipo de Manutenção: %s. Mecânico: %s. Prioridade: %s. Quilometragem: %s km. ' ||
        'Valor a ser definido com base nos custos de mão de obra e peças utilizadas.',
        NEW.maintenance_type,
        NEW.mechanic,
        NEW.priority,
        COALESCE(NEW.mileage::text, 'N/A')
      ),
      'Manutencao', -- Origem: Manutenção
      mechanic_employee_id, -- Employee who performed maintenance
      NEW.id, -- Reference to service note
      'service_note', -- Type of source reference
      NOW()
    ) RETURNING id INTO new_cost_id;

    -- Log the automatic cost creation
    RAISE NOTICE 'Custo de manutenção criado: ID=%, Categoria=Avaria, Origem=Manutencao, Responsável=%, Veículo=%', 
      new_cost_id, COALESCE(mechanic_employee_id::text, 'Sistema'), vehicle_plate;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. CORRIGIR FUNÇÃO DE CUSTOS DE PEÇAS
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_create_parts_cost_once()
RETURNS TRIGGER AS $$
DECLARE
  service_note_record RECORD;
  vehicle_record RECORD;
  part_record RECORD;
  mechanic_employee_id UUID;
  new_cost_id UUID;
  cost_description TEXT;
  existing_cost_count INTEGER;
BEGIN
  -- Verificar se já existe custo para esta peça nesta ordem de serviço
  SELECT COUNT(*) INTO existing_cost_count
  FROM costs
  WHERE source_reference_id = NEW.id
    AND source_reference_type = 'service_order_part'
    AND tenant_id = NEW.tenant_id;
  
  -- Se já existe, não criar novamente
  IF existing_cost_count > 0 THEN
    RAISE NOTICE 'Custo já existe para service_order_part ID=%, pulando criação', NEW.id;
    RETURN NEW;
  END IF;
  
  -- Get service note details
  SELECT sn.*, e.id as mechanic_employee_id, e.name as mechanic_name
  INTO service_note_record
  FROM service_notes sn
  LEFT JOIN employees e ON e.name = sn.mechanic 
    AND e.tenant_id = sn.tenant_id 
    AND e.role = 'Mechanic'
    AND e.active = true
  WHERE sn.id = NEW.service_note_id;
  
  -- Get vehicle details
  SELECT * INTO vehicle_record
  FROM vehicles
  WHERE id = service_note_record.vehicle_id;
  
  -- Get part details
  SELECT * INTO part_record
  FROM parts
  WHERE id = NEW.part_id;
  
  -- Create description for the cost
  cost_description := format(
    'Peça utilizada: %s (Qtde: %s) - %s',
    part_record.name,
    NEW.quantity_used,
    service_note_record.description
  );
  
  -- Insert cost record for parts used with FIXED category "Avaria"
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
    NEW.tenant_id,
    'Avaria', -- CORRIGIDO: Sempre usar "Avaria" independente do tipo de manutenção
    service_note_record.vehicle_id,
    cost_description,
    NEW.total_cost, -- Use actual cost of parts
    COALESCE(service_note_record.end_date::date, CURRENT_DATE),
    'Pendente',
    format('OS-%s-PART-%s', service_note_record.id, NEW.id),
    format(
      'Custo gerado automaticamente pela utilização de peças em manutenção. ' ||
      'Tipo de Manutenção: %s. Ordem de Serviço: %s. Veículo: %s - %s. Mecânico: %s. ' ||
      'Peça: %s (SKU: %s). Quantidade: %s. Custo unitário: R$ %s.',
      service_note_record.maintenance_type,
      service_note_record.id,
      vehicle_record.plate,
      vehicle_record.model,
      service_note_record.mechanic,
      part_record.name,
      part_record.sku,
      NEW.quantity_used,
      NEW.unit_cost_at_time
    ),
    'Manutencao', -- Origem: Manutenção
    service_note_record.mechanic_employee_id, -- Mechanic who used the parts
    NEW.id, -- Reference to service order part
    'service_order_part', -- Type of source reference
    NOW(),
    NOW()
  ) RETURNING id INTO new_cost_id;

  -- Log the automatic cost creation
  RAISE NOTICE 'CUSTO DE PEÇAS CRIADO: ID=%, Categoria=Avaria, Origem=Manutencao, Mecânico=%, Valor=R$ %', 
    new_cost_id, service_note_record.mechanic, NEW.total_cost;
    
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 3. ATUALIZAR CUSTOS EXISTENTES DE MANUTENÇÃO
-- ============================================================================

-- Atualizar custos existentes de manutenção para usar categoria "Avaria"
UPDATE costs 
SET category = 'Avaria'
WHERE origin = 'Manutencao' 
  AND category IN ('Preventiva', 'Corretiva', 'Revisão', 'Troca de Óleo', 'Freios', 'Suspensão', 'Motor', 'Elétrica', 'Funilaria')
  AND source_reference_type IN ('service_note', 'service_order_part');

-- ============================================================================
-- 4. VERIFICAR SE OS TRIGGERS EXISTEM E RECRIÁ-LOS
-- ============================================================================

-- Trigger para custos de manutenção principal
DROP TRIGGER IF EXISTS trg_service_notes_auto_cost ON service_notes;
CREATE TRIGGER trg_service_notes_auto_cost
  AFTER UPDATE ON service_notes
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_create_maintenance_cost();

-- Trigger para custos de peças
DROP TRIGGER IF EXISTS trg_service_order_parts_cost_once ON service_order_parts;
CREATE TRIGGER trg_service_order_parts_cost_once
  AFTER INSERT ON service_order_parts
  FOR EACH ROW
  EXECUTE FUNCTION fn_create_parts_cost_once();

-- ============================================================================
-- 5. MENSAGEM DE CONFIRMAÇÃO
-- ============================================================================

SELECT 'Custos de manutenção corrigidos para sempre usar categoria "Avaria"' as message; 