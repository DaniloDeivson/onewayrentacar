-- 🧪 TESTE DE DADOS PARA O FRONTEND - EXECUTE NO SUPABASE SQL EDITOR
-- Este script simula exatamente o que o frontend deveria buscar

BEGIN;

-- 1. Simular a query do hook useServiceOrderParts
-- Esta é exatamente a query que o frontend executa
SELECT 
  'Query do Frontend (useServiceOrderParts)' as test_name,
  COUNT(*) as result_count
FROM service_order_parts sop
WHERE sop.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND sop.service_note_id = '23de9fe1-16d5-4028-95e0-4dd3ce91637c';

-- 2. Dados completos que o frontend deveria receber
SELECT 
  sop.id,
  sop.service_note_id,
  sop.part_id,
  sop.quantity_used,
  sop.unit_cost_at_time,
  sop.total_cost,
  sop.created_at,
  p.sku,
  p.name,
  p.quantity as part_stock_quantity
FROM service_order_parts sop
LEFT JOIN parts p ON sop.part_id = p.id
WHERE sop.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND sop.service_note_id = '23de9fe1-16d5-4028-95e0-4dd3ce91637c'
ORDER BY sop.created_at DESC;

-- 3. Verificar se a ordem de serviço existe
SELECT 
  'Ordem de Serviço Existe' as check_name,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ SIM'
    ELSE '❌ NÃO'
  END as result
FROM service_notes sn
WHERE sn.id = '23de9fe1-16d5-4028-95e0-4dd3ce91637c'
  AND sn.tenant_id = '00000000-0000-0000-0000-000000000001'

UNION ALL

SELECT 
  'Peças na Ordem' as check_name,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ SIM (' || COUNT(*) || ' peças)'
    ELSE '❌ NÃO'
  END as result
FROM service_order_parts sop
WHERE sop.service_note_id = '23de9fe1-16d5-4028-95e0-4dd3ce91637c'
  AND sop.tenant_id = '00000000-0000-0000-0000-000000000001';

-- 4. Testar com outras ordens de serviço
SELECT 
  'Outras Ordens com Peças' as test_name,
  sn.id as service_note_id,
  sn.description,
  COUNT(sop.id) as parts_count
FROM service_notes sn
LEFT JOIN service_order_parts sop ON sn.id = sop.service_note_id
WHERE sn.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND sop.id IS NOT NULL
GROUP BY sn.id, sn.description
ORDER BY sn.created_at DESC;

-- 5. Verificar RLS (Row Level Security)
SELECT 
  'RLS Policies Ativas' as check_name,
  COUNT(*) as policy_count
FROM pg_policies 
WHERE tablename = 'service_order_parts';

-- 6. Testar permissões (simular usuário autenticado)
-- Esta query deve funcionar se as políticas RLS estão corretas
SELECT 
  'Teste de Permissão RLS' as test_name,
  COUNT(*) as accessible_records
FROM service_order_parts sop
WHERE sop.tenant_id = '00000000-0000-0000-0000-000000000001';

COMMIT;

-- ✅ TESTE FRONTEND CONCLUÍDO
-- Se a query 1 retornar 0, há problema de RLS ou dados
-- Se retornar > 0, o problema está no frontend 