-- Safe fix for infinite recursion in employees RLS policies
-- This migration safely removes problematic policies and creates working ones

-- ============================================================================
-- 1. VERIFY CURRENT STATE
-- ============================================================================

DO $$
DECLARE
    policy_count INTEGER;
    rls_enabled BOOLEAN;
BEGIN
    -- Check if RLS is enabled
    SELECT rowsecurity INTO rls_enabled 
    FROM pg_tables 
    WHERE tablename = 'employees';
    
    RAISE NOTICE 'RLS enabled for employees table: %', rls_enabled;
    
    -- Count existing policies
    SELECT COUNT(*) INTO policy_count 
    FROM pg_policies 
    WHERE tablename = 'employees';
    
    RAISE NOTICE 'Found % existing policies on employees table', policy_count;
    
    -- List all existing policies
    RAISE NOTICE 'Existing policies:';
    FOR policy_rec IN 
        SELECT policyname, cmd 
        FROM pg_policies 
        WHERE tablename = 'employees'
        ORDER BY policyname
    LOOP
        RAISE NOTICE '  - % (%)', policy_rec.policyname, policy_rec.cmd;
    END LOOP;
END
$$;

-- ============================================================================
-- 2. SAFELY REMOVE EXISTING POLICIES
-- ============================================================================

-- Drop policies only if they exist (using IF EXISTS)
DO $$
DECLARE
    policy_rec RECORD;
BEGIN
    -- Drop all policies found on the employees table
    FOR policy_rec IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'employees'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON employees', policy_rec.policyname);
        RAISE NOTICE 'Dropped policy: %', policy_rec.policyname;
    END LOOP;
END
$$;

-- ============================================================================
-- 3. CREATE SIMPLE WORKING POLICIES
-- ============================================================================

-- Ensure RLS is enabled
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

-- Create the simple working select policy
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
-- 4. VERIFY NEW POLICIES
-- ============================================================================

DO $$
DECLARE
    new_policy_count INTEGER;
BEGIN
    -- Count new policies
    SELECT COUNT(*) INTO new_policy_count 
    FROM pg_policies 
    WHERE tablename = 'employees';
    
    RAISE NOTICE 'Created % new policies on employees table', new_policy_count;
    
    -- Verify specific policies exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'employees' 
        AND policyname = 'employees_select_policy'
    ) THEN
        RAISE EXCEPTION 'Failed to create employees_select_policy';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'employees' 
        AND policyname = 'employees_insert_policy'
    ) THEN
        RAISE EXCEPTION 'Failed to create employees_insert_policy';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'employees' 
        AND policyname = 'employees_update_policy'
    ) THEN
        RAISE EXCEPTION 'Failed to create employees_update_policy';
    END IF;
    
    RAISE NOTICE 'All RLS policies successfully created for employees table';
END
$$; 