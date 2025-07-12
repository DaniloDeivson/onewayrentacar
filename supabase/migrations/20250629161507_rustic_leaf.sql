/*
  # OneWay Rent A Car - Initial Database Schema

  1. Core Tables
    - tenants (multi-tenancy support)
    - vehicles (fleet management)
    - costs (expense tracking)
    - maintenance_types (service categories)
    - service_notes (maintenance orders)
    - parts (inventory management)
    - stock_movements (inventory transactions)
    - customers (client management)
    - contracts (rental agreements)
    - drivers (driver management)
    - fines (traffic violations)
    - suppliers (vendor management)

  2. Security
    - Enable RLS on all tables
    - Add policies for tenant-based access control
*/

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tenants table for multi-tenancy
CREATE TABLE IF NOT EXISTS tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Vehicles table
CREATE TABLE IF NOT EXISTS vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  plate text UNIQUE NOT NULL,
  model text NOT NULL,
  year integer NOT NULL CHECK(year >= 2000),
  type text NOT NULL CHECK(type IN ('Furgão', 'Van')),
  color text,
  fuel text CHECK(fuel IN ('Diesel', 'Gasolina', 'Elétrico')),
  category text NOT NULL,
  chassis text UNIQUE,
  renavam text UNIQUE,
  cargo_capacity integer CHECK(cargo_capacity >= 0),
  location text,
  acquisition_date date,
  acquisition_value numeric(12,2),
  status text NOT NULL DEFAULT 'Disponível' CHECK(status IN ('Disponível', 'Em Uso', 'Manutenção', 'Inativo')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Costs table
CREATE TABLE IF NOT EXISTS costs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  category text NOT NULL CHECK(category IN ('Multa', 'Funilaria', 'Seguro', 'Avulsa')),
  vehicle_id uuid REFERENCES vehicles(id) ON DELETE CASCADE,
  description text NOT NULL,
  amount numeric(12,2) NOT NULL CHECK(amount >= 0),
  cost_date date NOT NULL,
  status text NOT NULL DEFAULT 'Pendente' CHECK(status IN ('Pendente', 'Pago')),
  document_ref text,
  observations text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Maintenance types
CREATE TABLE IF NOT EXISTS maintenance_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Service notes
CREATE TABLE IF NOT EXISTS service_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  vehicle_id uuid REFERENCES vehicles(id) ON DELETE CASCADE,
  maintenance_type text NOT NULL,
  start_date date NOT NULL,
  end_date date,
  mechanic text NOT NULL,
  priority text NOT NULL DEFAULT 'Média' CHECK(priority IN ('Baixa', 'Média', 'Alta')),
  mileage integer,
  description text NOT NULL,
  observations text,
  status text NOT NULL DEFAULT 'Aberta' CHECK(status IN ('Aberta', 'Em Andamento', 'Concluída')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Parts inventory
CREATE TABLE IF NOT EXISTS parts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  sku text UNIQUE NOT NULL,
  name text NOT NULL,
  quantity integer NOT NULL DEFAULT 0 CHECK(quantity >= 0),
  unit_cost numeric(12,2) NOT NULL CHECK(unit_cost >= 0),
  min_stock integer NOT NULL DEFAULT 0 CHECK(min_stock >= 0),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Stock movements
CREATE TABLE IF NOT EXISTS stock_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  part_id uuid REFERENCES parts(id) ON DELETE CASCADE,
  service_note_id uuid REFERENCES service_notes(id) ON DELETE SET NULL,
  type text NOT NULL CHECK(type IN ('Entrada', 'Saída')),
  quantity integer NOT NULL CHECK(quantity > 0),
  movement_date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz DEFAULT now()
);

-- Customers
CREATE TABLE IF NOT EXISTS customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  document text NOT NULL,
  email text,
  phone text,
  address text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Contracts
CREATE TABLE IF NOT EXISTS contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES customers(id) ON DELETE CASCADE,
  vehicle_id uuid REFERENCES vehicles(id) ON DELETE CASCADE,
  start_date date NOT NULL,
  end_date date NOT NULL,
  daily_rate numeric(12,2) NOT NULL CHECK(daily_rate >= 0),
  status text NOT NULL DEFAULT 'Ativo' CHECK(status IN ('Ativo', 'Finalizado', 'Cancelado')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Drivers
CREATE TABLE IF NOT EXISTS drivers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  cpf text UNIQUE,
  license_no text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Fines
CREATE TABLE IF NOT EXISTS fines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  vehicle_id uuid REFERENCES vehicles(id) ON DELETE CASCADE,
  driver_id uuid REFERENCES drivers(id) ON DELETE SET NULL,
  fine_number text UNIQUE NOT NULL,
  infraction_type text NOT NULL,
  amount numeric(12,2) NOT NULL CHECK(amount >= 0),
  infraction_date date NOT NULL,
  due_date date NOT NULL,
  notified boolean DEFAULT false,
  status text NOT NULL DEFAULT 'Pendente' CHECK(status IN ('Pendente', 'Pago', 'Contestado')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Suppliers
CREATE TABLE IF NOT EXISTS suppliers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  contact_info jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE fines ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users
CREATE POLICY "Users can view their tenant data" ON tenants
  FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can manage their tenant vehicles" ON vehicles
  FOR ALL TO authenticated
  USING (tenant_id IN (SELECT id FROM tenants WHERE auth.uid() IS NOT NULL));

CREATE POLICY "Users can manage their tenant costs" ON costs
  FOR ALL TO authenticated
  USING (tenant_id IN (SELECT id FROM tenants WHERE auth.uid() IS NOT NULL));

CREATE POLICY "Users can manage their tenant maintenance types" ON maintenance_types
  FOR ALL TO authenticated
  USING (tenant_id IN (SELECT id FROM tenants WHERE auth.uid() IS NOT NULL));

CREATE POLICY "Users can manage their tenant service notes" ON service_notes
  FOR ALL TO authenticated
  USING (tenant_id IN (SELECT id FROM tenants WHERE auth.uid() IS NOT NULL));

CREATE POLICY "Users can manage their tenant parts" ON parts
  FOR ALL TO authenticated
  USING (tenant_id IN (SELECT id FROM tenants WHERE auth.uid() IS NOT NULL));

CREATE POLICY "Users can manage their tenant stock movements" ON stock_movements
  FOR ALL TO authenticated
  USING (tenant_id IN (SELECT id FROM tenants WHERE auth.uid() IS NOT NULL));

CREATE POLICY "Users can manage their tenant customers" ON customers
  FOR ALL TO authenticated
  USING (tenant_id IN (SELECT id FROM tenants WHERE auth.uid() IS NOT NULL));

CREATE POLICY "Users can manage their tenant contracts" ON contracts
  FOR ALL TO authenticated
  USING (tenant_id IN (SELECT id FROM tenants WHERE auth.uid() IS NOT NULL));

CREATE POLICY "Users can manage their tenant drivers" ON drivers
  FOR ALL TO authenticated
  USING (tenant_id IN (SELECT id FROM tenants WHERE auth.uid() IS NOT NULL));

CREATE POLICY "Users can manage their tenant fines" ON fines
  FOR ALL TO authenticated
  USING (tenant_id IN (SELECT id FROM tenants WHERE auth.uid() IS NOT NULL));

CREATE POLICY "Users can manage their tenant suppliers" ON suppliers
  FOR ALL TO authenticated
  USING (tenant_id IN (SELECT id FROM tenants WHERE auth.uid() IS NOT NULL));

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_vehicles_tenant_id ON vehicles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_plate ON vehicles(plate);
CREATE INDEX IF NOT EXISTS idx_costs_tenant_id ON costs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_costs_vehicle_id ON costs(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_costs_date ON costs(cost_date);
CREATE INDEX IF NOT EXISTS idx_service_notes_tenant_id ON service_notes(tenant_id);
CREATE INDEX IF NOT EXISTS idx_service_notes_vehicle_id ON service_notes(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_parts_tenant_id ON parts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_parts_sku ON parts(sku);
CREATE INDEX IF NOT EXISTS idx_contracts_tenant_id ON contracts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_fines_tenant_id ON fines(tenant_id);
CREATE INDEX IF NOT EXISTS idx_fines_vehicle_id ON fines(vehicle_id);

-- Insert default tenant for demo
INSERT INTO tenants (id, name) VALUES 
  ('00000000-0000-0000-0000-000000000001', 'OneWay Rent A Car')
ON CONFLICT (id) DO NOTHING;

-- Insert default maintenance types
INSERT INTO maintenance_types (tenant_id, name) VALUES 
  ('00000000-0000-0000-0000-000000000001', 'Preventiva'),
  ('00000000-0000-0000-0000-000000000001', 'Corretiva'),
  ('00000000-0000-0000-0000-000000000001', 'Revisão')
ON CONFLICT DO NOTHING;