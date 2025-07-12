-- 🔍 VERIFICAR MIGRAÇÕES DA TABELA FINES (VERSÃO CORRIGIDA)
-- Execute este SQL no Supabase SQL Editor

-- 1. Verificar estrutura atual da tabela fines
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'fines' 
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Verificar especificamente os campos que podem estar faltando
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'fines' 
            AND table_schema = 'public'
            AND column_name = 'severity'
        ) THEN '✅ Campo severity existe'
        ELSE '❌ Campo severity NÃO existe - EXECUTE A MIGRAÇÃO'
    END as severity_status,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'fines' 
            AND table_schema = 'public'
            AND column_name = 'points'
        ) THEN '✅ Campo points existe'
        ELSE '❌ Campo points NÃO existe - EXECUTE A MIGRAÇÃO'
    END as points_status,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'fines' 
            AND table_schema = 'public'
            AND column_name = 'contract_id'
        ) THEN '✅ Campo contract_id existe'
        ELSE '❌ Campo contract_id NÃO existe'
    END as contract_id_status,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'fines' 
            AND table_schema = 'public'
            AND column_name = 'customer_id'
        ) THEN '✅ Campo customer_id existe'
        ELSE '❌ Campo customer_id NÃO existe'
    END as customer_id_status,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'fines' 
            AND table_schema = 'public'
            AND column_name = 'customer_name'
        ) THEN '✅ Campo customer_name existe'
        ELSE '❌ Campo customer_name NÃO existe'
    END as customer_name_status;

-- 3. Verificar constraints da tabela fines
SELECT 
    constraint_name,
    constraint_type
FROM information_schema.table_constraints 
WHERE table_name = 'fines' 
    AND table_schema = 'public';

-- 4. Verificar triggers da tabela fines (corrigido)
SELECT 
    tgname as trigger_name,
    tgtype as trigger_type
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'fines';

-- 5. Verificar se há multas existentes (apenas se tabela existe)
SELECT 
    COUNT(*) as total_multas
FROM public.fines;

-- 6. Se campos severity e points existirem, verificar dados
-- (Esta query só vai funcionar APÓS a migração)
-- SELECT 
--     COUNT(*) as total_multas,
--     COUNT(*) FILTER (WHERE severity IS NOT NULL) as com_severity,
--     COUNT(*) FILTER (WHERE points IS NOT NULL) as com_points
-- FROM public.fines;

-- 📋 INTERPRETAÇÃO DOS RESULTADOS:
-- 
-- ❌ SE severity_status = "❌ Campo severity NÃO existe":
-- → EXECUTE: supabase/migrations/20250703040000_add_missing_fines_fields.sql
-- 
-- ❌ SE points_status = "❌ Campo points NÃO existe":
-- → EXECUTE: supabase/migrations/20250703040000_add_missing_fines_fields.sql
-- 
-- ✅ SE TODOS OS CAMPOS EXISTEM:
-- → Pode testar o formulário de multas
-- 
-- 💡 PRÓXIMO PASSO:
-- Execute a migração e depois rode este script novamente 