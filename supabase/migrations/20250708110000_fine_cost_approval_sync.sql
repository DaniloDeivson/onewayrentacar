-- ============================================================================
-- SINCRONIZAÇÃO DE APROVAÇÃO ENTRE CUSTOS E MULTAS
-- ============================================================================
-- Esta migração implementa a funcionalidade de aprovação de multas
-- através dos custos, sincronizando o status entre as duas tabelas

-- 1. Função para aprovar multa através do custo
CREATE OR REPLACE FUNCTION fn_approve_fine_cost(p_cost_id uuid)
RETURNS json AS $$
DECLARE
  v_fine_id uuid;
  v_cost_record record;
  v_fine_record record;
  v_result json;
BEGIN
  -- Buscar o custo e verificar se é uma multa
  SELECT * INTO v_cost_record
  FROM costs
  WHERE id = p_cost_id 
    AND source_reference_type = 'fine'
    AND status = 'Pendente';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Custo não encontrado ou não é uma multa pendente';
  END IF;
  
  -- Buscar a multa associada
  SELECT * INTO v_fine_record
  FROM fines
  WHERE id = v_cost_record.source_reference_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Multa associada não encontrada';
  END IF;
  
  -- Atualizar o status do custo para 'Autorizado'
  UPDATE costs
  SET status = 'Autorizado',
      updated_at = now()
  WHERE id = p_cost_id;
  
  -- Atualizar o status da multa para 'Pago'
  UPDATE fines
  SET status = 'Pago',
      updated_at = now()
  WHERE id = v_fine_record.id;
  
  -- Retornar resultado
  v_result := json_build_object(
    'success', true,
    'cost_id', p_cost_id,
    'fine_id', v_fine_record.id,
    'fine_number', v_fine_record.fine_number,
    'message', 'Multa aprovada com sucesso'
  );
  
  RETURN v_result;
  
EXCEPTION
  WHEN OTHERS THEN
    v_result := json_build_object(
      'success', false,
      'error', SQLERRM,
      'message', 'Erro ao aprovar multa'
    );
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Função para reverter aprovação de multa
CREATE OR REPLACE FUNCTION fn_revert_fine_approval(p_cost_id uuid)
RETURNS json AS $$
DECLARE
  v_fine_id uuid;
  v_cost_record record;
  v_fine_record record;
  v_result json;
BEGIN
  -- Buscar o custo e verificar se é uma multa autorizada
  SELECT * INTO v_cost_record
  FROM costs
  WHERE id = p_cost_id 
    AND source_reference_type = 'fine'
    AND status = 'Autorizado';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Custo não encontrado ou não é uma multa autorizada';
  END IF;
  
  -- Buscar a multa associada
  SELECT * INTO v_fine_record
  FROM fines
  WHERE id = v_cost_record.source_reference_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Multa associada não encontrada';
  END IF;
  
  -- Reverter o status do custo para 'Pendente'
  UPDATE costs
  SET status = 'Pendente',
      updated_at = now()
  WHERE id = p_cost_id;
  
  -- Reverter o status da multa para 'Pendente'
  UPDATE fines
  SET status = 'Pendente',
      updated_at = now()
  WHERE id = v_fine_record.id;
  
  -- Retornar resultado
  v_result := json_build_object(
    'success', true,
    'cost_id', p_cost_id,
    'fine_id', v_fine_record.id,
    'fine_number', v_fine_record.fine_number,
    'message', 'Aprovação da multa revertida com sucesso'
  );
  
  RETURN v_result;
  
EXCEPTION
  WHEN OTHERS THEN
    v_result := json_build_object(
      'success', false,
      'error', SQLERRM,
      'message', 'Erro ao reverter aprovação da multa'
    );
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Trigger para sincronizar status quando multa for atualizada
CREATE OR REPLACE FUNCTION fn_sync_fine_cost_status()
RETURNS TRIGGER AS $$
DECLARE
  v_cost_id uuid;
