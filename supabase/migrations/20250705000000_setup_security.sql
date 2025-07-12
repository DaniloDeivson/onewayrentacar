-- Primeiro, vamos fazer backup das views
CREATE TABLE IF NOT EXISTS temp_view_backups AS
SELECT 
  schemaname,
  viewname,
  definition
FROM pg_views
WHERE viewname IN (
  'vw_maintenance_checkins_detailed',
  'vw_purchase_orders_detailed',
  'vw_employee_salaries',
  'vw_employee_audit',
  'vw_employees_email'
);

-- Backup das funções
DO $$
BEGIN
  CREATE TEMP TABLE temp_function_backups AS
  SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as definition
  FROM pg_proc p
  WHERE proname IN ('update_employee');
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- Backup das policies
DO $$
BEGIN
  CREATE TEMP TABLE temp_policy_backups AS
  SELECT 
    schemaname,
    tablename,
    policyname,
    roles,
    cmd,
    qual,
    with_check
  FROM pg_policies
  WHERE tablename IN (
    'contract_vehicles',
    'audit_log'
  );
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- Drop views
DROP VIEW IF EXISTS vw_maintenance_checkins_detailed CASCADE;
DROP VIEW IF EXISTS vw_purchase_orders_detailed CASCADE;
DROP VIEW IF EXISTS vw_employee_salaries CASCADE;
DROP VIEW IF EXISTS vw_employee_audit CASCADE;
DROP VIEW IF EXISTS vw_employees_email CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS update_employee(uuid,text,text,text,text) CASCADE;
DROP FUNCTION IF EXISTS update_employee(uuid,text,text[],text,text) CASCADE;
DROP FUNCTION IF EXISTS validate_session() CASCADE;
DROP FUNCTION IF EXISTS has_permission(text) CASCADE;
DROP FUNCTION IF EXISTS mark_duplicate_users() CASCADE;
DROP FUNCTION IF EXISTS cleanup_removed_users() CASCADE;
DROP FUNCTION IF EXISTS sync_auth_users() CASCADE;

-- Drop triggers
DROP TRIGGER IF EXISTS employees_updated_at ON public.employees;
DROP TRIGGER IF EXISTS employees_unique_email ON public.employees;
DROP TRIGGER IF EXISTS employees_role_validation ON public.employees;
DROP TRIGGER IF EXISTS employees_removed_sync ON public.employees;

-- Drop trigger functions
DROP FUNCTION IF EXISTS public.update_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.validate_unique_email() CASCADE;
DROP FUNCTION IF EXISTS public.validate_employee_role() CASCADE;
DROP FUNCTION IF EXISTS public.sync_removed_users() CASCADE;

-- Drop policies
DROP POLICY IF EXISTS "Employees can view their own profile" ON public.employees;
DROP POLICY IF EXISTS "Employees can update their own profile" ON public.employees;
DROP POLICY IF EXISTS "Admins can view all employees" ON public.employees;
DROP POLICY IF EXISTS "Admins can manage employees" ON public.employees;
DROP POLICY IF EXISTS "Only admins can view removed users" ON public.removed_users;
DROP POLICY IF EXISTS "Only admins can manage removed users" ON public.removed_users;
DROP POLICY IF EXISTS "Users can view contract_vehicles from their tenant" ON contract_vehicles;
DROP POLICY IF EXISTS "Users can insert contract_vehicles for their tenant" ON contract_vehicles;
DROP POLICY IF EXISTS "Users can update contract_vehicles from their tenant" ON contract_vehicles;
DROP POLICY IF EXISTS "Users can delete contract_vehicles from their tenant" ON contract_vehicles;
DROP POLICY IF EXISTS "Admins podem ver logs do seu tenant" ON audit_log;

-- Drop foreign key constraints
ALTER TABLE IF EXISTS purchase_orders 
  DROP CONSTRAINT IF EXISTS purchase_orders_created_by_employee_id_fkey;
ALTER TABLE IF EXISTS salaries 
  DROP CONSTRAINT IF EXISTS salaries_employee_id_fkey;
ALTER TABLE IF EXISTS maintenance_checkins 
  DROP CONSTRAINT IF EXISTS maintenance_checkins_mechanic_id_fkey;
