/*
  # Sistema de Inspeções e Gestão de Danos

  1. Novas Tabelas
    - `inspections` - Registra inspeções de entrada/saída
    - `inspection_items` - Itens específicos de cada inspeção (danos/observações)

  2. Funcionalidades
    - Check-In e Check-Out de veículos
    - Registro de danos com fotos
    - Geração automática de ordens de serviço para danos
    - Criação automática de custos estimados
    - Assinatura digital do responsável

  3. Segurança
    - RLS habilitado em todas as tabelas
    - Políticas baseadas em tenant_id
    - Triggers para automação
*/

-- 1. Tabela de Inspeções
CREATE TABLE IF NOT EXISTS inspections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  inspection_type text NOT NULL CHECK(inspection_type IN ('CheckIn', 'CheckOut')),
  inspected_by text NOT NULL, -- Nome do responsável pela inspeção
  inspected_at timestamptz NOT NULL DEFAULT now(),
  signature_url text, -- URL da assinatura digital
  notes text, -- Observações gerais da inspeção
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_inspections_vehicle ON inspections(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_inspections_tenant ON inspections(tenant_id);
CREATE INDEX IF NOT EXISTS idx_inspections_type ON inspections(inspection_type);
CREATE INDEX IF NOT EXISTS idx_inspections_date ON inspections(inspected_at);

-- 2. Tabela de Itens de Inspeção (Danos/Observações)
CREATE TABLE IF NOT EXISTS inspection_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_id uuid NOT NULL REFERENCES inspections(id) ON DELETE CASCADE,
  location text NOT NULL, -- ex: "Porta Direita Traseira", "Para-choque Dianteiro"
  description text NOT NULL,
  damage_type text NOT NULL CHECK(damage_type IN ('Arranhão', 'Amassado', 'Quebrado', 'Desgaste', 'Outro')),
  severity text NOT NULL DEFAULT 'Baixa' CHECK(severity IN ('Baixa', 'Média', 'Alta')),
  photo_url text, -- URL da foto do dano
  cost_estimate numeric(12,2), -- Valor estimado de reparo
  requires_repair boolean DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_inspection_items_inspection ON inspection_items(inspection_id);
CREATE INDEX IF NOT EXISTS idx_inspection_items_damage_type ON inspection_items(damage_type);
CREATE INDEX IF NOT EXISTS idx_inspection_items_severity ON inspection_items(severity);

-- 3. Habilita RLS
ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspection_items ENABLE ROW LEVEL SECURITY;

-- 4. Políticas RLS para inspections
CREATE POLICY "Allow all operations for default tenant on inspections"
  ON inspections
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Users can manage their tenant inspections"
  ON inspections
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

-- 5. Políticas RLS para inspection_items
CREATE POLICY "Allow all operations for default tenant on inspection_items"
  ON inspection_items
  FOR ALL
  TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM inspections i
    WHERE i.id = inspection_items.inspection_id
      AND i.tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM inspections i
    WHERE i.id = inspection_items.inspection_id
      AND i.tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  ));

CREATE POLICY "Users can manage their tenant inspection items"
  ON inspection_items
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM inspections i
    WHERE i.id = inspection_items.inspection_id
      AND i.tenant_id IN (
        SELECT tenants.id
        FROM tenants
        WHERE auth.uid() IS NOT NULL
      )
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM inspections i
    WHERE i.id = inspection_items.inspection_id
      AND i.tenant_id IN (
        SELECT tenants.id
        FROM tenants
        WHERE auth.uid() IS NOT NULL
      )
  ));

-- 6. Função para criar automaticamente OS de funilaria para danos
CREATE OR REPLACE FUNCTION fn_auto_create_damage_service_order()
RETURNS TRIGGER AS $$
DECLARE
  v_inspection_record RECORD;
  v_service_note_id uuid;
  v_maintenance_type_id uuid;
