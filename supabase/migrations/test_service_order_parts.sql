-- 🧪 TESTE DO SISTEMA DE PEÇAS UTILIZADAS - EXECUTE NO SUPABASE SQL EDITOR
-- Este script testa se o sistema de peças utilizadas está funcionando corretamente

BEGIN;

-- 1. Verificar se a tabela existe
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'service_order_parts'
ORDER BY ordinal_position;

-- 2. Verificar se as políticas RLS estão ativas
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'service_order_parts';

-- 3. Verificar se os triggers estão funcionando
SELECT 
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers 
WHERE trigger_name LIKE '%service_order_parts%';

-- 4. Verificar dados de teste (se existirem)
SELECT 
  sop.id,
  sop.service_note_id,
  sop.part_id,
  sop.quantity_used,
  sop.unit_cost_at_time,
  sop.total_cost,
  p.name as part_name,
  p.sku as part_sku,
  sn.description as service_note_description,
  v.plate as vehicle_plate
FROM service_order_parts sop
LEFT JOIN parts p ON sop.part_id = p.id
LEFT JOIN service_notes sn ON sop.service_note_id = sn.id
LEFT JOIN vehicles v ON sn.vehicle_id = v.id
WHERE sop.tenant_id = '00000000-0000-0000-0000-000000000001'
ORDER BY sop.created_at DESC
LIMIT 10;

-- 5. Verificar custos gerados automaticamente
SELECT 
  c.id,
  c.category,
  c.description,
  c.amount,
  c.origin,
  c.source_reference_type,
  c.source_reference_id,
  c.created_at
FROM costs c
WHERE c.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND c.source_reference_type = 'service_note'
ORDER BY c.created_at DESC
LIMIT 10;

-- 6. Verificar movimentos de estoque
SELECT 
  sm.id,
  sm.part_id,
  sm.service_note_id,
  sm.type,
  sm.quantity,
  sm.movement_date,
  p.name as part_name,
  p.sku as part_sku
FROM stock_movements sm
LEFT JOIN parts p ON sm.part_id = p.id
WHERE sm.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND sm.service_note_id IS NOT NULL
ORDER BY sm.created_at DESC
LIMIT 10;

-- 7. Contar registros por tabela
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

COMMIT;

-- ✅ TESTE CONCLUÍDO
-- Verifique os resultados acima para confirmar que o sistema está funcionando 