ALTER TABLE IF EXISTS service_notes 
  DROP CONSTRAINT IF EXISTS service_notes_employee_id_fkey;
ALTER TABLE IF EXISTS inspections 
  DROP CONSTRAINT IF EXISTS inspections_employee_id_fkey;
ALTER TABLE IF EXISTS contracts 
  DROP CONSTRAINT IF EXISTS contracts_salesperson_id_fkey;
ALTER TABLE IF EXISTS fines 
  DROP CONSTRAINT IF EXISTS fines_employee_id_fkey;
ALTER TABLE IF EXISTS costs 
  DROP CONSTRAINT IF EXISTS costs_created_by_employee_id_fkey;

-- Drop and recreate tables
DROP TABLE IF EXISTS public.removed_users;
DROP TABLE IF EXISTS public.employees CASCADE;

-- Create employees table
CREATE TABLE public.employees (
  id text PRIMARY KEY,
  tenant_id text NOT NULL,
  name text NOT NULL,
  role text NOT NULL,
  employee_code text,
  contact_info jsonb NOT NULL DEFAULT '{}'::jsonb,
  active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  roles_extra text[] DEFAULT NULL,
  CONSTRAINT employees_role_check CHECK (role IN ('Admin', 'Manager', 'Mechanic', 'Inspector', 'User')),
  CONSTRAINT employees_contact_info_check CHECK (
    contact_info ? 'email' AND 
    (contact_info->>'email')::text IS NOT NULL AND 
    (contact_info->>'email')::text != ''
  )
);

-- Create removed_users table
CREATE TABLE public.removed_users (
  id text PRIMARY KEY,
  email text NOT NULL,
  removed_at timestamp with time zone NOT NULL DEFAULT now(),
  reason text NOT NULL
);

-- Create indexes
CREATE INDEX employees_email_idx ON public.employees USING gin ((contact_info->>'email'));
CREATE INDEX employees_active_idx ON public.employees (active);
CREATE INDEX employees_role_idx ON public.employees (role);
CREATE INDEX removed_users_email_idx ON public.removed_users (email);
CREATE INDEX removed_users_removed_at_idx ON public.removed_users (removed_at);

-- Create security functions
CREATE OR REPLACE FUNCTION public.validate_session()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _user_id uuid;
  _is_valid boolean;
BEGIN
  -- Obter ID do usuário atual
  _user_id := auth.uid();
  
  IF _user_id IS NULL THEN
    RETURN false;
  END IF;

  -- Verificar se o usuário existe e está ativo
  SELECT EXISTS (
    SELECT 1 
    FROM public.employees e
    WHERE e.id = _user_id::text
    AND e.active = true
  ) INTO _is_valid;

  RETURN _is_valid;
END;
$$;

