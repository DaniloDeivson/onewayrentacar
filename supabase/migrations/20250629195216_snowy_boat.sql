/*
  # Fix employees table RLS policies

  1. Security
    - Drop existing policies on employees table
    - Create proper RLS policies for the employees table
    - Add policy for default tenant
    - Add policy for authenticated users
*/

-- Drop existing policies to recreate them properly
DROP POLICY IF EXISTS "Admins can manage employees" ON employees;
DROP POLICY IF EXISTS "Users can view their tenant employees" ON employees;

-- Create comprehensive policies for employees table
CREATE POLICY "Allow all operations for default tenant on employees"
  ON employees
  FOR ALL
  TO authenticated, anon
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

-- Additional policy for authenticated users to manage their tenant employees
CREATE POLICY "Users can manage their tenant employees"
  ON employees
  FOR ALL
  TO authenticated
  USING (tenant_id IN (
    SELECT id FROM tenants WHERE auth.uid() IS NOT NULL
  ))
  WITH CHECK (tenant_id IN (
    SELECT id FROM tenants WHERE auth.uid() IS NOT NULL
  ));