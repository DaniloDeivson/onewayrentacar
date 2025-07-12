-- Simplify policies further to avoid any recursion
BEGIN;

-- Temporarily disable RLS
ALTER TABLE employees DISABLE ROW LEVEL SECURITY;

-- Drop all existing policies and triggers
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN (
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'employees'
    )
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON employees', pol.policyname);
    END LOOP;
END
$$;

DROP TRIGGER IF EXISTS set_auth_context_trigger ON employees;
DROP FUNCTION IF EXISTS public.set_auth_context_trigger();
DROP FUNCTION IF EXISTS public.set_auth_context();

-- Re-enable RLS
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

-- Create super simple policies

-- 1. Users can always read their own record
CREATE POLICY "employees_select_self" ON employees
FOR SELECT TO authenticated
USING (id = auth.uid());

-- 2. Users can update their own record
CREATE POLICY "employees_update_self" ON employees
FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- 3. Users can read records in their tenant
CREATE POLICY "employees_select_tenant" ON employees
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM employees self
        WHERE self.id = auth.uid()
        AND self.tenant_id = employees.tenant_id
        AND self.active = true
    )
);

-- 4. Admins can do everything in their tenant
CREATE POLICY "employees_admin" ON employees
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM employees self
        WHERE self.id = auth.uid()
        AND self.tenant_id = employees.tenant_id
        AND self.active = true
        AND (
            self.role = 'Admin'
            OR 'Admin' = ANY(self.roles_extra::text[])
        )
    )
);

-- 5. Allow insert during registration
CREATE POLICY "employees_insert_self" ON employees
FOR INSERT TO authenticated
WITH CHECK (
    id = auth.uid()
    AND tenant_id = '00000000-0000-0000-0000-000000000001'
);

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON employees TO authenticated;
GRANT ALL ON employees TO service_role;

COMMIT; 