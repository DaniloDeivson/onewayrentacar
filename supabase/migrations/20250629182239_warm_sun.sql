/*
  # Corrigir integração de custos para Check-In

  1. Modificações na Função de Criação de Custos
    - Permitir criação de custos tanto para Check-In quanto Check-Out
    - Diferenciar a origem e categoria baseado no tipo de inspeção
    - Ajustar descrições para refletir o tipo de inspeção

  2. Melhorias na Rastreabilidade
    - Melhor identificação da origem do custo
    - Descrições mais claras para Check-In vs Check-Out
    - Referências corretas aos itens de inspeção

  3. Correções na View de Custos
    - Garantir que todos os custos sejam exibidos corretamente
    - Melhor formatação das informações de origem
*/

BEGIN;

-- 1. Atualizar função para criar custos tanto para Check-In quanto Check-Out
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
  -- Get inspection details
  SELECT * INTO inspection_record
  FROM inspections
  WHERE id = NEW.inspection_id;
  
  -- Get vehicle details
  SELECT * INTO vehicle_record
  FROM vehicles
  WHERE id = inspection_record.vehicle_id;
  
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
        'Veículo: %s - %s. Inspetor: %s. Data da inspeção: %s. ' ||
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
      inspector_employee_id, -- Employee who created (inspector)
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
        'origin', 'Patio',
        'requires_repair', NEW.requires_repair
      ),
      'pending',
      NOW()
    );

    -- Log the automatic cost creation
    RAISE NOTICE 'CUSTO AUTOMÁTICO CRIADO: ID=%, Tipo=%, Veículo=%, Valor=A Definir', 
      new_cost_id, inspection_type_label, vehicle_record.plate;
      
    -- Also log to help with debugging
    RAISE LOG 'Damage cost created automatically: cost_id=%, inspection_type=%, inspection_item_id=%, vehicle_plate=%', 
      new_cost_id, inspection_record.inspection_type, NEW.id, vehicle_record.plate;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Recriar trigger para garantir que funcione
DROP TRIGGER IF EXISTS trg_inspection_items_auto_damage_cost ON inspection_items;
CREATE TRIGGER trg_inspection_items_auto_damage_cost
  AFTER INSERT ON inspection_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_create_damage_cost();

-- 3. Atualizar função de atualização de status do veículo
CREATE OR REPLACE FUNCTION fn_update_vehicle_status_on_inspection()
RETURNS TRIGGER AS $$
BEGIN
  -- For inspections table trigger
  IF TG_TABLE_NAME = 'inspections' THEN
    -- Check if there are any inspection items that require repair
    IF EXISTS (
      SELECT 1 FROM inspection_items 
      WHERE inspection_id = NEW.id 
      AND requires_repair = true
    ) THEN
      -- Update vehicle status based on inspection type
      IF NEW.inspection_type = 'CheckOut' THEN
        -- CheckOut with damages: vehicle goes to maintenance
        UPDATE vehicles 
        SET status = 'Manutenção', updated_at = now()
        WHERE id = NEW.vehicle_id;
      ELSIF NEW.inspection_type = 'CheckIn' THEN
        -- CheckIn with damages: vehicle is available but flagged for repair
        UPDATE vehicles 
        SET status = 'Disponível', updated_at = now()
        WHERE id = NEW.vehicle_id;
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  -- For inspection_items table trigger
  IF TG_TABLE_NAME = 'inspection_items' THEN
    DECLARE
      inspection_record RECORD;
    BEGIN
      SELECT * INTO inspection_record 
      FROM inspections 
      WHERE id = NEW.inspection_id;
      
      -- Update vehicle status if requires repair
      IF NEW.requires_repair = true THEN
        IF inspection_record.inspection_type = 'CheckOut' THEN
          -- CheckOut with damages: vehicle goes to maintenance
          UPDATE vehicles 
          SET status = 'Manutenção', updated_at = now()
          WHERE id = inspection_record.vehicle_id;
        ELSIF inspection_record.inspection_type = 'CheckIn' THEN
          -- CheckIn with damages: vehicle is available but flagged
          UPDATE vehicles 
          SET status = 'Disponível', updated_at = now()
          WHERE id = inspection_record.vehicle_id;
        END IF;
      END IF;
      
      RETURN NEW;
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Recriar triggers para status do veículo
DROP TRIGGER IF EXISTS trg_inspections_update_vehicle_status ON inspections;
CREATE TRIGGER trg_inspections_update_vehicle_status
  AFTER INSERT ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_status_on_inspection();

DROP TRIGGER IF EXISTS trg_inspections_update_vehicle_status ON inspection_items;
CREATE TRIGGER trg_inspections_update_vehicle_status
  AFTER INSERT ON inspection_items
  FOR EACH ROW
  WHEN (NEW.requires_repair = true)
  EXECUTE FUNCTION fn_update_vehicle_status_on_inspection();

-- 5. Atualizar função de reprocessamento para incluir Check-In
CREATE OR REPLACE FUNCTION fn_reprocess_inspection_costs(p_tenant_id UUID DEFAULT '00000000-0000-0000-0000-000000000001')
RETURNS INTEGER AS $$
DECLARE
  inspection_item RECORD;
  costs_created INTEGER := 0;
