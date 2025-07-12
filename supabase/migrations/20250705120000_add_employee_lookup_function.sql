-- Drop existing function and policies
DROP FUNCTION IF EXISTS get_employee_by_id(uuid);
DROP FUNCTION IF EXISTS is_admin();
DROP POLICY IF EXISTS employees_select_policy ON employees;
DROP POLICY IF EXISTS employees_update_policy ON employees;
DROP POLICY IF EXISTS employees_delete_policy ON employees;

-- Create function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM employees 
    WHERE id = auth.uid() 
    AND permissions->>'admin' = 'true'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create employee lookup function
CREATE OR REPLACE FUNCTION get_employee_by_id(employee_id uuid)
RETURNS employees AS $$
  SELECT * FROM employees WHERE id = employee_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- Add comment
COMMENT ON FUNCTION get_employee_by_id IS 'Safely retrieves employee data by ID without triggering RLS policies';

-- Select policy: Admins can see all, others see themselves
CREATE POLICY employees_select_policy ON employees
FOR SELECT USING (
  is_admin() OR id = auth.uid()
);

-- Update policy: Admins can update all, others can't update
CREATE POLICY employees_update_policy ON employees
FOR UPDATE USING (
  is_admin()
);

-- Delete policy: Only admins can delete
CREATE POLICY employees_delete_policy ON employees
FOR DELETE USING (
  is_admin()
);

-- Enable RLS
ALTER TABLE employees ENABLE ROW LEVEL SECURITY; 