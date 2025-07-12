/*
  # Sistema Completo de Contratos com Prevenção de Overbooking

  1. Melhorias no Modelo de Dados
    - Adiciona exclusion constraint para prevenir sobreposição
    - Cria view materializada para consultas otimizadas
    - Implementa funções para verificar disponibilidade

  2. Integridade e Segurança
    - Constraints para garantir consistência
    - Políticas RLS atualizadas
    - Triggers para automação

  3. Performance e Consultas
    - Índices otimizados
    - Funções para consultas complexas
    - Views para relatórios
*/

-- Instala extensão necessária para exclusion constraints
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Adiciona coluna de período para contratos (se não existir)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'contracts' AND column_name = 'rental_period'
  ) THEN
    ALTER TABLE contracts
      ADD COLUMN rental_period tsrange GENERATED ALWAYS AS (tsrange(start_date::timestamp, end_date::timestamp, '[]')) STORED;
  END IF;
END $$;

-- Cria constraint de exclusão para prevenir overbooking
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'contracts_no_overlap'
  ) THEN
    ALTER TABLE contracts
      ADD CONSTRAINT contracts_no_overlap
      EXCLUDE USING GIST (
        vehicle_id WITH =,
        rental_period WITH &&
      )
      WHERE (status != 'Cancelado');
  END IF;
END $$;

-- Adiciona índices para performance
CREATE INDEX IF NOT EXISTS idx_contracts_vehicle_period ON contracts USING GIST (vehicle_id, rental_period);
CREATE INDEX IF NOT EXISTS idx_contracts_status ON contracts(status);
CREATE INDEX IF NOT EXISTS idx_contracts_dates ON contracts(start_date, end_date);

