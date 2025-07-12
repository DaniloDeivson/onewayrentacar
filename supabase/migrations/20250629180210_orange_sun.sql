/*
  # Corrigir integração entre danos do pátio e custos

  1. Correções na função de criação automática de custos
    - Garantir que custos sejam criados corretamente
    - Melhorar rastreamento de origem
    - Corrigir valores e descrições

  2. Atualizar view de custos detalhados
    - Incluir informações de origem corretamente
    - Melhorar exibição de responsáveis

  3. Corrigir triggers e funções
    - Garantir execução correta dos triggers
    - Melhorar logging e debugging
*/

BEGIN;

-- 1. Corrigir função de criação automática de custos de danos
CREATE OR REPLACE FUNCTION fn_auto_create_damage_cost()
RETURNS TRIGGER AS $$
DECLARE
  inspection_record RECORD;
  vehicle_record RECORD;
  cost_description TEXT;
  inspector_employee_id UUID;
  new_cost_id UUID;
BEGIN
  -- Get inspection details
  SELECT * INTO inspection_record
  FROM inspections
  WHERE id = NEW.inspection_id;
  
  -- Get vehicle details
  SELECT * INTO vehicle_record
  FROM vehicles
  WHERE id = inspection_record.vehicle_id;
  
  -- Only create cost for CheckOut inspections with damages that require repair
  IF inspection_record.inspection_type = 'CheckOut' AND NEW.requires_repair = true THEN
    
    -- Try to find employee by name (inspector)
    SELECT id INTO inspector_employee_id
    FROM employees 
    WHERE LOWER(name) = LOWER(inspection_record.inspected_by)
      AND tenant_id = inspection_record.tenant_id
      AND active = true
    LIMIT 1;
    
    -- Create description for the cost
    cost_description := format(
      'Dano detectado no pátio - %s: %s (%s)',
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
      'Funilaria',
      inspection_record.vehicle_id,
      cost_description,
      0.00, -- Amount to be defined later (will show as "A Definir")
      CURRENT_DATE,
      'Pendente',
      format('PATIO-%s-ITEM-%s', inspection_record.id, NEW.id),
      format(
        'Custo gerado automaticamente pelo controle de pátio. ' ||
        'Veículo: %s - %s. Inspetor: %s. Data da inspeção: %s. ' ||
        'Severidade: %s. Local: %s. Tipo: %s. ' ||
        'Valor a ser definido após orçamento.',
        vehicle_record.plate,
        vehicle_record.model,
        inspection_record.inspected_by,
        inspection_record.inspected_at::date,
        NEW.severity,
        NEW.location,
        NEW.damage_type
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
        'inspection_date', inspection_record.inspected_at,
        'inspector', inspection_record.inspected_by,
        'origin', 'Patio',
        'requires_repair', NEW.requires_repair
      ),
      'pending',
      NOW()
    );

    -- Log the automatic cost creation
    RAISE NOTICE 'CUSTO AUTOMÁTICO CRIADO: ID=%, Origem=Patio, Veículo=%, Valor=A Definir', 
      new_cost_id, vehicle_record.plate;
      
    -- Also log to help with debugging
    RAISE LOG 'Damage cost created automatically: cost_id=%, inspection_item_id=%, vehicle_plate=%', 
      new_cost_id, NEW.id, vehicle_record.plate;
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

-- 3. Atualizar view de custos detalhados para melhor exibição
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
    WHEN c.origin = 'Patio' THEN 'Controle de Pátio'
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

