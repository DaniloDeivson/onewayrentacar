-- 🔧 RECRIAR MOVIMENTOS DE ESTOQUE FALTANTES - EXECUTE NO SUPABASE SQL EDITOR
-- Este script recria os movimentos de estoque que não foram registrados anteriormente

BEGIN;

-- 1. Verificar quantos registros de service_order_parts não têm movimentos de estoque
SELECT 
  'service_order_parts without stock movements' as description,
  COUNT(*) as count
FROM service_order_parts sop
WHERE sop.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND NOT EXISTS (
    SELECT 1 FROM stock_movements sm 
    WHERE sm.part_id = sop.part_id 
    AND sm.service_note_id = sop.service_note_id
    AND sm.type = 'Saída'
  );

-- 2. Recriar movimentos de estoque faltantes
INSERT INTO stock_movements (
  tenant_id,
  part_id,
  service_note_id,
  type,
  quantity,
  movement_date,
  created_at
)
SELECT 
  sop.tenant_id,
  sop.part_id,
  sop.service_note_id,
  'Saída' as type,
  sop.quantity_used,
  sop.created_at::date as movement_date,
  sop.created_at
FROM service_order_parts sop
WHERE sop.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND NOT EXISTS (
    SELECT 1 FROM stock_movements sm 
    WHERE sm.part_id = sop.part_id 
    AND sm.service_note_id = sop.service_note_id
    AND sm.type = 'Saída'
  );

-- 3. Verificar se os movimentos foram criados
SELECT 
  'stock_movements created' as description,
  COUNT(*) as count
FROM stock_movements 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
  AND service_note_id IS NOT NULL;

-- 4. Verificar detalhes dos movimentos criados
SELECT 
  sm.id,
  sm.part_id,
  sm.service_note_id,
  sm.type,
  sm.quantity,
  sm.movement_date,
  p.name as part_name,
  p.sku as part_sku,
  sn.description as service_note_description
FROM stock_movements sm
LEFT JOIN parts p ON sm.part_id = p.id
LEFT JOIN service_notes sn ON sm.service_note_id = sn.id
WHERE sm.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND sm.service_note_id IS NOT NULL
ORDER BY sm.created_at DESC
LIMIT 10;

COMMIT;

-- ✅ MOVIMENTOS DE ESTOQUE RECRIADOS
-- Agora todos os registros de service_order_parts devem ter seus movimentos de estoque correspondentes 