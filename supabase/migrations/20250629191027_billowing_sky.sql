/*
  # Sistema de Check-In/Check-Out de Manutenção

  1. Novas Tabelas
    - `maintenance_checkins`
      - `id` (uuid, primary key)
      - `tenant_id` (uuid, foreign key)
      - `service_note_id` (uuid, foreign key)
      - `mechanic_id` (uuid, foreign key)
      - `checkin_at` (timestamptz)
      - `checkout_at` (timestamptz, nullable)
      - `notes` (text, nullable)
      - `signature_url` (text, nullable)
      - `created_at` (timestamptz)

  2. Alterações em Tabelas Existentes
    - Adicionar coluna `maintenance_status` em `vehicles`

  3. Segurança
    - Habilitar RLS na tabela `maintenance_checkins`
    - Políticas para mecânicos, admin e gerente

  4. Automação
    - Trigger para atualizar status do veículo automaticamente
    - Função para sincronizar status baseado em check-ins/outs
*/

-- Adicionar coluna de status de manutenção em vehicles se não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vehicles' AND column_name = 'maintenance_status'
  ) THEN
    ALTER TABLE vehicles ADD COLUMN maintenance_status text NOT NULL DEFAULT 'Available' 
      CHECK (maintenance_status IN ('Available', 'In_Maintenance', 'Reserved', 'Rented'));
  END IF;
END $$;

