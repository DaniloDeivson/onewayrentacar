-- Atualiza a policy de INSERT da tabela employees para incluir o papel Driver
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
      role IN ('Sales', 'Mechanic', 'Inspector', 'User', 'Driver')
    )
  ); 