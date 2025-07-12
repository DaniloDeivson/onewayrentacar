-- Create admin user for profitestrategista@gmail.com
DO $$
DECLARE
  v_user_id uuid;
  v_tenant_id uuid := '00000000-0000-0000-0000-000000000001';
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
      jsonb_build_object(
        'dashboard', true,
        'costs', true,
        'fleet', true,
        'contracts', true,
        'fines', true,
        'statistics', true,
        'employees', true,
        'admin', true,
        'suppliers', true,
        'purchases', true,
        'inventory', true,
        'maintenance', true,
        'inspections', true,
        'finance', true
      ),
      now(),
      now()
    );
    
    RAISE NOTICE 'Admin user created for profitestrategista@gmail.com';
  ELSE
    -- Update existing user with admin permissions
    UPDATE employees
    SET 
      role = 'Admin',
      permissions = jsonb_build_object(
        'dashboard', true,
        'costs', true,
        'fleet', true,
        'contracts', true,
        'fines', true,
        'statistics', true,
        'employees', true,
        'admin', true,
        'suppliers', true,
        'purchases', true,
        'inventory', true,
        'maintenance', true,
        'inspections', true,
        'finance', true
      ),
      updated_at = now()
    WHERE contact_info->>'email' = 'profitestrategista@gmail.com';
    
    RAISE NOTICE 'Admin permissions updated for profitestrategista@gmail.com';
  END IF;
  
  -- Ensure the user has the correct tenant_id
  UPDATE employees
  SET tenant_id = v_tenant_id
  WHERE contact_info->>'email' = 'profitestrategista@gmail.com'
  AND tenant_id IS DISTINCT FROM v_tenant_id;
  
  -- Make sure the user is active
  UPDATE employees
  SET active = true
  WHERE contact_info->>'email' = 'profitestrategista@gmail.com'
  AND active IS DISTINCT FROM true;
END $$;