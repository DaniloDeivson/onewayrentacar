-- Criar função para obter email do employee
CREATE OR REPLACE FUNCTION public.vw_employees_email(employee_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT contact_info->>'email'
  FROM employees
  WHERE id = employee_id;
$$;

-- Criar função para validar email
CREATE OR REPLACE FUNCTION public.is_valid_email(email text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
$$;

-- Criar função para normalizar email
CREATE OR REPLACE FUNCTION public.normalize_email(email text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT LOWER(TRIM(email));
$$;

-- Atualizar a política de autenticação para usar vw_employees_email
DROP POLICY IF EXISTS "employees_email_policy" ON employees;
CREATE POLICY "employees_email_policy" ON employees
FOR SELECT USING (
  auth.email() = public.vw_employees_email(id)
  AND active = true
  AND tenant_id = (auth.jwt()->>'tenant_id')::uuid
);

-- Criar índice composto para melhorar performance de busca por email e tenant
DROP INDEX IF EXISTS idx_employees_email_tenant;
CREATE INDEX idx_employees_email_tenant 
ON employees ((public.normalize_email(contact_info->>'email')), tenant_id) 
WHERE active = true;

-- Criar índice para busca por role
DROP INDEX IF EXISTS idx_employees_role;
CREATE INDEX idx_employees_role
ON employees (role)
WHERE active = true;

-- Verificar e corrigir registros com email inválido
UPDATE employees
SET active = false,
    contact_info = jsonb_set(
      jsonb_set(
        contact_info,
        '{status}',
        '"invalid_email"'
      ),
      '{updated_reason}',
      '"Email inválido detectado e desativado automaticamente"'
    ),
    permissions = '{}'::jsonb
WHERE 
  active = true 
  AND NOT public.is_valid_email(contact_info->>'email');

-- Normalizar emails existentes
UPDATE employees
SET contact_info = jsonb_set(
  contact_info,
  '{email}',
  to_jsonb(public.normalize_email(contact_info->>'email'))
)
WHERE 
  contact_info->>'email' IS NOT NULL 
  AND contact_info->>'email' != public.normalize_email(contact_info->>'email');

-- Verificar e corrigir registros sem email ou inativos
UPDATE employees
SET active = false,
    contact_info = jsonb_set(
      jsonb_set(
        contact_info,
        '{status}',
        '"orphaned"'
      ),
      '{updated_reason}',
      '"Registro sem email válido detectado e desativado automaticamente"'
    ),
    permissions = '{}'::jsonb
WHERE 
  contact_info->>'email' IS NULL 
  OR contact_info->>'email' = ''
  OR (contact_info->>'status' = 'orphaned' AND active = true);

-- Sincronizar emails entre auth.users e employees considerando tenant_id e roles
WITH email_mismatches AS (
  SELECT 
    e.id,
    e.tenant_id,
    public.vw_employees_email(e.id) as employee_email,
    u.email as auth_email,
    e.roles_extra,
    e.role as base_role,
    e.permissions
  FROM employees e
  JOIN auth.users u ON u.id = e.id::uuid
  WHERE (public.normalize_email(public.vw_employees_email(e.id)) != public.normalize_email(u.email)
    OR (u.raw_app_meta_data->>'tenant_id')::uuid != e.tenant_id
    OR (u.raw_app_meta_data->'roles')::jsonb IS DISTINCT FROM COALESCE(to_jsonb(e.roles_extra), '[]'::jsonb))
    AND e.active = true
)
UPDATE auth.users u
SET 
    email = m.employee_email,
    email_confirmed_at = NOW(),
    raw_app_meta_data = jsonb_build_object(
      'tenant_id', m.tenant_id,
      'roles', COALESCE(to_jsonb(m.roles_extra), '[]'::jsonb),
      'base_role', m.base_role,
      'permissions', m.permissions
    )
FROM email_mismatches m
WHERE u.id = m.id::uuid;

-- Adicionar constraint para garantir email único por tenant
ALTER TABLE employees
DROP CONSTRAINT IF EXISTS unique_active_email_per_tenant;

CREATE UNIQUE INDEX unique_active_email_per_tenant
ON employees ((public.normalize_email(contact_info->>'email')), tenant_id)
WHERE active = true;

-- Verificar e corrigir registros duplicados por tenant
WITH duplicates AS (
  SELECT 
    public.normalize_email(public.vw_employees_email(id)) as email,
    tenant_id,
    array_agg(id ORDER BY 
      CASE 
        WHEN role = 'Admin' THEN 1
        WHEN permissions->>'admin' = 'true' THEN 2
        ELSE 3
      END,
      created_at
    ) as ids,
    array_agg(created_at) as dates,
    array_agg(role) as roles
  FROM employees
  WHERE active = true
  GROUP BY public.normalize_email(public.vw_employees_email(id)), tenant_id
  HAVING COUNT(*) > 1
)
UPDATE employees e
SET 
  active = false,
  contact_info = jsonb_set(
    jsonb_set(
      contact_info,
      '{status}',
      '"orphaned_duplicate"'
    ),
    '{updated_reason}',
    '"Registro duplicado detectado e desativado automaticamente. Mantido registro com maior privilégio/mais antigo."'
  ),
  permissions = '{}'::jsonb
WHERE id = ANY(
  SELECT unnest(ids[2:])::uuid
  FROM duplicates
);

-- Criar view para auditoria de registros problemáticos
CREATE OR REPLACE VIEW vw_employee_audit AS
SELECT 
  e.id,
  e.tenant_id,
  e.name,
  e.role as base_role,
  e.roles_extra,
  e.active,
  e.contact_info->>'email' as email,
  e.contact_info->>'status' as status,
  e.contact_info->>'updated_reason' as update_reason,
  e.permissions,
  EXISTS(
    SELECT 1 FROM auth.users u WHERE u.id = e.id::uuid
  ) as has_auth_user,
  e.created_at,
  e.updated_at
FROM employees e
WHERE 
  NOT e.active 
  OR e.contact_info->>'status' IS NOT NULL
ORDER BY e.updated_at DESC;

-- Criar view para monitoramento de sincronização
CREATE OR REPLACE VIEW vw_employee_sync_status AS
SELECT 
  e.id,
  e.name,
  e.role as base_role,
  e.roles_extra,
  e.active,
  public.vw_employees_email(e.id) as employee_email,
  u.email as auth_email,
  e.tenant_id as employee_tenant,
  (u.raw_app_meta_data->>'tenant_id')::uuid as auth_tenant,
  (u.raw_app_meta_data->'roles')::jsonb as auth_roles,
  e.permissions as employee_permissions,
  (u.raw_app_meta_data->'permissions')::jsonb as auth_permissions,
  CASE 
    WHEN NOT e.active THEN 'inactive'
    WHEN u.id IS NULL THEN 'missing_auth'
    WHEN public.normalize_email(public.vw_employees_email(e.id)) != public.normalize_email(u.email) THEN 'email_mismatch'
    WHEN (u.raw_app_meta_data->>'tenant_id')::uuid != e.tenant_id THEN 'tenant_mismatch'
    WHEN (u.raw_app_meta_data->'roles')::jsonb IS DISTINCT FROM COALESCE(to_jsonb(e.roles_extra), '[]'::jsonb) THEN 'roles_mismatch'
    ELSE 'synced'
  END as sync_status,
  e.updated_at,
  u.updated_at as auth_updated_at
FROM employees e
LEFT JOIN auth.users u ON u.id = e.id::uuid
WHERE e.active = true
ORDER BY 
  CASE 
    WHEN u.id IS NULL THEN 1
    WHEN public.normalize_email(public.vw_employees_email(e.id)) != public.normalize_email(u.email) THEN 2
    WHEN (u.raw_app_meta_data->>'tenant_id')::uuid != e.tenant_id THEN 3
    WHEN (u.raw_app_meta_data->'roles')::jsonb IS DISTINCT FROM COALESCE(to_jsonb(e.roles_extra), '[]'::jsonb) THEN 4
    ELSE 5
  END,
  e.updated_at DESC; 