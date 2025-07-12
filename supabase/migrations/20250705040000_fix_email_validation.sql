-- Drop existing view if it exists
DROP VIEW IF EXISTS public.vw_employees_email;

-- Remove the problematic trigger
DROP TRIGGER IF EXISTS validate_login_trigger ON auth.users;
DROP FUNCTION IF EXISTS public.validate_login();

-- First, mark duplicate emails as inactive, keeping only the most recent one active
UPDATE employees e1
SET 
    active = false,
    contact_info = jsonb_set(
        contact_info, 
        '{status}',
        '"duplicate_resolved"'::jsonb
    )
WHERE id IN (
    SELECT e1.id
    FROM employees e1
    JOIN employees e2 ON LOWER(e1.contact_info->>'email') = LOWER(e2.contact_info->>'email')
    WHERE e1.id > e2.id  -- Keep the earliest record active
    AND e1.active = true
    AND e2.active = true
);

-- Create a view for email validation that handles JSONB properly and ensures uniqueness
CREATE VIEW public.vw_employees_email AS
WITH ranked_employees AS (
    SELECT 
        id,
        contact_info,
        active,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY LOWER(contact_info->>'email') 
            ORDER BY created_at DESC
        ) as rn
    FROM employees
    WHERE active = true
    AND (contact_info->>'status' IS NULL 
        OR contact_info->>'status' NOT IN ('orphaned', 'orphaned_duplicate', 'duplicate_resolved'))
)
SELECT 
    id,
    contact_info,
    active,
    created_at
FROM ranked_employees
WHERE rn = 1;

-- Create an index to improve performance
DROP INDEX IF EXISTS idx_employees_email;
CREATE INDEX idx_employees_email ON employees USING gin (contact_info);
CREATE INDEX idx_employees_email_text ON employees ((LOWER(contact_info->>'email')));

-- Create a simpler validation function that uses the view
CREATE OR REPLACE FUNCTION public.validate_login_email(p_email text)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.vw_employees_email
    WHERE LOWER(contact_info->>'email') = LOWER(p_email)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT SELECT ON public.vw_employees_email TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_login_email TO authenticated;

-- Update RLS policy to use the view for better performance
DROP POLICY IF EXISTS "employees_select_policy" ON employees;
CREATE POLICY "employees_select_policy" ON employees
FOR SELECT USING (
  EXISTS (
    SELECT 1 
    FROM public.vw_employees_email
    WHERE id = auth.uid()
  )
); 