-- Primeiro, garantir que todos os usuários tenham contact_info com email
UPDATE employees
SET contact_info = jsonb_build_object(
    'email', 
    COALESCE(
        contact_info->>'email',  -- manter email existente se houver
        CASE 
            WHEN name LIKE '%@%' THEN LOWER(name)  -- usar name se parecer email
            ELSE LOWER(REPLACE(REPLACE(name, ' ', '.'), '''', '') || '@onewayrentacar.com')  -- criar email do nome
        END
    ),
    'phone', COALESCE(contact_info->>'phone', null),
    'status', null
)
WHERE contact_info IS NULL 
   OR contact_info->>'email' IS NULL
   OR contact_info->>'email' = '';

-- Garantir que todos os usuários ativos tenham permissions
UPDATE employees
SET permissions = COALESCE(
    permissions,
    jsonb_build_object(
        'admin', role = 'Admin',
        'costs', true,
        'fines', true,
        'fleet', true,
        'finance', true,
        'contracts', true,
        'dashboard', true,
        'employees', role = 'Admin',
        'inventory', true,
        'purchases', true,
        'suppliers', true,
        'statistics', true,
        'inspections', true,
        'maintenance', true
    )
)
WHERE active = true AND (permissions IS NULL OR permissions = '{}'::jsonb);

-- Garantir que todos os usuários tenham tenant_id
UPDATE employees
SET tenant_id = '00000000-0000-0000-0000-000000000001'
WHERE tenant_id IS NULL;

-- Garantir que todos os usuários tenham role
UPDATE employees
SET role = 'User'
WHERE role IS NULL;

-- Garantir que todos os usuários tenham created_at
UPDATE employees
SET created_at = NOW()
WHERE created_at IS NULL;

-- Garantir que todos os usuários tenham updated_at
UPDATE employees
SET updated_at = NOW()
WHERE updated_at IS NULL;

-- Verificar e corrigir duplicatas de email
WITH duplicate_emails AS (
    SELECT LOWER(contact_info->>'email') as email
    FROM employees
    WHERE active = true
    GROUP BY LOWER(contact_info->>'email')
    HAVING COUNT(*) > 1
)
UPDATE employees e
SET 
    active = false,
    contact_info = jsonb_set(
        contact_info,
        '{status}',
        '"duplicate_resolved"'::jsonb
    )
WHERE id IN (
    SELECT e2.id
    FROM employees e2
    JOIN duplicate_emails de ON LOWER(e2.contact_info->>'email') = de.email
    WHERE e2.active = true
    AND e2.id NOT IN (
        -- Manter apenas o registro mais privilegiado/recente ativo
        SELECT DISTINCT ON (LOWER(e3.contact_info->>'email')) e3.id
        FROM employees e3
        JOIN duplicate_emails de2 ON LOWER(e3.contact_info->>'email') = de2.email
        WHERE e3.active = true
        ORDER BY LOWER(e3.contact_info->>'email'),
            CASE WHEN e3.role = 'Admin' THEN 0
                 WHEN e3.role = 'Manager' THEN 1
                 ELSE 2 END,
            e3.created_at DESC
    )
);

-- Verificar registros problemáticos
DO $$
DECLARE
    invalid_count integer;
BEGIN
    SELECT COUNT(*)
    INTO invalid_count
    FROM employees
    WHERE active = true
    AND (
        contact_info IS NULL
        OR contact_info->>'email' IS NULL
        OR contact_info->>'email' = ''
        OR permissions IS NULL
        OR permissions = '{}'::jsonb
        OR tenant_id IS NULL
        OR role IS NULL
        OR created_at IS NULL
        OR updated_at IS NULL
    );

    IF invalid_count > 0 THEN
        RAISE NOTICE 'Ainda existem % registros que precisam de atenção', invalid_count;
    END IF;
END $$; 