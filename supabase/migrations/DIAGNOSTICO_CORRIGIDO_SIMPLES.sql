-- 🔍 DIAGNÓSTICO CORRIGIDO (SEM ERRO DE COLUNA)
-- Execute este SQL no Supabase SQL Editor

-- 1. Verificar se campos severity e points existem
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'fines' AND column_name = 'severity'
        ) THEN '✅ severity EXISTS'
        ELSE '❌ severity MISSING'
    END as severity_status,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'fines' AND column_name = 'points'
        ) THEN '✅ points EXISTS'
        ELSE '❌ points MISSING'
    END as points_status;

-- 2. Verificar RLS na tabela fines
SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename = 'fines';

-- 3. Verificar políticas RLS
SELECT 
    policyname,
    cmd,
    permissive
FROM pg_policies 
WHERE tablename = 'fines';

-- 4. Teste simples de inserção
INSERT INTO public.fines (
    vehicle_id,
    employee_id,
    infraction_type,
    amount,
    infraction_date,
    due_date,
    status,
    tenant_id
) VALUES (
    '5d9d3ca2-883f-4929-bef3-9c0dbbbc11aa',
    '69baaaaa-9142-4c48-915b-a6b396107fa2',
    'TESTE DIAGNÓSTICO',
    100.00,
    '2025-07-03',
    '2025-08-02',
    'Pendente',
    'default'
);

-- 5. Verificar se inserção funcionou
SELECT * FROM public.fines WHERE infraction_type = 'TESTE DIAGNÓSTICO';

-- 6. Limpar teste
DELETE FROM public.fines WHERE infraction_type = 'TESTE DIAGNÓSTICO'; 