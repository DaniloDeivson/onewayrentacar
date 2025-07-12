-- Create a real admin user with full access
DO $$
DECLARE
  v_user_id uuid;
  v_email text := 'pedropardal04@gmail.com';
  v_password text := 'senha123'; -- This will be replaced with the actual password hash
  v_permissions jsonb := '{
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
  -- First, create the auth user
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    v_email,
    crypt(v_password, gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"name":"Pedro Pardal"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  )
  RETURNING id INTO v_user_id;

  -- Then, create the employee record
  INSERT INTO employees (
    id,
    tenant_id,
    name,
    role,
    employee_code,
    contact_info,
    active,
    permissions
  ) VALUES (
    v_user_id,
    '00000000-0000-0000-0000-000000000001',
    'Pedro Pardal',
    'Admin',
    'ADM002',
    jsonb_build_object(
      'email', v_email,
      'phone', '(11) 99999-9999'
    ),
    true,
    v_permissions
  );

  RAISE NOTICE 'Created admin user with ID: %', v_user_id;
END $$;