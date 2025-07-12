-- Criar tabela driver_inspections e view vw_driver_inspections_detailed
-- Esta migração garante que tanto a tabela quanto a view existam

-- 1. Criar tabela driver_inspections se não existir
CREATE TABLE IF NOT EXISTS driver_inspections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,
  contract_id UUID REFERENCES contracts(id) ON DELETE SET NULL,
  guest_id UUID REFERENCES guest_users(id) ON DELETE SET NULL,
  driver_employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
  driver_name TEXT NOT NULL,
  inspection_type TEXT NOT NULL CHECK (inspection_type IN ('checkout', 'checkin')),
  checklist JSONB DEFAULT '{}'::jsonb,
  fuel_level NUMERIC(3,2) CHECK (fuel_level >= 0 AND fuel_level <= 1),
  odometer_reading INTEGER CHECK (odometer_reading >= 0),
  damage_photos JSONB DEFAULT '[]'::jsonb,
  signature_url TEXT,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'approved')),
  approved_by_employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Habilitar RLS na tabela driver_inspections
ALTER TABLE driver_inspections ENABLE ROW LEVEL SECURITY;

-- 3. Criar políticas RLS para driver_inspections
DROP POLICY IF EXISTS "Guests can manage their own inspections" ON driver_inspections;
CREATE POLICY "Guests can manage their own inspections"
  ON driver_inspections
  FOR ALL
  TO authenticated
  USING (
    guest_id IN (
      SELECT id FROM guest_users WHERE auth_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Employees can view all inspections" ON driver_inspections;
CREATE POLICY "Employees can view all inspections"
  ON driver_inspections
  FOR SELECT
  TO authenticated
  USING (
    tenant_id = '00000000-0000-0000-0000-000000000001'::uuid AND
    EXISTS (
      SELECT 1 FROM employees e
      WHERE e.id = auth.uid() AND e.active = true
    )
  );

DROP POLICY IF EXISTS "Admins can manage all inspections" ON driver_inspections;
CREATE POLICY "Admins can manage all inspections"
  ON driver_inspections
  FOR ALL
  TO authenticated
  USING (
    tenant_id = '00000000-0000-0000-0000-000000000001'::uuid AND
    EXISTS (
      SELECT 1 FROM employees e
      WHERE e.id = auth.uid() AND e.role IN ('Admin', 'Manager')
    )
  );

-- 4. Criar índices para driver_inspections
CREATE INDEX IF NOT EXISTS idx_driver_inspections_tenant ON driver_inspections(tenant_id);
CREATE INDEX IF NOT EXISTS idx_driver_inspections_vehicle ON driver_inspections(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_driver_inspections_guest ON driver_inspections(guest_id);
CREATE INDEX IF NOT EXISTS idx_driver_inspections_type ON driver_inspections(inspection_type);
CREATE INDEX IF NOT EXISTS idx_driver_inspections_status ON driver_inspections(status);

-- 5. Criar trigger para atualizar updated_at
CREATE OR REPLACE FUNCTION fn_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_driver_inspections_updated_at ON driver_inspections;
CREATE TRIGGER trg_driver_inspections_updated_at
  BEFORE UPDATE ON driver_inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_updated_at();

-- 6. Recriar a view vw_driver_inspections_detailed
DROP VIEW IF EXISTS vw_driver_inspections_detailed;

CREATE OR REPLACE VIEW vw_driver_inspections_detailed AS
SELECT 
  di.*,
  v.plate as vehicle_plate,
  v.model as vehicle_model,
  CASE 
    WHEN di.guest_id IS NOT NULL THEN g.name
    WHEN di.driver_employee_id IS NOT NULL THEN e.name
    ELSE di.driver_name
  END as driver_full_name,
  c.contract_number,
  cust.name as customer_name,
  approved_emp.name as approved_by_name
FROM driver_inspections di
JOIN vehicles v ON di.vehicle_id = v.id
LEFT JOIN guest_users g ON di.guest_id = g.id
LEFT JOIN employees e ON di.driver_employee_id = e.id
LEFT JOIN contracts c ON di.contract_id = c.id
LEFT JOIN customers cust ON c.customer_id = cust.id
LEFT JOIN employees approved_emp ON di.approved_by_employee_id = approved_emp.id
ORDER BY di.created_at DESC; 