/*
  # Remove demo users and ensure profitestrategista@gmail.com has admin access

  1. Changes
    - Remove demo users (admin@oneway.com, gerente@oneway.com)
    - Ensure profitestrategista@gmail.com has admin role and permissions
    - Update permissions for all admin users

  2. Security
    - Maintain proper access control
    - Ensure admin users have all necessary permissions
*/

-- Remove demo users
DELETE FROM employees 
WHERE contact_info->>'email' IN ('admin@oneway.com', 'gerente@oneway.com')
AND id != '00000000-0000-0000-0000-000000000001';

-- Ensure profitestrategista@gmail.com has admin access
DO $$
DECLARE
  v_user_id uuid;
  v_tenant_id uuid := '00000000-0000-0000-0000-000000000001';
  v_admin_permissions jsonb := '{
    "dashboard": true,
    "costs": true,
    "fleet": true,
    "contracts": true,
    "fines": true,
    "statistics": true,
    "employees": true,
    "admin": true,
    "suppliers": true,
    "purchases": true,
    "inventory": true,
    "maintenance": true,
    "inspections": true,
    "finance": true
  }';
BEGIN
  -- Check if user already exists
  SELECT id INTO v_user_id
  FROM employees
  WHERE contact_info->>'email' = 'profitestrategista@gmail.com';
  
  IF v_user_id IS NULL THEN
    -- Create new employee record
    INSERT INTO employees (
      tenant_id,
      name,
      role,
      employee_code,
      contact_info,
      active,
      permissions,
      created_at,
      updated_at
    ) VALUES (
      v_tenant_id,
      'Profit Estrategista',
      'Admin',
      'ADM003',
      jsonb_build_object(
        'email', 'profitestrategista@gmail.com',
        'phone', '(11) 99999-9999'
      ),
      true,
      v_admin_permissions,
      now(),
      now()
    );
    
    RAISE NOTICE 'Admin user created for profitestrategista@gmail.com';
  ELSE
    -- Update existing user with admin permissions
    UPDATE employees
    SET 
      role = 'Admin',
      permissions = v_admin_permissions,
      active = true,
      updated_at = now()
    WHERE id = v_user_id;
    
    RAISE NOTICE 'Admin permissions updated for profitestrategista@gmail.com';
  END IF;
  
  -- Ensure the user has the correct tenant_id
  UPDATE employees
  SET tenant_id = v_tenant_id
  WHERE contact_info->>'email' = 'profitestrategista@gmail.com'
  AND tenant_id IS DISTINCT FROM v_tenant_id;
END $$;