-- Função para verificar disponibilidade de veículos
CREATE OR REPLACE FUNCTION fn_available_vehicles(
  p_start_date date,
  p_end_date date,
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
  p_exclude_contract_id uuid DEFAULT NULL
)
RETURNS TABLE(
  id uuid,
  plate text,
  model text,
  year integer,
  type text,
  status text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.id,
    v.plate,
    v.model,
    v.year,
    v.type,
    v.status
  FROM vehicles v
  WHERE v.tenant_id = p_tenant_id
    AND v.status IN ('Disponível', 'Em Uso') -- Permite veículos que podem ser alugados
    AND v.id NOT IN (
      SELECT c.vehicle_id 
      FROM contracts c
      WHERE c.tenant_id = p_tenant_id
        AND c.status = 'Ativo'
        AND (p_exclude_contract_id IS NULL OR c.id != p_exclude_contract_id) -- Excluir contrato atual se editando
        AND tsrange(p_start_date::timestamp, p_end_date::timestamp, '[]') && 
            tsrange(c.start_date::timestamp, c.end_date::timestamp, '[]')
    )
  ORDER BY v.plate;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Função para verificar conflitos de contrato
CREATE OR REPLACE FUNCTION fn_check_contract_conflicts(
  p_vehicle_id uuid,
  p_start_date date,
  p_end_date date,
  p_contract_id uuid DEFAULT NULL,
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid
)
RETURNS TABLE(
  has_conflict boolean,
  conflicting_contracts jsonb
) AS $$
DECLARE
  v_conflicts jsonb;
  v_has_conflict boolean := false;
BEGIN
  -- Busca contratos conflitantes
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'customer_name', cu.name,
      'start_date', c.start_date,
      'end_date', c.end_date,
      'status', c.status
    )
  )
  INTO v_conflicts
  FROM contracts c
  JOIN customers cu ON cu.id = c.customer_id
  WHERE c.tenant_id = p_tenant_id
    AND c.vehicle_id = p_vehicle_id
    AND c.status = 'Ativo'
    AND (p_contract_id IS NULL OR c.id != p_contract_id)
    AND tsrange(p_start_date::timestamp, p_end_date::timestamp, '[]') && 
        tsrange(c.start_date::timestamp, c.end_date::timestamp, '[]');

  v_has_conflict := v_conflicts IS NOT NULL;

  RETURN QUERY SELECT v_has_conflict, COALESCE(v_conflicts, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- View materializada para contratos com detalhes
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_contracts_detailed AS
SELECT
  c.id,
  c.tenant_id,
  c.customer_id,
  cu.name AS customer_name,
  cu.document AS customer_document,
  cu.phone AS customer_phone,
  c.vehicle_id,
  v.plate AS vehicle_plate,
  v.model AS vehicle_model,
  v.year AS vehicle_year,
  v.type AS vehicle_type,
  c.start_date,
  c.end_date,
  c.daily_rate,
  c.status,
  (c.end_date - c.start_date + 1) AS rental_days,
  (c.end_date - c.start_date + 1) * c.daily_rate AS total_value,
  c.created_at,
  c.updated_at
FROM contracts c
JOIN customers cu ON cu.id = c.customer_id
JOIN vehicles v ON v.id = c.vehicle_id;

-- Índice para a view materializada
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_contracts_detailed_id ON mv_contracts_detailed(id);
CREATE INDEX IF NOT EXISTS idx_mv_contracts_detailed_tenant ON mv_contracts_detailed(tenant_id);
CREATE INDEX IF NOT EXISTS idx_mv_contracts_detailed_status ON mv_contracts_detailed(status);

-- Função para atualizar a view materializada
CREATE OR REPLACE FUNCTION refresh_contracts_view()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_contracts_detailed;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para atualizar automaticamente a view quando houver mudanças
CREATE OR REPLACE FUNCTION trigger_refresh_contracts_view()
RETURNS trigger AS $$
BEGIN
  -- Agenda refresh da view (pode ser executado de forma assíncrona)
  PERFORM refresh_contracts_view();
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Triggers para atualizar a view
DROP TRIGGER IF EXISTS trg_contracts_refresh_view ON contracts;
CREATE TRIGGER trg_contracts_refresh_view
  AFTER INSERT OR UPDATE OR DELETE ON contracts
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_refresh_contracts_view();

DROP TRIGGER IF EXISTS trg_customers_refresh_view ON customers;
CREATE TRIGGER trg_customers_refresh_view
  AFTER INSERT OR UPDATE OR DELETE ON customers
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_refresh_contracts_view();

DROP TRIGGER IF EXISTS trg_vehicles_refresh_view ON vehicles;
CREATE TRIGGER trg_vehicles_refresh_view
  AFTER INSERT OR UPDATE OR DELETE ON vehicles
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_refresh_contracts_view();

-- Função para calcular estatísticas de contratos
CREATE OR REPLACE FUNCTION fn_contract_statistics(
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid
)
RETURNS TABLE(
  total_contracts integer,
  active_contracts integer,
  completed_contracts integer,
  cancelled_contracts integer,
  total_revenue numeric,
  monthly_revenue numeric,
  average_daily_rate numeric,
  most_rented_vehicle jsonb
) AS $$
DECLARE
  v_most_rented jsonb;
BEGIN
  -- Busca veículo mais alugado
  SELECT jsonb_build_object(
    'vehicle_id', vehicle_id,
    'plate', vehicle_plate,
    'model', vehicle_model,
    'rental_count', rental_count
  )
  INTO v_most_rented
  FROM (
    SELECT 
      vehicle_id,
      vehicle_plate,
      vehicle_model,
      COUNT(*) as rental_count
    FROM mv_contracts_detailed
    WHERE tenant_id = p_tenant_id
    GROUP BY vehicle_id, vehicle_plate, vehicle_model
    ORDER BY rental_count DESC
    LIMIT 1
  ) most_rented;

  RETURN QUERY
  SELECT
    COUNT(*)::integer AS total_contracts,
    COUNT(*) FILTER (WHERE status = 'Ativo')::integer AS active_contracts,
    COUNT(*) FILTER (WHERE status = 'Finalizado')::integer AS completed_contracts,
    COUNT(*) FILTER (WHERE status = 'Cancelado')::integer AS cancelled_contracts,
    COALESCE(SUM(total_value) FILTER (WHERE status = 'Finalizado'), 0) AS total_revenue,
    COALESCE(SUM(total_value) FILTER (WHERE status = 'Finalizado' AND 
      DATE_TRUNC('month', end_date) = DATE_TRUNC('month', CURRENT_DATE)), 0) AS monthly_revenue,
    COALESCE(AVG(daily_rate), 0) AS average_daily_rate,
    COALESCE(v_most_rented, '{}'::jsonb) AS most_rented_vehicle
  FROM mv_contracts_detailed
  WHERE tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Atualiza as políticas RLS para contratos
DROP POLICY IF EXISTS "Allow all operations for default tenant on contracts" ON contracts;
CREATE POLICY "Allow all operations for default tenant on contracts"
  ON contracts
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

DROP POLICY IF EXISTS "Users can manage their tenant contracts" ON contracts;
CREATE POLICY "Users can manage their tenant contracts"
  ON contracts
  FOR ALL
  TO authenticated
  USING (tenant_id IN (
    SELECT tenants.id
    FROM tenants
    WHERE auth.uid() IS NOT NULL
  ))
  WITH CHECK (tenant_id IN (
    SELECT tenants.id
    FROM tenants
    WHERE auth.uid() IS NOT NULL
  ));

-- Função para finalizar contratos automaticamente
CREATE OR REPLACE FUNCTION fn_auto_finalize_contracts()
RETURNS integer AS $$
DECLARE
  v_updated_count integer;
BEGIN
  UPDATE contracts
  SET 
    status = 'Finalizado',
    updated_at = now()
  WHERE status = 'Ativo'
    AND end_date < CURRENT_DATE;
    
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  
  RETURN v_updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Refresh inicial da view materializada
SELECT refresh_contracts_view();