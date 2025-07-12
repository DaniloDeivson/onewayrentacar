-- 🔧 MIGRAÇÃO SIMPLES PARA CORRIGIR ERRO 400
-- Execute este SQL no Supabase SQL Editor
-- SEM TESTES - Apenas corrige as constraints

-- 1. Verificar estrutura atual
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'costs' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Adicionar colunas faltantes
ALTER TABLE public.costs ADD COLUMN IF NOT EXISTS department text;
ALTER TABLE public.costs ADD COLUMN IF NOT EXISTS customer_id text;
ALTER TABLE public.costs ADD COLUMN IF NOT EXISTS customer_name text;
ALTER TABLE public.costs ADD COLUMN IF NOT EXISTS contract_id text;
ALTER TABLE public.costs ADD COLUMN IF NOT EXISTS source_reference_id text;
ALTER TABLE public.costs ADD COLUMN IF NOT EXISTS source_reference_type text;

-- 3. Remover constraints antigas
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_category_check;
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_origin_check;
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_status_check;
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_category_constraint;
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_origin_constraint;
ALTER TABLE public.costs DROP CONSTRAINT IF EXISTS costs_status_constraint;

-- 4. Criar constraints que permitem todos os valores
ALTER TABLE public.costs ADD CONSTRAINT costs_category_check 
  CHECK (category IN ('Multa', 'Funilaria', 'Seguro', 'Avulsa', 'Compra', 'Excesso Km', 'Diária Extra', 'Combustível', 'Avaria'));

ALTER TABLE public.costs ADD CONSTRAINT costs_origin_check 
  CHECK (origin IN ('Manual', 'Patio', 'Manutencao', 'Sistema', 'Compras'));

ALTER TABLE public.costs ADD CONSTRAINT costs_status_check 
  CHECK (status IN ('Pendente', 'Pago', 'Autorizado'));

-- 5. Verificar constraints criadas
SELECT constraint_name, constraint_type 
FROM information_schema.table_constraints 
WHERE table_name = 'costs' AND table_schema = 'public'
AND constraint_type = 'CHECK';

-- 6. Documentar
COMMENT ON TABLE public.costs IS 'Constraints atualizadas para aceitar: Compra, Excesso Km, Diária Extra, Combustível, Avaria (categorias) + Compras (origem) + Autorizado (status)';

-- 7. Mostrar estrutura final
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'costs' AND table_schema = 'public'
ORDER BY ordinal_position; 