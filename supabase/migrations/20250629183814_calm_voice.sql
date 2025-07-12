/*
  # Módulo de Multas - Sistema Completo

  1. Nova Tabela
    - `fines`
      - `id` (uuid, primary key)
      - `tenant_id` (uuid, foreign key)
      - `vehicle_id` (uuid, foreign key)
      - `driver_id` (uuid, foreign key, nullable)
      - `employee_id` (uuid, foreign key, nullable)
      - `fine_number` (text, unique)
      - `infraction_type` (text)
      - `amount` (numeric)
      - `infraction_date` (date)
      - `due_date` (date)
      - `notified` (boolean)
      - `status` (text)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Segurança
    - Habilitar RLS na tabela `fines`
    - Políticas para acesso por tenant

  3. Automação
    - Trigger para gerar número da multa automaticamente
    - Trigger para criar custo automático
    - Função para estatísticas

  4. View
    - `vw_fines_detailed` com dados relacionados
</*/

-- Verificar se a tabela já existe antes de criar
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'fines') THEN
    -- Criar tabela de multas
    CREATE TABLE fines (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
      driver_id uuid REFERENCES employees(id) ON DELETE SET NULL,
      employee_id uuid REFERENCES employees(id), -- Funcionário que registrou a multa
      fine_number text UNIQUE NOT NULL,
      infraction_type text NOT NULL,
      amount numeric(12,2) NOT NULL CHECK (amount >= 0),
      infraction_date date NOT NULL,
      due_date date NOT NULL,
      notified boolean DEFAULT false,
      status text NOT NULL DEFAULT 'Pendente' CHECK (status IN ('Pendente', 'Pago', 'Contestado')),
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now()
    );

    -- Índices para performance
    CREATE INDEX idx_fines_tenant_id ON fines(tenant_id);
    CREATE INDEX idx_fines_vehicle_id ON fines(vehicle_id);
    CREATE INDEX idx_fines_driver_id ON fines(driver_id);
    CREATE INDEX idx_fines_employee ON fines(employee_id);
    CREATE INDEX idx_fines_infraction_date ON fines(infraction_date);
    CREATE INDEX idx_fines_status ON fines(status);
    CREATE INDEX idx_fines_notified ON fines(notified);
    CREATE INDEX idx_fines_fine_number ON fines(fine_number);

    -- Habilitar Row Level Security
    ALTER TABLE fines ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Remover políticas existentes se existirem
DROP POLICY IF EXISTS "Allow all operations for default tenant on fines" ON fines;
DROP POLICY IF EXISTS "Users can manage their tenant fines" ON fines;

-- Criar políticas RLS
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
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

