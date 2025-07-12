-- Create function to list employees for admin without RLS issues
CREATE OR REPLACE FUNCTION public.list_employees_for_admin()
RETURNS SETOF employees
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Direct query without RLS to get all active employees
    RETURN QUERY
    SELECT *
    FROM employees e
    WHERE e.active = true
    ORDER BY e.name;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.list_employees_for_admin() TO authenticated;

-- Add comment
COMMENT ON FUNCTION public.list_employees_for_admin IS 'Lists all active employees for admin users without triggering RLS policies'; 