-- CORREÇÃO: Categoria e responsável dos custos de manutenção
-- Data: 2025-01-08 00:00:09
-- Descrição: Corrigir categoria dos custos de manutenção para "Peças" e responsável correto

-- 1. Adicionar "Peças" como categoria válida
ALTER TABLE costs DROP CONSTRAINT IF EXISTS costs_category_check;
ALTER TABLE costs ADD CONSTRAINT costs_category_check 
  CHECK (category IN ('Multa', 'Funilaria', 'Seguro', 'Avulsa', 'Compra', 'Excesso Km', 'Diária Extra', 'Combustível', 'Avaria', 'Peças'));

-- 2. Atualizar custos existentes de manutenção para usar categoria "Peças"
UPDATE costs 
SET category = 'Peças'
WHERE origin = 'Manutencao' 
  AND category = 'Avulsa'
  AND (
    description LIKE '%Peça utilizada%' OR 
    observations LIKE '%peças%' OR
    document_ref LIKE 'OS-%PART-%'
  );

-- 3. Atualizar função que cria custos de peças para usar categoria "Peças"
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
  
  -- Insert cost record for parts used
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
    'Peças', -- CORRIGIDO: Parts costs as "Peças" (não mais "Avulsa")
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
    'Manutencao', -- Origin: Manutenção
    service_note_record.mechanic_employee_id, -- Mechanic who used the parts (responsável correto)
    NEW.id, -- Reference to service order part
    'service_order_part', -- Type of source reference
    NOW(),
    NOW()
  ) RETURNING id INTO new_cost_id;

  -- Log the automatic cost creation
  RAISE NOTICE 'CUSTO DE PEÇAS CRIADO: ID=%, Origem=Manutencao, Categoria=Peças, Mecânico=%, Valor=R$ %', 
    new_cost_id, service_note_record.mechanic, NEW.total_cost;
    
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Atualizar função de custos de manutenção para usar categoria "Peças"
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
      'Peças', -- CORRIGIDO: Maintenance costs as "Peças" (não mais "Avulsa")
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
      mechanic_employee_id, -- Employee who performed maintenance (responsável correto)
      NEW.id, -- Reference to service note
      'service_note', -- Type of source reference
      NOW()
    ) RETURNING id INTO new_cost_id;

    -- Log the automatic cost creation
    RAISE NOTICE 'Custo de manutenção criado: ID=%, Origem=Manutencao, Categoria=Peças, Responsável=%, Veículo=%', 
      new_cost_id, COALESCE(mechanic_employee_id::text, 'Sistema'), vehicle_plate;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Atualizar view de custos para mostrar categoria "Peças" corretamente
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
        ELSE 'Controle de Pátio'
      END
    WHEN c.origin = 'Manutencao' THEN 
      CASE 
        WHEN c.category = 'Peças' THEN 'Manutenção (Peças)'
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

-- 6. Atualizar custos existentes que têm "Sistema" como responsável mas deveriam ter o mecânico
UPDATE costs 
SET created_by_employee_id = (
  SELECT e.id 
  FROM employees e 
  WHERE e.name = (
    SELECT sn.mechanic 
    FROM service_notes sn 
    WHERE sn.id = costs.source_reference_id::uuid
  )
  AND e.tenant_id = costs.tenant_id
  AND e.active = true
  LIMIT 1
)
WHERE costs.origin = 'Manutencao' 
  AND costs.created_by_employee_id IS NULL
  AND costs.source_reference_type = 'service_note'
  AND costs.source_reference_id IS NOT NULL;

-- 7. Log das correções realizadas
DO $$
DECLARE
  updated_costs_count INTEGER;
  updated_responsible_count INTEGER;
BEGIN
  -- Contar custos atualizados para categoria "Peças"
  SELECT COUNT(*) INTO updated_costs_count
  FROM costs 
  WHERE origin = 'Manutencao' 
    AND category = 'Peças'
    AND updated_at >= NOW() - INTERVAL '1 minute';
  
  -- Contar custos com responsável corrigido
  SELECT COUNT(*) INTO updated_responsible_count
  FROM costs 
  WHERE origin = 'Manutencao' 
    AND created_by_employee_id IS NOT NULL
    AND updated_at >= NOW() - INTERVAL '1 minute';
  
  RAISE NOTICE 'Migração concluída: % custos atualizados para categoria "Peças", % com responsável corrigido', 
    updated_costs_count, updated_responsible_count;
END $$; 