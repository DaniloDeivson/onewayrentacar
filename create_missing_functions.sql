-- 🔧 CRIAR FUNÇÕES FALTANTES - EXECUTE NO SUPABASE SQL EDITOR
-- Estas funções são necessárias para o sistema de peças funcionar corretamente

BEGIN;

-- 1. Função para gerenciar peças utilizadas (trigger principal)
CREATE OR REPLACE FUNCTION handle_service_order_parts()
RETURNS TRIGGER AS $$
DECLARE
  v_part_name TEXT;
  v_part_quantity INTEGER;
  v_vehicle_id UUID;
  v_service_note_id UUID;
BEGIN
  -- Get part information
  SELECT name, quantity INTO v_part_name, v_part_quantity
  FROM parts 
  WHERE id = NEW.part_id;

  -- Get service order vehicle information
  SELECT vehicle_id, id INTO v_vehicle_id, v_service_note_id
  FROM service_notes 
  WHERE id = NEW.service_note_id;

  -- Check if we have enough stock
  IF v_part_quantity < NEW.quantity_used THEN
    RAISE EXCEPTION 'Insufficient stock for part %. Available: %, Required: %', 
      v_part_name, v_part_quantity, NEW.quantity_used;
  END IF;

  -- Update parts quantity
  UPDATE parts 
  SET quantity = quantity - NEW.quantity_used,
      updated_at = now()
  WHERE id = NEW.part_id;

  -- Create stock movement record
  INSERT INTO stock_movements (
    tenant_id,
    part_id,
    service_note_id,
    type,
    quantity,
    movement_date,
    created_at
  ) VALUES (
    NEW.tenant_id,
    NEW.part_id,
    NEW.service_note_id,
    'Saída',
    NEW.quantity_used,
    CURRENT_DATE,
    now()
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Função para reverter uso de peças (para exclusões/correções)
CREATE OR REPLACE FUNCTION reverse_service_order_parts()
RETURNS TRIGGER AS $$
BEGIN
  -- Restaurar quantidade da peça
  UPDATE parts 
  SET quantity = quantity + OLD.quantity_used,
      updated_at = now()
  WHERE id = OLD.part_id;

  -- Criar movimento de estoque de entrada
  INSERT INTO stock_movements (
    tenant_id,
    part_id,
    service_note_id,
    type,
    quantity,
    movement_date,
    created_at
  ) VALUES (
    OLD.tenant_id,
    OLD.part_id,
    OLD.service_note_id,
    'Entrada',
    OLD.quantity_used,
    CURRENT_DATE,
    now()
  );

  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Função para criar custo de peças uma única vez
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
    'Avaria', -- Categoria permitida pela constraint
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
    'Manutencao', -- Origem permitida pela constraint
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Habilitar RLS na tabela service_order_parts
ALTER TABLE service_order_parts ENABLE ROW LEVEL SECURITY;

-- 5. Criar políticas de segurança
CREATE POLICY "Allow all operations for default tenant on service_order_parts"
  ON service_order_parts
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Users can manage their tenant service order parts"
  ON service_order_parts
  FOR ALL
  TO authenticated
  USING (tenant_id IN (
    SELECT tenants.id
    FROM tenants
    WHERE auth.uid() IS NOT NULL
  ))
  WITH CHECK (tenant_id IN (
    SELECT tenants.id
    FROM tenants
    WHERE auth.uid() IS NOT NULL
  ));

-- 6. Verificar se tudo foi criado corretamente
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines 
WHERE routine_name IN ('handle_service_order_parts', 'reverse_service_order_parts', 'fn_create_parts_cost_once')
ORDER BY routine_name;

-- 7. Verificar triggers
SELECT 
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers 
WHERE trigger_name LIKE '%service_order_parts%'
ORDER BY trigger_name;

COMMIT;

-- ✅ FUNÇÕES CRIADAS COM SUCESSO!
-- Agora o sistema de peças utilizadas deve funcionar completamente. 