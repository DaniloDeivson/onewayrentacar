-- FASE 2: TESTES DE INTEGRAÇÃO END-TO-END
-- Data: 2025-06-30 24:00:00
-- Descrição: Testes automatizados para validar correções da Fase 2

-- 1. FUNÇÃO DE TESTE PARA SISTEMA DE COBRANÇA

CREATE OR REPLACE FUNCTION fn_test_billing_integration()
RETURNS TABLE (
  test_name text,
  status text,
  message text
) AS $$
DECLARE
  v_test_contract_id uuid;
  v_test_vehicle_id uuid;
  v_test_customer_id uuid;
  v_test_cost_id uuid;
  v_test_fine_id uuid;
  v_total_before numeric;
  v_total_after numeric;
  v_paid_before numeric;
  v_paid_after numeric;
BEGIN
  -- Teste 1: Verificar se contratos têm status de pagamento
  BEGIN
    SELECT COUNT(*) INTO v_total_before FROM contracts WHERE payment_status IS NULL;
    IF v_total_before > 0 THEN
      RETURN QUERY SELECT 
        'Contratos sem status de pagamento'::text,
        'FALHOU'::text,
        'Existem ' || v_total_before || ' contratos sem status de pagamento'::text;
    ELSE
      RETURN QUERY SELECT 
        'Contratos sem status de pagamento'::text,
        'PASSOU'::text,
        'Todos os contratos têm status de pagamento'::text;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Contratos sem status de pagamento'::text,
      'ERRO'::text,
      'Erro ao verificar status de pagamento: ' || SQLERRM::text;
  END;

  -- Teste 2: Verificar se custos automáticos são gerados
  BEGIN
    SELECT COUNT(*) INTO v_total_before 
    FROM costs 
    WHERE origin IN ('Patio', 'Manutencao') 
      AND status = 'Pendente';
    
    IF v_total_before > 0 THEN
      RETURN QUERY SELECT 
        'Custos automáticos pendentes'::text,
        'PASSOU'::text,
        'Existem ' || v_total_before || ' custos automáticos pendentes'::text;
    ELSE
      RETURN QUERY SELECT 
        'Custos automáticos pendentes'::text,
        'AVISO'::text,
        'Nenhum custo automático pendente encontrado'::text;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Custos automáticos pendentes'::text,
      'ERRO'::text,
      'Erro ao verificar custos automáticos: ' || SQLERRM::text;
  END;

  -- Teste 3: Verificar se multas estão associadas a contratos
  BEGIN
    SELECT COUNT(*) INTO v_total_before 
    FROM fines 
    WHERE contract_id IS NOT NULL;
    
    SELECT COUNT(*) INTO v_total_after 
    FROM fines;
    
    IF v_total_after > 0 THEN
      IF v_total_before > 0 THEN
        RETURN QUERY SELECT 
          'Multas associadas a contratos'::text,
          'PASSOU'::text,
          v_total_before || ' de ' || v_total_after || ' multas associadas a contratos'::text;
      ELSE
        RETURN QUERY SELECT 
          'Multas associadas a contratos'::text,
          'AVISO'::text,
          'Nenhuma multa associada a contratos'::text;
      END IF;
    ELSE
      RETURN QUERY SELECT 
        'Multas associadas a contratos'::text,
        'AVISO'::text,
        'Nenhuma multa encontrada no sistema'::text;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Multas associadas a contratos'::text,
      'ERRO'::text,
      'Erro ao verificar multas: ' || SQLERRM::text;
  END;

  -- Teste 4: Verificar se views estão funcionando
  BEGIN
    SELECT COUNT(*) INTO v_total_before FROM vw_costs_detailed;
    RETURN QUERY SELECT 
      'View de custos detalhados'::text,
      'PASSOU'::text,
      'View retorna ' || v_total_before || ' registros'::text;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'View de custos detalhados'::text,
      'FALHOU'::text,
      'Erro na view: ' || SQLERRM::text;
  END;

  BEGIN
    SELECT COUNT(*) INTO v_total_before FROM vw_fines_detailed;
    RETURN QUERY SELECT 
      'View de multas detalhadas'::text,
      'PASSOU'::text,
      'View retorna ' || v_total_before || ' registros'::text;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'View de multas detalhadas'::text,
      'FALHOU'::text,
      'Erro na view: ' || SQLERRM::text;
  END;

  BEGIN
    SELECT COUNT(*) INTO v_total_before FROM vw_billing_detailed;
    RETURN QUERY SELECT 
      'View de cobranças detalhadas'::text,
      'PASSOU'::text,
      'View retorna ' || v_total_before || ' registros'::text;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'View de cobranças detalhadas'::text,
      'FALHOU'::text,
      'Erro na view: ' || SQLERRM::text;
  END;

  -- Teste 5: Verificar se triggers estão funcionando
  BEGIN
    -- Verificar se trigger de atualização de quantidade de peças existe
    SELECT COUNT(*) INTO v_total_before 
    FROM information_schema.triggers 
    WHERE trigger_name = 'trg_update_part_quantity';
    
    IF v_total_before > 0 THEN
      RETURN QUERY SELECT 
        'Trigger de atualização de peças'::text,
        'PASSOU'::text,
        'Trigger está ativo'::text;
    ELSE
      RETURN QUERY SELECT 
        'Trigger de atualização de peças'::text,
        'FALHOU'::text,
        'Trigger não encontrado'::text;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Trigger de atualização de peças'::text,
      'ERRO'::text,
      'Erro ao verificar trigger: ' || SQLERRM::text;
  END;

  BEGIN
    -- Verificar se trigger de geração de custos de danos existe
    SELECT COUNT(*) INTO v_total_before 
    FROM information_schema.triggers 
    WHERE trigger_name = 'trg_generate_damage_cost';
    
    IF v_total_before > 0 THEN
      RETURN QUERY SELECT 
        'Trigger de geração de custos de danos'::text,
        'PASSOU'::text,
        'Trigger está ativo'::text;
    ELSE
      RETURN QUERY SELECT 
        'Trigger de geração de custos de danos'::text,
        'FALHOU'::text,
        'Trigger não encontrado'::text;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Trigger de geração de custos de danos'::text,
      'ERRO'::text,
      'Erro ao verificar trigger: ' || SQLERRM::text;
  END;

  -- Teste 6: Verificar se funções RPC estão funcionando
  BEGIN
    SELECT COUNT(*) INTO v_total_before 
    FROM fn_inspection_statistics();
    RETURN QUERY SELECT 
      'Função de estatísticas de inspeções'::text,
      'PASSOU'::text,
      'Função retorna dados corretamente'::text;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Função de estatísticas de inspeções'::text,
      'FALHOU'::text,
      'Erro na função: ' || SQLERRM::text;
  END;

  BEGIN
    SELECT COUNT(*) INTO v_total_before 
    FROM fn_fines_statistics();
    RETURN QUERY SELECT 
      'Função de estatísticas de multas'::text,
      'PASSOU'::text,
      'Função retorna dados corretamente'::text;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Função de estatísticas de multas'::text,
      'FALHOU'::text,
      'Erro na função: ' || SQLERRM::text;
  END;

  BEGIN
    SELECT COUNT(*) INTO v_total_before 
    FROM fn_billing_statistics();
    RETURN QUERY SELECT 
      'Função de estatísticas de cobrança'::text,
      'PASSOU'::text,
      'Função retorna dados corretamente'::text;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Função de estatísticas de cobrança'::text,
      'FALHOU'::text,
      'Erro na função: ' || SQLERRM::text;
  END;

  -- Teste 7: Verificar integridade dos dados
  BEGIN
    -- Verificar se há custos sem veículo
    SELECT COUNT(*) INTO v_total_before 
    FROM costs 
    WHERE vehicle_id IS NULL AND origin != 'Manual';
    
    IF v_total_before > 0 THEN
      RETURN QUERY SELECT 
        'Custos sem veículo associado'::text,
        'AVISO'::text,
        v_total_before || ' custos sem veículo associado'::text;
    ELSE
      RETURN QUERY SELECT 
        'Custos sem veículo associado'::text,
        'PASSOU'::text,
        'Todos os custos têm veículo associado'::text;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Custos sem veículo associado'::text,
      'ERRO'::text,
      'Erro ao verificar integridade: ' || SQLERRM::text;
  END;

  -- Teste 8: Verificar performance dos índices
  BEGIN
    SELECT COUNT(*) INTO v_total_before 
    FROM pg_indexes 
    WHERE indexname LIKE 'idx_%' 
      AND tablename IN ('costs', 'fines', 'contracts', 'stock_movements');
    
    IF v_total_before >= 5 THEN
      RETURN QUERY SELECT 
        'Índices de performance'::text,
        'PASSOU'::text,
        v_total_before || ' índices encontrados'::text;
    ELSE
      RETURN QUERY SELECT 
        'Índices de performance'::text,
        'AVISO'::text,
        'Poucos índices encontrados: ' || v_total_before::text;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Índices de performance'::text,
      'ERRO'::text,
      'Erro ao verificar índices: ' || SQLERRM::text;
  END;

