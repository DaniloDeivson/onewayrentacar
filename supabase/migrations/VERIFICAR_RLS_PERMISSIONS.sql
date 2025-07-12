-- 🔐 VERIFICAR RLS E PERMISSÕES - CAUSA DO ERRO 400
-- Execute este SQL no Supabase SQL Editor

-- 1. Verificar se RLS está habilitado na tabela fines
SELECT 
    schemaname,
    tablename,
    rowsecurity,
    forcerowsecurity
FROM pg_tables 
WHERE tablename = 'fines';

-- 2. Verificar políticas RLS da tabela fines
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'fines';

-- 3. Verificar permissões da tabela fines
SELECT 
    grantee,
    table_schema,
    table_name,
    privilege_type,
    is_grantable
FROM information_schema.table_privileges 
WHERE table_name = 'fines'
ORDER BY grantee, privilege_type;

-- 4. Verificar se há triggers que podem estar bloqueando
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'fines';

-- 5. Verificar constraints check que podem estar falhando
SELECT 
    constraint_name,
    constraint_type,
    check_clause
FROM information_schema.check_constraints cc
JOIN information_schema.table_constraints tc
    ON cc.constraint_name = tc.constraint_name
WHERE tc.table_name = 'fines';

-- 6. Verificar se há problema com foreign keys
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'fines';

-- 7. Verificar se os UUIDs existem nas tabelas referenciadas
SELECT 
    'vehicles' as table_name,
    id,
    plate,
    model
FROM vehicles 
WHERE id = '5d9d3ca2-883f-4929-bef3-9c0dbbbc11aa'
UNION ALL
SELECT 
    'employees' as table_name,
    id,
    name,
    role
FROM employees 
WHERE id = '69baaaaa-9142-4c48-915b-a6b396107fa2';

-- 8. Verificar se tenant_id está correto
SELECT DISTINCT tenant_id FROM fines LIMIT 5; 