-- 🔧 CORREÇÃO DO TRIGGER DE PEÇAS - EXECUTE NO SUPABASE SQL EDITOR
-- Este SQL corrige o erro de constraint violation ao adicionar peças ao carrinho

BEGIN;

-- 1. Remover o trigger e função existentes
DROP TRIGGER IF EXISTS trg_service_order_parts_handle ON service_order_parts;
DROP FUNCTION IF EXISTS handle_service_order_parts();

-- 2. Criar a função corrigida
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

  -- Create cost record with CORRECT values that match the constraints
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
    'Peças', -- ✅ Categoria permitida pela constraint
    v_vehicle_id,
    CONCAT('Peça utilizada: ', v_part_name, ' (Qtde: ', NEW.quantity_used, ')'),
    NEW.total_cost,
    CURRENT_DATE,
    'Pendente',
    CONCAT('OS-', v_service_note_id),
    CONCAT('Lançamento automático via Ordem de Serviço - Peça: ', v_part_name),
    'Manutencao', -- ✅ Origem permitida pela constraint
    'Sistema', -- Responsável padrão
    v_service_note_id::text,
    'service_note', -- ✅ Tipo permitido pela constraint
    now()
  );

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

-- 5. Testar a função (opcional - remove após testar)
-- DO $$
-- DECLARE
--   test_tenant_id uuid := '00000000-0000-0000-0000-000000000001';
--   test_service_note_id uuid;
--   test_part_id uuid;
-- BEGIN
--   -- Get test data
--   SELECT id INTO test_service_note_id FROM service_notes WHERE tenant_id = test_tenant_id LIMIT 1;
--   SELECT id INTO test_part_id FROM parts WHERE tenant_id = test_tenant_id LIMIT 1;
--   
--   IF test_service_note_id IS NOT NULL AND test_part_id IS NOT NULL THEN
--     RAISE NOTICE 'Test data found - Service Note: %, Part: %', test_service_note_id, test_part_id;
--   ELSE
--     RAISE NOTICE 'No test data available';
--   END IF;
-- END $$;

COMMIT;

-- ✅ MIGRAÇÃO CONCLUÍDA
-- Agora o trigger deve funcionar corretamente ao adicionar peças ao carrinho! 