-- 4. Função para debug - verificar custos criados automaticamente
CREATE OR REPLACE FUNCTION fn_debug_automatic_costs(p_tenant_id UUID DEFAULT '00000000-0000-0000-0000-000000000001')
RETURNS TABLE (
  cost_id UUID,
  vehicle_plate TEXT,
  description TEXT,
  amount NUMERIC,
  origin TEXT,
  created_by TEXT,
  inspection_item_id UUID,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id as cost_id,
    v.plate as vehicle_plate,
    c.description,
    c.amount,
    c.origin,
    COALESCE(e.name, 'Sistema') as created_by,
    c.source_reference_id as inspection_item_id,
    c.created_at
  FROM costs c
  LEFT JOIN vehicles v ON v.id = c.vehicle_id
  LEFT JOIN employees e ON e.id = c.created_by_employee_id
  WHERE c.tenant_id = p_tenant_id
    AND c.origin IN ('Patio', 'Manutencao', 'Sistema')
  ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 5. Inserir alguns funcionários de exemplo se não existirem
INSERT INTO employees (tenant_id, name, role, employee_code, contact_info, active) 
VALUES 
  ('00000000-0000-0000-0000-000000000001', 'João Silva', 'Mechanic', 'MEC001', '{"email": "joao@oneway.com", "phone": "(11) 99999-1111"}', true),
  ('00000000-0000-0000-0000-000000000001', 'Maria Santos', 'PatioInspector', 'INS001', '{"email": "maria@oneway.com", "phone": "(11) 99999-2222"}', true),
  ('00000000-0000-0000-0000-000000000001', 'Carlos Vendas', 'Sales', 'VEN001', '{"email": "carlos@oneway.com", "phone": "(11) 99999-3333"}', true),
  ('00000000-0000-0000-0000-000000000001', 'Ana Motorista', 'Driver', 'MOT001', '{"email": "ana@oneway.com", "phone": "(11) 99999-4444"}', true),
  ('00000000-0000-0000-0000-000000000001', 'Pedro Admin', 'Admin', 'ADM001', '{"email": "pedro@oneway.com", "phone": "(11) 99999-5555"}', true)
ON CONFLICT DO NOTHING;

-- 6. Atualizar custos existentes que podem ter sido criados sem origem
UPDATE costs 
SET 
  origin = 'Patio',
  source_reference_type = 'inspection_item'
WHERE origin = 'Manual' 
  AND category = 'Funilaria' 
  AND (
    description LIKE '%Dano detectado%' OR 
    observations LIKE '%Custo gerado automaticamente%' OR
    document_ref LIKE 'PATIO-%'
  );

-- 7. Função para reprocessar custos de inspeções existentes (caso necessário)
CREATE OR REPLACE FUNCTION fn_reprocess_inspection_costs(p_tenant_id UUID DEFAULT '00000000-0000-0000-0000-000000000001')
RETURNS INTEGER AS $$
DECLARE
  inspection_item RECORD;
  costs_created INTEGER := 0;
BEGIN
  -- Buscar itens de inspeção que requerem reparo mas não têm custo associado
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
      AND i.inspection_type = 'CheckOut'
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
      inspection_item.model
    );
    
    costs_created := costs_created + 1;
  END LOOP;
  
  RETURN costs_created;
END;
$$ LANGUAGE plpgsql;

-- 8. Função auxiliar para criação manual de custos (para reprocessamento)
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
  p_vehicle_model TEXT
)
RETURNS UUID AS $$
DECLARE
  inspector_employee_id UUID;
  new_cost_id UUID;
  cost_description TEXT;
BEGIN
  -- Try to find employee by name (inspector)
  SELECT id INTO inspector_employee_id
  FROM employees 
  WHERE LOWER(name) = LOWER(p_inspected_by)
    AND tenant_id = p_tenant_id
    AND active = true
  LIMIT 1;
  
  -- Create description for the cost
  cost_description := format(
    'Dano detectado no pátio - %s: %s (%s)',
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
    format('PATIO-%s-ITEM-%s', p_inspection_id, p_item_id),
    format(
      'Custo gerado automaticamente pelo controle de pátio. ' ||
      'Veículo: %s - %s. Inspetor: %s. Data da inspeção: %s. ' ||
      'Severidade: %s. Local: %s. Tipo: %s. ' ||
      'Valor a ser definido após orçamento.',
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

COMMIT;