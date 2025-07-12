/*
  # Create Inventory System

  1. New Tables
    - `parts` - Store parts information with SKU, name, costs and stock levels
    - `stock_movements` - Track all inventory movements (entries and exits)
  
  2. Security
    - Enable RLS on both tables
    - Add policies for tenant-based access
    - Add policies for default tenant demo access
  
  3. Indexes
    - Add performance indexes for common queries
    - Add unique constraints where needed
*/

-- Create parts table
CREATE TABLE IF NOT EXISTS parts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  sku text UNIQUE NOT NULL,
  name text NOT NULL,
  quantity integer NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  unit_cost numeric(12,2) NOT NULL CHECK (unit_cost >= 0),
  min_stock integer NOT NULL DEFAULT 0 CHECK (min_stock >= 0),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create stock_movements table
CREATE TABLE IF NOT EXISTS stock_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  part_id uuid REFERENCES parts(id) ON DELETE CASCADE,
  service_note_id uuid REFERENCES service_notes(id) ON DELETE SET NULL,
  type text NOT NULL CHECK (type IN ('Entrada', 'Saída')),
  quantity integer NOT NULL CHECK (quantity > 0),
  movement_date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz DEFAULT now()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_parts_sku ON parts(sku);
CREATE INDEX IF NOT EXISTS idx_parts_tenant_id ON parts(tenant_id);
CREATE UNIQUE INDEX IF NOT EXISTS parts_sku_key ON parts(sku);

-- Enable RLS
ALTER TABLE parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;

-- Remove existing policies and create new ones
DO $$
BEGIN
  -- Policies for parts
  DROP POLICY IF EXISTS "Allow all operations for default tenant on parts" ON parts;
  DROP POLICY IF EXISTS "Users can manage their tenant parts" ON parts;
  
  CREATE POLICY "Allow all operations for default tenant on parts"
    ON parts
    FOR ALL
    TO anon, authenticated
    USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
    WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

  CREATE POLICY "Users can manage their tenant parts"
    ON parts
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

  -- Policies for stock_movements
  DROP POLICY IF EXISTS "Allow all operations for default tenant on stock_movements" ON stock_movements;
  DROP POLICY IF EXISTS "Users can manage their tenant stock movements" ON stock_movements;
  
  CREATE POLICY "Allow all operations for default tenant on stock_movements"
    ON stock_movements
    FOR ALL
    TO anon, authenticated
    USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
    WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

  CREATE POLICY "Users can manage their tenant stock movements"
    ON stock_movements
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
END $$;

-- Insert sample data for default tenant
INSERT INTO parts (tenant_id, sku, name, quantity, unit_cost, min_stock) VALUES
  ('00000000-0000-0000-0000-000000000001', 'FLT-001', 'Filtro de Óleo', 25, 45.00, 10),
  ('00000000-0000-0000-0000-000000000001', 'PST-001', 'Pastilha de Freio', 8, 120.00, 5),
  ('00000000-0000-0000-0000-000000000001', 'OLE-001', 'Óleo Motor 15W40', 50, 28.00, 20)
ON CONFLICT (sku) DO NOTHING;