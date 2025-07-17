-- 🎯 TESTE FINAL - SISTEMA DE PEÇAS UTILIZADAS - EXECUTE NO SUPABASE SQL EDITOR
-- Este script confirma que o sistema está 100% funcional

BEGIN;

-- 1. Contagem final de registros
SELECT 
  'service_order_parts' as table_name,
  COUNT(*) as record_count
FROM service_order_parts 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'

UNION ALL

SELECT 
  'stock_movements (service_note)' as table_name,
  COUNT(*) as record_count
FROM stock_movements 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
  AND service_note_id IS NOT NULL

UNION ALL

SELECT 
  'costs (service_note)' as table_name,
  COUNT(*) as record_count
FROM costs 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
  AND source_reference_type = 'service_note';

-- 2. Verificar integridade dos dados
SELECT 
  'service_order_parts without stock movements' as issue,
  COUNT(*) as count
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
  'service_order_parts without costs' as issue,
  COUNT(*) as count
FROM service_order_parts sop
WHERE sop.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND NOT EXISTS (
    SELECT 1 FROM costs c 
    WHERE c.source_reference_id = sop.service_note_id
    AND c.source_reference_type = 'service_note'
  );

-- 3. Resumo por ordem de serviço
SELECT 
  sn.description as service_note_description,
  COUNT(sop.id) as parts_used,
  COUNT(sm.id) as stock_movements,
  COUNT(c.id) as costs_generated,
  SUM(sop.total_cost) as total_cost
FROM service_notes sn
LEFT JOIN service_order_parts sop ON sn.id = sop.service_note_id
LEFT JOIN stock_movements sm ON sop.part_id = sm.part_id AND sop.service_note_id = sm.service_note_id
LEFT JOIN costs c ON sn.id = c.source_reference_id AND c.source_reference_type = 'service_note'
WHERE sn.tenant_id = '00000000-0000-0000-0000-000000000001'
GROUP BY sn.id, sn.description
ORDER BY sn.created_at DESC;

-- 4. Verificar se os triggers estão ativos
SELECT 
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers 
WHERE trigger_name LIKE '%service_order_parts%';

COMMIT;

-- ✅ SISTEMA VERIFICADO
-- Se todos os números coincidem, o sistema está 100% funcional! 