-- Desabilitar temporariamente o trigger de auditoria
ALTER TABLE employees DISABLE TRIGGER audit_employees_changes;

-- Função para normalizar email (lowercase e trim)
CREATE OR REPLACE FUNCTION normalize_email(email text)
RETURNS text AS $$
BEGIN
  RETURN lower(trim(email));
END;
$$ LANGUAGE plpgsql;

-- Atualizar contas existentes
DO $$
DECLARE
    user_record RECORD;
BEGIN
    -- Primeiro, garantir que todos os usuários têm um tenant_id válido
    UPDATE employees 
    SET tenant_id = '00000000-0000-0000-0000-000000000001'
    WHERE tenant_id IS NULL;

    -- Normalizar emails em contact_info
    UPDATE employees
    SET contact_info = jsonb_set(
        contact_info,
        '{email}',
        to_jsonb(normalize_email(contact_info->>'email'))
    )
    WHERE contact_info->>'email' IS NOT NULL;

    -- Garantir que todos os usuários têm um papel válido
    UPDATE employees
    SET role = 'Sales'
    WHERE role IS NULL OR role NOT IN ('Admin', 'Mechanic', 'PatioInspector', 'Sales', 'Driver');

    -- Garantir que todos os usuários estão ativos por padrão
    UPDATE employees
    SET active = true
    WHERE active IS NULL;

    -- Garantir que todos os usuários têm contact_info
    UPDATE employees
    SET contact_info = '{}'::jsonb
    WHERE contact_info IS NULL;

    -- Verificar usuários auth que não têm registro em employees
    FOR user_record IN 
        SELECT au.id, au.email, au.raw_user_meta_data->>'name' as name
        FROM auth.users au
        LEFT JOIN employees e ON e.id = au.id
        WHERE e.id IS NULL
    LOOP
        -- Criar registro em employees para usuários auth sem registro
        INSERT INTO employees (
            id,
            name,
            role,
            contact_info,
            active,
            tenant_id
        ) VALUES (
            user_record.id,
            COALESCE(user_record.name, split_part(user_record.email, '@', 1)),
            'Sales', -- Papel padrão para novos usuários
            jsonb_build_object(
                'email', normalize_email(user_record.email),
                'phone', null
            ),
            true,
            '00000000-0000-0000-0000-000000000001'
        )
        ON CONFLICT (id) DO NOTHING;
    END LOOP;

    -- Verificar registros em employees que não têm usuário auth correspondente
    FOR user_record IN 
        SELECT e.id, e.contact_info->>'email' as email
        FROM employees e
        LEFT JOIN auth.users au ON au.id = e.id
        WHERE au.id IS NULL
        AND e.contact_info->>'email' IS NOT NULL
    LOOP
        -- Marcar como inativo registros órfãos
        UPDATE employees
        SET active = false,
            contact_info = jsonb_set(
                contact_info,
                '{status}',
                '"orphaned"'
            )
        WHERE id = user_record.id;
    END LOOP;

    -- Garantir que temos pelo menos um admin
    IF NOT EXISTS (SELECT 1 FROM employees WHERE role = 'Admin') THEN
        -- Pegar o primeiro usuário ativo e torná-lo admin
        UPDATE employees
        SET role = 'Admin'
        WHERE id = (
            SELECT id 
            FROM employees 
            WHERE active = true 
            ORDER BY id 
            LIMIT 1
        );
    END IF;

    -- Log das alterações
    RAISE NOTICE 'Atualização de contas concluída:';
    RAISE NOTICE '- Total de usuários ativos: %', (SELECT COUNT(*) FROM employees WHERE active = true);
    RAISE NOTICE '- Total de admins: %', (SELECT COUNT(*) FROM employees WHERE role = 'Admin');
    RAISE NOTICE '- Total de usuários inativos: %', (SELECT COUNT(*) FROM employees WHERE active = false);
END $$;

-- Criar função para manter emails normalizados
CREATE OR REPLACE FUNCTION normalize_employee_email()
RETURNS trigger AS $$
BEGIN
    IF NEW.contact_info->>'email' IS NOT NULL THEN
        NEW.contact_info = jsonb_set(
            NEW.contact_info,
            '{email}',
            to_jsonb(normalize_email(NEW.contact_info->>'email'))
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar trigger para normalizar emails automaticamente
DROP TRIGGER IF EXISTS normalize_email_trigger ON employees;
CREATE TRIGGER normalize_email_trigger
    BEFORE INSERT OR UPDATE ON employees
    FOR EACH ROW
    EXECUTE FUNCTION normalize_employee_email();

-- Verificar e corrigir possíveis problemas de permissão
DO $$
BEGIN
    -- Garantir que o serviço de autenticação tem acesso
    GRANT USAGE ON SCHEMA public TO authenticated;
    GRANT USAGE ON SCHEMA public TO service_role;
    
    -- Garantir permissões na tabela employees
    GRANT SELECT, INSERT, UPDATE ON public.employees TO authenticated;
    GRANT ALL ON public.employees TO service_role;
    
    -- Garantir permissões nas sequências (se houver)
    GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
    GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO service_role;
END $$;

-- Reabilitar o trigger de auditoria
ALTER TABLE employees ENABLE TRIGGER audit_employees_changes; 