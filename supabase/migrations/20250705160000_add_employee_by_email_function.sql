-- Add function to get employee by email without RLS issues
-- Drop the function if it exists to recreate it properly
DROP FUNCTION IF EXISTS public.get_employee_by_email(text);

-- Create function to safely get employee data by email
CREATE OR REPLACE FUNCTION public.get_employee_by_email(email_param text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    employee_data jsonb;
BEGIN
    -- Direct query without RLS to get employee data by email
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
    AND (e.contact_info->>'status' IS NULL 
        OR e.contact_info->>'status' NOT IN ('orphaned', 'orphaned_duplicate', 'duplicate_resolved'))
    LIMIT 1;

    RETURN employee_data;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_employee_by_email(text) TO authenticated;

-- Add comment
COMMENT ON FUNCTION public.get_employee_by_email IS 'Safely retrieves employee data by email without triggering RLS policies'; 