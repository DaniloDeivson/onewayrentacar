-- Primeiro, remover todas as políticas existentes da tabela employees para evitar conflitos
DROP POLICY IF EXISTS "Employees can view their own profile" ON employees;
DROP POLICY IF EXISTS "Employees can update their own profile" ON employees;
DROP POLICY IF EXISTS "Admins can view all employees" ON employees;
DROP POLICY IF EXISTS "Admins can update all employees" ON employees;
DROP POLICY IF EXISTS "Managers can view employees" ON employees;
DROP POLICY IF EXISTS "Managers can update employees" ON employees;

-- Garantir que RLS está habilitado
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

-- Política para permitir que usuários vejam seu próprio perfil
CREATE POLICY "Users can view own profile"
ON employees
FOR SELECT
USING (
  auth.uid() = id
  OR 
  EXISTS (
    SELECT 1 FROM employees e 
    WHERE e.id = auth.uid() 
    AND (e.role = 'Admin' OR e.role = 'Manager')
  )
);

-- Política para permitir que usuários atualizem seu próprio perfil
CREATE POLICY "Users can update own profile"
ON employees
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Política para permitir que admins e gerentes vejam todos os funcionários
CREATE POLICY "Admins and managers can view all"
ON employees
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM employees e 
    WHERE e.id = auth.uid() 
    AND (e.role = 'Admin' OR e.role = 'Manager')
  )
);

-- Política para permitir que admins atualizem qualquer funcionário
CREATE POLICY "Admins can update all"
ON employees
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM employees e 
    WHERE e.id = auth.uid() 
    AND e.role = 'Admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM employees e 
    WHERE e.id = auth.uid() 
    AND e.role = 'Admin'
  )
);

-- Política para permitir inserção de novos funcionários
CREATE POLICY "Allow employee registration"
ON employees
FOR INSERT
WITH CHECK (
  -- Permitir que qualquer usuário autenticado crie seu próprio registro
  id = auth.uid()
  OR
  -- Ou que admins criem registros para outros
  EXISTS (
    SELECT 1 FROM employees e 
    WHERE e.id = auth.uid() 
    AND e.role = 'Admin'
  )
);

-- Política para permitir que admins deletem funcionários
CREATE POLICY "Admins can delete"
ON employees
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM employees e 
    WHERE e.id = auth.uid() 
    AND e.role = 'Admin'
  )
);

-- Criar índice para melhorar performance das consultas por email
CREATE INDEX IF NOT EXISTS idx_employees_email 
ON employees USING gin ((contact_info->'email'));

-- Criar índice para melhorar performance das consultas por tenant_id
CREATE INDEX IF NOT EXISTS idx_employees_tenant_id 
ON employees (tenant_id);

-- Criar índice para melhorar performance das consultas por role
CREATE INDEX IF NOT EXISTS idx_employees_role
ON employees (role);

-- Garantir que temos pelo menos um usuário admin
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM employees 
    WHERE role = 'Admin' 
    AND tenant_id = '00000000-0000-0000-0000-000000000001'
  ) THEN
    INSERT INTO employees (
      id,
      name,
      role,
      contact_info,
      active,
      tenant_id
    ) VALUES (
      '00000000-0000-0000-0000-000000000002',
      'Admin',
      'Admin',
      '{"email": "admin@onewayrentacar.com", "phone": null}'::jsonb,
      true,
      '00000000-0000-0000-0000-000000000001'
    );
  END IF;
END $$; 