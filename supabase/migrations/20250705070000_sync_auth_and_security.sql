-- Remover políticas antigas
DROP POLICY IF EXISTS "Enable read for authenticated users" ON employees;
DROP POLICY IF EXISTS "Enable self update" ON employees;
DROP POLICY IF EXISTS "Enable admin access" ON employees;
DROP POLICY IF EXISTS "employees_select_policy" ON employees;

-- Sincronizar dados do auth.users com employees
UPDATE auth.users au
SET 
    email = LOWER(e.contact_info->>'email'),
    raw_user_meta_data = jsonb_build_object(
        'name', e.name,
        'role', e.role,
        'tenant_id', e.tenant_id,
        'permissions', e.permissions
    ),
    updated_at = NOW()
FROM employees e
WHERE au.id::text = e.id::text
AND e.active = true;

-- Sincronizar email_confirmed_at para usuários existentes
UPDATE auth.users
SET email_confirmed_at = LEAST(created_at, NOW())
WHERE email_confirmed_at IS NULL;

-- Criar função para validar sessão
CREATE OR REPLACE FUNCTION public.validate_session()
RETURNS boolean AS $$
BEGIN
    -- Verificar se o usuário está autenticado e ativo
    RETURN EXISTS (
        SELECT 1 
        FROM employees e
        WHERE e.id = auth.uid()
        AND e.active = true
        AND (e.contact_info->>'status' IS NULL 
            OR e.contact_info->>'status' NOT IN ('orphaned', 'orphaned_duplicate', 'duplicate_resolved'))
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Criar função para verificar permissões específicas
CREATE OR REPLACE FUNCTION public.has_permission(required_permission text)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM employees e
        WHERE e.id = auth.uid()
        AND e.active = true
        AND (
            e.role = 'Admin'
            OR (e.permissions->>required_permission)::boolean = true
            OR required_permission = ANY(e.roles_extra)
        )
        AND (e.contact_info->>'status' IS NULL 
            OR e.contact_info->>'status' NOT IN ('orphaned', 'orphaned_duplicate', 'duplicate_resolved'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Criar função para obter tenant_id do usuário
CREATE OR REPLACE FUNCTION public.get_user_tenant()
RETURNS uuid AS $$
DECLARE
    user_tenant_id uuid;
BEGIN
    SELECT tenant_id INTO user_tenant_id
    FROM employees
    WHERE id = auth.uid()
    AND active = true;
    
    RETURN user_tenant_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Novas políticas RLS
-- Política base: usuários só podem ver registros do seu tenant
CREATE POLICY "tenant_isolation_policy" ON employees
FOR ALL USING (
    tenant_id = get_user_tenant()
    AND validate_session()
);

-- Política para leitura: usuários podem ver todos os registros do seu tenant
CREATE POLICY "read_policy" ON employees
FOR SELECT USING (
    tenant_id = get_user_tenant()
    AND validate_session()
);

-- Política para atualização: apenas próprio registro ou admin
CREATE POLICY "update_policy" ON employees
FOR UPDATE USING (
    validate_session()
    AND (
        id = auth.uid()
        OR has_permission('admin')
    )
)
WITH CHECK (
    validate_session()
    AND (
        id = auth.uid()
        OR has_permission('admin')
    )
);

-- Política para inserção: apenas admin
CREATE POLICY "insert_policy" ON employees
FOR INSERT WITH CHECK (
    validate_session()
    AND has_permission('admin')
    AND tenant_id = get_user_tenant()
);

-- Política para deleção: apenas admin
CREATE POLICY "delete_policy" ON employees
FOR DELETE USING (
    validate_session()
    AND has_permission('admin')
    AND tenant_id = get_user_tenant()
);

-- Garantir que RLS está ativado
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

-- Garantir permissões corretas
GRANT SELECT, INSERT, UPDATE, DELETE ON employees TO authenticated;
GRANT EXECUTE ON FUNCTION validate_session TO authenticated;
GRANT EXECUTE ON FUNCTION has_permission TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_tenant TO authenticated;

-- Criar índices para melhorar performance das funções de segurança
CREATE INDEX IF NOT EXISTS idx_employees_auth_validation ON employees (id, active, tenant_id);
CREATE INDEX IF NOT EXISTS idx_employees_permissions ON employees USING GIN (permissions);
CREATE INDEX IF NOT EXISTS idx_employees_roles_extra ON employees USING GIN (roles_extra);

-- Verificar e reportar inconsistências
DO $$
DECLARE
    auth_count integer;
    employee_count integer;
    orphaned_auth_count integer;
    orphaned_employee_count integer;
BEGIN
    -- Contar usuários auth sem employee correspondente
    SELECT COUNT(*) INTO orphaned_auth_count
    FROM auth.users au
    LEFT JOIN employees e ON au.id::text = e.id::text
    WHERE e.id IS NULL;

    -- Contar employees sem auth correspondente
    SELECT COUNT(*) INTO orphaned_employee_count
    FROM employees e
    LEFT JOIN auth.users au ON e.id::text = au.id::text
    WHERE au.id IS NULL AND e.active = true;

    -- Contar totais
    SELECT COUNT(*) INTO auth_count FROM auth.users;
    SELECT COUNT(*) INTO employee_count FROM employees WHERE active = true;

    RAISE NOTICE 'Relatório de sincronização:';
    RAISE NOTICE '- Total de usuários auth: %', auth_count;
    RAISE NOTICE '- Total de employees ativos: %', employee_count;
    RAISE NOTICE '- Usuários auth sem employee: %', orphaned_auth_count;
    RAISE NOTICE '- Employees ativos sem auth: %', orphaned_employee_count;

    IF orphaned_auth_count > 0 OR orphaned_employee_count > 0 THEN
        RAISE WARNING 'Existem inconsistências entre auth.users e employees';
    END IF;
END $$; 