-- Remover todas as políticas criadas
DROP POLICY IF EXISTS "Users can view own profile" ON employees;
DROP POLICY IF EXISTS "Users can update own profile" ON employees;
DROP POLICY IF EXISTS "Admins and managers can view all" ON employees;
DROP POLICY IF EXISTS "Admins can update all" ON employees;
DROP POLICY IF EXISTS "Admins can insert" ON employees;
DROP POLICY IF EXISTS "Admins can delete" ON employees;

-- Remover índices criados
DROP INDEX IF EXISTS idx_employees_email;
DROP INDEX IF EXISTS idx_employees_tenant_id;
DROP INDEX IF EXISTS idx_employees_role;

-- Desabilitar RLS
ALTER TABLE employees DISABLE ROW LEVEL SECURITY;

-- Remover o usuário admin padrão se existir
DELETE FROM employees 
WHERE id = '00000000-0000-0000-0000-000000000002' 
AND role = 'Admin' 
AND tenant_id = '00000000-0000-0000-0000-000000000001'; 