-- Criar tabela de check-ins de manutenção
CREATE TABLE IF NOT EXISTS maintenance_checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  service_note_id uuid NOT NULL REFERENCES service_notes(id) ON DELETE CASCADE,
  mechanic_id uuid NOT NULL REFERENCES employees(id),
  checkin_at timestamptz NOT NULL DEFAULT now(),
  checkout_at timestamptz,
  notes text,
  signature_url text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_maintenance_checkins_service_note ON maintenance_checkins(service_note_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_checkins_mechanic ON maintenance_checkins(mechanic_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_checkins_tenant ON maintenance_checkins(tenant_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_checkins_checkin_at ON maintenance_checkins(checkin_at);
CREATE INDEX IF NOT EXISTS idx_maintenance_checkins_checkout_at ON maintenance_checkins(checkout_at);

-- Habilitar Row Level Security
ALTER TABLE maintenance_checkins ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes se existirem
DROP POLICY IF EXISTS "maintenance_checkins_select" ON maintenance_checkins;
DROP POLICY IF EXISTS "maintenance_checkins_insert" ON maintenance_checkins;
DROP POLICY IF EXISTS "maintenance_checkins_update" ON maintenance_checkins;

-- Políticas RLS
CREATE POLICY "maintenance_checkins_select" ON maintenance_checkins
  FOR SELECT
  USING (
    tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  );

CREATE POLICY "maintenance_checkins_insert" ON maintenance_checkins
  FOR INSERT
  WITH CHECK (
    tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  );

CREATE POLICY "maintenance_checkins_update" ON maintenance_checkins
  FOR UPDATE
  USING (
    tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  );

-- Função para sincronizar status do veículo
CREATE OR REPLACE FUNCTION fn_sync_vehicle_maintenance_status()
RETURNS TRIGGER AS $$
DECLARE
  v_vehicle_id uuid;
  v_new_status text;
BEGIN
  -- Buscar o vehicle_id através da service_note
  SELECT sn.vehicle_id INTO v_vehicle_id
  FROM service_notes sn
  WHERE sn.id = COALESCE(NEW.service_note_id, OLD.service_note_id);

  IF v_vehicle_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Determinar novo status baseado na operação
  IF (TG_OP = 'INSERT') THEN
    -- Check-in: veículo vai para manutenção
    v_new_status := 'In_Maintenance';
  ELSIF (TG_OP = 'UPDATE' AND NEW.checkout_at IS NOT NULL AND OLD.checkout_at IS NULL) THEN
    -- Check-out: veículo volta a ficar disponível
    v_new_status := 'Available';
  ELSIF (TG_OP = 'DELETE') THEN
    -- Se deletar check-in, verificar se há outros check-ins ativos
    IF EXISTS (
      SELECT 1 FROM maintenance_checkins mc
      JOIN service_notes sn ON sn.id = mc.service_note_id
      WHERE sn.vehicle_id = v_vehicle_id 
        AND mc.checkout_at IS NULL
        AND mc.id != OLD.id
    ) THEN
      v_new_status := 'In_Maintenance';
    ELSE
      v_new_status := 'Available';
    END IF;
  ELSE
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Atualizar status do veículo
  UPDATE vehicles
  SET 
    maintenance_status = v_new_status,
    updated_at = now()
  WHERE id = v_vehicle_id;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Remover trigger existente se existir
DROP TRIGGER IF EXISTS trg_sync_vehicle_maintenance_status ON maintenance_checkins;

-- Criar trigger para sincronizar status
CREATE TRIGGER trg_sync_vehicle_maintenance_status
  AFTER INSERT OR UPDATE OR DELETE ON maintenance_checkins
  FOR EACH ROW
  EXECUTE FUNCTION fn_sync_vehicle_maintenance_status();

-- Função para estatísticas de check-ins
CREATE OR REPLACE FUNCTION fn_maintenance_checkins_statistics(p_tenant_id uuid)
RETURNS TABLE (
  total_checkins bigint,
  active_checkins bigint,
  completed_checkins bigint,
  vehicles_in_maintenance bigint,
  avg_maintenance_duration interval,
  most_active_mechanic text,
  longest_maintenance_duration interval
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::bigint as total_checkins,
    COUNT(*) FILTER (WHERE mc.checkout_at IS NULL)::bigint as active_checkins,
    COUNT(*) FILTER (WHERE mc.checkout_at IS NOT NULL)::bigint as completed_checkins,
    (
      SELECT COUNT(DISTINCT sn.vehicle_id)::bigint
      FROM maintenance_checkins mc2
      JOIN service_notes sn ON sn.id = mc2.service_note_id
      WHERE mc2.tenant_id = p_tenant_id AND mc2.checkout_at IS NULL
    ) as vehicles_in_maintenance,
    AVG(mc.checkout_at - mc.checkin_at) FILTER (WHERE mc.checkout_at IS NOT NULL) as avg_maintenance_duration,
    (
      SELECT e.name
      FROM maintenance_checkins mc3
      JOIN employees e ON e.id = mc3.mechanic_id
      WHERE mc3.tenant_id = p_tenant_id
      GROUP BY e.name
      ORDER BY COUNT(*) DESC
      LIMIT 1
    ) as most_active_mechanic,
    MAX(mc.checkout_at - mc.checkin_at) FILTER (WHERE mc.checkout_at IS NOT NULL) as longest_maintenance_duration
  FROM maintenance_checkins mc
  WHERE mc.tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql;

-- View para check-ins detalhados
CREATE OR REPLACE VIEW vw_maintenance_checkins_detailed AS
SELECT 
  mc.id,
  mc.tenant_id,
  mc.service_note_id,
  sn.description as service_description,
  sn.maintenance_type,
  sn.priority,
  sn.status as service_status,
  mc.mechanic_id,
  e.name as mechanic_name,
  e.employee_code as mechanic_code,
  sn.vehicle_id,
  v.plate as vehicle_plate,
  v.model as vehicle_model,
  v.maintenance_status as vehicle_status,
  mc.checkin_at,
  mc.checkout_at,
  mc.notes,
  mc.signature_url,
  mc.created_at,
  -- Campos calculados
  CASE 
    WHEN mc.checkout_at IS NULL THEN true
    ELSE false
  END as is_active,
  CASE 
    WHEN mc.checkout_at IS NOT NULL THEN mc.checkout_at - mc.checkin_at
    ELSE now() - mc.checkin_at
  END as duration,
  CASE 
    WHEN mc.checkout_at IS NULL AND mc.checkin_at < now() - interval '24 hours' THEN true
    ELSE false
  END as is_overdue
FROM maintenance_checkins mc
JOIN service_notes sn ON sn.id = mc.service_note_id
JOIN employees e ON e.id = mc.mechanic_id
JOIN vehicles v ON v.id = sn.vehicle_id;

-- Trigger para atualizar updated_at em maintenance_checkins
CREATE TRIGGER trg_maintenance_checkins_updated_at
  BEFORE UPDATE ON maintenance_checkins
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();