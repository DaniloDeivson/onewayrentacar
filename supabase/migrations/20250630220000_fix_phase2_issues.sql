-- FASE 2: CORREÇÕES DE PROBLEMAS CRÍTICOS
-- Data: 2025-06-30 22:00:00
-- Descrição: Correções de triggers, views e funções para resolver problemas de integração

-- 1. CORREÇÃO DE TRIGGERS PROBLEMÁTICOS

-- Remover triggers duplicados ou problemáticos
DROP TRIGGER IF EXISTS trg_rental_checkout ON inspections;
DROP TRIGGER IF EXISTS trg_inspection_items_auto_damage_cost ON inspection_items;
DROP TRIGGER IF EXISTS trg_service_order_parts_auto_cost ON service_order_parts;
DROP TRIGGER IF EXISTS trg_inspections_update_vehicle_status ON inspections;

-- 2. CORREÇÃO DE VIEWS PROBLEMÁTICAS

-- Recriar view de custos detalhados com estrutura correta
DROP VIEW IF EXISTS vw_costs_detailed;
CREATE VIEW vw_costs_detailed AS
SELECT 
  c.*,
  v.plate as vehicle_plate,
  v.model as vehicle_model,
  e.name as created_by_name,
  e.role as created_by_role,
  e.employee_code as created_by_code,
  CASE 
    WHEN c.origin = 'Patio' THEN 'Controle de Pátio'
    WHEN c.origin = 'Manutencao' THEN 'Manutenção'
    WHEN c.origin = 'Manual' THEN 'Lançamento Manual'
    WHEN c.origin = 'Compras' THEN 'Compras'
    ELSE 'Sistema'
  END as origin_description,
  CASE 
    WHEN c.amount = 0 AND c.status = 'Pendente' THEN true
    ELSE false
  END as is_amount_to_define
FROM costs c
LEFT JOIN vehicles v ON c.vehicle_id = v.id
LEFT JOIN employees e ON c.created_by_employee_id = e.id
LEFT JOIN contracts ct ON c.contract_id = ct.id
LEFT JOIN customers cust ON c.customer_id = cust.id
WHERE c.tenant_id = '00000000-0000-0000-0000-000000000001';

-- Recriar view de multas detalhadas
DROP VIEW IF EXISTS vw_fines_detailed;
CREATE VIEW vw_fines_detailed AS
SELECT 
  f.*,
  v.plate as vehicle_plate,
  v.model as vehicle_model,
  v.year as vehicle_year,
  d.name as driver_name,
  d.cpf as driver_cpf,
  e.name as employee_name,
  e.role as employee_role
FROM fines f
LEFT JOIN vehicles v ON f.vehicle_id = v.id
LEFT JOIN drivers d ON f.driver_id = d.id
LEFT JOIN employees e ON f.employee_id = e.id
LEFT JOIN contracts ct ON f.contract_id = ct.id
LEFT JOIN customers cust ON f.customer_id = cust.id
WHERE f.tenant_id = '00000000-0000-0000-0000-000000000001';

-- Recriar view de check-ins de manutenção
DROP VIEW IF EXISTS vw_maintenance_checkins_detailed;
CREATE VIEW vw_maintenance_checkins_detailed AS
SELECT 
  mc.*,
  sn.description as service_description,
  sn.maintenance_type,
  sn.priority,
  sn.status as service_status,
  e.name as mechanic_name,
  e.employee_code as mechanic_code,
  v.id as vehicle_id,
  v.plate as vehicle_plate,
  v.model as vehicle_model,
  v.maintenance_status as vehicle_status,
  CASE WHEN mc.checkout_at IS NULL THEN true ELSE false END as is_active,
  CASE 
    WHEN mc.checkout_at IS NOT NULL THEN 
      EXTRACT(EPOCH FROM (mc.checkout_at::timestamp - mc.checkin_at::timestamp)) / 3600
    ELSE 
      EXTRACT(EPOCH FROM (NOW() - mc.checkin_at::timestamp)) / 3600
  END as duration_hours,
  CASE 
    WHEN mc.checkout_at IS NULL AND mc.checkin_at < NOW() - INTERVAL '24 hours' THEN true
    ELSE false
  END as is_overdue
FROM maintenance_checkins mc
LEFT JOIN service_notes sn ON mc.service_note_id = sn.id
LEFT JOIN employees e ON mc.mechanic_id = e.id
LEFT JOIN vehicles v ON sn.vehicle_id = v.id
WHERE mc.tenant_id = '00000000-0000-0000-0000-000000000001';

-- 3. CORREÇÃO DE FUNÇÕES RPC

