-- SCRIPT DE TESTE COMPLETO - FASE 2
-- Execute este script no SQL Editor do Supabase para testar todas as funcionalidades

-- 1. TESTAR TODAS AS FUNCIONALIDADES DA FASE 2
SELECT 
  '=== RESULTADOS DOS TESTES DA FASE 2 ===' as titulo;

SELECT * FROM fn_run_phase2_tests();

-- 2. TESTAR CÁLCULOS ESPECÍFICOS
SELECT 
  '=== TESTE DE PRECISÃO DOS CÁLCULOS ===' as titulo;

SELECT * FROM fn_test_calculation_accuracy();

-- 3. TESTAR TRIGGERS
SELECT 
  '=== TESTE DE FUNCIONAMENTO DOS TRIGGERS ===' as titulo;

SELECT * FROM fn_test_trigger_functionality();

-- 4. VERIFICAR ESTATÍSTICAS DE COBRANÇA
SELECT 
  '=== ESTATÍSTICAS DE COBRANÇA ===' as titulo;

SELECT * FROM fn_billing_statistics();

-- 5. VERIFICAR ESTATÍSTICAS DE INSPEÇÕES
SELECT 
  '=== ESTATÍSTICAS DE INSPEÇÕES ===' as titulo;

SELECT * FROM fn_inspection_statistics();

-- 6. VERIFICAR ESTATÍSTICAS DE MULTAS
SELECT 
  '=== ESTATÍSTICAS DE MULTAS ===' as titulo;

SELECT * FROM fn_fines_statistics();

-- 7. VERIFICAR VIEWS
SELECT 
  '=== TESTE DAS VIEWS ===' as titulo;

-- Testar view de custos detalhados
SELECT 'vw_costs_detailed' as view_name, COUNT(*) as records FROM vw_costs_detailed
UNION ALL
-- Testar view de multas detalhadas
SELECT 'vw_fines_detailed' as view_name, COUNT(*) as records FROM vw_fines_detailed
UNION ALL
-- Testar view de cobranças detalhadas
SELECT 'vw_billing_detailed' as view_name, COUNT(*) as records FROM vw_billing_detailed
UNION ALL
-- Testar view de check-ins de manutenção
SELECT 'vw_maintenance_checkins_detailed' as view_name, COUNT(*) as records FROM vw_maintenance_checkins_detailed;

-- 8. VERIFICAR CONTRATOS COM STATUS DE PAGAMENTO
SELECT 
  '=== CONTRATOS COM STATUS DE PAGAMENTO ===' as titulo;

SELECT 
  id,
  contract_number,
  payment_status,
  total_amount,
  paid_amount,
  CASE 
    WHEN total_amount > 0 THEN ROUND((paid_amount / total_amount) * 100, 2)
    ELSE 0
  END as percentage_paid
FROM contracts 
WHERE payment_status IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;

-- 9. VERIFICAR CUSTOS AUTOMÁTICOS
SELECT 
  '=== CUSTOS AUTOMÁTICOS GERADOS ===' as titulo;

SELECT 
  origin,
  status,
  COUNT(*) as quantity,
  SUM(amount) as total_amount
FROM costs 
WHERE origin IN ('Patio', 'Manutencao')
GROUP BY origin, status
ORDER BY origin, status;

-- 10. VERIFICAR MULTAS ASSOCIADAS A CONTRATOS
SELECT 
  '=== MULTAS ASSOCIADAS A CONTRATOS ===' as titulo;

SELECT 
  COUNT(*) as total_fines,
  COUNT(contract_id) as fines_with_contract,
  ROUND((COUNT(contract_id)::numeric / COUNT(*)::numeric) * 100, 2) as percentage_associated
FROM fines;

-- 11. VERIFICAR ÍNDICES DE PERFORMANCE
SELECT 
  '=== ÍNDICES DE PERFORMANCE ===' as titulo;

SELECT 
  indexname,
  tablename
FROM pg_indexes 
WHERE indexname LIKE 'idx_%' 
  AND tablename IN ('costs', 'fines', 'contracts', 'stock_movements', 'maintenance_checkins')
ORDER BY tablename, indexname;

-- 12. VERIFICAR INTEGRIDADE DOS DADOS
SELECT 
  '=== VERIFICAÇÃO DE INTEGRIDADE ===' as titulo;

-- Custos sem veículo (exceto manuais)
SELECT 'Custos sem veículo' as check_type, COUNT(*) as count
FROM costs 
WHERE vehicle_id IS NULL AND origin != 'Manual'
UNION ALL
-- Contratos sem status de pagamento
SELECT 'Contratos sem status pagamento' as check_type, COUNT(*) as count
FROM contracts 
WHERE payment_status IS NULL
UNION ALL
-- Funcionários inativos
SELECT 'Funcionários inativos' as check_type, COUNT(*) as count
FROM employees 
WHERE active = false;

-- 13. RESUMO FINAL
SELECT 
  '=== RESUMO FINAL DO SISTEMA ===' as titulo;

SELECT 
  'Contratos Ativos' as metric,
  COUNT(*) as value
FROM contracts 
WHERE status = 'Ativo'
UNION ALL
SELECT 
  'Custos Pendentes' as metric,
  COUNT(*) as value
FROM costs 
WHERE status = 'Pendente'
UNION ALL
SELECT 
  'Custos Autorizados' as metric,
  COUNT(*) as value
FROM costs 
WHERE status = 'Autorizado'
UNION ALL
SELECT 
  'Multas Pendentes' as metric,
  COUNT(*) as value
FROM fines 
WHERE status = 'Pendente'
UNION ALL
SELECT 
  'Veículos em Manutenção' as metric,
  COUNT(*) as value
FROM vehicles 
WHERE maintenance_status = 'In_Maintenance'
UNION ALL
SELECT 
  'Funcionários Ativos' as metric,
  COUNT(*) as value
FROM employees 
WHERE active = true;

-- MENSAGEM FINAL
SELECT 
  '=== TESTES CONCLUÍDOS ===' as titulo,
  'Se todos os testes passaram, o sistema está funcionando corretamente!' as mensagem; 