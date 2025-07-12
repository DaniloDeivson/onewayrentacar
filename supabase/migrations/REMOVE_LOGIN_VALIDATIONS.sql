-- Remove the login validation trigger
DROP TRIGGER IF EXISTS validate_login_trigger ON auth.users;
DROP FUNCTION IF EXISTS public.validate_login();

-- Drop all email-related indices first
DROP INDEX IF EXISTS unique_active_email_per_tenant;
DROP INDEX IF EXISTS idx_employees_email_tenant;
DROP INDEX IF EXISTS idx_employees_email;

-- Create or replace the normalize_email function as IMMUTABLE
CREATE OR REPLACE FUNCTION public.normalize_email(email text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT LOWER(TRIM(email));
$$;

-- Create view for login validation
CREATE OR REPLACE VIEW public.vw_employees_email AS
SELECT 
  e.id,
  e.tenant_id,
  public.normalize_email(e.contact_info->>'email') as email,
  e.active,
  e.role,
  e.permissions,
  e.roles_extra,
  e.contact_info->>'status' as status
FROM employees e;

-- Create function to validate login using the view
CREATE OR REPLACE FUNCTION public.validate_login_email(login_email text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM vw_employees_email 
    WHERE email = public.normalize_email(login_email)
  );
$$;

-- Update RLS policies to use the view for login
DROP POLICY IF EXISTS "employees_select_policy" ON employees;
CREATE POLICY "employees_select_policy" ON employees
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 
    FROM vw_employees_email v 
    WHERE v.email = public.normalize_email(auth.email())
  )
);

-- Identify and handle duplicate emails
WITH duplicates AS (
  SELECT 
    email,
    array_agg(id ORDER BY 
      CASE 
        WHEN role = 'Admin' THEN 1
        WHEN permissions->>'admin' = 'true' THEN 2
        WHEN active = true THEN 3
        ELSE 4
      END,
      created_at DESC
    ) as ids
  FROM vw_employees_email
  WHERE email IS NOT NULL
  GROUP BY email
  HAVING COUNT(*) > 1
)
UPDATE employees e
SET 
  active = false,
  contact_info = jsonb_set(
    contact_info,
    '{status}',
    '"duplicate_resolved"'
  )
WHERE id IN (
  SELECT unnest(ids[2:]) -- Keep only the first record (most privileged/recent)
  FROM duplicates
);

-- Now reactivate non-duplicate orphaned records
UPDATE employees
SET 
  active = true,
  contact_info = contact_info - 'status'
WHERE 
  id NOT IN (
    SELECT e.id
    FROM vw_employees_email e
    WHERE email IN (
      SELECT email
      FROM vw_employees_email
      GROUP BY email
      HAVING COUNT(*) > 1
    )
  )
  AND (
    contact_info->>'status' IN ('orphaned', 'orphaned_duplicate')
    OR NOT active
  );

-- Finally create the email index
CREATE INDEX idx_employees_email_tenant 
ON employees ((contact_info->>'email'), tenant_id);

-- Grant necessary permissions
GRANT SELECT ON public.vw_employees_email TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_login_email TO authenticated; 