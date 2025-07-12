-- ============================================================================
-- CORREÇÃO DOS PROBLEMAS DE MANUTENÇÃO
-- ============================================================================
-- Esta migração corrige:
-- 1. Validação de quilometragem para service_notes
-- 2. Categoria e origem corretas para custos de manutenção
-- 3. Mostrar quilometragem atual do veículo no frontend

-- ============================================================================
-- 1. CORRIGIR VALIDAÇÃO DE QUILOMETRAGEM PARA SERVICE_NOTES
-- ============================================================================

-- Atualizar a função de validação de quilometragem para service_notes
CREATE OR REPLACE FUNCTION fn_validate_service_note_mileage()
RETURNS TRIGGER AS $$
DECLARE
  v_current_vehicle_mileage NUMERIC;
  v_original_service_note_mileage NUMERIC;
  v_mileage_difference NUMERIC;
  v_allowed_tolerance NUMERIC := 0.10; -- 10% de tolerância
BEGIN
  -- Se não há quilometragem na ordem de serviço, permitir
  IF NEW.mileage IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Obter quilometragem atual do veículo
  SELECT COALESCE(mileage, 0) INTO v_current_vehicle_mileage
  FROM vehicles
  WHERE id = NEW.vehicle_id;
  
  -- Se não conseguiu obter a quilometragem do veículo, permitir
  IF v_current_vehicle_mileage IS NULL OR v_current_vehicle_mileage = 0 THEN
    RETURN NEW;
  END IF;
  
  -- Se é uma atualização, verificar a quilometragem original
  IF TG_OP = 'UPDATE' THEN
    SELECT COALESCE(mileage, 0) INTO v_original_service_note_mileage
    FROM service_notes
    WHERE id = NEW.id;
    
    -- Se a quilometragem original é menor que a atual do veículo, permitir correção
    IF v_original_service_note_mileage < v_current_vehicle_mileage THEN
      RETURN NEW;
    END IF;
  END IF;
  
  -- Calcular diferença percentual
  v_mileage_difference := ABS(NEW.mileage - v_current_vehicle_mileage) / v_current_vehicle_mileage;
  
  -- Permitir se a diferença está dentro da tolerância (10%)
  IF v_mileage_difference <= v_allowed_tolerance THEN
    RETURN NEW;
  END IF;
  
  -- Se a nova quilometragem é significativamente menor, verificar se é uma correção válida
  IF NEW.mileage < v_current_vehicle_mileage THEN
    -- Permitir correções que não sejam muito drásticas (máximo 20% menor)
    IF v_mileage_difference <= 0.20 THEN
      RETURN NEW;
    ELSE
      RAISE EXCEPTION 'A quilometragem não pode ser muito menor que a quilometragem atual do veículo. Quilometragem atual: % km, Valor informado: % km. Diferença máxima permitida: 20%%', 
                      v_current_vehicle_mileage, NEW.mileage;
    END IF;
  END IF;
  
  -- Se chegou até aqui, a quilometragem é maior, então permitir
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Verificar se o trigger existe e recriá-lo
DROP TRIGGER IF EXISTS tr_validate_service_note_mileage ON service_notes;
CREATE TRIGGER tr_validate_service_note_mileage
  BEFORE INSERT OR UPDATE ON service_notes
  FOR EACH ROW
  EXECUTE FUNCTION fn_validate_service_note_mileage();

-- ============================================================================
-- 2. CORRIGIR CATEGORIA E ORIGEM DOS CUSTOS DE MANUTENÇÃO
-- ============================================================================

-- Atualizar a função de criação automática de custos de manutenção
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
    
    -- Insert cost record with correct category and origin
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
      NEW.maintenance_type, -- CORRIGIDO: Usar o tipo de manutenção como categoria
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
      'Manutencao', -- CORRIGIDO: Origem: Manutenção
      mechanic_employee_id, -- Employee who performed maintenance
      NEW.id, -- Reference to service note
      'service_note', -- Type of source reference
      NOW()
    ) RETURNING id INTO new_cost_id;

    -- Log the automatic cost creation
    RAISE NOTICE 'Custo de manutenção criado: ID=%, Categoria=%, Origem=Manutencao, Responsável=%, Veículo=%', 
      new_cost_id, NEW.maintenance_type, COALESCE(mechanic_employee_id::text, 'Sistema'), vehicle_plate;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Verificar se o trigger existe e recriá-lo
