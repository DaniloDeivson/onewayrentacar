-- Verificar estrutura da view
SELECT 
    table_schema,
    table_name,
    column_name,
    data_type,
    udt_name
FROM information_schema.columns 
WHERE table_name = 'vw_employees_email';

-- Testar consulta direta
SELECT * FROM vw_employees_email 
WHERE email = 'teste@teste1.com';

-- Testar consulta com JSONB
SELECT * FROM employees 
WHERE contact_info->>'email' = 'teste@teste1.com';

-- Verificar se há duplicatas
SELECT 
    contact_info->>'email' as email,
    COUNT(*) 
FROM employees 
WHERE active = true 
GROUP BY contact_info->>'email' 
HAVING COUNT(*) > 1;

-- Query correta para a view (considerando que email ainda é JSONB)
SELECT * FROM employees
WHERE 
    active = true 
    AND contact_info->>'email' = 'teste@teste1.com'
    AND (contact_info->>'status' IS NULL 
        OR contact_info->>'status' NOT IN ('orphaned', 'orphaned_duplicate', 'duplicate_resolved'))
ORDER BY created_at DESC
LIMIT 1; 