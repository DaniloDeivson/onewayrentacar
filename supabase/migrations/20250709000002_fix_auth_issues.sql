-- Fix authentication issues
-- This migration fixes issues with employee creation and authentication

-- ============================================================================
-- 1. VERIFY AND FIX EMPLOYEES TABLE STRUCTURE
-- ============================================================================

-- Ensure the employees table has the correct structure
DO $$
BEGIN
    -- Check if the table exists and has proper columns
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'employees' 
        AND column_name = 'permissions'
        AND data_type = 'jsonb'
    ) THEN
        -- Add permissions column if it doesn't exist
        ALTER TABLE employees ADD COLUMN IF NOT EXISTS permissions jsonb DEFAULT '{}'::jsonb;
    END IF;
    
    -- Ensure contact_info constraint allows proper structure
    ALTER TABLE employees DROP CONSTRAINT IF EXISTS employees_contact_info_check;
    ALTER TABLE employees ADD CONSTRAINT employees_contact_info_check CHECK (
        contact_info ? 'email' AND 
        (contact_info->>'email')::text IS NOT NULL AND 
        (contact_info->>'email')::text != ''
    );
    
    -- Update role constraint to include all valid roles
    ALTER TABLE employees DROP CONSTRAINT IF EXISTS employees_role_check;
    ALTER TABLE employees ADD CONSTRAINT employees_role_check CHECK (
        role IN ('Admin', 'Manager', 'Mechanic', 'Inspector', 'User', 'Sales', 'Driver', 'FineAdmin')
    );
END $$;

-- ============================================================================
-- 2. CREATE/UPDATE SECURITY FUNCTIONS
-- ============================================================================

-- Function to safely create employee records without RLS conflicts
CREATE OR REPLACE FUNCTION public.create_employee_record(
    employee_id text,
    employee_name text,
    employee_role text,
    employee_tenant_id text,
    employee_contact_info jsonb,
    employee_permissions jsonb DEFAULT '{}'::jsonb,
    employee_roles_extra text[] DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Insert employee record directly without RLS
    INSERT INTO employees (
        id,
        name,
        role,
        tenant_id,
        contact_info,
        permissions,
        roles_extra,
        active,
        created_at,
        updated_at
    ) VALUES (
        employee_id,
        employee_name,
        employee_role,
        employee_tenant_id,
        employee_contact_info,
        employee_permissions,
        employee_roles_extra,
        true,
        NOW(),
        NOW()
    );
    
    RETURN true;
EXCEPTION WHEN OTHERS THEN
    RETURN false;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.create_employee_record TO authenticated;

-- ============================================================================
-- 3. SIMPLIFY RLS POLICIES
-- ============================================================================

-- Drop all existing policies
DROP POLICY IF EXISTS "employees_select_policy" ON employees;
DROP POLICY IF EXISTS "employees_insert_policy" ON employees;
DROP POLICY IF EXISTS "employees_update_policy" ON employees;
DROP POLICY IF EXISTS "employees_delete_policy" ON employees;
DROP POLICY IF EXISTS "employees_select_self" ON employees;
DROP POLICY IF EXISTS "employees_update_self" ON employees;
DROP POLICY IF EXISTS "employees_select_tenant" ON employees;
DROP POLICY IF EXISTS "employees_admin" ON employees;
DROP POLICY IF EXISTS "employees_insert_self" ON employees;

-- Create simple, working policies
-- 1. Allow authenticated users to read all employees (for now)
CREATE POLICY "employees_read_all" ON employees
FOR SELECT TO authenticated
USING (true);

-- 2. Allow authenticated users to insert their own records
CREATE POLICY "employees_insert_own" ON employees
FOR INSERT TO authenticated
WITH CHECK (id = auth.uid()::text);

-- 3. Allow users to update their own records
CREATE POLICY "employees_update_own" ON employees
FOR UPDATE TO authenticated
USING (id = auth.uid()::text)
WITH CHECK (id = auth.uid()::text);

-- 4. Allow admin users to do everything
CREATE POLICY "employees_admin_all" ON employees
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM employees e
        WHERE e.id = auth.uid()::text
        AND e.role = 'Admin'
        AND e.active = true
    )
);

-- ============================================================================
-- 4. CREATE HELPER FUNCTIONS FOR AUTHENTICATION
-- ============================================================================

-- Function to check if user exists by email
CREATE OR REPLACE FUNCTION public.get_employee_by_email_safe(email_param text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    employee_data jsonb;
BEGIN
    SELECT jsonb_build_object(
        'id', e.id,
        'name', e.name,
        'role', e.role,
        'tenant_id', e.tenant_id,
        'contact_info', e.contact_info,
        'permissions', e.permissions,
        'roles_extra', e.roles_extra,
        'active', e.active,
        'created_at', e.created_at,
        'updated_at', e.updated_at
    )
    INTO employee_data
    FROM employees e
    WHERE LOWER(e.contact_info->>'email') = LOWER(email_param)
    AND e.active = true
    LIMIT 1;

    RETURN employee_data;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_employee_by_email_safe TO authenticated;

-- ============================================================================
-- 5. ENSURE MINIMUM VIABLE ADMIN USER
-- ============================================================================

-- Ensure we have at least one admin user that can be used
DO $$
DECLARE
    admin_exists boolean;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM employees 
        WHERE role = 'Admin' 
        AND active = true
        AND tenant_id = '00000000-0000-0000-0000-000000000001'
    ) INTO admin_exists;
    
    IF NOT admin_exists THEN
        -- Create a basic admin user
        INSERT INTO employees (
            id,
            name,
            role,
            tenant_id,
            contact_info,
            permissions,
            active,
            created_at,
            updated_at
        ) VALUES (
            'admin-bootstrap-' || extract(epoch from now())::text,
            'Admin Bootstrap',
            'Admin',
            '00000000-0000-0000-0000-000000000001',
            '{"email": "admin@oneway.local"}'::jsonb,
            '{"admin": true, "dashboard": true, "costs": true, "fleet": true, "contracts": true, "fines": true, "statistics": true, "employees": true, "suppliers": true, "purchases": true, "inventory": true, "maintenance": true, "inspections": true, "finance": true}'::jsonb,
            true,
            NOW(),
            NOW()
        )
        ON CONFLICT (id) DO NOTHING;
        
        RAISE NOTICE 'Bootstrap admin user created';
    END IF;
END $$;

-- Add comments
COMMENT ON FUNCTION public.create_employee_record IS 'Safely creates employee records bypassing RLS';
COMMENT ON FUNCTION public.get_employee_by_email_safe IS 'Safely retrieves employee by email bypassing RLS'; 