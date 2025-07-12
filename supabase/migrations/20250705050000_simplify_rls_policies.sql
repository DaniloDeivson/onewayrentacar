-- Simplify RLS policies
BEGIN;

-- Temporarily disable RLS
ALTER TABLE employees DISABLE ROW LEVEL SECURITY;

-- Drop all existing policies
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

-- Re-enable RLS
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

-- Create simplified policies

-- 1. Basic read access for authenticated users
CREATE POLICY "employees_select_policy" ON employees
FOR SELECT TO authenticated
USING (
    -- Users can see themselves
    id = auth.uid()
    OR
    -- Users can see others in their tenant if they have appropriate permissions
    (
        tenant_id = (
            SELECT e2.tenant_id 
            FROM employees e2 
            WHERE e2.id = auth.uid()
        )
        AND
        EXISTS (
            SELECT 1 
            FROM employees e3 
            WHERE e3.id = auth.uid() 
            AND (
                e3.role = 'Admin' 
                OR 'Admin' = ANY(e3.roles_extra::text[])
                OR e3.permissions->>'employees' = 'true'
            )
        )
    )
);

-- 2. Self-update policy
CREATE POLICY "employees_update_self_policy" ON employees
FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- 3. Admin operations policy
CREATE POLICY "employees_admin_policy" ON employees
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 
        FROM employees e 
        WHERE e.id = auth.uid()
        AND (
            e.role = 'Admin' 
            OR 'Admin' = ANY(e.roles_extra::text[])
        )
        AND e.tenant_id = employees.tenant_id
    )
);

-- Grant necessary permissions
GRANT SELECT, UPDATE ON employees TO authenticated;
GRANT ALL ON employees TO service_role;

-- Create helper function for checking permissions
CREATE OR REPLACE FUNCTION public.check_employee_permission(permission text)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM employees e 
        WHERE e.id = auth.uid()
        AND (
            e.permissions->>permission = 'true'
            OR e.role = 'Admin'
            OR 'Admin' = ANY(e.roles_extra::text[])
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT; 