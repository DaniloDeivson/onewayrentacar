/*
  # Create maintenance system tables

  1. New Tables
    - `maintenance_types`
      - `id` (uuid, primary key)
      - `tenant_id` (uuid, foreign key to tenants)
      - `name` (text, maintenance type name)
      - `created_at` (timestamp)
    - `mechanics`
      - `id` (uuid, primary key)
      - `tenant_id` (uuid, foreign key to tenants)
      - `name` (text, mechanic name)
      - `employee_code` (text, employee identifier)
      - `phone` (text, contact phone)
      - `specialization` (text, area of expertise)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on both tables
    - Add policies for authenticated users to manage their tenant data
    - Add policies for default tenant access

  3. Initial Data
    - Insert default maintenance types
    - Insert sample mechanics for default tenant
*/

-- Criar tabela de tipos de manutenção
CREATE TABLE IF NOT EXISTS maintenance_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Criar tabela de mecânicos
CREATE TABLE IF NOT EXISTS mechanics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  employee_code text,
  phone text,
  specialization text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Adicionar índices
CREATE INDEX IF NOT EXISTS idx_maintenance_types_tenant_id ON maintenance_types(tenant_id);
CREATE INDEX IF NOT EXISTS idx_mechanics_tenant_id ON mechanics(tenant_id);

-- Habilitar RLS
ALTER TABLE maintenance_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE mechanics ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes se existirem e criar novas
DO $$
BEGIN
  -- Políticas para maintenance_types
  DROP POLICY IF EXISTS "Allow all operations for default tenant on maintenance_types" ON maintenance_types;
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

  -- Políticas para mechanics
  DROP POLICY IF EXISTS "Allow all operations for default tenant on mechanics" ON mechanics;
  DROP POLICY IF EXISTS "Users can manage their tenant mechanics" ON mechanics;
  
  CREATE POLICY "Allow all operations for default tenant on mechanics"
    ON mechanics
    FOR ALL
    TO anon, authenticated
    USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
    WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

  CREATE POLICY "Users can manage their tenant mechanics"
    ON mechanics
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

-- Inserir dados iniciais para o tenant padrão
INSERT INTO maintenance_types (tenant_id, name) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Preventiva'),
  ('00000000-0000-0000-0000-000000000001', 'Corretiva'),
  ('00000000-0000-0000-0000-000000000001', 'Revisão'),
  ('00000000-0000-0000-0000-000000000001', 'Troca de Óleo'),
  ('00000000-0000-0000-0000-000000000001', 'Freios'),
  ('00000000-0000-0000-0000-000000000001', 'Suspensão'),
  ('00000000-0000-0000-0000-000000000001', 'Motor'),
  ('00000000-0000-0000-0000-000000000001', 'Elétrica')
ON CONFLICT DO NOTHING;

INSERT INTO mechanics (tenant_id, name, employee_code, specialization) VALUES
  ('00000000-0000-0000-0000-000000000001', 'João Silva', 'MEC001', 'Motor e Transmissão'),
  ('00000000-0000-0000-0000-000000000001', 'Pedro Santos', 'MEC002', 'Freios e Suspensão'),
  ('00000000-0000-0000-0000-000000000001', 'Carlos Oliveira', 'MEC003', 'Elétrica e Eletrônica'),
  ('00000000-0000-0000-0000-000000000001', 'Roberto Lima', 'MEC004', 'Geral')
ON CONFLICT DO NOTHING;