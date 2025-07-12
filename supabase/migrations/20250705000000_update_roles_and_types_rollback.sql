-- Remover as políticas RLS
DROP POLICY IF EXISTS "employees_select_policy" ON employees;
DROP POLICY IF EXISTS "employees_insert_policy" ON employees;
DROP POLICY IF EXISTS "employees_update_admin_policy" ON employees;
DROP POLICY IF EXISTS "employees_update_self_policy" ON employees;
DROP POLICY IF EXISTS "employees_delete_policy" ON employees;

-- Remover constraints e índices com segurança
DO $$
BEGIN
  -- Remover constraint de contact_info se existir
  IF EXISTS (
    SELECT 1 
    FROM information_schema.table_constraints 
    WHERE constraint_name = 'contact_info_check'
  ) THEN
    ALTER TABLE employees DROP CONSTRAINT contact_info_check;
  END IF;

  -- Remover constraint de notification_data se existir
  IF EXISTS (
    SELECT 1 
    FROM information_schema.tables 
    WHERE table_name = 'damage_notifications'
  ) AND EXISTS (
    SELECT 1 
    FROM information_schema.table_constraints 
    WHERE constraint_name = 'notification_data_check'
  ) THEN
    ALTER TABLE damage_notifications DROP CONSTRAINT notification_data_check;
  END IF;

  -- Remover índice de email se existir
  IF EXISTS (
    SELECT 1 
    FROM pg_indexes 
    WHERE indexname = 'idx_employees_email'
  ) THEN
    DROP INDEX idx_employees_email;
  END IF;
END
$$;

-- Restaurar o tipo enum original com segurança
DO $$
BEGIN
  -- Verificar se o tipo atual existe
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'employee_role') THEN
    -- Criar tipo temporário para backup dos dados
    CREATE TYPE employee_role_backup AS ENUM (
      'Admin', 'Mechanic', 'PatioInspector', 'Sales', 
      'Driver', 'FineAdmin', 'Manager'
    );

    -- Converter dados para o tipo backup
    ALTER TABLE employees 
      ALTER COLUMN role TYPE text;

    -- Dropar o tipo atual
    DROP TYPE employee_role;

    -- Criar o tipo original
    CREATE TYPE employee_role AS ENUM (
      'Admin', 'Mechanic', 'PatioInspector', 'Sales', 
      'Driver', 'FineAdmin', 'Manager'
    );

    -- Converter dados de volta
    ALTER TABLE employees 
      ALTER COLUMN role TYPE employee_role USING 
        CASE role
          WHEN 'Admin' THEN 'Admin'::employee_role
          WHEN 'Manager' THEN 'Manager'::employee_role
          WHEN 'Mechanic' THEN 'Mechanic'::employee_role
          WHEN 'Inspector' THEN 'PatioInspector'::employee_role
          WHEN 'User' THEN 'Sales'::employee_role
          ELSE 'Sales'::employee_role
        END;

    -- Dropar o tipo backup
    DROP TYPE employee_role_backup;
  END IF;
END
$$;

-- Restaurar as funções originais
CREATE OR REPLACE FUNCTION public.has_role(required_role text)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM employees AS e
    WHERE e.id = auth.uid()::uuid
    AND (
      e.role::text = required_role 
      OR required_role = ANY(e.roles_extra)
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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