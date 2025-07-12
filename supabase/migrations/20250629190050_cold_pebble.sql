/*
  # Create drivers table

  1. New Tables
    - `drivers`
      - `id` (uuid, primary key)
      - `tenant_id` (uuid, foreign key to tenants)
      - `name` (text, not null)
      - `cpf` (text, unique)
      - `license_no` (text)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on `drivers` table
    - Add policy for default tenant operations
    - Add policy for authenticated users to manage their tenant drivers

  3. Indexes
    - Index on tenant_id for performance
    - Unique index on cpf

  4. Triggers
    - Auto-update updated_at column on updates
*/

-- Criar tabela de motoristas se não existir
CREATE TABLE IF NOT EXISTS drivers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  cpf text UNIQUE,
  license_no text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_drivers_tenant_id ON drivers(tenant_id);
CREATE UNIQUE INDEX IF NOT EXISTS drivers_cpf_key ON drivers(cpf);

-- Habilitar Row Level Security
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes se existirem
DROP POLICY IF EXISTS "Allow all operations for default tenant on drivers" ON drivers;
DROP POLICY IF EXISTS "Users can manage their tenant drivers" ON drivers;

-- Políticas RLS
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

-- Criar função para atualizar updated_at se não existir
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para atualizar updated_at
DROP TRIGGER IF EXISTS trg_drivers_updated_at ON drivers;
CREATE TRIGGER trg_drivers_updated_at
  BEFORE UPDATE ON drivers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();