CREATE OR REPLACE FUNCTION public.has_permission(required_permission text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _user_id uuid;
  _user_role text;
  _has_permission boolean;
BEGIN
  -- Obter ID do usuário atual
  _user_id := auth.uid();
  
  IF _user_id IS NULL THEN
    RETURN false;
  END IF;

  -- Verificar se o usuário existe e está ativo
  SELECT e.role
  FROM public.employees e
  WHERE e.id = _user_id::text
  AND e.active = true
  INTO _user_role;

  IF _user_role IS NULL THEN
    RETURN false;
  END IF;

  -- Admin tem todas as permissões
  IF _user_role = 'Admin' THEN
    RETURN true;
  END IF;

  -- Manager tem todas as permissões exceto admin
  IF _user_role = 'Manager' AND required_permission != 'admin' THEN
    RETURN true;
  END IF;

  -- Verificar permissões específicas por role
  CASE _user_role
    WHEN 'Mechanic' THEN
      _has_permission := required_permission IN ('maintenance', 'inventory');
    WHEN 'Inspector' THEN
      _has_permission := required_permission IN ('inspections', 'fleet');
    WHEN 'User' THEN
      _has_permission := required_permission IN ('dashboard');
    ELSE
      _has_permission := false;
  END CASE;

  RETURN _has_permission;
END;
$$;

-- Create maintenance functions
CREATE OR REPLACE FUNCTION public.mark_duplicate_users()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Atualizar status de emails duplicados
  WITH duplicates AS (
    SELECT 
      e.id,
      e.contact_info->>'email' as email,
      e.created_at,
      ROW_NUMBER() OVER (
        PARTITION BY LOWER(e.contact_info->>'email')
        ORDER BY e.created_at DESC
      ) as rn
    FROM public.employees e
    WHERE e.active = true
  )
  UPDATE public.employees e
  SET 
    contact_info = jsonb_set(
      jsonb_set(
        e.contact_info,
        '{status}',
        '"orphaned_duplicate"'::jsonb
      ),
      '{updated_reason}',
      '"Duplicate email found"'::jsonb
    ),
    active = false,
    updated_at = NOW()
  WHERE EXISTS (
    SELECT 1
    FROM duplicates d
    WHERE d.id = e.id
    AND d.rn > 1
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cleanup_removed_users()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Inserir usuários removidos na tabela de histórico
  INSERT INTO public.removed_users (id, email, removed_at, reason)
  SELECT 
    e.id,
    e.contact_info->>'email',
    NOW(),
    COALESCE(e.contact_info->>'updated_reason', 'User deactivated')
  FROM public.employees e
  WHERE e.active = false
  AND e.contact_info->>'status' IN ('orphaned', 'orphaned_duplicate')
  AND NOT EXISTS (
    SELECT 1 
    FROM public.removed_users ru 
    WHERE ru.id = e.id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_auth_users()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Marcar usuários órfãos (existem em auth mas não em employees)
  UPDATE public.employees e
  SET 
    contact_info = jsonb_set(
      jsonb_set(
        e.contact_info,
        '{status}',
        '"orphaned"'::jsonb
      ),
      '{updated_reason}',
      '"User not found in auth.users"'::jsonb
    ),
    active = false,
    updated_at = NOW()
  WHERE NOT EXISTS (
    SELECT 1
    FROM auth.users au
    WHERE au.id::text = e.id
  )
  AND e.active = true;

  -- Marcar usuários inativos no auth
  UPDATE public.employees e
  SET 
    contact_info = jsonb_set(
      jsonb_set(
        e.contact_info,
        '{status}',
        '"orphaned"'::jsonb
      ),
      '{updated_reason}',
      '"User inactive in auth.users"'::jsonb
    ),
    active = false,
    updated_at = NOW()
  WHERE EXISTS (
    SELECT 1
    FROM auth.users au
    WHERE au.id::text = e.id
    AND NOT au.confirmed_at IS NOT NULL
  )
  AND e.active = true;
END;
$$;

-- Create triggers
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER employees_updated_at
  BEFORE UPDATE ON public.employees
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

CREATE OR REPLACE FUNCTION public.validate_unique_email()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.employees e
    WHERE LOWER(e.contact_info->>'email') = LOWER(NEW.contact_info->>'email')
    AND e.id != NEW.id
    AND e.active = true
  ) THEN
    RAISE EXCEPTION 'Email already exists';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER employees_unique_email
  BEFORE INSERT OR UPDATE ON public.employees
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_unique_email();

CREATE OR REPLACE FUNCTION public.validate_employee_role()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.role NOT IN ('Admin', 'Manager', 'Mechanic', 'Inspector', 'User') THEN
    RAISE EXCEPTION 'Invalid role';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER employees_role_validation
  BEFORE INSERT OR UPDATE ON public.employees
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_employee_role();

CREATE OR REPLACE FUNCTION public.sync_removed_users()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.active = true AND NEW.active = false THEN
    INSERT INTO public.removed_users (id, email, removed_at, reason)
    VALUES (
      NEW.id,
      NEW.contact_info->>'email',
      NOW(),
      COALESCE(NEW.contact_info->>'updated_reason', 'User deactivated')
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER employees_removed_sync
  AFTER UPDATE ON public.employees
  FOR EACH ROW
  WHEN (OLD.active = true AND NEW.active = false)
  EXECUTE FUNCTION public.sync_removed_users();

-- Enable RLS
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.removed_users ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Employees can view their own profile"
  ON public.employees
  FOR SELECT
  TO authenticated
  USING (
    id::uuid = auth.uid()
    AND active = true
  );

CREATE POLICY "Employees can update their own profile"
  ON public.employees
  FOR UPDATE
  TO authenticated
  USING (
    id::uuid = auth.uid()
    AND active = true
  )
  WITH CHECK (
    id::uuid = auth.uid()
    AND active = true
  );

CREATE POLICY "Admins can view all employees"
  ON public.employees
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.employees e
      WHERE e.id::uuid = auth.uid()
      AND e.role = 'Admin'
      AND e.active = true
    )
  );

CREATE POLICY "Admins can manage employees"
  ON public.employees
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.employees e
      WHERE e.id::uuid = auth.uid()
      AND e.role = 'Admin'
      AND e.active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.employees e
      WHERE e.id::uuid = auth.uid()
      AND e.role = 'Admin'
      AND e.active = true
    )
  );

