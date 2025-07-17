-- 🔍 DEBUG SIMPLES - SISTEMA DE PEÇAS UTILIZADAS - EXECUTE NO SUPABASE SQL EDITOR
-- Este script verifica de forma simples se o sistema está funcionando

BEGIN;

-- 1. Contagem básica
SELECT 
  'service_notes' as table_name,
  COUNT(*) as record_count
FROM service_notes 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'

UNION ALL

SELECT 
  'service_order_parts' as table_name,
  COUNT(*) as record_count
FROM service_order_parts 
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

-- 2. Verificar ordens de serviço existentes
SELECT 
  id,
  description,
  status,
  created_at
FROM service_notes 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
ORDER BY created_at DESC
LIMIT 5;

-- 3. Verificar peças utilizadas
SELECT 
  sop.id,
  sop.service_note_id,
  sop.part_id,
  sop.quantity_used,
  sop.unit_cost_at_time,
  p.name as part_name,
  p.sku as part_sku,
  sn.description as service_note_description
FROM service_order_parts sop
LEFT JOIN parts p ON sop.part_id = p.id
LEFT JOIN service_notes sn ON sop.service_note_id = sn.id
WHERE sop.tenant_id = '00000000-0000-0000-0000-000000000001'
ORDER BY sop.created_at DESC
LIMIT 10;

-- 4. Verificar custos gerados
SELECT 
  id,
  category,
  description,
  amount,
  source_reference_id,
  source_reference_type,
  created_at
FROM costs 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
  AND source_reference_type = 'service_note'
ORDER BY created_at DESC
LIMIT 5;

-- 5. Verificar movimentos de estoque
SELECT 
  id,
  part_id,
  service_note_id,
  type,
  quantity,
  movement_date
FROM stock_movements 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
  AND service_note_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;

COMMIT;

-- ✅ DEBUG SIMPLES CONCLUÍDO 