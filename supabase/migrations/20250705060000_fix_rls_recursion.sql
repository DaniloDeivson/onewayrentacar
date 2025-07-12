-- Fix RLS recursion issue
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

-- Create simplified policies without recursion

-- 1. Basic read access for authenticated users
CREATE POLICY "employees_select_policy" ON employees
FOR SELECT TO authenticated
USING (
    -- Users can always see themselves
    id = auth.uid()
    OR
    -- Users can see others in their tenant if they have appropriate permissions
    (
        -- Store tenant_id in a variable to avoid recursion
        tenant_id = COALESCE(
            (SELECT current_setting('app.current_tenant_id', true))::uuid,
            '00000000-0000-0000-0000-000000000001'::uuid
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
    -- Use current_setting to avoid recursion
    COALESCE(
        (SELECT current_setting('app.is_admin', true))::boolean,
        false
    )
);

-- Create function to set current tenant and admin status
CREATE OR REPLACE FUNCTION public.set_auth_context()
RETURNS void AS $$
DECLARE
    _tenant_id uuid;
    _is_admin boolean;
BEGIN
    -- Get tenant_id and admin status directly without recursion
    SELECT 
        e.tenant_id,
        (e.role = 'Admin' OR 'Admin' = ANY(e.roles_extra::text[]))
    INTO _tenant_id, _is_admin
    FROM employees e
    WHERE e.id = auth.uid()
    LIMIT 1;

    -- Set context
    IF _tenant_id IS NOT NULL THEN
        PERFORM set_config('app.current_tenant_id', _tenant_id::text, false);
    END IF;

    IF _is_admin IS NOT NULL THEN
        PERFORM set_config('app.is_admin', _is_admin::text, false);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to set context on RLS checks
CREATE OR REPLACE FUNCTION public.set_auth_context_trigger()
RETURNS trigger AS $$
BEGIN
    PERFORM set_auth_context();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add trigger to employees table
DROP TRIGGER IF EXISTS set_auth_context_trigger ON employees;
CREATE TRIGGER set_auth_context_trigger
    BEFORE SELECT OR INSERT OR UPDATE OR DELETE ON employees
    FOR EACH STATEMENT
    EXECUTE FUNCTION set_auth_context_trigger();

-- Grant necessary permissions
GRANT SELECT, UPDATE ON employees TO authenticated;
GRANT ALL ON employees TO service_role;

COMMIT; 