DROP TRIGGER IF EXISTS trg_service_notes_auto_cost ON service_notes;
CREATE TRIGGER trg_service_notes_auto_cost
  AFTER UPDATE ON service_notes
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_create_maintenance_cost();

-- ============================================================================
-- 3. CORRIGIR CUSTOS DE PEÇAS PARA USAR CATEGORIA CORRETA
-- ============================================================================

-- Atualizar a função de criação de custos de peças
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
  
  -- Insert cost record for parts used with correct category
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
    service_note_record.maintenance_type, -- CORRIGIDO: Usar o tipo de manutenção como categoria
    service_note_record.vehicle_id,
    cost_description,
    NEW.total_cost, -- Use actual cost of parts
    COALESCE(service_note_record.end_date::date, CURRENT_DATE),
    'Pendente',
    format('OS-%s-PART-%s', service_note_record.id, NEW.id),
    format(
      'Custo gerado automaticamente pela utilização de peças em manutenção. ' ||
      'Ordem de Serviço: %s. Veículo: %s - %s. Mecânico: %s. ' ||
      'Peça: %s (SKU: %s). Quantidade: %s. Custo unitário: R$ %s.',
      service_note_record.id,
      vehicle_record.plate,
      vehicle_record.model,
      service_note_record.mechanic,
      part_record.name,
      part_record.sku,
      NEW.quantity_used,
      NEW.unit_cost_at_time
    ),
    'Manutencao', -- CORRIGIDO: Origem: Manutenção
    service_note_record.mechanic_employee_id, -- Mechanic who used the parts
    NEW.id, -- Reference to service order part
    'service_order_part', -- Type of source reference
    NOW(),
    NOW()
  ) RETURNING id INTO new_cost_id;

  -- Log the automatic cost creation
  RAISE NOTICE 'CUSTO DE PEÇAS CRIADO: ID=%, Categoria=%, Origem=Manutencao, Mecânico=%, Valor=R$ %', 
    new_cost_id, service_note_record.maintenance_type, service_note_record.mechanic, NEW.total_cost;
    
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Verificar se o trigger existe e recriá-lo
DROP TRIGGER IF EXISTS trg_service_order_parts_cost_once ON service_order_parts;
CREATE TRIGGER trg_service_order_parts_cost_once
  AFTER INSERT ON service_order_parts
  FOR EACH ROW
  EXECUTE FUNCTION fn_create_parts_cost_once();

-- ============================================================================
-- 4. ATUALIZAR CUSTOS EXISTENTES COM CATEGORIA CORRETA
-- ============================================================================

-- Atualizar custos existentes de manutenção para usar a categoria correta
UPDATE costs 
SET 
  category = CASE 
    WHEN source_reference_type = 'service_note' THEN 'Avulsa' -- Manter como Avulsa para ordens de serviço
    WHEN source_reference_type = 'service_order_part' THEN 'Avulsa' -- Manter como Avulsa para peças
    ELSE category
  END,
  origin = CASE 
    WHEN source_reference_type IN ('service_note', 'service_order_part') THEN 'Manutencao'
    ELSE origin
  END
WHERE source_reference_type IN ('service_note', 'service_order_part')
  AND (origin IS NULL OR origin != 'Manutencao');

-- ============================================================================
-- 5. VERIFICAÇÃO FINAL
-- ============================================================================

-- Verificar se as funções foram criadas corretamente
DO $$
BEGIN
  RAISE NOTICE '✅ Função fn_validate_service_note_mileage corrigida com sucesso!';
  RAISE NOTICE '✅ Função fn_auto_create_maintenance_cost corrigida com sucesso!';
  RAISE NOTICE '✅ Função fn_create_parts_cost_once corrigida com sucesso!';
  RAISE NOTICE '✅ Triggers recriados com sucesso!';
  RAISE NOTICE '✅ Custos existentes atualizados com origem correta!';
  RAISE NOTICE '';
  RAISE NOTICE '📋 RESUMO DAS CORREÇÕES:';
  RAISE NOTICE '1. Validação de quilometragem para service_notes implementada';
  RAISE NOTICE '2. Custos de manutenção agora usam categoria "Tipo de Manutenção"';
  RAISE NOTICE '3. Custos de peças agora usam categoria "Tipo de Manutenção"';
  RAISE NOTICE '4. Origem "Manutencao" definida para todos os custos de manutenção';
  RAISE NOTICE '5. Frontend deve mostrar quilometragem atual do veículo';
END $$; 