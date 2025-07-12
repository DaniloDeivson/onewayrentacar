-- FASE 2: CORREÇÕES DE STATUS DE PAGAMENTO E CÁLCULOS AUTOMÁTICOS
-- Data: 2025-06-30 23:00:00
-- Descrição: Correções de status de pagamento, cálculos automáticos e integração de cobrança

-- 1. CORREÇÃO DE STATUS DE PAGAMENTO

-- Adicionar coluna de status de pagamento em contratos
ALTER TABLE contracts 
ADD COLUMN IF NOT EXISTS payment_status text DEFAULT 'Pendente' CHECK (payment_status IN ('Pendente', 'Parcial', 'Pago', 'Atrasado'));

-- Adicionar coluna de valor total do contrato
ALTER TABLE contracts 
ADD COLUMN IF NOT EXISTS total_amount numeric DEFAULT 0;

-- Adicionar coluna de valor pago
ALTER TABLE contracts 
ADD COLUMN IF NOT EXISTS paid_amount numeric DEFAULT 0;

-- 2. FUNÇÃO PARA CALCULAR VALOR TOTAL DO CONTRATO

CREATE OR REPLACE FUNCTION fn_calculate_contract_total(p_contract_id uuid)
RETURNS numeric AS $$
DECLARE
  v_total numeric := 0;
  v_daily_rate numeric;
  v_days integer;
  v_contract record;
BEGIN
  -- Buscar dados do contrato
  SELECT * INTO v_contract FROM contracts WHERE id = p_contract_id;
  
  IF NOT FOUND THEN
    RETURN 0;
  END IF;
  
  -- Calcular dias de locação
  v_days := (v_contract.end_date::date - v_contract.start_date::date) + 1;
  
  -- Usar diária do contrato
  v_daily_rate := v_contract.daily_rate;
  
  -- Calcular valor base da locação
  v_total := COALESCE(v_daily_rate, 0) * v_days;
  
  -- Adicionar custos extras do contrato
  v_total := v_total + COALESCE((
    SELECT SUM(amount) 
    FROM costs 
    WHERE contract_id = p_contract_id 
      AND status != 'Cancelado'
  ), 0);
  
  -- Adicionar multas do contrato
  v_total := v_total + COALESCE((
    SELECT SUM(amount) 
    FROM fines 
    WHERE contract_id = p_contract_id 
      AND status != 'Contestado'
  ), 0);
  
  RETURN v_total;
END;
$$ LANGUAGE plpgsql;

-- 3. FUNÇÃO PARA CALCULAR VALOR PAGO DO CONTRATO

CREATE OR REPLACE FUNCTION fn_calculate_contract_paid(p_contract_id uuid)
RETURNS numeric AS $$
BEGIN
  RETURN COALESCE((
    SELECT SUM(amount) 
    FROM costs 
    WHERE contract_id = p_contract_id 
      AND status = 'Pago'
  ), 0);
END;
$$ LANGUAGE plpgsql;

-- 4. FUNÇÃO PARA ATUALIZAR STATUS DE PAGAMENTO

CREATE OR REPLACE FUNCTION fn_update_contract_payment_status(p_contract_id uuid)
RETURNS void AS $$
DECLARE
  v_total numeric;
  v_paid numeric;
  v_status text;
BEGIN
  -- Calcular valores
  v_total := fn_calculate_contract_total(p_contract_id);
  v_paid := fn_calculate_contract_paid(p_contract_id);
  
  -- Determinar status
  IF v_paid >= v_total THEN
    v_status := 'Pago';
  ELSIF v_paid > 0 THEN
    v_status := 'Parcial';
  ELSE
    v_status := 'Pendente';
  END IF;
  
  -- Atualizar contrato
  UPDATE contracts 
  SET 
    total_amount = v_total,
    paid_amount = v_paid,
    payment_status = v_status,
    updated_at = NOW()
  WHERE id = p_contract_id;
END;
$$ LANGUAGE plpgsql;

-- 5. TRIGGER PARA ATUALIZAR STATUS DE PAGAMENTO AUTOMATICAMENTE

