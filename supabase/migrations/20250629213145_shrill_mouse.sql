-- 1. Atualizar constraint de roles para incluir FineAdmin
ALTER TABLE employees DROP CONSTRAINT IF EXISTS employees_role_check;
ALTER TABLE employees ADD CONSTRAINT employees_role_check 
  CHECK (role = ANY (ARRAY['Admin'::text, 'Mechanic'::text, 'PatioInspector'::text, 'Sales'::text, 'Driver'::text, 'FineAdmin'::text]));

-- 2. Inserir usuário com a nova função
INSERT INTO employees (
  tenant_id,
  name,
  role,
  employee_code,
  contact_info,
  active
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  'Carlos Multas',
  'FineAdmin',
  'FINE001',
  '{"email": "multas@oneway.com", "phone": "(11) 99999-7777"}',
  true
)
ON CONFLICT DO NOTHING;

-- 3. Atualizar view de multas detalhadas para incluir a nova função
DROP VIEW IF EXISTS vw_fines_detailed;
CREATE VIEW vw_fines_detailed AS
SELECT 
  f.id,
  f.tenant_id,
  f.vehicle_id,
  v.plate as vehicle_plate,
  v.model as vehicle_model,
  v.year as vehicle_year,
  f.driver_id,
  d.name as driver_name,
  -- Removendo a referência incorreta a d.employee_code
  NULL as driver_code, -- Drivers não têm employee_code, apenas employees
  f.employee_id,
  e.name as created_by_name,
  e.role as created_by_role,
  f.fine_number,
  f.infraction_type,
  f.amount,
  f.infraction_date,
  f.due_date,
  f.notified,
  f.status,
  f.document_ref,
  f.observations,
  f.created_at,
  f.updated_at,
  -- Campos calculados
  CASE 
    WHEN f.due_date < CURRENT_DATE AND f.status = 'Pendente' THEN true
    ELSE false
  END as is_overdue,
  CURRENT_DATE - f.due_date as days_overdue
FROM fines f
LEFT JOIN vehicles v ON v.id = f.vehicle_id
LEFT JOIN drivers d ON d.id = f.driver_id
LEFT JOIN employees e ON e.id = f.employee_id;

-- 4. Primeiro dropar a função existente e depois recriar com o novo retorno
DROP FUNCTION IF EXISTS fn_fines_statistics(uuid);

-- Recriar a função com o novo campo
CREATE OR REPLACE FUNCTION fn_fines_statistics(p_tenant_id uuid)
RETURNS TABLE (
  total_fines bigint,
  pending_fines bigint,
  paid_fines bigint,
  contested_fines bigint,
  total_amount numeric,
  pending_amount numeric,
  notified_count bigint,
  not_notified_count bigint,
  avg_fine_amount numeric,
  most_common_infraction text,
  most_fined_vehicle text,
  top_fine_admin text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::bigint as total_fines,
    COUNT(*) FILTER (WHERE f.status = 'Pendente')::bigint as pending_fines,
    COUNT(*) FILTER (WHERE f.status = 'Pago')::bigint as paid_fines,
    COUNT(*) FILTER (WHERE f.status = 'Contestado')::bigint as contested_fines,
    COALESCE(SUM(f.amount), 0) as total_amount,
    COALESCE(SUM(f.amount) FILTER (WHERE f.status = 'Pendente'), 0) as pending_amount,
    COUNT(*) FILTER (WHERE f.notified = true)::bigint as notified_count,
    COUNT(*) FILTER (WHERE f.notified = false)::bigint as not_notified_count,
    COALESCE(AVG(f.amount), 0) as avg_fine_amount,
    (
      SELECT f2.infraction_type
      FROM fines f2
      WHERE f2.tenant_id = p_tenant_id
      GROUP BY f2.infraction_type
      ORDER BY COUNT(*) DESC
      LIMIT 1
    ) as most_common_infraction,
    (
      SELECT v.plate
      FROM fines f3
      JOIN vehicles v ON v.id = f3.vehicle_id
      WHERE f3.tenant_id = p_tenant_id
      GROUP BY v.plate
      ORDER BY COUNT(*) DESC
      LIMIT 1
    ) as most_fined_vehicle,
    (
      SELECT e.name
      FROM fines f4
      JOIN employees e ON e.id = f4.employee_id
      WHERE f4.tenant_id = p_tenant_id
      GROUP BY e.name
      ORDER BY COUNT(*) DESC
      LIMIT 1
    ) as top_fine_admin
  FROM fines f
  WHERE f.tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql;