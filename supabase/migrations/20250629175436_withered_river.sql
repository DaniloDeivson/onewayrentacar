/*
  # Sistema de Rastreamento de Origem e Responsável para Custos

  1. Alterações na tabela costs
    - Adicionar coluna origin (origem do custo)
    - Adicionar coluna created_by_employee_id (responsável pelo lançamento)
    - Adicionar coluna source_reference_id (referência ao item de origem)

  2. Atualizar funções
    - Modificar função de criação automática de custos
    - Adicionar informações de origem nos custos existentes

  3. Políticas e índices
    - Criar índices para as novas colunas
    - Manter RLS existente
*/

BEGIN;

-- 1. Adicionar colunas de rastreamento à tabela costs
DO $$
BEGIN
  -- Adicionar coluna origin se não existir
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'costs' AND column_name = 'origin'
  ) THEN
    ALTER TABLE costs ADD COLUMN origin TEXT NOT NULL DEFAULT 'Manual' 
    CHECK (origin IN ('Manual', 'Patio', 'Manutencao', 'Sistema'));
  END IF;

  -- Adicionar coluna created_by_employee_id se não existir
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'costs' AND column_name = 'created_by_employee_id'
  ) THEN
    ALTER TABLE costs ADD COLUMN created_by_employee_id UUID REFERENCES employees(id);
  END IF;

  -- Adicionar coluna source_reference_id se não existir
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'costs' AND column_name = 'source_reference_id'
  ) THEN
    ALTER TABLE costs ADD COLUMN source_reference_id UUID;
  END IF;

  -- Adicionar coluna source_reference_type se não existir
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'costs' AND column_name = 'source_reference_type'
  ) THEN
    ALTER TABLE costs ADD COLUMN source_reference_type TEXT 
    CHECK (source_reference_type IN ('inspection_item', 'service_note', 'manual', 'system'));
  END IF;
END $$;

-- 2. Criar índices para as novas colunas
CREATE INDEX IF NOT EXISTS idx_costs_origin ON costs(origin);
CREATE INDEX IF NOT EXISTS idx_costs_created_by ON costs(created_by_employee_id);
CREATE INDEX IF NOT EXISTS idx_costs_source_reference ON costs(source_reference_id);

-- 3. Atualizar função de criação automática de custos de danos
CREATE OR REPLACE FUNCTION fn_auto_create_damage_cost()
RETURNS TRIGGER AS $$
DECLARE
  inspection_record RECORD;
  cost_description TEXT;
  inspector_employee_id UUID;
  new_cost_id UUID;
BEGIN
  -- Get inspection details with vehicle info
  SELECT i.*, v.plate, v.model 
  INTO inspection_record
  FROM inspections i
  JOIN vehicles v ON v.id = i.vehicle_id
  WHERE i.id = NEW.inspection_id;
  
  -- Only create cost for CheckOut inspections with damages that require repair
  IF inspection_record.inspection_type = 'CheckOut' AND NEW.requires_repair = true THEN
    
    -- Try to find employee by name (inspector)
    SELECT id INTO inspector_employee_id
    FROM employees 
    WHERE name = inspection_record.inspected_by 
      AND tenant_id = inspection_record.tenant_id
      AND active = true
    LIMIT 1;
    
    -- Create description for the cost
    cost_description := format(
      'Dano detectado no pátio - %s (%s): %s',
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
      observations,
      origin,
      created_by_employee_id,
      source_reference_id,
      source_reference_type,
      created_at
    ) VALUES (
      inspection_record.tenant_id,
      'Funilaria',
      inspection_record.vehicle_id,
      cost_description,
      0.00, -- Amount to be defined later
      CURRENT_DATE,
      'Pendente',
      format(
        'Custo gerado automaticamente pelo sistema a partir da inspeção de pátio. ' ||
        'Veículo: %s - %s. Inspetor: %s. Data da inspeção: %s. ' ||
        'Severidade: %s. Valor a ser definido após orçamento.',
        inspection_record.plate,
        inspection_record.model,
        inspection_record.inspected_by,
        inspection_record.inspected_at::date,
        NEW.severity
      ),
      'Patio', -- Origin: Patio (controle de pátio)
      inspector_employee_id, -- Employee who created (inspector)
      NEW.id, -- Reference to inspection item
      'inspection_item', -- Type of source reference
      NOW()
    ) RETURNING id INTO new_cost_id;
    
    -- Create damage notification record
    INSERT INTO damage_notifications (
      tenant_id,
      cost_id,
      inspection_item_id,
      notification_data,
      status
    ) VALUES (
      inspection_record.tenant_id,
      new_cost_id,
      NEW.id,
      jsonb_build_object(
        'vehicle_plate', inspection_record.plate,
        'vehicle_model', inspection_record.model,
        'damage_location', NEW.location,
        'damage_type', NEW.damage_type,
        'damage_description', NEW.description,
        'severity', NEW.severity,
        'inspection_date', inspection_record.inspected_at,
        'inspector', inspection_record.inspected_by,
        'cost_id', new_cost_id,
        'origin', 'Patio'
      ),
      'pending'
    );

    -- Log the automatic cost creation
    RAISE NOTICE 'Custo automático criado: ID=%, Origem=Patio, Responsável=%, Veículo=%', 
      new_cost_id, COALESCE(inspector_employee_id::text, 'Sistema'), inspection_record.plate;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Função para criar custos de manutenção automaticamente
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
    RAISE NOTICE 'Custo de manutenção criado: ID=%, Origem=Manutencao, Responsável=%, Veículo=%', 
      new_cost_id, COALESCE(mechanic_employee_id::text, 'Sistema'), vehicle_plate;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Criar trigger para custos de manutenção
