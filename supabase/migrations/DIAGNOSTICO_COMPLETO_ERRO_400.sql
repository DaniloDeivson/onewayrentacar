-- 🔍 DIAGNÓSTICO COMPLETO - ERRO 400 PERSISTENTE
-- Execute este SQL no Supabase SQL Editor

-- 1. Verificar se os campos foram realmente criados
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'fines' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Verificar especificamente os campos severity e points
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'fines' 
            AND column_name = 'severity'
        ) THEN '✅ severity EXISTS'
        ELSE '❌ severity MISSING'
    END as severity_check,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'fines' 
            AND column_name = 'points'
        ) THEN '✅ points EXISTS'
        ELSE '❌ points MISSING'
    END as points_check;

-- 3. Verificar todas as constraints da tabela fines
SELECT 
    constraint_name,
    constraint_type,
    table_name,
    column_name,
    is_deferrable,
    initially_deferred
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'fines'
ORDER BY constraint_type, constraint_name;

-- 4. Verificar RLS (Row Level Security) policies
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'fines';

-- 5. Verificar se há triggers que podem estar causando problemas
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'fines';

-- 6. Testar inserção manual para ver o erro específico
-- (Descomente as linhas abaixo para testar)
/*
INSERT INTO public.fines (
    vehicle_id,
    employee_id,
    infraction_type,
    amount,
    infraction_date,
    due_date,
    status,
    severity,
    points,
    tenant_id
) VALUES (
    '5d9d3ca2-883f-4929-bef3-9c0dbbbc11aa',
    '69baaaaa-9142-4c48-915b-a6b396107fa2',
    'Excesso de velocidade',
    213,
    '2025-07-03',
    '2025-08-02',
    'Pendente',
    'Média',
    3,
    'default'
);
*/

-- 7. Verificar se existe a tabela fines e suas permissões
SELECT 
    schemaname,
    tablename,
    tableowner,
    hasindexes,
    hasrules,
    hastriggers,
    rowsecurity
FROM pg_tables 
WHERE tablename = 'fines'; 