-- Função para buscar o cliente responsável pelo veículo em uma data específica
CREATE OR REPLACE FUNCTION fn_get_vehicle_customer_at_date(
  p_vehicle_id uuid,
  p_date date,
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'
)
RETURNS TABLE (
  customer_id uuid,
  customer_name text,
  contract_id uuid,
  contract_number text
) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT
    c.customer_id,
    customers.name as customer_name,
    c.id as contract_id,
    c.contract_number
  FROM contracts c
  JOIN customers ON customers.id = c.customer_id
  WHERE (
    -- Caso de veículo único
    (NOT c.uses_multiple_vehicles AND c.vehicle_id = p_vehicle_id)
    OR
    -- Caso de múltiplos veículos
    (c.uses_multiple_vehicles AND EXISTS (
      SELECT 1 FROM contract_vehicles cv
      WHERE cv.contract_id = c.id
      AND cv.vehicle_id = p_vehicle_id
    ))
  )
  AND c.tenant_id = p_tenant_id
  AND c.status = 'Ativo'
  AND p_date BETWEEN c.start_date AND c.end_date
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Atualizar a view de custos para incluir informações do cliente
CREATE OR REPLACE VIEW vw_costs_with_customer AS
WITH ranked_contracts AS (
  SELECT 
    c.id as cost_id,
    c.vehicle_id,
    c.cost_date,
    contracts.customer_id,
    customers.name as contract_customer_name,
    ROW_NUMBER() OVER (PARTITION BY c.vehicle_id, c.cost_date::date ORDER BY contracts.created_at DESC) as rn
  FROM costs c
  LEFT JOIN vehicles v ON v.id = c.vehicle_id
  LEFT JOIN contracts ON (
    (NOT contracts.uses_multiple_vehicles AND contracts.vehicle_id = c.vehicle_id)
    OR
    (contracts.uses_multiple_vehicles AND EXISTS (
      SELECT 1 FROM contract_vehicles cv
      WHERE cv.contract_id = contracts.id
      AND cv.vehicle_id = c.vehicle_id
    ))
  )
  AND c.cost_date::date BETWEEN contracts.start_date AND contracts.end_date
  AND contracts.status = 'Ativo'
  LEFT JOIN customers ON customers.id = contracts.customer_id
  WHERE c.tenant_id = '00000000-0000-0000-0000-000000000001'
)
SELECT 
  c.*,
  COALESCE(
    -- Tenta pegar o cliente do contrato vinculado
    (CASE 
      WHEN c.contract_id IS NOT NULL THEN (
        SELECT json_build_object(
          'id', contracts.customer_id,
          'name', customers.name
        )
        FROM contracts
        JOIN customers ON customers.id = contracts.customer_id
        WHERE contracts.id = c.contract_id
      )
      -- Se não tem contrato vinculado, busca pelo veículo e data
      WHEN c.vehicle_id IS NOT NULL THEN (
        SELECT json_build_object(
          'id', rc.customer_id,
          'name', rc.contract_customer_name
        )
        FROM ranked_contracts rc
        WHERE rc.cost_id = c.id
        AND rc.rn = 1
      )
      ELSE NULL
    END)::jsonb,
    -- Fallback para campos legados
    CASE 
      WHEN c.customer_id IS NOT NULL AND c.customer_name IS NOT NULL THEN
        jsonb_build_object(
          'id', c.customer_id,
          'name', c.customer_name
        )
      ELSE NULL
    END
  ) as customers,
  -- Mantém os outros relacionamentos existentes
  vehicles.plate as vehicle_plate,
  vehicles.model as vehicle_model,
  jsonb_build_object(
    'plate', vehicles.plate,
    'model', vehicles.model
  ) as vehicles,
  CASE 
    WHEN c.contract_id IS NOT NULL THEN
      jsonb_build_object(
        'id', contracts.id,
        'contract_number', contracts.contract_number
      )
    ELSE NULL
  END as contracts
FROM costs c
LEFT JOIN vehicles ON vehicles.id = c.vehicle_id
LEFT JOIN contracts ON contracts.id = c.contract_id
WHERE c.tenant_id = '00000000-0000-0000-0000-000000000001';

-- Atualizar a função de busca de custos para usar a nova view
CREATE OR REPLACE FUNCTION fn_get_costs(
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001',
  p_vehicle_id uuid DEFAULT NULL
)
RETURNS SETOF vw_costs_with_customer AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM vw_costs_with_customer
  WHERE tenant_id = p_tenant_id
  AND (p_vehicle_id IS NULL OR vehicle_id = p_vehicle_id)
  ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql; 