DROP TRIGGER IF EXISTS trg_service_notes_auto_cost ON service_notes;
CREATE TRIGGER trg_service_notes_auto_cost
  AFTER UPDATE ON service_notes
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_create_maintenance_cost();

-- 6. Atualizar custos existentes com informações de origem
UPDATE costs 
SET 
  origin = CASE 
    WHEN category = 'Funilaria' AND observations LIKE '%Custo gerado automaticamente%' THEN 'Patio'
    WHEN category = 'Avulsa' AND observations LIKE '%manutenção%' THEN 'Manutencao'
    ELSE 'Manual'
  END,
  source_reference_type = CASE 
    WHEN category = 'Funilaria' AND observations LIKE '%Custo gerado automaticamente%' THEN 'inspection_item'
    WHEN category = 'Avulsa' AND observations LIKE '%manutenção%' THEN 'service_note'
    ELSE 'manual'
  END
WHERE origin IS NULL OR origin = 'Manual';

-- 7. Função para obter estatísticas de custos por origem
CREATE OR REPLACE FUNCTION fn_cost_statistics_by_origin(p_tenant_id UUID)
RETURNS TABLE (
  total_costs BIGINT,
  manual_costs BIGINT,
  patio_costs BIGINT,
  maintenance_costs BIGINT,
  system_costs BIGINT,
  total_amount NUMERIC,
  pending_amount NUMERIC,
  paid_amount NUMERIC,
  costs_to_define BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*) as total_costs,
    COUNT(*) FILTER (WHERE origin = 'Manual') as manual_costs,
    COUNT(*) FILTER (WHERE origin = 'Patio') as patio_costs,
    COUNT(*) FILTER (WHERE origin = 'Manutencao') as maintenance_costs,
    COUNT(*) FILTER (WHERE origin = 'Sistema') as system_costs,
    COALESCE(SUM(amount), 0) as total_amount,
    COALESCE(SUM(amount) FILTER (WHERE status = 'Pendente'), 0) as pending_amount,
    COALESCE(SUM(amount) FILTER (WHERE status = 'Pago'), 0) as paid_amount,
    COUNT(*) FILTER (WHERE amount = 0 AND status = 'Pendente') as costs_to_define
  FROM costs
  WHERE tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql;

-- 8. View para relatório detalhado de custos com origem
CREATE OR REPLACE VIEW vw_costs_detailed AS
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
  c.origin,
  c.source_reference_type,
  e.name as created_by_name,
  e.role as created_by_role,
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
LEFT JOIN employees e ON e.id = c.created_by_employee_id;

COMMIT;