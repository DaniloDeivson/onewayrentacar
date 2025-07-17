-- 🔧 CORREÇÃO FINAL DO TRIGGER - EXECUTE NO SUPABASE SQL EDITOR
-- Este SQL corrige o trigger para usar os tipos corretos da tabela costs

BEGIN;

-- 1. Remover o trigger e função existentes
DROP TRIGGER IF EXISTS trg_service_order_parts_handle ON service_order_parts;
DROP FUNCTION IF EXISTS handle_service_order_parts();

-- 2. Criar a função corrigida com tipos corretos
CREATE OR REPLACE FUNCTION handle_service_order_parts()
RETURNS TRIGGER AS $$
DECLARE
  v_part_name TEXT;
  v_part_quantity INTEGER;
  v_vehicle_id UUID;
  v_service_note_id UUID;
  v_stock_movement_id UUID;
  v_cost_id UUID;
BEGIN
  -- Debug: Log the operation
  RAISE NOTICE 'handle_service_order_parts triggered for part_id: %, service_note_id: %, quantity: %', 
    NEW.part_id, NEW.service_note_id, NEW.quantity_used;

  -- Get part information
  SELECT name, quantity INTO v_part_name, v_part_quantity
  FROM parts 
  WHERE id = NEW.part_id;

  -- Get service order vehicle information
  SELECT vehicle_id, id INTO v_vehicle_id, v_service_note_id
  FROM service_notes 
  WHERE id = NEW.service_note_id;

  -- Debug: Log retrieved data
  RAISE NOTICE 'Part: %, Available: %, Vehicle: %, Service Note: %', 
    v_part_name, v_part_quantity, v_vehicle_id, v_service_note_id;

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

  RAISE NOTICE 'Updated part quantity for %: reduced by %', v_part_name, NEW.quantity_used;

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
  ) RETURNING id INTO v_stock_movement_id;

  RAISE NOTICE 'Created stock movement: %', v_stock_movement_id;

  -- Create cost record with CORRECT types (source_reference_id as UUID)
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
    created_by_name,
    source_reference_id,
    source_reference_type,
    created_at
  ) VALUES (
    NEW.tenant_id,
    'Avaria', -- ✅ Categoria permitida pela constraint (não 'Peças')
    v_vehicle_id,
    CONCAT('Peça utilizada: ', v_part_name, ' (Qtde: ', NEW.quantity_used, ')'),
    NEW.total_cost,
    CURRENT_DATE,
    'Pendente',
    CONCAT('OS-', v_service_note_id),
    CONCAT('Lançamento automático via Ordem de Serviço - Peça: ', v_part_name),
    'Manutencao', -- ✅ Origem permitida pela constraint
    'Sistema', -- Responsável padrão
    v_service_note_id, -- ✅ UUID, não text
    'service_note', -- ✅ Tipo permitido pela constraint (não 'service_order_part')
    now()
  ) RETURNING id INTO v_cost_id;

  RAISE NOTICE 'Created cost record: %', v_cost_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Recriar o trigger
CREATE TRIGGER trg_service_order_parts_handle
  AFTER INSERT ON service_order_parts
  FOR EACH ROW
  EXECUTE FUNCTION handle_service_order_parts();

-- 4. Verificar se foi criado corretamente
SELECT 
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'trg_service_order_parts_handle';

COMMIT;

-- ✅ TRIGGER CORRIGIDO COM TIPOS CORRETOS
-- Agora deve funcionar sem erros de tipo 