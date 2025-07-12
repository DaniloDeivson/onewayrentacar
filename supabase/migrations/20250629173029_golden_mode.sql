/*
  # Automação de Custos para Danos Detectados em Inspeções

  1. Funções
    - `fn_auto_create_damage_cost()` - Cria custo automaticamente quando dano é detectado
    - `fn_send_damage_notification()` - Envia notificação por email
    - `fn_update_vehicle_status_on_inspection()` - Atualiza status do veículo
    - Funções auxiliares para processamento de notificações

  2. Tabela
    - `damage_notifications` - Controle de notificações de danos

  3. Triggers
    - Automação de criação de custos
    - Atualização de status do veículo

  4. Alterações
    - Remove coluna `cost_estimate` da tabela `inspection_items`
    - Atualiza view `vw_inspections_summary`

  5. Segurança
    - RLS habilitado para `damage_notifications`
    - Políticas para acesso por tenant
*/

BEGIN;

-- 1. Função para criar custo automaticamente quando dano é detectado
CREATE OR REPLACE FUNCTION fn_auto_create_damage_cost()
RETURNS TRIGGER AS $$
DECLARE
  v_inspection_record RECORD;
  v_vehicle_plate TEXT;
  v_vehicle_model TEXT;
  v_vehicle_year INTEGER;
  v_cost_id UUID;
BEGIN
  -- Buscar dados da inspeção
  SELECT * INTO v_inspection_record
  FROM inspections
  WHERE id = NEW.inspection_id;

  -- Buscar dados do veículo separadamente
  SELECT plate, model, year 
  INTO v_vehicle_plate, v_vehicle_model, v_vehicle_year
  FROM vehicles
  WHERE id = v_inspection_record.vehicle_id;

  -- Criar custo apenas para CheckOut (danos na saída)
  IF v_inspection_record.inspection_type = 'CheckOut' THEN
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
      CONCAT('Dano detectado em ', NEW.location, ' - ', NEW.damage_type),
      0.01, -- Valor simbólico "A Definir"
      CURRENT_DATE,
      'Pendente',
      CONCAT('INSP-', v_inspection_record.id, '-ITEM-', NEW.id),
      CONCAT('Severidade: ', NEW.severity, '. Descrição: ', NEW.description, '. Requer reparo: ', CASE WHEN NEW.requires_repair THEN 'Sim' ELSE 'Não' END),
      NOW()
    )
    RETURNING id INTO v_cost_id;

    -- Chamar função para enviar notificação por email
    PERFORM fn_send_damage_notification(
      v_cost_id,
      NEW.id,
      v_inspection_record.id,
      v_vehicle_plate,
      v_vehicle_model,
      NEW.location,
      NEW.damage_type,
      NEW.severity,
      NEW.description,
      NEW.requires_repair
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Função para enviar notificação por email (placeholder)
CREATE OR REPLACE FUNCTION fn_send_damage_notification(
  p_cost_id UUID,
  p_item_id UUID,
  p_inspection_id UUID,
  p_vehicle_plate TEXT,
  p_vehicle_model TEXT,
  p_damage_location TEXT,
  p_damage_type TEXT,
  p_severity TEXT,
  p_description TEXT,
  p_requires_repair BOOLEAN
)
RETURNS VOID AS $$
DECLARE
  v_notification_data JSONB;
  v_tenant_id UUID;
BEGIN
  -- Buscar tenant_id do custo
  SELECT tenant_id INTO v_tenant_id
  FROM costs
  WHERE id = p_cost_id;

  -- Preparar dados para notificação
  v_notification_data := jsonb_build_object(
    'cost_id', p_cost_id,
    'item_id', p_item_id,
    'inspection_id', p_inspection_id,
    'vehicle_plate', p_vehicle_plate,
    'vehicle_model', p_vehicle_model,
    'damage_location', p_damage_location,
    'damage_type', p_damage_type,
    'severity', p_severity,
    'description', p_description,
    'requires_repair', p_requires_repair,
    'timestamp', NOW()
  );

  -- Inserir na tabela de notificações (para processamento posterior)
  INSERT INTO damage_notifications (
    tenant_id,
    cost_id,
    inspection_item_id,
    notification_data,
    status,
    created_at
  )
  VALUES (
    v_tenant_id,
    p_cost_id,
    p_item_id,
    v_notification_data,
    'pending',
    NOW()
  );

  -- Log da notificação
  RAISE NOTICE 'Notificação de dano criada para custo % - Veículo: % - Local: %', 
    p_cost_id, p_vehicle_plate, p_damage_location;

END;
$$ LANGUAGE plpgsql;

-- 3. Tabela para controle de notificações
CREATE TABLE IF NOT EXISTS damage_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  cost_id UUID NOT NULL REFERENCES costs(id) ON DELETE CASCADE,
  inspection_item_id UUID NOT NULL REFERENCES inspection_items(id) ON DELETE CASCADE,
  notification_data JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'sent', 'failed')),
  sent_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices para damage_notifications