-- Função para gerar número da multa automaticamente
CREATE OR REPLACE FUNCTION fn_generate_fine_number()
RETURNS TRIGGER AS $$
BEGIN
  -- Se o número não foi fornecido, gerar automaticamente
  IF NEW.fine_number IS NULL OR NEW.fine_number = '' THEN
    NEW.fine_number := CONCAT(
      'MLT-',
      to_char(NEW.infraction_date, 'YYYYMMDD'),
      '-',
      UPPER(substr(md5(random()::text), 1, 6))
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Remover trigger existente se existir
DROP TRIGGER IF EXISTS trg_fines_generate_number ON fines;

-- Criar trigger para gerar número da multa
CREATE TRIGGER trg_fines_generate_number
  BEFORE INSERT ON fines
  FOR EACH ROW
  EXECUTE FUNCTION fn_generate_fine_number();

-- Função para processar multa após inserção
CREATE OR REPLACE FUNCTION fn_fine_postprocess()
RETURNS TRIGGER AS $$
DECLARE
  v_driver_name text;
  v_vehicle_plate text;
BEGIN
  -- Buscar dados do motorista e veículo
  SELECT e.name INTO v_driver_name
  FROM employees e
  WHERE e.id = NEW.driver_id;
  
  SELECT v.plate INTO v_vehicle_plate
  FROM vehicles v
  WHERE v.id = NEW.vehicle_id;
  
  -- Criar custo automático para a multa
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
    origin,
    created_by_employee_id,
    source_reference_id,
    source_reference_type
  ) VALUES (
    NEW.tenant_id,
    'Multa',
    NEW.vehicle_id,
    CONCAT('Multa ', NEW.fine_number, ' - ', NEW.infraction_type),
    NEW.amount,
    NEW.infraction_date,
    'Pendente',
    NEW.fine_number,
    CONCAT(
      'Motorista responsável: ', COALESCE(v_driver_name, 'Não informado'), 
      ' | Veículo: ', COALESCE(v_vehicle_plate, 'N/A')
    ),
    'Sistema',
    NEW.employee_id, -- Funcionário que registrou a multa
    NEW.id,
    'fine'
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Remover trigger existente se existir
DROP TRIGGER IF EXISTS trg_fines_postprocess ON fines;

-- Criar trigger para processar multa após inserção
CREATE TRIGGER trg_fines_postprocess
  AFTER INSERT ON fines
  FOR EACH ROW
  EXECUTE FUNCTION fn_fine_postprocess();

-- Remover trigger existente se existir
DROP TRIGGER IF EXISTS trg_fines_updated_at ON fines;

-- Criar trigger para atualizar updated_at
CREATE TRIGGER trg_fines_updated_at
  BEFORE UPDATE ON fines
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Função para estatísticas de multas
CREATE OR REPLACE FUNCTION fn_fines_statistics(p_tenant_id uuid)
RETURNS TABLE (
  total_fines bigint,
  pending_fines bigint,
  paid_fines bigint,
  contested_fines bigint,
  total_amount numeric,
  pending_amount numeric,
  notified_count bigint,
  not_notified_count bigint,
  avg_fine_amount numeric,
  most_common_infraction text,
  most_fined_vehicle text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::bigint as total_fines,
    COUNT(*) FILTER (WHERE f.status = 'Pendente')::bigint as pending_fines,
    COUNT(*) FILTER (WHERE f.status = 'Pago')::bigint as paid_fines,
    COUNT(*) FILTER (WHERE f.status = 'Contestado')::bigint as contested_fines,
    COALESCE(SUM(f.amount), 0) as total_amount,
    COALESCE(SUM(f.amount) FILTER (WHERE f.status = 'Pendente'), 0) as pending_amount,
    COUNT(*) FILTER (WHERE f.notified = true)::bigint as notified_count,
    COUNT(*) FILTER (WHERE f.notified = false)::bigint as not_notified_count,
    COALESCE(AVG(f.amount), 0) as avg_fine_amount,
    (
      SELECT f2.infraction_type
      FROM fines f2
      WHERE f2.tenant_id = p_tenant_id
      GROUP BY f2.infraction_type
      ORDER BY COUNT(*) DESC
      LIMIT 1
    ) as most_common_infraction,
    (
      SELECT v.plate
      FROM fines f3
      JOIN vehicles v ON v.id = f3.vehicle_id
      WHERE f3.tenant_id = p_tenant_id
      GROUP BY v.plate
      ORDER BY COUNT(*) DESC
      LIMIT 1
    ) as most_fined_vehicle
  FROM fines f
  WHERE f.tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql;

-- Remover view existente se existir
DROP VIEW IF EXISTS vw_fines_detailed;

-- Criar view para multas detalhadas
CREATE VIEW vw_fines_detailed AS
SELECT 
  f.id,
  f.tenant_id,
  f.vehicle_id,
  v.plate as vehicle_plate,
  v.model as vehicle_model,
  v.year as vehicle_year,
  f.driver_id,
  d.name as driver_name,
  d.employee_code as driver_code,
  f.employee_id,
  e.name as created_by_name,
  e.role as created_by_role,
  f.fine_number,
  f.infraction_type,
  f.amount,
  f.infraction_date,
  f.due_date,
  f.notified,
  f.status,
  f.created_at,
  f.updated_at,
  -- Campos calculados
  CASE 
    WHEN f.due_date < CURRENT_DATE AND f.status = 'Pendente' THEN true
    ELSE false
  END as is_overdue,
  CURRENT_DATE - f.due_date as days_overdue
FROM fines f
LEFT JOIN vehicles v ON v.id = f.vehicle_id
LEFT JOIN employees d ON d.id = f.driver_id
LEFT JOIN employees e ON e.id = f.employee_id;