END;
$$ LANGUAGE plpgsql;

-- 2. FUNÇÃO DE TESTE PARA VALIDAÇÃO DE CÁLCULOS

CREATE OR REPLACE FUNCTION fn_test_calculation_accuracy()
RETURNS TABLE (
  test_name text,
  status text,
  expected numeric,
  actual numeric,
  difference numeric
) AS $$
DECLARE
  v_contract record;
  v_calculated_total numeric;
  v_stored_total numeric;
  v_calculated_paid numeric;
  v_stored_paid numeric;
BEGIN
  -- Testar cálculos para cada contrato
  FOR v_contract IN 
    SELECT id, total_amount, paid_amount 
    FROM contracts 
    WHERE status = 'Ativo' 
    LIMIT 10
  LOOP
    -- Calcular total usando função
    v_calculated_total := fn_calculate_contract_total(v_contract.id);
    v_stored_total := COALESCE(v_contract.total_amount, 0);
    
    -- Calcular pago usando função
    v_calculated_paid := fn_calculate_contract_paid(v_contract.id);
    v_stored_paid := COALESCE(v_contract.paid_amount, 0);
    
    -- Verificar diferença no total
    IF ABS(v_calculated_total - v_stored_total) > 0.01 THEN
      RETURN QUERY SELECT 
        'Cálculo total contrato ' || v_contract.id::text::text,
        'FALHOU'::text,
        v_calculated_total,
        v_stored_total,
        v_calculated_total - v_stored_total;
    ELSE
      RETURN QUERY SELECT 
        'Cálculo total contrato ' || v_contract.id::text::text,
        'PASSOU'::text,
        v_calculated_total,
        v_stored_total,
        0::numeric;
    END IF;
    
    -- Verificar diferença no pago
    IF ABS(v_calculated_paid - v_stored_paid) > 0.01 THEN
      RETURN QUERY SELECT 
        'Cálculo pago contrato ' || v_contract.id::text::text,
        'FALHOU'::text,
        v_calculated_paid,
        v_stored_paid,
        v_calculated_paid - v_stored_paid;
    ELSE
      RETURN QUERY SELECT 
        'Cálculo pago contrato ' || v_contract.id::text::text,
        'PASSOU'::text,
        v_calculated_paid,
        v_stored_paid,
        0::numeric;
    END IF;
  END LOOP;
  
  -- Se não há contratos, retornar teste vazio
  IF NOT FOUND THEN
    RETURN QUERY SELECT 
      'Nenhum contrato para testar'::text,
      'AVISO'::text,
      0::numeric,
      0::numeric,
      0::numeric;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 3. FUNÇÃO DE TESTE PARA VALIDAÇÃO DE TRIGGERS