CREATE OR REPLACE FUNCTION fn_contract_payment_status_trigger()
RETURNS TRIGGER AS $$
BEGIN
  -- Se é um custo relacionado a um contrato
  IF NEW.contract_id IS NOT NULL THEN
    PERFORM fn_update_contract_payment_status(NEW.contract_id);
  END IF;
  
  -- Se é uma multa relacionada a um contrato
  IF TG_TABLE_NAME = 'fines' AND NEW.contract_id IS NOT NULL THEN
    PERFORM fn_update_contract_payment_status(NEW.contract_id);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para custos
CREATE TRIGGER trg_contract_payment_status_costs
  AFTER INSERT OR UPDATE ON costs
  FOR EACH ROW
  EXECUTE FUNCTION fn_contract_payment_status_trigger();

-- Trigger para multas
CREATE TRIGGER trg_contract_payment_status_fines
  AFTER INSERT OR UPDATE ON fines
  FOR EACH ROW
  EXECUTE FUNCTION fn_contract_payment_status_trigger();

-- 6. FUNÇÃO PARA GERAR COBRANÇAS AUTOMÁTICAS

CREATE OR REPLACE FUNCTION fn_generate_billing_costs(
  p_contract_id uuid DEFAULT NULL,
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid
)
RETURNS TABLE (
  generated_count integer,
  total_amount numeric
) AS $$
DECLARE
  v_contract record;
  v_generated_count integer := 0;
  v_total_amount numeric := 0;
  v_cost record;
BEGIN
  -- Se não especificado contrato, processar todos os contratos ativos
  IF p_contract_id IS NULL THEN
    FOR v_contract IN 
      SELECT * FROM contracts 
      WHERE tenant_id = p_tenant_id 
        AND status = 'Ativo'
        AND payment_status IN ('Pendente', 'Parcial')
    LOOP
      -- Gerar cobrança para custos pendentes
      FOR v_cost IN 
        SELECT * FROM costs 
        WHERE contract_id = v_contract.id 
          AND status = 'Pendente'
          AND origin != 'Manual'
      LOOP
        -- Atualizar status para Autorizado (pronto para cobrança)
        UPDATE costs 
        SET status = 'Autorizado',
            updated_at = NOW()
        WHERE id = v_cost.id;
        
        v_generated_count := v_generated_count + 1;
        v_total_amount := v_total_amount + v_cost.amount;
      END LOOP;
    END LOOP;
  ELSE
    -- Processar contrato específico
    SELECT * INTO v_contract FROM contracts WHERE id = p_contract_id;
    
    IF FOUND THEN
      FOR v_cost IN 
        SELECT * FROM costs 
        WHERE contract_id = p_contract_id 
          AND status = 'Pendente'
          AND origin != 'Manual'
      LOOP
        UPDATE costs 
        SET status = 'Autorizado',
            updated_at = NOW()
        WHERE id = v_cost.id;
        
        v_generated_count := v_generated_count + 1;
        v_total_amount := v_total_amount + v_cost.amount;
      END LOOP;
    END IF;
  END IF;
  
  RETURN QUERY SELECT v_generated_count, v_total_amount;
END;
$$ LANGUAGE plpgsql;

-- 7. VIEW PARA COBRANÇAS DETALHADAS

CREATE OR REPLACE VIEW vw_billing_detailed AS
SELECT 
  c.*,
  ct.contract_number,
  ct.start_date as contract_start,
  ct.end_date as contract_end,
  ct.payment_status as contract_payment_status,
  ct.total_amount as contract_total,
  ct.paid_amount as contract_paid,
  cust.name as customer_name,
  cust.document as customer_document,
  cust.phone as customer_phone,
  v.plate as vehicle_plate,
  v.model as vehicle_model,
  v.year as vehicle_year,
  e.name as created_by_name,
  e.role as created_by_role,
  CASE 
    WHEN c.status = 'Pendente' THEN 'Aguardando Aprovação'
    WHEN c.status = 'Autorizado' THEN 'Pronto para Cobrança'
    WHEN c.status = 'Pago' THEN 'Pago'
    WHEN c.status = 'Cancelado' THEN 'Cancelado'
    ELSE c.status
  END as status_description,
  CASE 
    WHEN c.amount = 0 AND c.status = 'Pendente' THEN true
    ELSE false
  END as is_amount_to_define,
  CASE 
    WHEN ct.payment_status = 'Atrasado' THEN true
    ELSE false
  END as is_overdue
