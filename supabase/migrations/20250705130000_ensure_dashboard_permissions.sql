-- Ensure all active employees have dashboard permission
UPDATE employees 
SET permissions = COALESCE(permissions, '{}'::jsonb) || '{"dashboard": true}'::jsonb
WHERE active = true 
AND (permissions IS NULL OR permissions->>'dashboard' IS NULL);

-- Ensure Admin users have all permissions
UPDATE employees 
SET permissions = '{
  "dashboard": true,
  "fleet": true,
  "costs": true,
  "maintenance": true,
  "inventory": true,
  "contracts": true,
  "inspections": true,
  "fines": true,
  "suppliers": true,
  "purchases": true,
  "statistics": true,
  "finance": true,
  "admin": true,
  "employees": true
}'::jsonb
WHERE role = 'Admin' AND active = true;

-- Ensure Manager users have common permissions
UPDATE employees 
SET permissions = COALESCE(permissions, '{}'::jsonb) || '{
  "dashboard": true,
  "fleet": true,
  "costs": true,
  "maintenance": true,
  "inventory": true,
  "contracts": true,
  "inspections": true,
  "fines": true,
  "suppliers": true,
  "purchases": true,
  "statistics": true,
  "finance": true
}'::jsonb
WHERE role = 'Manager' AND active = true;

-- Ensure Mechanic users have maintenance permissions
UPDATE employees 
SET permissions = COALESCE(permissions, '{}'::jsonb) || '{
  "dashboard": true,
  "maintenance": true,
  "inventory": true
}'::jsonb
WHERE role = 'Mechanic' AND active = true;

-- Ensure Inspector users have inspection permissions
UPDATE employees 
SET permissions = COALESCE(permissions, '{}'::jsonb) || '{
  "dashboard": true,
  "inspections": true,
  "fleet": true
}'::jsonb
WHERE role = 'Inspector' AND active = true;

-- Ensure User role has basic permissions
UPDATE employees 
SET permissions = COALESCE(permissions, '{}'::jsonb) || '{
  "dashboard": true
}'::jsonb
WHERE role = 'User' AND active = true; 