CREATE OR REPLACE FUNCTION fn_test_trigger_functionality()
RETURNS TABLE (
  test_name text,
  status text,
  message text
) AS $$
DECLARE
  v_test_part_id uuid;
  v_test_inspection_id uuid;
  v_quantity_before integer;
  v_quantity_after integer;
  v_cost_count_before integer;
  v_cost_count_after integer;
BEGIN
  -- Teste de trigger de movimentação de estoque
  BEGIN
    -- Buscar uma peça para teste
    SELECT id, quantity INTO v_test_part_id, v_quantity_before 
    FROM parts 
    WHERE quantity > 0 
    LIMIT 1;
    
    IF v_test_part_id IS NOT NULL THEN
      -- Inserir movimentação de saída
      INSERT INTO stock_movements (
        tenant_id,
        part_id,
        type,
        quantity,
        movement_date,
        reason
      ) VALUES (
        '00000000-0000-0000-0000-000000000001'::uuid,
        v_test_part_id,
        'Saída',
        1,
        NOW()::date,
        'Teste de trigger'
      );
      
      -- Verificar se quantidade foi atualizada
      SELECT quantity INTO v_quantity_after FROM parts WHERE id = v_test_part_id;
      
      IF v_quantity_after = v_quantity_before - 1 THEN
        RETURN QUERY SELECT 
          'Trigger de movimentação de estoque'::text,
          'PASSOU'::text,
          'Quantidade atualizada corretamente'::text;
      ELSE
        RETURN QUERY SELECT 
          'Trigger de movimentação de estoque'::text,
          'FALHOU'::text,
          'Quantidade não foi atualizada corretamente'::text;
      END IF;
      
      -- Limpar teste
      DELETE FROM stock_movements WHERE reason = 'Teste de trigger';
    ELSE
      RETURN QUERY SELECT 
        'Trigger de movimentação de estoque'::text,
        'AVISO'::text,
        'Nenhuma peça disponível para teste'::text;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Trigger de movimentação de estoque'::text,
      'ERRO'::text,
      'Erro no teste: ' || SQLERRM::text;
  END;

  -- Teste de trigger de geração de custos de danos
  BEGIN
    -- Buscar uma inspeção para teste
    SELECT id INTO v_test_inspection_id 
    FROM inspections 
    WHERE inspection_type = 'CheckOut'
    LIMIT 1;
    
    IF v_test_inspection_id IS NOT NULL THEN
      -- Contar custos antes
      SELECT COUNT(*) INTO v_cost_count_before 
      FROM costs 
      WHERE source_reference_type = 'inspection_item';
      
      -- Inserir item de inspeção com dano
      INSERT INTO inspection_items (
        tenant_id,
        inspection_id,
        description,
        severity,
        location
      ) VALUES (
        '00000000-0000-0000-0000-000000000001'::uuid,
        v_test_inspection_id,
        'Dano de teste',
        'Média',
        'Dianteira'
      );
      
      -- Contar custos depois
      SELECT COUNT(*) INTO v_cost_count_after 
      FROM costs 
      WHERE source_reference_type = 'inspection_item';
      
      IF v_cost_count_after > v_cost_count_before THEN
        RETURN QUERY SELECT 
          'Trigger de geração de custos de danos'::text,
          'PASSOU'::text,
          'Custo gerado automaticamente'::text;
      ELSE
        RETURN QUERY SELECT 
          'Trigger de geração de custos de danos'::text,
          'FALHOU'::text,
          'Custo não foi gerado automaticamente'::text;
      END IF;
      
      -- Limpar teste
      DELETE FROM inspection_items WHERE description = 'Dano de teste';
      DELETE FROM costs WHERE description LIKE '%Dano de teste%';
    ELSE
      RETURN QUERY SELECT 
        'Trigger de geração de custos de danos'::text,
        'AVISO'::text,
        'Nenhuma inspeção disponível para teste'::text;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
      'Trigger de geração de custos de danos'::text,
      'ERRO'::text,
      'Erro no teste: ' || SQLERRM::text;
  END;

