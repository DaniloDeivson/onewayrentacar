/*
  # Fix employee policies

  1. Changes
    - Safely drop and recreate policies for employees table
    - Use DO block to check if policies exist before creating them
    - Maintain the same policy logic but avoid duplicate policy errors
*/

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can manage employees" ON employees;
DROP POLICY IF EXISTS "Users can view their tenant employees" ON employees;

-- Use DO block to check if policies exist before creating them
DO $$
BEGIN
  -- Check if the first policy exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employees' 
    AND policyname = 'Allow all operations for default tenant on employees'
  ) THEN
    -- Create policy for default tenant
    CREATE POLICY "Allow all operations for default tenant on employees"
      ON employees
      FOR ALL
      TO authenticated, anon
      USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
      WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);
  END IF;

  -- Check if the second policy exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employees' 
    AND policyname = 'Users can manage their tenant employees'
  ) THEN
    -- Create policy for authenticated users
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
  END IF;
END $$;