CREATE POLICY "Only admins can view removed users"
  ON public.removed_users
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.employees e
      WHERE e.id::uuid = auth.uid()
      AND e.role = 'Admin'
      AND e.active = true
    )
  );

CREATE POLICY "Only admins can manage removed users"
  ON public.removed_users
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.employees e
      WHERE e.id::uuid = auth.uid()
      AND e.role = 'Admin'
      AND e.active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.employees e
      WHERE e.id::uuid = auth.uid()
      AND e.role = 'Admin'
      AND e.active = true
    )
  );

-- Recriar foreign keys
ALTER TABLE IF EXISTS purchase_orders 
  ADD CONSTRAINT purchase_orders_created_by_employee_id_fkey 
  FOREIGN KEY (created_by_employee_id) REFERENCES employees(id);

ALTER TABLE IF EXISTS salaries 
  ADD CONSTRAINT salaries_employee_id_fkey 
  FOREIGN KEY (employee_id) REFERENCES employees(id);

ALTER TABLE IF EXISTS maintenance_checkins 
  ADD CONSTRAINT maintenance_checkins_mechanic_id_fkey 
  FOREIGN KEY (mechanic_id) REFERENCES employees(id);

ALTER TABLE IF EXISTS service_notes 
  ADD CONSTRAINT service_notes_employee_id_fkey 
  FOREIGN KEY (employee_id) REFERENCES employees(id);

ALTER TABLE IF EXISTS inspections 
  ADD CONSTRAINT inspections_employee_id_fkey 
  FOREIGN KEY (employee_id) REFERENCES employees(id);

ALTER TABLE IF EXISTS contracts 
  ADD CONSTRAINT contracts_salesperson_id_fkey 
  FOREIGN KEY (salesperson_id) REFERENCES employees(id);

ALTER TABLE IF EXISTS fines 
  ADD CONSTRAINT fines_employee_id_fkey 
  FOREIGN KEY (employee_id) REFERENCES employees(id);

ALTER TABLE IF EXISTS costs 
  ADD CONSTRAINT costs_created_by_employee_id_fkey 
  FOREIGN KEY (created_by_employee_id) REFERENCES employees(id);

-- Restaurar views
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT * FROM temp_view_backups LOOP
    EXECUTE format('CREATE OR REPLACE VIEW %I.%I AS %s', 
      r.schemaname, r.viewname, r.definition);
  END LOOP;
END $$;

-- Restaurar funções
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT * FROM temp_function_backups LOOP
    EXECUTE r.definition;
  END LOOP;
END $$;

-- Restaurar policies
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT * FROM temp_policy_backups LOOP
    EXECUTE format(
      'CREATE POLICY %I ON %I.%I FOR %s TO %s USING (%s) WITH CHECK (%s)',
      r.policyname, r.schemaname, r.tablename, 
      r.cmd, r.roles, r.qual, COALESCE(r.with_check, r.qual)
    );
  END LOOP;
END $$;

-- Limpar tabelas temporárias
DROP TABLE IF EXISTS temp_view_backups;
DROP TABLE IF EXISTS temp_function_backups;
DROP TABLE IF EXISTS temp_policy_backups; 