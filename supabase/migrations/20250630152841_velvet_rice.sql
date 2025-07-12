-- Create admin user for profitestrategista@gmail.com
DO $$
DECLARE
  v_user_id uuid;
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
      '00000000-0000-0000-0000-000000000001',
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
    WHERE id = v_user_id;
    
    RAISE NOTICE 'Admin permissions updated for profitestrategista@gmail.com';
  END IF;
  
  -- Remove demo users
  DELETE FROM employees 
  WHERE contact_info->>'email' IN ('admin@oneway.com', 'gerente@oneway.com')
  AND id != '00000000-0000-0000-0000-000000000001';
  
  RAISE NOTICE 'Demo users removed';
END $$;