-- Drop existing policies
DROP POLICY IF EXISTS "tenant_isolation_policy" ON employees;
DROP POLICY IF EXISTS "read_policy" ON employees;
DROP POLICY IF EXISTS "update_policy" ON employees;
DROP POLICY IF EXISTS "insert_policy" ON employees;
DROP POLICY IF EXISTS "delete_policy" ON employees;

-- Drop existing functions
DROP FUNCTION IF EXISTS public.validate_session();
DROP FUNCTION IF EXISTS public.has_permission(text);
DROP FUNCTION IF EXISTS public.get_user_tenant();

-- Create optimized security functions
CREATE OR REPLACE FUNCTION public.get_user_tenant()
RETURNS uuid AS $$
DECLARE
    user_tenant_id uuid;
BEGIN
    -- Direct query without RLS check to avoid recursion
    SELECT tenant_id INTO user_tenant_id
    FROM employees
    WHERE id = auth.uid()
    AND active = true;
    
    RETURN user_tenant_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.validate_session()
RETURNS boolean AS $$
DECLARE
    is_valid boolean;
BEGIN
    -- Direct query without RLS check to avoid recursion
    SELECT EXISTS (
        SELECT 1 
        FROM employees
        WHERE id = auth.uid()
        AND active = true
        AND (contact_info->>'status' IS NULL 
            OR contact_info->>'status' NOT IN ('orphaned', 'orphaned_duplicate', 'duplicate_resolved'))
    ) INTO is_valid;
    
    RETURN is_valid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.has_permission(required_permission text)
RETURNS boolean AS $$
DECLARE
    has_perm boolean;
BEGIN
    -- Direct query without RLS check to avoid recursion
    SELECT EXISTS (
        SELECT 1 
        FROM employees
        WHERE id = auth.uid()
        AND active = true
        AND (
            role = 'Admin'
            OR (permissions->>required_permission)::boolean = true
            OR required_permission = ANY(roles_extra)
        )
        AND (contact_info->>'status' IS NULL 
            OR contact_info->>'status' NOT IN ('orphaned', 'orphaned_duplicate', 'duplicate_resolved'))
    ) INTO has_perm;
    
    RETURN has_perm;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new optimized policies
CREATE POLICY "employees_read_policy" ON employees
FOR SELECT USING (
    -- Simple tenant check first
    tenant_id = (
        SELECT tenant_id 
        FROM employees 
        WHERE id = auth.uid() 
        AND active = true
    )
    -- Then validate session
    AND validate_session()
);

CREATE POLICY "employees_update_policy" ON employees
FOR UPDATE USING (
    validate_session()
    AND (
        -- Self update
        id = auth.uid()
        -- Or admin update within same tenant
        OR (
            has_permission('admin')
            AND tenant_id = (
                SELECT tenant_id 
                FROM employees 
                WHERE id = auth.uid() 
                AND active = true
            )
        )
    )
)
WITH CHECK (
    validate_session()
    AND (
        id = auth.uid()
        OR (
            has_permission('admin')
            AND tenant_id = (
                SELECT tenant_id 
                FROM employees 
                WHERE id = auth.uid() 
                AND active = true
            )
        )
    )
);

CREATE POLICY "employees_insert_policy" ON employees
FOR INSERT WITH CHECK (
    validate_session()
    AND has_permission('admin')
    AND tenant_id = (
        SELECT tenant_id 
        FROM employees 
        WHERE id = auth.uid() 
        AND active = true
    )
);

CREATE POLICY "employees_delete_policy" ON employees
FOR DELETE USING (
    validate_session()
    AND has_permission('admin')
    AND tenant_id = (
        SELECT tenant_id 
        FROM employees 
        WHERE id = auth.uid() 
        AND active = true
    )
);

-- Ensure RLS is enabled
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON employees TO authenticated;
GRANT EXECUTE ON FUNCTION validate_session TO authenticated;
GRANT EXECUTE ON FUNCTION has_permission TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_tenant TO authenticated; 