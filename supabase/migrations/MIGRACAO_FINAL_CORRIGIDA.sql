-- 🔧 MIGRAÇÃO FINAL CORRIGIDA PARA ERRO 400 DE CUSTOS
-- Execute este SQL no Supabase SQL Editor

-- 1. Verificar estrutura atual da tabela
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'costs' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Adicionar colunas faltantes se não existirem
ALTER TABLE public.costs ADD COLUMN IF NOT EXISTS department text;
ALTER TABLE public.costs ADD COLUMN IF NOT EXISTS customer_id text;
ALTER TABLE public.costs ADD COLUMN IF NOT EXISTS customer_name text;
ALTER TABLE public.costs ADD COLUMN IF NOT EXISTS contract_id text;
ALTER TABLE public.costs ADD COLUMN IF NOT EXISTS source_reference_id text;
ALTER TABLE public.costs ADD COLUMN IF NOT EXISTS source_reference_type text;

-- 3. Remover constraints restritivas antigas
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_category_check;
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_origin_check;
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_status_check;
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_category_constraint;
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_origin_constraint;
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_status_constraint;

-- 4. Criar constraints atualizadas que aceitam todos os valores
ALTER TABLE public.costs ADD CONSTRAINT costs_category_check 
  CHECK (category IN ('Multa', 'Funilaria', 'Seguro', 'Avulsa', 'Compra', 'Excesso Km', 'Diária Extra', 'Combustível', 'Avaria'));

ALTER TABLE public.costs ADD CONSTRAINT costs_origin_check 
  CHECK (origin IN ('Manual', 'Patio', 'Manutencao', 'Sistema', 'Compras'));

ALTER TABLE public.costs ADD CONSTRAINT costs_status_check 
  CHECK (status IN ('Pendente', 'Pago', 'Autorizado'));

-- 5. Verificar se as constraints foram criadas
SELECT constraint_name, constraint_type 
FROM information_schema.table_constraints 
WHERE table_name = 'costs' AND table_schema = 'public'
AND constraint_type = 'CHECK';

-- 6. Teste com UUID correto (DEFAULT_TENANT_ID do código)
INSERT INTO public.costs (
  tenant_id, category, vehicle_id, description, amount, cost_date, status, origin
) VALUES (
  '00000000-0000-0000-0000-000000000001'::uuid,  -- UUID correto do código
  'Compra', 
  (SELECT id FROM public.vehicles WHERE tenant_id = '00000000-0000-0000-0000-000000000001'::uuid LIMIT 1), 
  'Teste migração - categoria Compra', 
  1.00, 
  CURRENT_DATE, 
  'Autorizado', 
  'Compras'
) RETURNING id, category, origin, status;

-- 7. Teste adicional com origem Compras
INSERT INTO public.costs (
  tenant_id, category, vehicle_id, description, amount, cost_date, status, origin
) VALUES (
  '00000000-0000-0000-0000-000000000001'::uuid,
  'Avulsa', 
  (SELECT id FROM public.vehicles WHERE tenant_id = '00000000-0000-0000-0000-000000000001'::uuid LIMIT 1), 
  'Teste migração - origem Compras', 
  1.00, 
  CURRENT_DATE, 
  'Pendente', 
  'Compras'
) RETURNING id, category, origin, status;

-- 8. Teste com status Autorizado
INSERT INTO public.costs (
  tenant_id, category, vehicle_id, description, amount, cost_date, status, origin
) VALUES (
  '00000000-0000-0000-0000-000000000001'::uuid,
  'Seguro', 
  (SELECT id FROM public.vehicles WHERE tenant_id = '00000000-0000-0000-0000-000000000001'::uuid LIMIT 1), 
  'Teste migração - status Autorizado', 
  1.00, 
  CURRENT_DATE, 
  'Autorizado', 
  'Manual'
) RETURNING id, category, origin, status;

-- 9. Comentário de documentação
COMMENT ON TABLE public.costs IS 'Tabela de custos atualizada para suportar todas as categorias e status - UUID: 00000000-0000-0000-0000-000000000001';

-- 10. Verificar resultados
SELECT 
  id, category, origin, status, description, created_at
FROM public.costs 
WHERE description LIKE '%Teste migração%'
ORDER BY created_at DESC;

-- 11. Verificar total de custos
SELECT COUNT(*) as total_costs FROM public.costs;

-- 12. Verificar se podemos inserir todos os novos valores
SELECT 
  'Categoria Compra' as teste,
  CASE 
    WHEN EXISTS(SELECT 1 FROM public.costs WHERE category = 'Compra') 
    THEN '✅ OK' 
    ELSE '❌ FALHOU' 
  END as resultado
UNION ALL
SELECT 
  'Origem Compras' as teste,
  CASE 
    WHEN EXISTS(SELECT 1 FROM public.costs WHERE origin = 'Compras') 
    THEN '✅ OK' 
    ELSE '❌ FALHOU' 
  END as resultado
UNION ALL
SELECT 
  'Status Autorizado' as teste,
  CASE 
    WHEN EXISTS(SELECT 1 FROM public.costs WHERE status = 'Autorizado') 
    THEN '✅ OK' 
    ELSE '❌ FALHOU' 
  END as resultado; 