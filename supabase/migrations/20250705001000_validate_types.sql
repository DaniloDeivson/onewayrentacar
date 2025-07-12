-- Verificar estrutura da tabela employees
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'employees';

-- Verificar um registro de exemplo na employees
SELECT id::text as id_as_text, 
       tenant_id,
       role,
       contact_info,
       roles_extra
FROM employees 
LIMIT 1;

-- Testar a função auth.uid()
SELECT auth.uid()::text as uid_as_text;

-- Verificar se temos registros válidos para teste
SELECT COUNT(*) as total_employees,
       COUNT(DISTINCT tenant_id) as total_tenants,
       COUNT(DISTINCT role) as total_roles,
       COUNT(CASE WHEN id = auth.uid()::text THEN 1 END) as current_user_count
FROM employees;

-- Testar a política de SELECT
SELECT EXISTS (
    SELECT 1 FROM employees AS e
    WHERE e.id = auth.uid()::text
    AND e.tenant_id = 'default'
) as can_access_default_tenant;

-- Verificar tipos das colunas específicas que estamos usando
SELECT 
    col.column_name,
    col.data_type,
    col.character_maximum_length,
    col.is_nullable,
    col.column_default
FROM information_schema.columns col
WHERE col.table_name = 'employees'
AND col.column_name IN ('id', 'tenant_id', 'role', 'contact_info', 'roles_extra');

-- Testar o formato do contact_info
SELECT 
    id,
    contact_info,
    contact_info->>'email' as email,
    contact_info->>'phone' as phone,
    jsonb_typeof(contact_info) as contact_info_type
FROM employees 
WHERE contact_info IS NOT NULL
LIMIT 1;

-- Verificar se roles_extra é um array
SELECT 
    id,
    roles_extra,
    array_length(roles_extra, 1) as roles_count,
    array_to_json(roles_extra) as roles_as_json
FROM employees 
WHERE roles_extra IS NOT NULL
LIMIT 1;

-- Testar a conversão de IDs
DO $$
DECLARE
    test_id text;
    test_tenant text;
BEGIN
    -- Teste 1: Pegar um ID existente
    SELECT id INTO test_id FROM employees LIMIT 1;
    RAISE NOTICE 'ID exemplo: %', test_id;
    
    -- Teste 2: Pegar um tenant_id existente
    SELECT tenant_id INTO test_tenant FROM employees LIMIT 1;
    RAISE NOTICE 'Tenant ID exemplo: %', test_tenant;
    
    -- Teste 3: auth.uid()
    BEGIN
        RAISE NOTICE 'auth.uid() como texto: %', auth.uid()::text;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Erro ao converter auth.uid(): %', SQLERRM;
    END;
END;
$$;

-- Verificar formato dos IDs
SELECT 
    id,
    tenant_id,
    role,
    length(id) as id_length,
    length(tenant_id) as tenant_id_length
FROM employees
LIMIT 5;

-- Testar a função has_role
SELECT has_role('Admin') as is_admin,
       has_role('User') as is_user,
       (SELECT role FROM employees WHERE id = auth.uid()::text) as actual_role;

-- Testar a função same_tenant
SELECT same_tenant('default') as has_access_to_default,
       (SELECT tenant_id FROM employees WHERE id = auth.uid()::text) as actual_tenant;

-- Verificar índices existentes
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'employees';

-- Verificar políticas RLS existentes
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'employees'; 