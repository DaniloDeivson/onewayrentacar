-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their tenant employees" ON employees;
DROP POLICY IF EXISTS "Admins can manage employees" ON employees;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON employees;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON employees;
DROP POLICY IF EXISTS "Enable update for users based on email" ON employees;
DROP POLICY IF EXISTS "Enable delete for users based on email" ON employees;
DROP POLICY IF EXISTS "Allow read access for all authenticated users" ON employees;
DROP POLICY IF EXISTS "Allow users to update their own data" ON employees;
DROP POLICY IF EXISTS "Allow full access for admins" ON employees;

-- Política básica de leitura
CREATE POLICY "Enable read for authenticated users"
ON employees FOR SELECT
TO authenticated
USING (true);

-- Política para atualização própria
CREATE POLICY "Enable self update"
ON employees FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Política para admins (usando subquery para evitar recursão)
CREATE POLICY "Enable admin access"
ON employees FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM employees 
    WHERE id = auth.uid() 
    AND role = 'Admin'
    AND id != employees.id  -- Evita recursão
  )
  OR (id = auth.uid())  -- Admin pode gerenciar seu próprio registro
);

-- Garantir que o serviço tenha acesso total
GRANT ALL ON employees TO service_role;

-- Função auxiliar para verificar se um usuário existe
CREATE OR REPLACE FUNCTION public.user_exists(user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM employees 
    WHERE id = user_id 
    AND active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Atualizar função is_admin para considerar roles_extra e status ativo
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM employees
    WHERE id = auth.uid()::uuid
    AND active = true
    AND (
      role = 'Admin' 
      OR 'Admin' = ANY(roles_extra)
    )
    AND (contact_info->>'status' IS NULL OR contact_info->>'status' NOT IN ('orphaned', 'orphaned_duplicate'))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Atualizar política de SELECT para considerar apenas usuários ativos
DROP POLICY IF EXISTS "employees_select_policy" ON employees;
CREATE POLICY "employees_select_policy" ON employees
FOR SELECT USING (
  tenant_id = (
    SELECT tenant_id FROM employees 
    WHERE id = auth.uid()::uuid 
    AND active = true
    AND (contact_info->>'status' IS NULL OR contact_info->>'status' NOT IN ('orphaned', 'orphaned_duplicate'))
    LIMIT 1
  )
  AND active = true
  AND (contact_info->>'status' IS NULL OR contact_info->>'status' NOT IN ('orphaned', 'orphaned_duplicate'))
);

-- Função para validar login
CREATE OR REPLACE FUNCTION public.validate_login()
RETURNS trigger AS $$
BEGIN
  -- Verificar se existe um usuário ativo com o mesmo email
  IF EXISTS (
    SELECT 1 FROM employees
    WHERE 
      contact_info->>'email' = NEW.email
      AND active = true
      AND (contact_info->>'status' IS NULL OR contact_info->>'status' NOT IN ('orphaned', 'orphaned_duplicate'))
  ) THEN
    RETURN NEW;
  ELSE
    RAISE EXCEPTION 'Usuário inativo ou não encontrado';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Aplicar trigger de validação no login
DROP TRIGGER IF EXISTS validate_login_trigger ON auth.users;
CREATE TRIGGER validate_login_trigger
  BEFORE INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION validate_login();

-- Marcar duplicatas como inativas
UPDATE employees 
SET 
  active = false,
  contact_info = jsonb_set(
    contact_info, 
    '{status}', 
    '"orphaned_duplicate"'::jsonb
  )
WHERE id IN (
  SELECT e1.id
  FROM employees e1
  JOIN employees e2 ON (e1.contact_info->>'email') = (e2.contact_info->>'email')
  WHERE e1.id > e2.id
  AND e1.active = true
  AND e2.active = true
);

-- Remover permissões de usuários inativos
UPDATE employees
SET permissions = '{}'::jsonb
WHERE active = false
OR (contact_info->>'status' IN ('orphaned', 'orphaned_duplicate')); 