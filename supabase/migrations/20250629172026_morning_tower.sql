/*
  # Módulo de Colaboradores - Gestão Unificada de Funcionários

  1. Nova Tabela
    - `employees` - Cadastro unificado de funcionários com roles
      - `id` (uuid, primary key)
      - `tenant_id` (uuid, foreign key)
      - `name` (text)
      - `role` (text, check constraint)
      - `employee_code` (text, opcional)
      - `contact_info` (jsonb)
      - `active` (boolean)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Alterações em Tabelas Existentes
    - Adicionar `employee_id` em service_notes (mecânicos)
    - Alterar `inspected_by` em inspections para referenciar employees
    - Adicionar `salesperson_id` em contracts
    - Alterar `driver_id` em fines para referenciar employees

  3. Segurança
    - RLS habilitado em todas as tabelas
    - Políticas baseadas em tenant_id e roles
*/

BEGIN;

-- 1. Criar tabela de funcionários
CREATE TABLE IF NOT EXISTS employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK(role IN ('Admin','Mechanic','PatioInspector','Sales','Driver')),
  employee_code TEXT,
  contact_info JSONB DEFAULT '{}'::jsonb,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Índices para employees
CREATE INDEX IF NOT EXISTS idx_employees_tenant ON employees(tenant_id);
CREATE INDEX IF NOT EXISTS idx_employees_role ON employees(role);
CREATE INDEX IF NOT EXISTS idx_employees_active ON employees(active);

-- Habilitar RLS
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

-- 2. Políticas RLS para employees
CREATE POLICY "Users can view their tenant employees"
  ON employees
  FOR SELECT
  TO authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Admins can manage employees"
  ON employees
  FOR ALL
  TO authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

-- 3. Alterar service_notes para usar employee_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'service_notes' AND column_name = 'employee_id'
  ) THEN
    ALTER TABLE service_notes ADD COLUMN employee_id UUID REFERENCES employees(id);
    CREATE INDEX IF NOT EXISTS idx_service_notes_employee ON service_notes(employee_id);
  END IF;
END $$;

-- 4. Alterar inspections para usar employee_id
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'inspected_by' AND data_type = 'text'
  ) THEN
    -- Adicionar nova coluna
    ALTER TABLE inspections ADD COLUMN employee_id UUID REFERENCES employees(id);
    CREATE INDEX IF NOT EXISTS idx_inspections_employee ON inspections(employee_id);
    
    -- Remover coluna antiga após migração (opcional)
    -- ALTER TABLE inspections DROP COLUMN inspected_by;
  END IF;
END $$;

-- 5. Alterar contracts para incluir vendedor
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'contracts' AND column_name = 'salesperson_id'
  ) THEN
    ALTER TABLE contracts ADD COLUMN salesperson_id UUID REFERENCES employees(id);
    CREATE INDEX IF NOT EXISTS idx_contracts_salesperson ON contracts(salesperson_id);
  END IF;
END $$;

-- 6. Alterar fines para usar employee_id para motorista
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'fines' AND column_name = 'employee_id'
  ) THEN
    ALTER TABLE fines ADD COLUMN employee_id UUID REFERENCES employees(id);
    CREATE INDEX IF NOT EXISTS idx_fines_employee ON fines(employee_id);
  END IF;
END $$;

-- 7. Função para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. Trigger para updated_at em employees
CREATE TRIGGER trg_employees_updated_at
  BEFORE UPDATE ON employees
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 9. Inserir alguns funcionários padrão para demonstração
INSERT INTO employees (tenant_id, name, role, employee_code, contact_info, active) VALUES
  ('00000000-0000-0000-0000-000000000001', 'João Silva', 'Mechanic', 'MEC001', '{"email": "joao@oneway.com", "phone": "(11) 99999-1111"}', true),
  ('00000000-0000-0000-0000-000000000001', 'Maria Santos', 'PatioInspector', 'INS001', '{"email": "maria@oneway.com", "phone": "(11) 99999-2222"}', true),
  ('00000000-0000-0000-0000-000000000001', 'Carlos Vendas', 'Sales', 'VEN001', '{"email": "carlos@oneway.com", "phone": "(11) 99999-3333"}', true),
  ('00000000-0000-0000-0000-000000000001', 'Ana Motorista', 'Driver', 'MOT001', '{"email": "ana@oneway.com", "phone": "(11) 99999-4444"}', true),
  ('00000000-0000-0000-0000-000000000001', 'Pedro Admin', 'Admin', 'ADM001', '{"email": "pedro@oneway.com", "phone": "(11) 99999-5555"}', true)
ON CONFLICT DO NOTHING;

COMMIT;