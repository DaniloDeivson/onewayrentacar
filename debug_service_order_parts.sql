-- 🔍 DEBUG SERVICE ORDER PARTS - EXECUTE NO SUPABASE SQL EDITOR
-- Este script verifica se os dados estão sendo salvos corretamente

BEGIN;

-- 1. Verificar todas as ordens de serviço
SELECT 
  'Todas as ordens de serviço' as description,
  COUNT(*) as count
FROM service_notes 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'

UNION ALL

SELECT 
  'Ordens com peças' as description,
  COUNT(DISTINCT sop.service_note_id) as count
FROM service_order_parts sop
WHERE sop.tenant_id = '00000000-0000-0000-0000-000000000001';

-- 2. Verificar detalhes das ordens com peças
SELECT 
  sn.id as service_note_id,
  sn.description,
  v.plate as vehicle_plate,
  sn.status,
  COUNT(sop.id) as parts_count,
  COALESCE(SUM(sop.total_cost), 0) as total_cost
FROM service_notes sn
LEFT JOIN vehicles v ON sn.vehicle_id = v.id
LEFT JOIN service_order_parts sop ON sn.id = sop.service_note_id
WHERE sn.tenant_id = '00000000-0000-0000-0000-000000000001'
GROUP BY sn.id, sn.description, v.plate, sn.status
HAVING COUNT(sop.id) > 0
ORDER BY sn.created_at DESC;

-- 3. Verificar peças de uma ordem específica (substitua o ID)
-- SELECT 
--   sop.id,
--   sop.part_id,
--   sop.quantity_used,
--   sop.unit_cost_at_time,
--   sop.total_cost,
--   p.name as part_name,
--   p.sku as part_sku,
--   sn.description as service_note_description
-- FROM service_order_parts sop
-- LEFT JOIN parts p ON sop.part_id = p.id
-- LEFT JOIN service_notes sn ON sop.service_note_id = sn.id
-- WHERE sop.service_note_id = 'ID_DA_ORDEM_AQUI'
-- ORDER BY sop.created_at DESC;

-- 4. Verificar se há problemas de relacionamento
SELECT 
  'Peças sem relacionamento com parts' as issue,
  COUNT(*) as count
FROM service_order_parts sop
LEFT JOIN parts p ON sop.part_id = p.id
WHERE sop.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND p.id IS NULL

UNION ALL

SELECT 
  'Peças sem relacionamento com service_notes' as issue,
  COUNT(*) as count
FROM service_order_parts sop
LEFT JOIN service_notes sn ON sop.service_note_id = sn.id
WHERE sop.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND sn.id IS NULL;

-- 5. Verificar custos gerados
SELECT 
  'Custos gerados por peças' as description,
  COUNT(*) as count
FROM costs c
WHERE c.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND c.source_reference_type = 'service_note'

UNION ALL

SELECT 
  'Custos com source_reference_type incorreto' as description,
  COUNT(*) as count
FROM costs c
WHERE c.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND c.source_reference_type = 'service_order_part';

-- 6. Verificar movimentos de estoque
SELECT 
  'Movimentos de estoque por peças' as description,
  COUNT(*) as count
FROM stock_movements sm
WHERE sm.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND sm.service_note_id IS NOT NULL

UNION ALL

SELECT 
  'Movimentos de estoque sem service_note_id' as description,
  COUNT(*) as count
FROM stock_movements sm
WHERE sm.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND sm.service_note_id IS NULL
  AND sm.type = 'Saída';

-- 7. Teste de inserção manual (opcional)
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
--     RAISE NOTICE 'Testando inserção com Service Note: % e Part: %', test_service_note_id, test_part_id;
--     
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

-- ✅ DEBUG CONCLUÍDO
-- Verifique os resultados para identificar problemas 