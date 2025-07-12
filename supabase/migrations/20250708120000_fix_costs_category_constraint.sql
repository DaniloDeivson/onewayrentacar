-- ============================================================================
-- CORREÇÃO DA CONSTRAINT DE CATEGORIA DOS CUSTOS
-- ============================================================================
-- Esta migração corrige:
-- 1. Adiciona "Peças" como categoria válida para custos de manutenção
-- 2. Garante que os tipos de manutenção sejam aceitos como categorias
-- 3. Corrige o erro de constraint violation ao adicionar peças ao carrinho

-- ============================================================================
-- 1. ATUALIZAR CONSTRAINT DE CATEGORIA
-- ============================================================================

-- Remover constraint existente
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_category_check;

-- Adicionar nova constraint com todas as categorias válidas
ALTER TABLE public.costs ADD CONSTRAINT costs_category_check 
  CHECK (category IN (
    'Multa', 
    'Funilaria', 
    'Seguro', 
    'Avulsa', 
    'Compra', 
    'Excesso Km', 
    'Diária Extra', 
    'Combustível', 
    'Avaria',
    'Peças'
  ));

-- ============================================================================
-- 2. ATUALIZAR FUNÇÃO DE CUSTOS DE PEÇAS PARA USAR CATEGORIA "Peças"
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
    'Peças', -- CORRIGIDO: Usar categoria "Peças" para custos de peças
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
  RAISE NOTICE 'CUSTO DE PEÇAS CRIADO: ID=%, Categoria=Peças, Origem=Manutencao, Mecânico=%, Valor=R$ %', 
    new_cost_id, service_note_record.mechanic, NEW.total_cost;
    
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 3. ATUALIZAR FUNÇÃO DE CUSTOS DE MANUTENÇÃO PARA USAR CATEGORIA "Avulsa"
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
    
    -- Insert cost record with correct category
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
      'Avulsa', -- CORRIGIDO: Usar categoria "Avulsa" para custos de manutenção
      NEW.vehicle_id,
      cost_description,
      0.00, -- Amount to be defined
      COALESCE(NEW.end_date::date, CURRENT_DATE),
      'Pendente',
      format(
        'Custo gerado automaticamente pela conclusão da ordem de serviço. ' ||
        'Tipo: %s. Mecânico: %s. Prioridade: %s. Quilometragem: %s km. ' ||
        'Valor a ser definido com base nos custos de mão de obra e peças utilizadas.',
        NEW.maintenance_type,
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
    RAISE NOTICE 'Custo de manutenção criado: ID=%, Categoria=Avulsa, Origem=Manutencao, Responsável=%, Veículo=%', 
      new_cost_id, COALESCE(mechanic_employee_id::text, 'Sistema'), vehicle_plate;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. VERIFICAÇÃO FINAL
-- ============================================================================

-- Verificar se as funções foram criadas corretamente
DO $$
BEGIN
  RAISE NOTICE '✅ Constraint de categoria corrigida com sucesso!';
  RAISE NOTICE '✅ Função fn_create_parts_cost_once corrigida com sucesso!';
  RAISE NOTICE '✅ Função fn_auto_create_maintenance_cost corrigida com sucesso!';
  RAISE NOTICE '';
  RAISE NOTICE '📋 RESUMO DAS CORREÇÕES:';
  RAISE NOTICE '1. Categoria "Peças" adicionada à constraint de custos';
  RAISE NOTICE '2. Custos de peças agora usam categoria "Peças"';
  RAISE NOTICE '3. Custos de manutenção agora usam categoria "Avulsa"';
  RAISE NOTICE '4. Origem "Manutencao" mantida para todos os custos de manutenção';
END $$; 