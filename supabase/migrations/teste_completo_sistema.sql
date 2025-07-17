-- 🧪 TESTE COMPLETO DO SISTEMA - EXECUTE NO SUPABASE SQL EDITOR
-- Este script testa todo o fluxo do sistema de peças utilizadas

BEGIN;

-- 1. Verificar estrutura das tabelas
SELECT 
  'service_order_parts' as table_name,
  COUNT(*) as record_count
FROM service_order_parts 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'

UNION ALL

SELECT 
  'service_notes' as table_name,
  COUNT(*) as record_count
FROM service_notes 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'

UNION ALL

SELECT 
  'parts' as table_name,
  COUNT(*) as record_count
FROM parts 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'

UNION ALL

SELECT 
  'costs (service_note)' as table_name,
  COUNT(*) as record_count
FROM costs 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
  AND source_reference_type = 'service_note'

UNION ALL

SELECT 
  'stock_movements (service_note)' as table_name,
  COUNT(*) as record_count
FROM stock_movements 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
  AND service_note_id IS NOT NULL;

-- 2. Verificar triggers ativos
SELECT 
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers 
WHERE trigger_name LIKE '%service_order_parts%'
ORDER BY trigger_name;

-- 3. Verificar dados de exemplo
SELECT 
  'Últimas 3 ordens de serviço' as description,
  '' as details
UNION ALL
SELECT 
  sn.description,
  CONCAT('ID: ', sn.id, ' | Veículo: ', v.plate, ' | Status: ', sn.status)
FROM service_notes sn
LEFT JOIN vehicles v ON sn.vehicle_id = v.id
WHERE sn.tenant_id = '00000000-0000-0000-0000-000000000001'
ORDER BY sn.created_at DESC
LIMIT 3;

-- 4. Verificar peças de exemplo
SELECT 
  'Peças disponíveis' as description,
  '' as details
UNION ALL
SELECT 
  p.name,
  CONCAT('SKU: ', p.sku, ' | Estoque: ', p.quantity, ' | Custo: R$ ', p.unit_cost)
FROM parts p
WHERE p.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND p.quantity > 0
ORDER BY p.name
LIMIT 5;

-- 5. Verificar integridade dos dados
SELECT 
  'Verificação de integridade' as check_type,
  CASE 
    WHEN COUNT(*) = 0 THEN '✅ OK - Todos os registros têm movimentos de estoque'
    ELSE CONCAT('⚠️ PROBLEMA - ', COUNT(*), ' registros sem movimentos de estoque')
  END as status
FROM service_order_parts sop
WHERE sop.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND NOT EXISTS (
    SELECT 1 FROM stock_movements sm 
    WHERE sm.part_id = sop.part_id 
    AND sm.service_note_id = sop.service_note_id
    AND sm.type = 'Saída'
  )

UNION ALL

SELECT 
  'Verificação de custos' as check_type,
  CASE 
    WHEN COUNT(*) = 0 THEN '✅ OK - Todos os registros têm custos'
    ELSE CONCAT('⚠️ PROBLEMA - ', COUNT(*), ' registros sem custos')
  END as status
FROM service_order_parts sop
WHERE sop.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND NOT EXISTS (
    SELECT 1 FROM costs c 
    WHERE c.source_reference_id = sop.service_note_id
    AND c.source_reference_type = 'service_note'
  );

-- 6. Teste de inserção manual (opcional - remova após testar)
-- DO $$
-- DECLARE
--   test_tenant_id uuid := '00000000-0000-0000-0000-000000000001';
--   test_service_note_id uuid;
--   test_part_id uuid;
--   test_result text;
-- BEGIN
--   -- Get test data
--   SELECT id INTO test_service_note_id FROM service_notes WHERE tenant_id = test_tenant_id LIMIT 1;
--   SELECT id INTO test_part_id FROM parts WHERE tenant_id = test_tenant_id AND quantity > 0 LIMIT 1;
--   
--   IF test_service_note_id IS NOT NULL AND test_part_id IS NOT NULL THEN
--     -- Insert a test record
--     INSERT INTO service_order_parts (
--       tenant_id,
--       service_note_id,
--       part_id,
--       quantity_used,
--       unit_cost_at_time
--     ) VALUES (
--       test_tenant_id,
--       test_service_note_id,
--       test_part_id,
--       1,
--       10.00
--     );
--     
--     test_result := '✅ Teste de inserção bem-sucedido';
--   ELSE
--     test_result := '❌ Dados de teste não disponíveis';
--   END IF;
--   
--   RAISE NOTICE '%', test_result;
-- END $$;

COMMIT;

-- ✅ TESTE COMPLETO CONCLUÍDO
-- Verifique os resultados acima para confirmar que o sistema está funcionando 