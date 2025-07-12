-- Migração para criar tabelas dependentes que estão faltando
-- Inclui: tenants, guest_users, driver_inspections e view vw_driver_inspections_detailed

-- 1. Criar tabela tenants se não existir
CREATE TABLE IF NOT EXISTS tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  domain TEXT UNIQUE,
  settings JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Inserir tenant padrão se não existir
INSERT INTO tenants (id, name) 
VALUES ('00000000-0000-0000-0000-000000000001', 'OneWay Rent A Car')
ON CONFLICT (id) DO NOTHING;

-- 2. Criar tabela guest_users se não existir
CREATE TABLE IF NOT EXISTS guest_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  auth_user_id UUID UNIQUE,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  document TEXT,
  address TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'blocked')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Habilitar RLS na tabela guest_users
ALTER TABLE guest_users ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para guest_users
CREATE POLICY "Guests can view their own profile"
  ON guest_users
  FOR SELECT
  TO authenticated
  USING (auth_user_id = auth.uid());

CREATE POLICY "Guests can update their own profile"
  ON guest_users
  FOR UPDATE
  TO authenticated
  USING (auth_user_id = auth.uid())
  WITH CHECK (auth_user_id = auth.uid());

CREATE POLICY "Admins can manage all guests"
  ON guest_users
  FOR ALL
  TO authenticated
  USING (
    tenant_id = '00000000-0000-0000-0000-000000000001'::uuid AND
    EXISTS (
      SELECT 1 FROM employees e
      WHERE e.id = auth.uid() AND e.role IN ('Admin', 'Manager')
    )
  );

-- Criar índices para guest_users
CREATE INDEX IF NOT EXISTS idx_guest_users_tenant ON guest_users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_guest_users_auth_user ON guest_users(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_guest_users_email ON guest_users(email);

-- 3. Adicionar guest_id aos contratos se não existir
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS guest_id UUID REFERENCES guest_users(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_contracts_guest_id ON contracts(guest_id);

-- 4. Criar tabela driver_inspections se não existir
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

-- Habilitar RLS na tabela driver_inspections
ALTER TABLE driver_inspections ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para driver_inspections
CREATE POLICY "Guests can manage their own inspections"
  ON driver_inspections
  FOR ALL
  TO authenticated
  USING (
    guest_id IN (
      SELECT id FROM guest_users WHERE auth_user_id = auth.uid()
    )
  );

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

-- Criar índices para driver_inspections
CREATE INDEX IF NOT EXISTS idx_driver_inspections_tenant ON driver_inspections(tenant_id);
CREATE INDEX IF NOT EXISTS idx_driver_inspections_vehicle ON driver_inspections(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_driver_inspections_guest ON driver_inspections(guest_id);
CREATE INDEX IF NOT EXISTS idx_driver_inspections_type ON driver_inspections(inspection_type);
CREATE INDEX IF NOT EXISTS idx_driver_inspections_status ON driver_inspections(status);

-- 5. Criar view vw_driver_inspections_detailed
DROP VIEW IF EXISTS vw_driver_inspections_detailed CASCADE;
CREATE OR REPLACE VIEW vw_driver_inspections_detailed AS
SELECT 
  di.id,
  di.tenant_id,
  di.vehicle_id,
  di.contract_id,
  di.guest_id,
  di.driver_employee_id,
  di.driver_name,
  di.inspection_type,
  di.checklist,
  di.fuel_level,
  di.odometer_reading,
  di.damage_photos,
  di.signature_url,
  di.notes,
  di.status,
  di.approved_by_employee_id,
  di.approved_at,
  di.created_at,
  di.updated_at,
  v.plate as vehicle_plate,
  v.model as vehicle_model,
  v.year as vehicle_year,
  c.contract_number,
  c.start_date as contract_start_date,
  c.end_date as contract_end_date,
  gu.name as guest_name,
  gu.email as guest_email,
  gu.phone as guest_phone,
  e.name as employee_name,
  e.contact_info->>'email' as employee_email,
  approver.name as approver_name,
  approver.contact_info->>'email' as approver_email
FROM driver_inspections di
LEFT JOIN vehicles v ON di.vehicle_id = v.id
LEFT JOIN contracts c ON di.contract_id = c.id
LEFT JOIN guest_users gu ON di.guest_id = gu.id
LEFT JOIN employees e ON di.driver_employee_id = e.id
LEFT JOIN employees approver ON di.approved_by_employee_id = approver.id;

-- 6. Criar função para atualizar updated_at
CREATE OR REPLACE FUNCTION fn_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Criar triggers para updated_at
CREATE TRIGGER trg_guest_users_updated_at
  BEFORE UPDATE ON guest_users
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_updated_at();

CREATE TRIGGER trg_driver_inspections_updated_at
  BEFORE UPDATE ON driver_inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_updated_at(); 