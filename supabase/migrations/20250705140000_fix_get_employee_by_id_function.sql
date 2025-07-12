-- Fix get_employee_by_id function
-- Drop the function if it exists to recreate it properly
DROP FUNCTION IF EXISTS public.get_employee_by_id(uuid);

-- Create function to safely get employee data
CREATE OR REPLACE FUNCTION public.get_employee_by_id(user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    employee_data jsonb;
BEGIN
    -- Direct query without RLS to get employee data
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
    WHERE e.id = user_id::text
    AND e.active = true
    AND (e.contact_info->>'status' IS NULL 
        OR e.contact_info->>'status' NOT IN ('orphaned', 'orphaned_duplicate', 'duplicate_resolved'));

    RETURN employee_data;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_employee_by_id(uuid) TO authenticated;

-- Add comment
COMMENT ON FUNCTION public.get_employee_by_id IS 'Safely retrieves employee data by ID without triggering RLS policies'; 