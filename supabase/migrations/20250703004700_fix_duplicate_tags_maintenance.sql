-- CORREÇÃO: Tags duplicadas na manutenção
-- Data: 2025-07-03 00:47:00
-- Descrição: Corrigir problema de tags duplicadas "Lançamento Manual" na manutenção

-- 1. Verificar se a trigger ainda existe e removê-la definitivamente
DROP TRIGGER IF EXISTS trg_service_order_parts_auto_cost ON service_order_parts;
DROP FUNCTION IF EXISTS fn_auto_create_parts_cost();

-- 2. Criar nova função que não duplica custos
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
    'service_order_part', -- Type of source reference (corrigido)
    NOW(),
    NOW()
  ) RETURNING id INTO new_cost_id;

  -- Log the automatic cost creation
  RAISE NOTICE 'CUSTO DE PEÇAS CRIADO: ID=%, Origem=Manutencao, Mecânico=%, Valor=R$ %', 
    new_cost_id, service_note_record.mechanic, NEW.total_cost;
    
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Criar trigger apenas se não existir
CREATE TRIGGER trg_service_order_parts_cost_once
  AFTER INSERT ON service_order_parts
  FOR EACH ROW
  EXECUTE FUNCTION fn_create_parts_cost_once();

-- 4. Limpar custos duplicados existentes (manter apenas o mais recente)
WITH duplicate_costs AS (
  SELECT 
    id,
    ROW_NUMBER() OVER (
      PARTITION BY source_reference_id, source_reference_type 
      ORDER BY created_at DESC
    ) as rn
  FROM costs
  WHERE source_reference_type = 'service_order_part'
    AND tenant_id = '00000000-0000-0000-0000-000000000001'
)
DELETE FROM costs
WHERE id IN (
  SELECT id FROM duplicate_costs WHERE rn > 1
);

-- 5. Atualizar view de custos para mostrar origem correta
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
    WHEN c.origin = 'Manutencao' THEN 'Manutenção (Peças)'
    WHEN c.origin = 'Manual' THEN 'Lançamento Manual'
    WHEN c.origin = 'Compras' THEN 'Compras'
    ELSE 'Sistema'
  END as origin_description,
  CASE 
    WHEN c.amount = 0 AND c.status = 'Pendente' THEN true
    ELSE false
  END as is_amount_to_define,
  ct.id as contract_id,
  ct.contract_number,
  cust.name as customer_name
FROM costs c
LEFT JOIN vehicles v ON c.vehicle_id = v.id
LEFT JOIN employees e ON c.created_by_employee_id = e.id
LEFT JOIN contracts ct ON c.contract_id = ct.id
LEFT JOIN customers cust ON c.customer_id = cust.id
WHERE c.tenant_id = '00000000-0000-0000-0000-000000000001'; 