-- Verificar e criar o tipo enum de roles se não existir
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'employee_role') THEN
    CREATE TYPE employee_role AS ENUM ('Admin', 'Manager', 'Mechanic', 'Inspector', 'User');
  ELSE
    -- Se já existe, renomear e recriar
    ALTER TYPE employee_role RENAME TO employee_role_old;
    CREATE TYPE employee_role AS ENUM ('Admin', 'Manager', 'Mechanic', 'Inspector', 'User');
    
    -- Converter roles antigos para novos
    ALTER TABLE employees 
      ALTER COLUMN role TYPE employee_role USING 
        CASE role::text
          WHEN 'Admin' THEN 'Admin'::employee_role
          WHEN 'Manager' THEN 'Manager'::employee_role
          WHEN 'Mechanic' THEN 'Mechanic'::employee_role
          WHEN 'PatioInspector' THEN 'Inspector'::employee_role
          WHEN 'Sales' THEN 'User'::employee_role
          WHEN 'Driver' THEN 'User'::employee_role
          WHEN 'FineAdmin' THEN 'User'::employee_role
          ELSE 'User'::employee_role
        END;

    -- Dropar o tipo antigo
    DROP TYPE employee_role_old;
  END IF;
END
$$;

-- Verificar se a coluna role já existe
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'employees' 
    AND column_name = 'role'
  ) THEN
    -- Se não existe, criar a coluna
    ALTER TABLE employees ADD COLUMN role employee_role NOT NULL DEFAULT 'User';
  END IF;
END
$$;

-- Adicionar constraint para contact_info se não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.table_constraints 
    WHERE constraint_name = 'contact_info_check'
  ) THEN
    ALTER TABLE employees 
      ADD CONSTRAINT contact_info_check 
      CHECK (
        contact_info ? 'email' AND 
        (contact_info->>'email')::text IS NOT NULL AND
        (contact_info->>'email')::text != ''
      );
  END IF;
END
$$;

-- Atualizar a função de verificação de role
CREATE OR REPLACE FUNCTION public.has_role(required_role text)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM employees AS e
    WHERE e.id = auth.uid()::uuid
    AND (
      e.role::text = required_role 
      OR required_role = ANY(e.roles_extra)
      OR e.role = 'Admin'
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Atualizar a função de verificação de admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM employees
    WHERE id = auth.uid()::uuid
    AND role = 'Admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Atualizar o tipo notification_data se a tabela existir
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 
    FROM information_schema.tables 
    WHERE table_name = 'damage_notifications'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 
      FROM information_schema.table_constraints 
      WHERE constraint_name = 'notification_data_check'
    ) THEN
      ALTER TABLE damage_notifications
        ADD CONSTRAINT notification_data_check
        CHECK (
          notification_data ? 'message' AND
          notification_data ? 'recipient' AND
          (notification_data->>'message')::text IS NOT NULL AND
          (notification_data->>'recipient')::text IS NOT NULL
        );
    END IF;
  END IF;
END
$$;

-- Criar índice para busca por email se não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_indexes 
    WHERE indexname = 'idx_employees_email'
  ) THEN
    CREATE INDEX idx_employees_email 
      ON employees USING gin ((contact_info->'email'));
  END IF;
END
$$;

-- Habilitar RLS
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

-- Atualizar as políticas RLS
DROP POLICY IF EXISTS "employees_select_policy" ON employees;
DROP POLICY IF EXISTS "employees_insert_policy" ON employees;
DROP POLICY IF EXISTS "employees_update_admin_policy" ON employees;
DROP POLICY IF EXISTS "employees_update_self_policy" ON employees;
DROP POLICY IF EXISTS "employees_delete_policy" ON employees;

-- Recriar as políticas
CREATE POLICY "employees_select_policy" ON employees
FOR SELECT USING (
  tenant_id = (
    SELECT tenant_id FROM employees 
    WHERE id = auth.uid()::uuid 
    LIMIT 1
  )
);

CREATE POLICY "employees_insert_policy" ON employees
FOR INSERT WITH CHECK (
  is_admin() AND
  tenant_id = (
    SELECT tenant_id FROM employees 
    WHERE id = auth.uid()::uuid 
    LIMIT 1
  )
);

CREATE POLICY "employees_update_admin_policy" ON employees
FOR UPDATE USING (
  is_admin() AND
  tenant_id = (
    SELECT tenant_id FROM employees 
    WHERE id = auth.uid()::uuid 
    LIMIT 1
  )
);

CREATE POLICY "employees_update_self_policy" ON employees
FOR UPDATE USING (
  auth.uid()::uuid = id
);

CREATE POLICY "employees_delete_policy" ON employees
FOR DELETE USING (
  is_admin() AND
  tenant_id = (
    SELECT tenant_id FROM employees 
    WHERE id = auth.uid()::uuid 
    LIMIT 1
  )
); 