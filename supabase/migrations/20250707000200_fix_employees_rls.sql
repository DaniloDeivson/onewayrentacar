-- Remove policies antigas
DROP POLICY IF EXISTS employees_select_self_policy ON employees;
DROP POLICY IF EXISTS employees_admin_select_policy ON employees;
DROP POLICY IF EXISTS employees_update_self_policy ON employees;
DROP POLICY IF EXISTS employees_admin_update_policy ON employees;
DROP POLICY IF EXISTS employees_delete_self_policy ON employees;
DROP POLICY IF EXISTS employees_admin_delete_policy ON employees;
DROP POLICY IF EXISTS employees_insert_policy ON employees;

-- SELECT: Admin pode ver todos, usuário vê o próprio
CREATE POLICY employees_admin_select_policy
  ON employees
  FOR SELECT
  USING (
    (EXISTS (
      SELECT 1 FROM employees e
      WHERE e.id = auth.uid() AND e.role = 'Admin' AND e.active = true
    ))
    OR (id = auth.uid())
  );

-- UPDATE: Admin pode atualizar todos, usuário o próprio
CREATE POLICY employees_admin_update_policy
  ON employees
  FOR UPDATE
  USING (
    (EXISTS (
      SELECT 1 FROM employees e
      WHERE e.id = auth.uid() AND e.role = 'Admin' AND e.active = true
    ))
    OR (id = auth.uid())
  )
  WITH CHECK (
    (EXISTS (
      SELECT 1 FROM employees e
      WHERE e.id = auth.uid() AND e.role = 'Admin' AND e.active = true
    ))
    OR (id = auth.uid())
  );

-- DELETE: Admin pode deletar todos, usuário o próprio
CREATE POLICY employees_admin_delete_policy
  ON employees
  FOR DELETE
  USING (
    (EXISTS (
      SELECT 1 FROM employees e
      WHERE e.id = auth.uid() AND e.role = 'Admin' AND e.active = true
    ))
    OR (id = auth.uid())
  );

-- INSERT: Admin pode inserir qualquer role, usuário comum só roles públicas
CREATE POLICY employees_insert_policy
  ON employees
  FOR INSERT
  WITH CHECK (
    (EXISTS (
      SELECT 1 FROM employees e
      WHERE e.id = auth.uid() AND e.role = 'Admin' AND e.active = true
    ))
    OR (
      role IN ('Sales', 'Mechanic', 'Inspector', 'User')
    )
  ); 