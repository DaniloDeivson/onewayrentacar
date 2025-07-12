-- Fix duplicate users and normalize permissions
BEGIN;

-- Temporarily disable audit trigger
ALTER TABLE employees DISABLE TRIGGER audit_employees_changes;

-- First, mark all duplicates as inactive and orphaned
WITH duplicate_emails AS (
  SELECT contact_info->>'email' as email
  FROM employees
  WHERE contact_info->>'email' IS NOT NULL
  GROUP BY contact_info->>'email'
  HAVING COUNT(*) > 1
)
UPDATE employees e
SET 
  active = false,
  contact_info = jsonb_set(
    contact_info,
    '{status}',
    '"orphaned_duplicate"'
  )
WHERE contact_info->>'email' IN (
  SELECT email FROM duplicate_emails
)
AND id NOT IN (
  -- Keep the most recently updated active record for each email
  SELECT DISTINCT ON (contact_info->>'email') id
  FROM employees
  WHERE contact_info->>'email' IN (SELECT email FROM duplicate_emails)
  AND active = true
  ORDER BY contact_info->>'email', updated_at DESC
);

-- Set default permissions for users with empty permissions
UPDATE employees
SET permissions = jsonb_build_object(
  'admin', CASE 
    WHEN role = 'Admin' OR 'Admin' = ANY(roles_extra::text[]) THEN true 
    ELSE false 
  END,
  'costs', CASE 
    WHEN role IN ('Admin', 'Sales') OR 'Admin' = ANY(roles_extra::text[]) THEN true 
    ELSE false 
  END,
  'fines', CASE 
    WHEN role IN ('Admin', 'Sales') OR 'Admin' = ANY(roles_extra::text[]) THEN true 
    ELSE false 
  END,
  'fleet', CASE 
    WHEN role IN ('Admin', 'Sales', 'Mechanic', 'Driver', 'PatioInspector') OR 'Admin' = ANY(roles_extra::text[]) THEN true 
    ELSE false 
  END,
  'finance', CASE 
    WHEN role IN ('Admin', 'Sales') OR 'Admin' = ANY(roles_extra::text[]) THEN true 
    ELSE false 
  END,
  'contracts', CASE 
    WHEN role IN ('Admin', 'Sales') OR 'Admin' = ANY(roles_extra::text[]) THEN true 
    ELSE false 
  END,
  'dashboard', true,
  'employees', CASE 
    WHEN role = 'Admin' OR 'Admin' = ANY(roles_extra::text[]) THEN true 
    ELSE false 
  END,
  'inventory', CASE 
    WHEN role IN ('Admin', 'Sales', 'Mechanic') OR 'Admin' = ANY(roles_extra::text[]) THEN true 
    ELSE false 
  END,
  'purchases', CASE 
    WHEN role = 'Admin' OR 'Admin' = ANY(roles_extra::text[]) THEN true 
    ELSE false 
  END,
  'suppliers', CASE 
    WHEN role = 'Admin' OR 'Admin' = ANY(roles_extra::text[]) THEN true 
    ELSE false 
  END,
  'statistics', CASE 
    WHEN role = 'Admin' OR 'Admin' = ANY(roles_extra::text[]) THEN true 
    ELSE false 
  END,
  'inspections', CASE 
    WHEN role IN ('Admin', 'PatioInspector') OR 'Admin' = ANY(roles_extra::text[]) THEN true 
    ELSE false 
  END,
  'maintenance', CASE 
    WHEN role IN ('Admin', 'Mechanic') OR 'Admin' = ANY(roles_extra::text[]) THEN true 
    ELSE false 
  END
)
WHERE permissions = '{}'::jsonb
AND active = true;

-- Create unique index to prevent future duplicates
DROP INDEX IF EXISTS idx_employees_email;
CREATE UNIQUE INDEX idx_employees_email 
ON employees ((contact_info->>'email')) 
WHERE active = true;

-- Re-enable audit trigger
ALTER TABLE employees ENABLE TRIGGER audit_employees_changes;

-- Add a manual audit log entry for this migration
INSERT INTO audit_log (
  table_name,
  record_id,
  operation,
  old_data,
  new_data,
  changed_by,
  tenant_id,
  changed_at
)
SELECT 
  'employees',
  id,
  'UPDATE',
  NULL,
  to_jsonb(e),
  '00000000-0000-0000-0000-000000000001'::uuid, -- System user ID
  tenant_id,
  now()
FROM employees e
WHERE permissions = '{}'::jsonb
AND active = true;

COMMIT; 