-- Recriar função de estatísticas de inspeções
CREATE OR REPLACE FUNCTION fn_inspection_statistics(
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL
)
RETURNS TABLE (
  total_inspections bigint,
  checkin_count bigint,
  checkout_count bigint,
  total_damages bigint,
  high_severity_damages bigint,
  total_estimated_costs numeric,
  vehicles_in_maintenance bigint,
  average_damages_per_checkout numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::bigint as total_inspections,
    COUNT(*) FILTER (WHERE i.inspection_type = 'CheckIn')::bigint as checkin_count,
    COUNT(*) FILTER (WHERE i.inspection_type = 'CheckOut')::bigint as checkout_count,
    COUNT(ii.id)::bigint as total_damages,
    COUNT(ii.id) FILTER (WHERE ii.severity = 'Alta')::bigint as high_severity_damages,
    COALESCE(SUM(c.amount), 0) as total_estimated_costs,
    COUNT(DISTINCT v.id) FILTER (WHERE v.maintenance_status = 'In_Maintenance')::bigint as vehicles_in_maintenance,
    CASE 
      WHEN COUNT(*) FILTER (WHERE i.inspection_type = 'CheckOut') > 0 
      THEN COUNT(ii.id)::numeric / COUNT(*) FILTER (WHERE i.inspection_type = 'CheckOut')
      ELSE 0 
    END as average_damages_per_checkout
  FROM inspections i
  LEFT JOIN inspection_items ii ON i.id = ii.inspection_id
  LEFT JOIN costs c ON c.source_reference_id = ii.id AND c.source_reference_type = 'inspection_item'
  LEFT JOIN vehicles v ON i.vehicle_id = v.id
  WHERE i.tenant_id = p_tenant_id
    AND (p_start_date IS NULL OR i.inspected_at::date >= p_start_date)
    AND (p_end_date IS NULL OR i.inspected_at::date <= p_end_date);
END;
$$ LANGUAGE plpgsql;

-- Recriar função de estatísticas de multas
DROP FUNCTION IF EXISTS fn_fines_statistics(uuid);
CREATE OR REPLACE FUNCTION fn_fines_statistics(
  p_tenant_id uuid
)
RETURNS TABLE (
  total_fines bigint,
  pending_fines bigint,
  paid_fines bigint,
  contested_fines bigint,
  total_amount numeric,
  pending_amount numeric,
  notified_count bigint,
  not_notified_count bigint,
  avg_fine_amount numeric,
  most_common_infraction text,
  most_fined_vehicle text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::bigint as total_fines,
    COUNT(*) FILTER (WHERE f.status = 'Pendente')::bigint as pending_fines,
    COUNT(*) FILTER (WHERE f.status = 'Pago')::bigint as paid_fines,
    COUNT(*) FILTER (WHERE f.status = 'Contestado')::bigint as contested_fines,
    COALESCE(SUM(f.amount), 0) as total_amount,
    COALESCE(SUM(f.amount) FILTER (WHERE f.status = 'Pendente'), 0) as pending_amount,
    COUNT(*) FILTER (WHERE f.notified = true)::bigint as notified_count,
    COUNT(*) FILTER (WHERE f.notified = false)::bigint as not_notified_count,
    COALESCE(AVG(f.amount), 0) as avg_fine_amount,
    (SELECT infraction_type FROM fines WHERE tenant_id = p_tenant_id GROUP BY infraction_type ORDER BY COUNT(*) DESC LIMIT 1) as most_common_infraction,
    (SELECT v.plate FROM fines f2 JOIN vehicles v ON f2.vehicle_id = v.id WHERE f2.tenant_id = p_tenant_id GROUP BY v.plate ORDER BY COUNT(*) DESC LIMIT 1) as most_fined_vehicle
  FROM fines f
  WHERE f.tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql;

-- Recriar função de estatísticas de check-ins de manutenção
DROP FUNCTION IF EXISTS fn_maintenance_checkins_statistics(uuid);
CREATE OR REPLACE FUNCTION fn_maintenance_checkins_statistics(
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid
)
RETURNS TABLE (
  total_checkins bigint,
  active_checkins bigint,
  completed_checkins bigint,
  vehicles_in_maintenance bigint,
  avg_maintenance_duration numeric,
  most_active_mechanic text,
  longest_maintenance_duration numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::bigint as total_checkins,
    COUNT(*) FILTER (WHERE mc.checkout_at IS NULL)::bigint as active_checkins,
    COUNT(*) FILTER (WHERE mc.checkout_at IS NOT NULL)::bigint as completed_checkins,
    COUNT(DISTINCT v.id) FILTER (WHERE v.maintenance_status = 'In_Maintenance')::bigint as vehicles_in_maintenance,
    COALESCE(AVG(EXTRACT(EPOCH FROM (mc.checkout_at::timestamp - mc.checkin_at::timestamp)) / 3600) FILTER (WHERE mc.checkout_at IS NOT NULL), 0) as avg_maintenance_duration,
    (SELECT e.name FROM maintenance_checkins mc2 JOIN employees e ON mc2.mechanic_id = e.id WHERE mc2.tenant_id = p_tenant_id GROUP BY e.name ORDER BY COUNT(*) DESC LIMIT 1) as most_active_mechanic,
    COALESCE(MAX(EXTRACT(EPOCH FROM (mc.checkout_at::timestamp - mc.checkin_at::timestamp)) / 3600) FILTER (WHERE mc.checkout_at IS NOT NULL), 0) as longest_maintenance_duration
  FROM maintenance_checkins mc
  LEFT JOIN service_notes sn ON mc.service_note_id = sn.id
  LEFT JOIN vehicles v ON sn.vehicle_id = v.id
  WHERE mc.tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql;

-- 4. CORREÇÃO DE TRIGGERS ESSENCIAIS

-- Trigger para atualizar quantidade de peças quando há movimentação de estoque
CREATE OR REPLACE FUNCTION fn_update_part_quantity()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.type = 'Entrada' THEN
      UPDATE parts 
      SET quantity = quantity + NEW.quantity,
          updated_at = NOW()
      WHERE id = NEW.part_id;
    ELSIF NEW.type = 'Saída' THEN
      UPDATE parts 
      SET quantity = quantity - NEW.quantity,
          updated_at = NOW()
      WHERE id = NEW.part_id;
    END IF;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_part_quantity
  AFTER INSERT ON stock_movements
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_part_quantity();

-- Trigger para gerar custos automaticamente quando há danos em inspeções
CREATE OR REPLACE FUNCTION fn_generate_damage_cost()
RETURNS TRIGGER AS $$
DECLARE
  v_vehicle_id uuid;
  v_contract_id uuid;
  v_customer_id uuid;
BEGIN
  -- Get vehicle ID from inspection
  SELECT vehicle_id INTO v_vehicle_id FROM inspections WHERE id = NEW.inspection_id;
  
  -- Get contract and customer info if available
  SELECT contract_id, customer_id INTO v_contract_id, v_customer_id 
  FROM inspections 
  WHERE id = NEW.inspection_id;
  
  -- Insert cost record with amount 0 (to be defined later)
  INSERT INTO costs (
    tenant_id,
    category,
    vehicle_id,
    description,
    amount,
    cost_date,
    status,
    origin,
    source_reference_id,
    source_reference_type,
    contract_id,
    customer_id,
    created_by_name
  ) VALUES (
    NEW.tenant_id,
    'Funilaria',
    v_vehicle_id,
    'Danos identificados em inspeção: ' || NEW.description || ' (Severidade: ' || NEW.severity || ')',
    0, -- Valor 0 para orçamento a definir
    NOW()::date,
    'Pendente',
    'Patio',
    NEW.id,
    'inspection_item',
    v_contract_id,
    v_customer_id,
    'Sistema'
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_damage_cost
  AFTER INSERT ON inspection_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_generate_damage_cost();

-- 5. CORREÇÃO DE ÍNDICES PARA PERFORMANCE

-- Índices para melhorar performance das consultas
CREATE INDEX IF NOT EXISTS idx_costs_contract_customer ON costs(contract_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_fines_contract_customer ON fines(contract_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_inspections_contract_customer ON inspections(contract_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_part_date ON stock_movements(part_id, movement_date);
CREATE INDEX IF NOT EXISTS idx_maintenance_checkins_service_note ON maintenance_checkins(service_note_id);

-- 6. CORREÇÃO DE CONSTRAINTS

-- Adicionar constraints para garantir integridade
ALTER TABLE costs 
ADD CONSTRAINT chk_cost_amount_positive CHECK (amount >= 0);

ALTER TABLE stock_movements 
ADD CONSTRAINT chk_stock_quantity_positive CHECK (quantity > 0);

ALTER TABLE inspection_items 
ADD CONSTRAINT chk_severity_valid CHECK (severity IN ('Baixa', 'Média', 'Alta'));

-- 7. CORREÇÃO DE DADOS EXISTENTES

-- Atualizar registros existentes que podem estar inconsistentes
UPDATE costs 
SET contract_id = i.contract_id,
    customer_id = i.customer_id
FROM inspections i
WHERE costs.source_reference_id = i.id 
  AND costs.source_reference_type = 'inspection_item'
  AND costs.contract_id IS NULL;

-- Atualizar multas para associar com contratos baseado na data
UPDATE fines 
SET contract_id = c.id,
    customer_id = c.customer_id
FROM contracts c
WHERE fines.vehicle_id = c.vehicle_id
  AND fines.infraction_date::date BETWEEN c.start_date AND c.end_date
  AND fines.contract_id IS NULL;

-- 8. COMENTÁRIOS DE DOCUMENTAÇÃO

COMMENT ON FUNCTION fn_inspection_statistics IS 'Retorna estatísticas completas de inspeções com filtros opcionais de data';
COMMENT ON FUNCTION fn_fines_statistics IS 'Retorna estatísticas completas de multas';
COMMENT ON FUNCTION fn_maintenance_checkins_statistics IS 'Retorna estatísticas de check-ins de manutenção';
COMMENT ON FUNCTION fn_update_part_quantity IS 'Atualiza quantidade de peças automaticamente quando há movimentação de estoque';
COMMENT ON FUNCTION fn_generate_damage_cost IS 'Gera custos automaticamente quando há danos identificados em inspeções';

COMMENT ON VIEW vw_costs_detailed IS 'View detalhada de custos com informações de veículos, funcionários e contratos';
COMMENT ON VIEW vw_fines_detailed IS 'View detalhada de multas com informações de veículos, motoristas e contratos';
COMMENT ON VIEW vw_maintenance_checkins_detailed IS 'View detalhada de check-ins de manutenção com informações de serviço e veículos'; 