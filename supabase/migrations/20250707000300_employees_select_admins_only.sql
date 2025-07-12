-- Remove policies antigas de SELECT
DROP POLICY IF EXISTS employees_select_policy ON employees;
DROP POLICY IF EXISTS employees_select_self_policy ON employees;
DROP POLICY IF EXISTS employees_admin_select_policy ON employees;

-- Policy: Admin (da linha) ou o próprio usuário podem ver o registro
CREATE POLICY employees_select_policy
  ON employees
  FOR SELECT
  USING (
    (role = 'Admin')
    OR (id = auth.uid())
  ); 