BEGIN
  -- Buscar itens de inspeção que requerem reparo mas não têm custo associado
  -- Agora incluindo tanto CheckIn quanto CheckOut
  FOR inspection_item IN
    SELECT 
      ii.*,
      i.inspection_type,
      i.tenant_id,
      i.vehicle_id,
      i.inspected_by,
      i.inspected_at,
      v.plate,
      v.model
    FROM inspection_items ii
    JOIN inspections i ON i.id = ii.inspection_id
    JOIN vehicles v ON v.id = i.vehicle_id
    WHERE i.tenant_id = p_tenant_id
      AND i.inspection_type IN ('CheckIn', 'CheckOut') -- Incluir ambos os tipos
      AND ii.requires_repair = true
      AND NOT EXISTS (
        SELECT 1 FROM costs c 
        WHERE c.source_reference_id = ii.id 
          AND c.source_reference_type = 'inspection_item'
      )
  LOOP
    -- Simular trigger para criar custo
    PERFORM fn_auto_create_damage_cost_manual(
      inspection_item.id,
      inspection_item.inspection_id,
      inspection_item.location,
      inspection_item.description,
      inspection_item.damage_type,
      inspection_item.severity,
      inspection_item.requires_repair,
      inspection_item.tenant_id,
      inspection_item.vehicle_id,
      inspection_item.inspected_by,
      inspection_item.inspected_at,
      inspection_item.plate,
      inspection_item.model,
      inspection_item.inspection_type -- Adicionar tipo de inspeção
    );
    
    costs_created := costs_created + 1;
  END LOOP;
  
  RETURN costs_created;
END;
$$ LANGUAGE plpgsql;

-- 6. Atualizar função auxiliar para incluir tipo de inspeção
CREATE OR REPLACE FUNCTION fn_auto_create_damage_cost_manual(
  p_item_id UUID,
  p_inspection_id UUID,
  p_location TEXT,
  p_description TEXT,
  p_damage_type TEXT,
  p_severity TEXT,
  p_requires_repair BOOLEAN,
  p_tenant_id UUID,
  p_vehicle_id UUID,
  p_inspected_by TEXT,
  p_inspected_at TIMESTAMPTZ,
  p_vehicle_plate TEXT,
  p_vehicle_model TEXT,
  p_inspection_type TEXT DEFAULT 'CheckOut'
)
RETURNS UUID AS $$
DECLARE
  inspector_employee_id UUID;
  new_cost_id UUID;
  cost_description TEXT;
  inspection_type_label TEXT;
BEGIN
  -- Try to find employee by name (inspector)
  SELECT id INTO inspector_employee_id
  FROM employees 
  WHERE LOWER(name) = LOWER(p_inspected_by)
    AND tenant_id = p_tenant_id
    AND active = true
  LIMIT 1;
  
  -- Set label based on inspection type
  IF p_inspection_type = 'CheckIn' THEN
    inspection_type_label := 'Check-In (Entrada)';
  ELSE
    inspection_type_label := 'Check-Out (Saída)';
  END IF;
  
  -- Create description for the cost
  cost_description := format(
    'Dano detectado em %s - %s: %s (%s)',
    inspection_type_label,
    p_location,
    p_damage_type,
    p_description
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
    document_ref,
    observations,
    origin,
    created_by_employee_id,
    source_reference_id,
    source_reference_type,
    created_at,
    updated_at
  ) VALUES (
    p_tenant_id,
    'Funilaria',
    p_vehicle_id,
    cost_description,
    0.00,
    CURRENT_DATE,
    'Pendente',
    format('PATIO-%s-%s-ITEM-%s', p_inspection_type, p_inspection_id, p_item_id),
    format(
      'Custo gerado automaticamente pelo controle de pátio (%s). ' ||
      'Veículo: %s - %s. Inspetor: %s. Data da inspeção: %s. ' ||
      'Severidade: %s. Local: %s. Tipo: %s. ' ||
      'Valor a ser definido após orçamento.',
      inspection_type_label,
      p_vehicle_plate,
      p_vehicle_model,
      p_inspected_by,
      p_inspected_at::date,
      p_severity,
      p_location,
      p_damage_type
    ),
    'Patio',
    inspector_employee_id,
    p_item_id,
    'inspection_item',
    NOW(),
    NOW()
  ) RETURNING id INTO new_cost_id;
  
  RETURN new_cost_id;
END;
$$ LANGUAGE plpgsql;

-- 7. Atualizar view de custos para melhor exibição do tipo de inspeção
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
    WHEN c.origin = 'Manutencao' THEN 'Manutenção'
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

-- 8. Função para debug específica para Check-In
CREATE OR REPLACE FUNCTION fn_debug_checkin_costs(p_tenant_id UUID DEFAULT '00000000-0000-0000-0000-000000000001')
RETURNS TABLE (
  inspection_id UUID,
  inspection_type TEXT,
  vehicle_plate TEXT,
  inspector TEXT,
  inspection_date TIMESTAMPTZ,
  damage_count BIGINT,
  cost_count BIGINT,
  missing_costs BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    i.id as inspection_id,
    i.inspection_type,
    v.plate as vehicle_plate,
    i.inspected_by as inspector,
    i.inspected_at as inspection_date,
    COUNT(ii.id) as damage_count,
    COUNT(c.id) as cost_count,
    COUNT(ii.id) FILTER (WHERE ii.requires_repair = true AND c.id IS NULL) as missing_costs
  FROM inspections i
  LEFT JOIN vehicles v ON v.id = i.vehicle_id
  LEFT JOIN inspection_items ii ON ii.inspection_id = i.id
  LEFT JOIN costs c ON c.source_reference_id = ii.id AND c.source_reference_type = 'inspection_item'
  WHERE i.tenant_id = p_tenant_id
    AND i.inspection_type = 'CheckIn'
  GROUP BY i.id, i.inspection_type, v.plate, i.inspected_by, i.inspected_at
  ORDER BY i.inspected_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;