BEGIN
  -- Só cria OS para CheckOut com danos que requerem reparo
  IF NEW.requires_repair = false THEN
    RETURN NEW;
  END IF;

  -- Busca informações da inspeção
  SELECT i.*, v.plate, v.model
  INTO v_inspection_record
  FROM inspections i
  JOIN vehicles v ON v.id = i.vehicle_id
  WHERE i.id = NEW.inspection_id;

  -- Só processa CheckOut (danos novos)
  IF v_inspection_record.inspection_type != 'CheckOut' THEN
    RETURN NEW;
  END IF;

  -- Busca ou cria tipo de manutenção "Funilaria"
  SELECT id INTO v_maintenance_type_id
  FROM maintenance_types
  WHERE tenant_id = v_inspection_record.tenant_id
    AND name = 'Funilaria'
  LIMIT 1;

  -- Se não existe, cria o tipo de manutenção
  IF v_maintenance_type_id IS NULL THEN
    INSERT INTO maintenance_types (tenant_id, name)
    VALUES (v_inspection_record.tenant_id, 'Funilaria')
    RETURNING id INTO v_maintenance_type_id;
  END IF;

  -- Cria ordem de serviço automaticamente
  INSERT INTO service_notes (
    tenant_id,
    vehicle_id,
    maintenance_type,
    start_date,
    mechanic,
    priority,
    description,
    observations,
    status,
    created_at
  )
  VALUES (
    v_inspection_record.tenant_id,
    v_inspection_record.vehicle_id,
    'Funilaria',
    CURRENT_DATE,
    'A definir', -- Será atribuído posteriormente
    CASE 
      WHEN NEW.severity = 'Alta' THEN 'Alta'
      WHEN NEW.severity = 'Média' THEN 'Média'
      ELSE 'Baixa'
    END,
    CONCAT('Reparo de dano detectado em inspeção - ', NEW.location, ': ', NEW.damage_type),
    CONCAT('Dano detectado em ', v_inspection_record.inspected_at::date, ' por ', v_inspection_record.inspected_by, '. Descrição: ', NEW.description),
    'Aberta',
    now()
  )
  RETURNING id INTO v_service_note_id;

  -- Cria custo estimado se fornecido
  IF NEW.cost_estimate IS NOT NULL AND NEW.cost_estimate > 0 THEN
    INSERT INTO costs (
      tenant_id,
      category,
      vehicle_id,
      description,
      amount,
      cost_date,
      status,
      document_ref,
      observations,
      created_at
    )
    VALUES (
      v_inspection_record.tenant_id,
      'Funilaria',
      v_inspection_record.vehicle_id,
      CONCAT('Estimativa de reparo - ', NEW.location, ' (', NEW.damage_type, ')'),
      NEW.cost_estimate,
      CURRENT_DATE,
      'Pendente',
      CONCAT('INSP-', NEW.inspection_id, '-OS-', v_service_note_id),
      CONCAT('Custo estimado baseado em inspeção. Severidade: ', NEW.severity),
      now()
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Trigger para criar OS automaticamente
CREATE TRIGGER trg_inspection_items_auto_service_order
  AFTER INSERT ON inspection_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_create_damage_service_order();

-- 8. Função para atualizar status do veículo baseado em inspeções
CREATE OR REPLACE FUNCTION fn_update_vehicle_status_on_inspection()
RETURNS TRIGGER AS $$
BEGIN
  -- Atualiza status do veículo baseado no tipo de inspeção
  IF NEW.inspection_type = 'CheckOut' THEN
    -- Verifica se há danos que requerem reparo
    IF EXISTS (
      SELECT 1 FROM inspection_items ii
      WHERE ii.inspection_id = NEW.id
        AND ii.requires_repair = true
        AND ii.severity IN ('Média', 'Alta')
    ) THEN
      -- Se há danos significativos, coloca em manutenção
      UPDATE vehicles
      SET status = 'Manutenção', updated_at = now()
      WHERE id = NEW.vehicle_id;
    ELSE
      -- Se não há danos ou são leves, marca como disponível
      UPDATE vehicles
      SET status = 'Disponível', updated_at = now()
      WHERE id = NEW.vehicle_id;
    END IF;
  ELSIF NEW.inspection_type = 'CheckIn' THEN
    -- No CheckIn, marca como em uso
    UPDATE vehicles
    SET status = 'Em Uso', updated_at = now()
    WHERE id = NEW.vehicle_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Trigger para atualizar status do veículo
CREATE TRIGGER trg_inspections_update_vehicle_status
  AFTER INSERT ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_status_on_inspection();

-- 10. View para relatórios de inspeções
CREATE OR REPLACE VIEW vw_inspections_summary AS
SELECT
  i.id,
  i.tenant_id,
  i.vehicle_id,
  v.plate AS vehicle_plate,
  v.model AS vehicle_model,
  i.inspection_type,
  i.inspected_by,
  i.inspected_at,
  i.notes,
  COUNT(ii.id) AS total_items,
  COUNT(ii.id) FILTER (WHERE ii.requires_repair = true) AS damage_count,
  COUNT(ii.id) FILTER (WHERE ii.severity = 'Alta') AS high_severity_count,
  COALESCE(SUM(ii.cost_estimate), 0) AS total_estimated_cost,
  i.created_at
FROM inspections i
JOIN vehicles v ON v.id = i.vehicle_id
LEFT JOIN inspection_items ii ON ii.inspection_id = i.id
GROUP BY i.id, v.plate, v.model
ORDER BY i.inspected_at DESC;

-- 11. Função para estatísticas de inspeções
CREATE OR REPLACE FUNCTION fn_inspection_statistics(
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
  p_start_date date DEFAULT CURRENT_DATE - INTERVAL '30 days',
  p_end_date date DEFAULT CURRENT_DATE
)
RETURNS TABLE(
  total_inspections integer,
  checkin_count integer,
  checkout_count integer,
  total_damages integer,
  high_severity_damages integer,
  total_estimated_costs numeric,
  vehicles_in_maintenance integer,
  average_damages_per_checkout numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(i.id)::integer AS total_inspections,
    COUNT(i.id) FILTER (WHERE i.inspection_type = 'CheckIn')::integer AS checkin_count,
    COUNT(i.id) FILTER (WHERE i.inspection_type = 'CheckOut')::integer AS checkout_count,
    COUNT(ii.id) FILTER (WHERE ii.requires_repair = true)::integer AS total_damages,
    COUNT(ii.id) FILTER (WHERE ii.severity = 'Alta')::integer AS high_severity_damages,
    COALESCE(SUM(ii.cost_estimate), 0) AS total_estimated_costs,
    COUNT(DISTINCT i.vehicle_id) FILTER (WHERE EXISTS (
      SELECT 1 FROM inspection_items ii2
      WHERE ii2.inspection_id = i.id
        AND ii2.requires_repair = true
        AND ii2.severity IN ('Média', 'Alta')
    ))::integer AS vehicles_in_maintenance,
    CASE 
      WHEN COUNT(i.id) FILTER (WHERE i.inspection_type = 'CheckOut') > 0 
      THEN ROUND(
        COUNT(ii.id) FILTER (WHERE ii.requires_repair = true)::numeric / 
        COUNT(i.id) FILTER (WHERE i.inspection_type = 'CheckOut')::numeric, 2
      )
      ELSE 0
    END AS average_damages_per_checkout
  FROM inspections i
  LEFT JOIN inspection_items ii ON ii.inspection_id = i.id
  WHERE i.tenant_id = p_tenant_id
    AND i.inspected_at::date BETWEEN p_start_date AND p_end_date;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 12. Função para buscar inspeções com detalhes
CREATE OR REPLACE FUNCTION fn_get_inspection_details(p_inspection_id uuid)
RETURNS TABLE(
  inspection_data jsonb,
  items_data jsonb
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    to_jsonb(i.*) AS inspection_data,
    COALESCE(
      jsonb_agg(
        to_jsonb(ii.*) ORDER BY ii.created_at
      ) FILTER (WHERE ii.id IS NOT NULL),
      '[]'::jsonb
    ) AS items_data
  FROM inspections i
  LEFT JOIN inspection_items ii ON ii.inspection_id = i.id
  WHERE i.id = p_inspection_id
  GROUP BY i.id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 13. Trigger para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_inspections_updated_at
  BEFORE UPDATE ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();