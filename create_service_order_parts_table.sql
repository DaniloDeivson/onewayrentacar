-- 🔧 CRIAR TABELA SERVICE_ORDER_PARTS - EXECUTE NO SUPABASE SQL EDITOR
-- Esta tabela é essencial para o sistema de peças utilizadas em manutenção

BEGIN;

-- 1. Criar a tabela service_order_parts
CREATE TABLE IF NOT EXISTS public.service_order_parts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  service_note_id uuid REFERENCES service_notes(id) ON DELETE CASCADE,
  part_id uuid REFERENCES parts(id) ON DELETE CASCADE,
  quantity_used integer NOT NULL CHECK (quantity_used > 0),
  unit_cost_at_time numeric(12,2) NOT NULL CHECK (unit_cost_at_time >= 0),
  total_cost numeric(12,2) GENERATED ALWAYS AS (quantity_used * unit_cost_at_time) STORED,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 2. Criar índices para performance
CREATE INDEX IF NOT EXISTS idx_service_order_parts_service_note ON service_order_parts(service_note_id);
CREATE INDEX IF NOT EXISTS idx_service_order_parts_part ON service_order_parts(part_id);
CREATE INDEX IF NOT EXISTS idx_service_order_parts_tenant ON service_order_parts(tenant_id);

-- 3. Habilitar RLS (Row Level Security)
ALTER TABLE service_order_parts ENABLE ROW LEVEL SECURITY;

-- 4. Criar políticas de segurança
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

-- 5. Criar função para gerenciar peças utilizadas
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

  -- Create cost record with CORRECT values
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
    'Avaria', -- Categoria permitida pela constraint
    v_vehicle_id,
    CONCAT('Peça utilizada: ', v_part_name, ' (Qtde: ', NEW.quantity_used, ')'),
    NEW.total_cost,
    CURRENT_DATE,
    'Pendente',
    CONCAT('OS-', v_service_note_id),
    CONCAT('Lançamento automático via Ordem de Serviço - Peça: ', v_part_name),
    'Manutencao', -- Origem permitida pela constraint
    'Sistema', -- Responsável padrão
    v_service_note_id::text,
    'service_note', -- Tipo permitido pela constraint
    now()
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Criar trigger para processamento automático
CREATE TRIGGER trg_service_order_parts_handle
  AFTER INSERT ON service_order_parts
  FOR EACH ROW
  EXECUTE FUNCTION handle_service_order_parts();

-- 7. Função para reverter uso de peças (para exclusões/correções)
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

-- 8. Trigger para reverter quando peças são removidas
CREATE TRIGGER trg_service_order_parts_reverse
  AFTER DELETE ON service_order_parts
  FOR EACH ROW
  EXECUTE FUNCTION reverse_service_order_parts();

-- 9. Verificar se tudo foi criado corretamente
SELECT 
  table_name,
  column_name,
  data_type
FROM information_schema.columns 
WHERE table_name = 'service_order_parts'
ORDER BY ordinal_position;

-- 10. Verificar triggers
SELECT 
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers 
WHERE trigger_name LIKE '%service_order_parts%';

COMMIT;

-- ✅ TABELA SERVICE_ORDER_PARTS CRIADA COM SUCESSO!
-- Agora o sistema de peças utilizadas deve funcionar corretamente. 