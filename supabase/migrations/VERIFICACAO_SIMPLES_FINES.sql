-- 🔍 VERIFICAÇÃO SIMPLES - CAMPOS DA TABELA FINES
-- Execute este SQL no Supabase SQL Editor

-- Verificar se os campos necessários existem
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'fines' 
            AND column_name = 'severity'
        ) THEN '✅ severity existe'
        ELSE '❌ severity FALTANDO'
    END as campo_severity,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'fines' 
            AND column_name = 'points'
        ) THEN '✅ points existe'
        ELSE '❌ points FALTANDO'
    END as campo_points;

-- Se ambos mostram ❌ FALTANDO:
-- 1. Execute: supabase/migrations/20250703040000_add_missing_fines_fields.sql
-- 2. Execute este script novamente para confirmar
-- 3. Teste o formulário de multas 