CREATE INDEX IF NOT EXISTS idx_damage_notifications_tenant ON damage_notifications(tenant_id);
CREATE INDEX IF NOT EXISTS idx_damage_notifications_status ON damage_notifications(status);
CREATE INDEX IF NOT EXISTS idx_damage_notifications_created ON damage_notifications(created_at);

-- RLS para damage_notifications
ALTER TABLE damage_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their tenant damage notifications"
  ON damage_notifications
  FOR SELECT
  TO authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Allow all operations for default tenant on damage_notifications"
  ON damage_notifications
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

-- 4. Remover trigger existente se existir e criar novo
DROP TRIGGER IF EXISTS trg_inspection_items_auto_service_order ON inspection_items;

CREATE TRIGGER trg_inspection_items_auto_damage_cost
  AFTER INSERT ON inspection_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_create_damage_cost();

-- 5. Função para atualizar status do veículo quando há danos
CREATE OR REPLACE FUNCTION fn_update_vehicle_status_on_inspection()
RETURNS TRIGGER AS $$
DECLARE
  v_inspection_record RECORD;
  v_damage_count INTEGER;
BEGIN
  -- Buscar dados da inspeção
  SELECT * INTO v_inspection_record
  FROM inspections
  WHERE id = NEW.inspection_id;

  -- Contar danos que requerem reparo nesta inspeção
  SELECT COUNT(*)
  INTO v_damage_count
  FROM inspection_items
  WHERE inspection_id = NEW.inspection_id
    AND requires_repair = TRUE;

  -- Se é CheckOut e há danos que requerem reparo, colocar veículo em manutenção
  IF v_inspection_record.inspection_type = 'CheckOut' AND v_damage_count > 0 THEN
    UPDATE vehicles
    SET status = 'Manutenção',
        updated_at = NOW()
    WHERE id = v_inspection_record.vehicle_id;
    
    RAISE NOTICE 'Veículo % colocado em manutenção devido a % danos detectados', 
      v_inspection_record.vehicle_id, v_damage_count;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Remover trigger existente se existir e criar novo
DROP TRIGGER IF EXISTS trg_inspections_update_vehicle_status ON inspection_items;

CREATE TRIGGER trg_inspections_update_vehicle_status
  AFTER INSERT ON inspection_items
  FOR EACH ROW
  WHEN (NEW.requires_repair = TRUE)
  EXECUTE FUNCTION fn_update_vehicle_status_on_inspection();

-- 7. Remover coluna cost_estimate da tabela inspection_items com CASCADE
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspection_items' AND column_name = 'cost_estimate'
  ) THEN
    -- Primeiro, dropar a view que depende da coluna
    DROP VIEW IF EXISTS vw_inspections_summary CASCADE;
    
    -- Agora remover a coluna
    ALTER TABLE inspection_items DROP COLUMN cost_estimate;
    
    -- Recriar a view sem a coluna cost_estimate
    CREATE VIEW vw_inspections_summary AS
    SELECT 
      i.id,
      i.tenant_id,
      i.vehicle_id,
      v.plate as vehicle_plate,
      v.model as vehicle_model,
      i.inspection_type,
      i.inspected_by,
      i.inspected_at,
      i.notes,
      COUNT(ii.id) as total_items,
      COUNT(CASE WHEN ii.requires_repair = true THEN 1 END) as damage_count,
      COUNT(CASE WHEN ii.severity = 'Alta' THEN 1 END) as high_severity_count,
      0::numeric as total_estimated_cost, -- Sempre 0 agora que removemos cost_estimate
      i.created_at
    FROM inspections i
    LEFT JOIN vehicles v ON v.id = i.vehicle_id
    LEFT JOIN inspection_items ii ON ii.inspection_id = i.id
    GROUP BY i.id, i.tenant_id, i.vehicle_id, v.plate, v.model, i.inspection_type, 
             i.inspected_by, i.inspected_at, i.notes, i.created_at;
  END IF;
END $$;

-- 8. Função para processar notificações pendentes (para uso com Edge Functions)
CREATE OR REPLACE FUNCTION fn_get_pending_damage_notifications()
RETURNS TABLE (
  id UUID,
  tenant_id UUID,
  cost_id UUID,
  inspection_item_id UUID,
  notification_data JSONB,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dn.id,
    dn.tenant_id,
    dn.cost_id,
    dn.inspection_item_id,
    dn.notification_data,
    dn.created_at
  FROM damage_notifications dn
  WHERE dn.status = 'pending'
    AND dn.created_at > NOW() - INTERVAL '24 hours'
  ORDER BY dn.created_at ASC
  LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- 9. Função para marcar notificação como enviada
CREATE OR REPLACE FUNCTION fn_mark_notification_sent(p_notification_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE damage_notifications
  SET status = 'sent',
      sent_at = NOW()
  WHERE id = p_notification_id;
END;
$$ LANGUAGE plpgsql;

-- 10. Função para marcar notificação como falha
CREATE OR REPLACE FUNCTION fn_mark_notification_failed(p_notification_id UUID, p_error_message TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE damage_notifications
  SET status = 'failed',
      error_message = p_error_message
  WHERE id = p_notification_id;
END;
$$ LANGUAGE plpgsql;

COMMIT;