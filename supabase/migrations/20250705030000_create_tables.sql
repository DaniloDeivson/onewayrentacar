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

-- Drop policies
DROP POLICY IF EXISTS "Users can view contract_vehicles from their tenant" ON contract_vehicles;
DROP POLICY IF EXISTS "Users can insert contract_vehicles for their tenant" ON contract_vehicles;
DROP POLICY IF EXISTS "Users can update contract_vehicles from their tenant" ON contract_vehicles;
DROP POLICY IF EXISTS "Users can delete contract_vehicles from their tenant" ON contract_vehicles;
DROP POLICY IF EXISTS "Admins podem ver logs do seu tenant" ON audit_log;

-- Backup dos dados da tabela employees
CREATE TEMP TABLE temp_employees_backup AS
SELECT 
  id,
  tenant_id,
  name,
  role,
  employee_code,
  COALESCE(contact_info, '{"email": null}'::jsonb) as contact_info,
  COALESCE(active, true) as active,
  created_at,
  updated_at,
  roles_extra
FROM employees;

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

-- Agora podemos dropar e recriar a tabela employees
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

-- Restaurar dados
INSERT INTO employees (
  id,
  tenant_id,
  name,
  role,
  employee_code,
  contact_info,
  active,
  created_at,
  updated_at,
  roles_extra
)
SELECT 
  id,
  tenant_id,
  name,
  role,
  employee_code,
  contact_info,
  active,
  created_at,
  updated_at,
  roles_extra
FROM temp_employees_backup;

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
DROP TABLE IF EXISTS temp_employees_backup; 