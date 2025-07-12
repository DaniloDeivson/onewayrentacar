-- Fix Employees RLS Recursion Issue
-- This migration fixes the infinite recursion in employees table RLS policies

-- ============================================================================
-- 1. CREATE SECURITY DEFINER FUNCTIONS TO AVOID RECURSION
-- ============================================================================

-- Function to get user tenant_id without triggering RLS
CREATE OR REPLACE FUNCTION public.get_user_tenant_id()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_tenant_id uuid;
BEGIN
    -- Direct query without RLS to avoid recursion
    SELECT tenant_id INTO user_tenant_id
    FROM employees
    WHERE id = (SELECT auth.uid())
    AND active = true
    LIMIT 1;
    
    RETURN user_tenant_id;
END;
$$;

-- Function to check if user is admin without triggering RLS
CREATE OR REPLACE FUNCTION public.is_user_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    is_admin boolean;
BEGIN
    -- Direct query without RLS to avoid recursion
    SELECT EXISTS (
        SELECT 1 
        FROM employees
        WHERE id = (SELECT auth.uid())
        AND active = true
        AND (
            role = 'Admin'
            OR 'Admin' = ANY(roles_extra::text[])
        )
    ) INTO is_admin;
    
    RETURN is_admin;
END;
$$;

-- Function to check if user has permission without triggering RLS
CREATE OR REPLACE FUNCTION public.user_has_permission(required_permission text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    has_perm boolean;
BEGIN
    -- Direct query without RLS to avoid recursion
    SELECT EXISTS (
        SELECT 1 
        FROM employees
        WHERE id = (SELECT auth.uid())
        AND active = true
        AND (
            role = 'Admin'
            OR (permissions->>required_permission)::boolean = true
            OR required_permission = ANY(roles_extra::text[])
        )
    ) INTO has_perm;
    
    RETURN has_perm;
END;
$$;

-- Function to check if user exists and is active without triggering RLS
CREATE OR REPLACE FUNCTION public.user_exists_and_active()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    exists_and_active boolean;
BEGIN
    -- Direct query without RLS to avoid recursion
    SELECT EXISTS (
        SELECT 1 
        FROM employees
        WHERE id = (SELECT auth.uid())
        AND active = true
    ) INTO exists_and_active;
    
    RETURN exists_and_active;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_user_tenant_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_user_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_has_permission(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_exists_and_active() TO authenticated;

-- ============================================================================
-- 2. DROP ALL EXISTING EMPLOYEES POLICIES
-- ============================================================================

-- Temporarily disable RLS to drop policies
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

-- ============================================================================
-- 3. CREATE NEW NON-RECURSIVE POLICIES
-- ============================================================================

-- Policy for users to read their own record
CREATE POLICY "employees_select_self" ON employees
FOR SELECT TO authenticated
USING (
    id = (SELECT auth.uid())
    AND active = true
);

-- Policy for users to read records in their tenant
CREATE POLICY "employees_select_tenant" ON employees
FOR SELECT TO authenticated
USING (
    user_exists_and_active()
    AND tenant_id = get_user_tenant_id()
    AND active = true
);

-- Policy for users to update their own record
CREATE POLICY "employees_update_self" ON employees
FOR UPDATE TO authenticated
USING (
    id = (SELECT auth.uid())
    AND active = true
)
WITH CHECK (
    id = (SELECT auth.uid())
    AND active = true
);

-- Policy for admins to update any record in their tenant
CREATE POLICY "employees_update_admin" ON employees
FOR UPDATE TO authenticated
USING (
    user_exists_and_active()
    AND is_user_admin()
    AND tenant_id = get_user_tenant_id()
)
WITH CHECK (
    user_exists_and_active()
    AND is_user_admin()
    AND tenant_id = get_user_tenant_id()
);

-- Policy for admins to insert records in their tenant
CREATE POLICY "employees_insert_admin" ON employees
FOR INSERT TO authenticated
WITH CHECK (
    user_exists_and_active()
    AND is_user_admin()
    AND tenant_id = get_user_tenant_id()
);

-- Policy for admins to delete records in their tenant
CREATE POLICY "employees_delete_admin" ON employees
FOR DELETE TO authenticated
USING (
    user_exists_and_active()
    AND is_user_admin()
    AND tenant_id = get_user_tenant_id()
);

-- ============================================================================
-- 4. GRANT NECESSARY PERMISSIONS
-- ============================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON employees TO authenticated;

-- ============================================================================
-- 5. VERIFICATION QUERIES
-- ============================================================================

-- Check if policies were created successfully
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    permissive
FROM pg_policies 
WHERE tablename = 'employees'
ORDER BY policyname;

-- Check if functions were created successfully
SELECT 
    proname as function_name,
    proargtypes::regtype[] as argument_types,
    prorettype::regtype as return_type
FROM pg_proc 
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
AND proname IN ('get_user_tenant_id', 'is_user_admin', 'user_has_permission', 'user_exists_and_active')
ORDER BY proname; 