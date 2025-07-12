/*
  # Corrigir custos de peças de manutenção e responsáveis

  1. Função para criar custos de peças utilizadas em manutenção
  2. Atualizar função de custos de danos para usar funcionário correto
  3. Trigger para peças utilizadas em ordens de serviço
  4. Correção de responsáveis por tipo de custo
*/

BEGIN;

-- 1. Função para criar custo de peças utilizadas em manutenção
CREATE OR REPLACE FUNCTION fn_auto_create_parts_cost()
RETURNS TRIGGER AS $$
DECLARE
  service_note_record RECORD;
  vehicle_record RECORD;
  part_record RECORD;
  mechanic_employee_id UUID;
  new_cost_id UUID;
  cost_description TEXT;
BEGIN
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
    'Avulsa', -- Parts costs as "Avulsa"
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
    service_note_record.mechanic_employee_id, -- Mechanic who used the parts
    NEW.id, -- Reference to service order part
    'service_note', -- Type of source reference
    NOW(),
    NOW()
  ) RETURNING id INTO new_cost_id;

  -- Log the automatic cost creation
  RAISE NOTICE 'CUSTO DE PEÇAS CRIADO: ID=%, Origem=Manutencao, Mecânico=%, Valor=R$ %', 
    new_cost_id, service_note_record.mechanic, NEW.total_cost;
    
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Criar trigger para custos de peças
DROP TRIGGER IF EXISTS trg_service_order_parts_auto_cost ON service_order_parts;
CREATE TRIGGER trg_service_order_parts_auto_cost
  AFTER INSERT ON service_order_parts
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_create_parts_cost();

-- 3. Atualizar função de custos de danos para usar funcionário correto
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

-- 4. Recriar trigger para custos de danos
DROP TRIGGER IF EXISTS trg_inspection_items_auto_damage_cost ON inspection_items;
CREATE TRIGGER trg_inspection_items_auto_damage_cost
  AFTER INSERT ON inspection_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_create_damage_cost();

-- 5. Atualizar view de custos para melhor identificação de responsáveis
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

-- 6. Função para debug de custos de manutenção
CREATE OR REPLACE FUNCTION fn_debug_maintenance_costs(p_tenant_id UUID DEFAULT '00000000-0000-0000-0000-000000000001')
RETURNS TABLE (
  service_note_id UUID,
  vehicle_plate TEXT,
  mechanic TEXT,
  parts_used BIGINT,
  parts_cost_total NUMERIC,
  cost_records BIGINT,
  missing_costs BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sn.id as service_note_id,
    v.plate as vehicle_plate,
    sn.mechanic,
    COUNT(sop.id) as parts_used,
    COALESCE(SUM(sop.total_cost), 0) as parts_cost_total,
    COUNT(c.id) as cost_records,
    COUNT(sop.id) FILTER (WHERE c.id IS NULL) as missing_costs
  FROM service_notes sn
  LEFT JOIN vehicles v ON v.id = sn.vehicle_id
  LEFT JOIN service_order_parts sop ON sop.service_note_id = sn.id
  LEFT JOIN costs c ON c.source_reference_id = sop.id AND c.source_reference_type = 'service_note'
  WHERE sn.tenant_id = p_tenant_id
    AND sn.status = 'Concluída'
  GROUP BY sn.id, v.plate, sn.mechanic
  HAVING COUNT(sop.id) > 0
  ORDER BY sn.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 7. Atualizar custos existentes de peças para ter origem correta
UPDATE costs 
SET 
  origin = 'Manutencao',
  source_reference_type = 'service_note'
WHERE origin = 'Manual' 
  AND category = 'Avulsa' 
  AND (
    description LIKE '%Peça utilizada%' OR 
    observations LIKE '%peças%' OR
    document_ref LIKE 'OS-%'
  );

-- 8. Função para reprocessar custos de peças de manutenção
CREATE OR REPLACE FUNCTION fn_reprocess_parts_costs(p_tenant_id UUID DEFAULT '00000000-0000-0000-0000-000000000001')
RETURNS INTEGER AS $$
DECLARE
  parts_record RECORD;
  costs_created INTEGER := 0;
BEGIN
  -- Buscar peças utilizadas que não têm custo associado
  FOR parts_record IN
    SELECT 
      sop.*,
      sn.vehicle_id,
      sn.mechanic,
      sn.description as service_description,
      sn.end_date,
      v.plate,
      v.model,
      p.name as part_name,
      p.sku as part_sku
    FROM service_order_parts sop
    JOIN service_notes sn ON sn.id = sop.service_note_id
    JOIN vehicles v ON v.id = sn.vehicle_id
    JOIN parts p ON p.id = sop.part_id
    WHERE sop.tenant_id = p_tenant_id
      AND NOT EXISTS (
        SELECT 1 FROM costs c 
        WHERE c.source_reference_id = sop.id 
          AND c.source_reference_type = 'service_note'
          AND c.origin = 'Manutencao'
      )
  LOOP
    -- Criar custo para a peça
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
      source_reference_id,
      source_reference_type,
      created_at,
      updated_at
    ) VALUES (
      p_tenant_id,
      'Avulsa',
      parts_record.vehicle_id,
      format('Peça utilizada: %s (Qtde: %s) - %s', parts_record.part_name, parts_record.quantity_used, parts_record.service_description),
      parts_record.total_cost,
      COALESCE(parts_record.end_date::date, CURRENT_DATE),
      'Pendente',
      format('OS-%s-PART-%s', parts_record.service_note_id, parts_record.id),
      format(
        'Custo gerado automaticamente pela utilização de peças em manutenção. ' ||
        'Veículo: %s - %s. Mecânico: %s. Peça: %s (SKU: %s). Quantidade: %s.',
        parts_record.plate,
        parts_record.model,
        parts_record.mechanic,
        parts_record.part_name,
        parts_record.part_sku,
        parts_record.quantity_used
      ),
      'Manutencao',
      parts_record.id,
      'service_note',
      NOW(),
      NOW()
    );
    
    costs_created := costs_created + 1;
  END LOOP;
  
  RETURN costs_created;
END;
$$ LANGUAGE plpgsql;

COMMIT;