-- Fix login policies to ensure users can access the employees table
-- Drop existing problematic policies
DROP POLICY IF EXISTS "employees_select_policy" ON employees;
DROP POLICY IF EXISTS "Enable read for authenticated users" ON employees;
DROP POLICY IF EXISTS "tenant_isolation_policy" ON employees;
DROP POLICY IF EXISTS "read_policy" ON employees;

-- Create a simple policy that allows authenticated users to read their own data
CREATE POLICY "employees_self_access" ON employees
FOR SELECT TO authenticated
USING (
  id = auth.uid()::text
  AND active = true
);

-- Create a policy that allows users to read all employees in their tenant
CREATE POLICY "employees_tenant_access" ON employees
FOR SELECT TO authenticated
USING (
  tenant_id = (
    SELECT tenant_id 
    FROM employees 
    WHERE id = auth.uid()::text 
    AND active = true
    LIMIT 1
  )
  AND active = true
);

-- Ensure RLS is enabled
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

-- Grant necessary permissions
GRANT SELECT ON employees TO authenticated;

-- Create a simple function to check if user exists and is active
CREATE OR REPLACE FUNCTION public.check_user_access(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM employees 
    WHERE id = user_id::text
    AND active = true
  );
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.check_user_access TO authenticated; 