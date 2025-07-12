-- Simple fix for infinite recursion in employees RLS policies
-- This migration safely removes problematic policies and creates working ones

-- ============================================================================
-- 1. DISABLE RLS TEMPORARILY
-- ============================================================================

-- Disable RLS to avoid recursion issues during cleanup
ALTER TABLE employees DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 2. DROP ALL EXISTING POLICIES (SAFE APPROACH)
-- ============================================================================

-- Drop policies one by one with IF EXISTS to avoid errors
DROP POLICY IF EXISTS employees_select_policy ON employees;
DROP POLICY IF EXISTS employees_insert_policy ON employees;
DROP POLICY IF EXISTS employees_update_policy ON employees;
DROP POLICY IF EXISTS employees_delete_policy ON employees;
DROP POLICY IF EXISTS employees_select_self ON employees;
DROP POLICY IF EXISTS employees_update_self ON employees;
DROP POLICY IF EXISTS employees_select_tenant ON employees;
DROP POLICY IF EXISTS employees_admin ON employees;
DROP POLICY IF EXISTS employees_insert_self ON employees;
DROP POLICY IF EXISTS employees_read_all ON employees;
DROP POLICY IF EXISTS employees_insert_admin ON employees;
DROP POLICY IF EXISTS employees_update_admin ON employees;
DROP POLICY IF EXISTS employees_delete_admin ON employees;
DROP POLICY IF EXISTS employees_tenant_access ON employees;
DROP POLICY IF EXISTS employees_own_record ON employees;
DROP POLICY IF EXISTS employees_select_all ON employees;
DROP POLICY IF EXISTS employees_insert_all ON employees;
DROP POLICY IF EXISTS employees_update_all ON employees;
DROP POLICY IF EXISTS employees_delete_all ON employees;

-- ============================================================================
-- 3. RE-ENABLE RLS AND CREATE SIMPLE POLICIES
-- ============================================================================

-- Re-enable RLS
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

-- Create the simple working select policy (exactly as mentioned by user)
CREATE POLICY employees_select_policy
  ON employees
  FOR SELECT
  USING (id = auth.uid());

-- Create insert policy for registration
CREATE POLICY employees_insert_policy
  ON employees
  FOR INSERT
  WITH CHECK (id = auth.uid());

-- Create update policy
CREATE POLICY employees_update_policy
  ON employees
  FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ============================================================================
-- 4. VERIFY POLICIES WERE CREATED
-- ============================================================================

-- Simple verification
DO $$
BEGIN
  -- Check if the main policy exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employees' 
    AND policyname = 'employees_select_policy'
  ) THEN
    RAISE EXCEPTION 'Failed to create employees_select_policy';
  END IF;
  
  RAISE NOTICE 'RLS policies successfully created for employees table';
END
$$; 