BEGIN
  -- Se a multa tem um cost_id associado, sincronizar o status
  IF NEW.cost_id IS NOT NULL THEN
    -- Buscar o custo associado
    SELECT id INTO v_cost_id
    FROM costs
    WHERE source_reference_id = NEW.id 
      AND source_reference_type = 'fine'
    LIMIT 1;
    
    IF FOUND THEN
      -- Sincronizar status baseado na mudança da multa
      IF NEW.status = 'Pago' AND OLD.status != 'Pago' THEN
        -- Multa foi paga, autorizar o custo
        UPDATE costs
        SET status = 'Autorizado',
            updated_at = now()
        WHERE id = v_cost_id;
      ELSIF NEW.status = 'Pendente' AND OLD.status = 'Pago' THEN
        -- Multa voltou para pendente, reverter custo
        UPDATE costs
        SET status = 'Pendente',
            updated_at = now()
        WHERE id = v_cost_id;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Criar trigger para sincronização
DROP TRIGGER IF EXISTS tr_sync_fine_cost_status ON fines;
CREATE TRIGGER tr_sync_fine_cost_status
  AFTER UPDATE ON fines
  FOR EACH ROW
  EXECUTE FUNCTION fn_sync_fine_cost_status();

-- 5. Trigger para sincronizar status quando custo for atualizado
CREATE OR REPLACE FUNCTION fn_sync_cost_fine_status()
RETURNS TRIGGER AS $$
DECLARE
  v_fine_id uuid;
BEGIN
  -- Se o custo é de uma multa, sincronizar o status
  IF NEW.source_reference_type = 'fine' AND NEW.source_reference_id IS NOT NULL THEN
    v_fine_id := NEW.source_reference_id;
    
    -- Sincronizar status baseado na mudança do custo
    IF NEW.status = 'Autorizado' AND OLD.status = 'Pendente' THEN
      -- Custo foi autorizado, pagar a multa
      UPDATE fines
      SET status = 'Pago',
          updated_at = now()
      WHERE id = v_fine_id;
    ELSIF NEW.status = 'Pendente' AND OLD.status = 'Autorizado' THEN
      -- Custo voltou para pendente, reverter multa
      UPDATE fines
      SET status = 'Pendente',
          updated_at = now()
      WHERE id = v_fine_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Criar trigger para sincronização de custos
DROP TRIGGER IF EXISTS tr_sync_cost_fine_status ON costs;
CREATE TRIGGER tr_sync_cost_fine_status
  AFTER UPDATE ON costs
  FOR EACH ROW
  EXECUTE FUNCTION fn_sync_cost_fine_status();

-- 7. Função para buscar custos de multas pendentes
CREATE OR REPLACE FUNCTION fn_get_pending_fine_costs()
RETURNS TABLE (
  cost_id uuid,
  fine_id uuid,
  fine_number text,
  infraction_type text,
  amount numeric,
  infraction_date date,
  due_date date,
  vehicle_plate text,
  vehicle_model text,
  driver_name text,
  customer_name text,
  cost_status text,
  fine_status text,
  created_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id as cost_id,
    f.id as fine_id,
    f.fine_number,
    f.infraction_type,
    f.amount,
    f.infraction_date,
    f.due_date,
    v.plate as vehicle_plate,
    v.model as vehicle_model,
    e.name as driver_name,
    f.customer_name,
    c.status as cost_status,
    f.status as fine_status,
    c.created_at
  FROM costs c
  JOIN fines f ON f.id = c.source_reference_id
  JOIN vehicles v ON v.id = f.vehicle_id
  LEFT JOIN employees e ON e.id = f.driver_id
  WHERE c.source_reference_type = 'fine'
    AND c.status = 'Pendente'
    AND c.tenant_id = '00000000-0000-0000-0000-000000000001'
  ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 8. Log da implementação
DO $$
BEGIN
  RAISE NOTICE 'Sistema de aprovação de multas implementado com sucesso';
  RAISE NOTICE 'Funções criadas: fn_approve_fine_cost, fn_revert_fine_approval';
  RAISE NOTICE 'Triggers criados: tr_sync_fine_cost_status, tr_sync_cost_fine_status';
  RAISE NOTICE 'Função de consulta criada: fn_get_pending_fine_costs';
END $$; 