END;
$$ LANGUAGE plpgsql;

-- 4. FUNÇÃO PRINCIPAL DE TESTE

CREATE OR REPLACE FUNCTION fn_run_phase2_tests()
RETURNS TABLE (
  test_suite text,
  test_name text,
  status text,
  message text,
  details text
) AS $$
BEGIN
  -- Executar testes de integração
  RETURN QUERY 
  SELECT 
    'Integração'::text,
    t.test_name,
    t.status,
    t.message,
    ''::text
  FROM fn_test_billing_integration() t;
  
  -- Executar testes de cálculo
  RETURN QUERY 
  SELECT 
    'Cálculos'::text,
    t.test_name,
    t.status,
    CASE 
      WHEN t.status = 'PASSOU' THEN 'Cálculo correto'
      WHEN t.status = 'FALHOU' THEN 'Diferença: R$ ' || t.difference::text
      ELSE 'Teste não executado'
    END,
    'Esperado: R$ ' || t.expected::text || ' | Atual: R$ ' || t.actual::text
  FROM fn_test_calculation_accuracy() t;
  
  -- Executar testes de triggers
  RETURN QUERY 
  SELECT 
    'Triggers'::text,
    t.test_name,
    t.status,
    t.message,
    ''::text
  FROM fn_test_trigger_functionality() t;
END;
$$ LANGUAGE plpgsql;

-- 5. COMENTÁRIOS DE DOCUMENTAÇÃO

COMMENT ON FUNCTION fn_test_billing_integration IS 'Testa integração do sistema de cobrança';
COMMENT ON FUNCTION fn_test_calculation_accuracy IS 'Testa precisão dos cálculos automáticos';
COMMENT ON FUNCTION fn_test_trigger_functionality IS 'Testa funcionamento dos triggers';
COMMENT ON FUNCTION fn_run_phase2_tests IS 'Executa todos os testes da Fase 2'; 