FROM costs c
LEFT JOIN contracts ct ON c.contract_id = ct.id
LEFT JOIN customers cust ON c.customer_id = cust.id
LEFT JOIN vehicles v ON c.vehicle_id = v.id
LEFT JOIN employees e ON c.created_by_employee_id = e.id
WHERE c.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND c.status IN ('Autorizado', 'Pago')
  AND c.origin != 'Manual';

-- 8. FUNÇÃO PARA ESTATÍSTICAS DE COBRANÇA

CREATE OR REPLACE FUNCTION fn_billing_statistics(
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid
)
RETURNS TABLE (
  total_billing numeric,
  pending_billing numeric,
  paid_billing numeric,
  overdue_billing numeric,
  total_contracts integer,
  active_contracts integer,
  overdue_contracts integer,
  avg_contract_value numeric,
  most_common_cost_category text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(SUM(c.amount) FILTER (WHERE c.status IN ('Autorizado', 'Pago')), 0) as total_billing,
    COALESCE(SUM(c.amount) FILTER (WHERE c.status = 'Autorizado'), 0) as pending_billing,
    COALESCE(SUM(c.amount) FILTER (WHERE c.status = 'Pago'), 0) as paid_billing,
    COALESCE(SUM(c.amount) FILTER (WHERE ct.payment_status = 'Atrasado'), 0) as overdue_billing,
    COUNT(DISTINCT ct.id)::integer as total_contracts,
    COUNT(DISTINCT ct.id) FILTER (WHERE ct.status = 'Ativo')::integer as active_contracts,
    COUNT(DISTINCT ct.id) FILTER (WHERE ct.payment_status = 'Atrasado')::integer as overdue_contracts,
    COALESCE(AVG(ct.total_amount), 0) as avg_contract_value,
    (SELECT category FROM costs WHERE tenant_id = p_tenant_id GROUP BY category ORDER BY COUNT(*) DESC LIMIT 1) as most_common_cost_category
  FROM costs c
  LEFT JOIN contracts ct ON c.contract_id = ct.id
  WHERE c.tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql;

-- 9. ATUALIZAR DADOS EXISTENTES

-- Calcular valores totais para contratos existentes
UPDATE contracts 
SET 
  total_amount = fn_calculate_contract_total(id),
  paid_amount = fn_calculate_contract_paid(id)
WHERE total_amount = 0 OR total_amount IS NULL;

-- Atualizar status de pagamento para contratos existentes
UPDATE contracts 
SET payment_status = CASE 
  WHEN paid_amount >= total_amount THEN 'Pago'
  WHEN paid_amount > 0 THEN 'Parcial'
  ELSE 'Pendente'
END
WHERE payment_status IS NULL OR payment_status = 'Pendente';

-- 10. ÍNDICES PARA PERFORMANCE

CREATE INDEX IF NOT EXISTS idx_contracts_payment_status ON contracts(payment_status, status);
CREATE INDEX IF NOT EXISTS idx_costs_billing_status ON costs(status, origin);
CREATE INDEX IF NOT EXISTS idx_contracts_total_paid ON contracts(total_amount, paid_amount);

-- 11. COMENTÁRIOS DE DOCUMENTAÇÃO

COMMENT ON FUNCTION fn_calculate_contract_total IS 'Calcula o valor total de um contrato incluindo diárias, custos e multas';
COMMENT ON FUNCTION fn_calculate_contract_paid IS 'Calcula o valor já pago de um contrato';
COMMENT ON FUNCTION fn_update_contract_payment_status IS 'Atualiza o status de pagamento de um contrato baseado nos valores pagos';
COMMENT ON FUNCTION fn_generate_billing_costs IS 'Gera cobranças automáticas para custos pendentes de contratos';
COMMENT ON FUNCTION fn_billing_statistics IS 'Retorna estatísticas completas de cobrança';

COMMENT ON VIEW vw_billing_detailed IS 'View detalhada de cobranças com informações de contratos, clientes e veículos'; 