-- 🔍 VERIFICAR SETUP DE COBRANÇAS DE CLIENTES
-- Execute este SQL após executar CREATE_CUSTOMER_CHARGES_TABLE_CORRIGIDO.sql

-- 1. Verificar se a tabela foi criada
SELECT 
    'customer_charges table' as object_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'customer_charges' AND table_schema = 'public'
        ) THEN '✅ EXISTS'
        ELSE '❌ NOT FOUND'
    END as status;

-- 2. Verificar se as funções foram criadas
SELECT 
    'fn_customer_charges_statistics' as object_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'fn_customer_charges_statistics' AND routine_schema = 'public'
        ) THEN '✅ EXISTS'
        ELSE '❌ NOT FOUND'
    END as status

UNION ALL

SELECT 
    'fn_generate_customer_charges' as object_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'fn_generate_customer_charges' AND routine_schema = 'public'
        ) THEN '✅ EXISTS'
        ELSE '❌ NOT FOUND'
    END as status;

-- 3. Verificar colunas da tabela
SELECT 
    'Table Structure' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'customer_charges' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. Testar as funções
SELECT 
    'Function Test' as info,
    'fn_customer_charges_statistics' as function_name,
    'Testing...' as result;

-- Chamar função de estatísticas
SELECT 
    'Statistics Result' as info,
    total_charges,
    pending_charges,
    paid_charges,
    total_amount,
    pending_amount,
    paid_amount
FROM fn_customer_charges_statistics('00000000-0000-0000-0000-000000000001'::uuid);

-- 5. Verificar registros de teste
SELECT 
    'Test Records' as info,
    count(*) as total_records,
    charge_type,
    status
FROM customer_charges
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
GROUP BY charge_type, status; 