-- Corrige a policy de INSERT da tabela employees
DROP POLICY IF EXISTS employees_insert_policy ON employees;

CREATE POLICY employees_insert_policy
  ON employees
  FOR INSERT
  WITH CHECK (
    -- Permite Admin criar qualquer funcionário
    (EXISTS (
      SELECT 1 FROM employees e
      WHERE e.id = auth.uid() AND e.role = 'Admin' AND e.active = true
    ))
    -- Permite registro público apenas para roles não administrativas
    OR (
      role IN ('Sales', 'Mechanic', 'Inspector', 'User')
    )
  ); 
  -- Permite que cada usuário veja seu próprio registro
DROP POLICY IF EXISTS employees_select_self_policy ON employees;
CREATE POLICY employees_select_self_policy
  ON employees
  FOR SELECT
  USING (id = auth.uid());

-- Permite que todos vejam todos (se quiser liberar para admin, só faça isso quando o claim do JWT trouxer o papel)
DROP POLICY IF EXISTS employees_admin_select_policy ON employees;
CREATE POLICY employees_admin_select_policy
  ON employees
  FOR SELECT
  USING (true);