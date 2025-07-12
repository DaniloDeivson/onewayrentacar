/*
  # Fix RLS policies and create default tenant

  1. Changes
    - Create default tenant if it doesn't exist
    - Update RLS policies to allow operations for the default tenant
    - Add policies that work without authentication for demo purposes

  2. Security
    - Maintain RLS on all tables
    - Add specific policies for the default tenant
    - Keep existing authenticated user policies
*/

-- First, ensure the default tenant exists
INSERT INTO tenants (id, name, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'Demo Tenant',
  now(),
  now()
)
ON CONFLICT (id) DO NOTHING;

-- Update vehicles table policies
DROP POLICY IF EXISTS "Users can manage their tenant vehicles" ON vehicles;

-- Create new policies for vehicles
CREATE POLICY "Allow all operations for default tenant"
  ON vehicles
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Users can manage their tenant vehicles"
  ON vehicles
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

-- Update costs table policies
DROP POLICY IF EXISTS "Users can manage their tenant costs" ON costs;

CREATE POLICY "Allow all operations for default tenant on costs"
  ON costs
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Users can manage their tenant costs"
  ON costs
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

-- Update service_notes table policies
DROP POLICY IF EXISTS "Users can manage their tenant service notes" ON service_notes;

CREATE POLICY "Allow all operations for default tenant on service_notes"
  ON service_notes
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Users can manage their tenant service notes"
  ON service_notes
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

-- Update parts table policies
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

-- Update stock_movements table policies
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

-- Update customers table policies
DROP POLICY IF EXISTS "Users can manage their tenant customers" ON customers;

CREATE POLICY "Allow all operations for default tenant on customers"
  ON customers
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Users can manage their tenant customers"
  ON customers
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

-- Update contracts table policies
DROP POLICY IF EXISTS "Users can manage their tenant contracts" ON contracts;

CREATE POLICY "Allow all operations for default tenant on contracts"
  ON contracts
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

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

-- Update drivers table policies
DROP POLICY IF EXISTS "Users can manage their tenant drivers" ON drivers;

CREATE POLICY "Allow all operations for default tenant on drivers"
  ON drivers
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Users can manage their tenant drivers"
  ON drivers
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

-- Update fines table policies
DROP POLICY IF EXISTS "Users can manage their tenant fines" ON fines;

CREATE POLICY "Allow all operations for default tenant on fines"
  ON fines
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Users can manage their tenant fines"
  ON fines
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

-- Update suppliers table policies
DROP POLICY IF EXISTS "Users can manage their tenant suppliers" ON suppliers;

CREATE POLICY "Allow all operations for default tenant on suppliers"
  ON suppliers
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Users can manage their tenant suppliers"
  ON suppliers
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

-- Update maintenance_types table policies
DROP POLICY IF EXISTS "Users can manage their tenant maintenance types" ON maintenance_types;

CREATE POLICY "Allow all operations for default tenant on maintenance_types"
  ON maintenance_types
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Users can manage their tenant maintenance types"
  ON maintenance_types
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

-- Update tenants table policy
DROP POLICY IF EXISTS "Users can view their tenant data" ON tenants;

CREATE POLICY "Allow read access to default tenant"
  ON tenants
  FOR SELECT
  TO anon, authenticated
  USING (id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Users can view their tenant data"
  ON tenants
  FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);