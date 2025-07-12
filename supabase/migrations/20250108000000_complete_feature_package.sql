/*
  # OneWay Rent A Car - Pacote Completo de Funcionalidades

  1. Funcionalidades Implementadas:
    - Custos recorrentes (aluguel de veículos)
    - Abastecimentos para motoristas guests
    - Inspeções para motoristas guests
    - Histórico completo de veículos
    - Estatísticas do departamento de compras
    - Sistema de guests/clientes

  2. Novas Tabelas:
    - fuel_records: registros de abastecimento
    - driver_inspections: inspeções de motoristas
    - vehicle_history: histórico completo dos veículos
    - guest_users: usuários guests/clientes

  3. Modificações:
    - costs: campos de recorrência e categorias atualizadas
    - contracts: vinculação com guests
    - Novas funções e triggers
    - RLS para guests

  4. Segurança:
    - RLS baseado em tenant_id e guest_id
    - Permissões específicas para guests
*/

-- 1. Atualizar tabela costs para recorrência
ALTER TABLE costs DROP CONSTRAINT IF EXISTS costs_category_check;
ALTER TABLE costs ADD CONSTRAINT costs_category_check 
  CHECK (category IN (
    'Multa', 'Funilaria', 'Seguro', 'Avulsa', 'Compra', 'Excesso Km', 
    'Diária Extra', 'Combustível', 'Avaria', 'Manutenção', 'Aluguel de Veículo'
  ));

-- Adicionar colunas para recorrência
ALTER TABLE costs ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT FALSE;
ALTER TABLE costs ADD COLUMN IF NOT EXISTS recurrence_type TEXT CHECK (recurrence_type IN ('monthly', 'weekly', 'yearly'));
ALTER TABLE costs ADD COLUMN IF NOT EXISTS recurrence_day INTEGER CHECK (recurrence_day >= 1 AND recurrence_day <= 31);
ALTER TABLE costs ADD COLUMN IF NOT EXISTS next_due_date DATE;
ALTER TABLE costs ADD COLUMN IF NOT EXISTS parent_recurring_cost_id UUID REFERENCES costs(id);
ALTER TABLE costs ADD COLUMN IF NOT EXISTS auto_generated BOOLEAN DEFAULT FALSE;
ALTER TABLE costs ADD COLUMN IF NOT EXISTS guest_id UUID;

-- Criar índices para recorrência
CREATE INDEX IF NOT EXISTS idx_costs_recurring ON costs(is_recurring);
CREATE INDEX IF NOT EXISTS idx_costs_next_due ON costs(next_due_date);
CREATE INDEX IF NOT EXISTS idx_costs_parent_recurring ON costs(parent_recurring_cost_id);
CREATE INDEX IF NOT EXISTS idx_costs_guest_id ON costs(guest_id);

-- 2. Criar tabela de usuários guests
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

-- 3. Adicionar guest_id aos contratos
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS guest_id UUID REFERENCES guest_users(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_contracts_guest_id ON contracts(guest_id);

-- 4. Criar tabela de abastecimentos
CREATE TABLE IF NOT EXISTS fuel_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,
  contract_id UUID REFERENCES contracts(id) ON DELETE SET NULL,
  guest_id UUID REFERENCES guest_users(id) ON DELETE SET NULL,
  driver_employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
  driver_name TEXT NOT NULL,
  fuel_amount NUMERIC(8,2) NOT NULL CHECK (fuel_amount > 0),
  unit_price NUMERIC(8,2) NOT NULL CHECK (unit_price > 0),
  total_cost NUMERIC(10,2) NOT NULL CHECK (total_cost > 0),
  odometer_reading INTEGER CHECK (odometer_reading >= 0),
  fuel_station TEXT,
  receipt_number TEXT,
  receipt_photo_url TEXT,
  dashboard_photo_url TEXT,
  notes TEXT,
  recorded_at TIMESTAMPTZ DEFAULT NOW(),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  approved_by_employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
  approved_at TIMESTAMPTZ,
  cost_id UUID REFERENCES costs(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Habilitar RLS na tabela fuel_records
ALTER TABLE fuel_records ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para fuel_records
CREATE POLICY "Guests can manage their own fuel records"
  ON fuel_records
  FOR ALL
  TO authenticated
  USING (
    guest_id IN (
      SELECT id FROM guest_users WHERE auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Employees can view all fuel records"
  ON fuel_records
  FOR SELECT
  TO authenticated
  USING (
    tenant_id = '00000000-0000-0000-0000-000000000001'::uuid AND
    EXISTS (
      SELECT 1 FROM employees e
      WHERE e.id = auth.uid() AND e.active = true
    )
  );

CREATE POLICY "Admins can manage all fuel records"
  ON fuel_records
  FOR ALL
  TO authenticated
  USING (
    tenant_id = '00000000-0000-0000-0000-000000000001'::uuid AND
    EXISTS (
      SELECT 1 FROM employees e
      WHERE e.id = auth.uid() AND e.role IN ('Admin', 'Manager')
    )
  );

-- Criar índices para fuel_records
CREATE INDEX IF NOT EXISTS idx_fuel_records_tenant ON fuel_records(tenant_id);
CREATE INDEX IF NOT EXISTS idx_fuel_records_vehicle ON fuel_records(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_fuel_records_guest ON fuel_records(guest_id);
CREATE INDEX IF NOT EXISTS idx_fuel_records_status ON fuel_records(status);
CREATE INDEX IF NOT EXISTS idx_fuel_records_recorded_at ON fuel_records(recorded_at);

-- 5. Criar tabela de inspeções de motoristas
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

-- 6. Criar tabela de histórico de veículos
CREATE TABLE IF NOT EXISTS vehicle_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (event_type IN ('cost', 'maintenance', 'inspection', 'fine', 'fuel', 'contract_start', 'contract_end')),
  event_date TIMESTAMPTZ NOT NULL,
  description TEXT NOT NULL,
  amount NUMERIC(10,2),
  reference_id UUID,
  reference_table TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Habilitar RLS na tabela vehicle_history
ALTER TABLE vehicle_history ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para vehicle_history
CREATE POLICY "Employees can view vehicle history"
  ON vehicle_history
  FOR SELECT
  TO authenticated
  USING (
    tenant_id = '00000000-0000-0000-0000-000000000001'::uuid AND
    EXISTS (
      SELECT 1 FROM employees e
      WHERE e.id = auth.uid() AND e.active = true
    )
  );

CREATE POLICY "Admins can manage vehicle history"
  ON vehicle_history
  FOR ALL
  TO authenticated
  USING (
    tenant_id = '00000000-0000-0000-0000-000000000001'::uuid AND
    EXISTS (
      SELECT 1 FROM employees e
      WHERE e.id = auth.uid() AND e.role IN ('Admin', 'Manager')
    )
  );

-- Criar índices para vehicle_history
CREATE INDEX IF NOT EXISTS idx_vehicle_history_tenant ON vehicle_history(tenant_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_history_vehicle ON vehicle_history(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_history_event_type ON vehicle_history(event_type);
CREATE INDEX IF NOT EXISTS idx_vehicle_history_event_date ON vehicle_history(event_date);

-- 7. Criar funções para custos recorrentes
CREATE OR REPLACE FUNCTION fn_generate_recurring_costs()
RETURNS INTEGER AS $$
DECLARE
  recurring_cost costs%ROWTYPE;
  generated_count INTEGER := 0;
BEGIN
  FOR recurring_cost IN 
    SELECT * FROM costs 
    WHERE is_recurring = TRUE 
    AND next_due_date <= CURRENT_DATE
    AND status = 'Autorizado'
  LOOP
    -- Criar novo custo baseado no recorrente
    INSERT INTO costs (
      tenant_id,
      category,
      description,
      amount,
      cost_date,
      status,
      vehicle_id,
      customer_id,
      customer_name,
      contract_id,
      guest_id,
      is_recurring,
      recurrence_type,
      recurrence_day,
      parent_recurring_cost_id,
      auto_generated
    ) VALUES (
      recurring_cost.tenant_id,
      recurring_cost.category,
      recurring_cost.description || ' (Gerado automaticamente)',
      recurring_cost.amount,
      recurring_cost.next_due_date,
      'Pendente',
      recurring_cost.vehicle_id,
      recurring_cost.customer_id,
      recurring_cost.customer_name,
      recurring_cost.contract_id,
      recurring_cost.guest_id,
      FALSE,
      NULL,
      NULL,
      recurring_cost.id,
      TRUE
    );
    
    -- Atualizar próxima data de vencimento
    UPDATE costs 
    SET next_due_date = 
      CASE 
        WHEN recurrence_type = 'monthly' THEN 
          next_due_date + INTERVAL '1 month'
        WHEN recurrence_type = 'weekly' THEN 
          next_due_date + INTERVAL '1 week'
        WHEN recurrence_type = 'yearly' THEN 
          next_due_date + INTERVAL '1 year'
        ELSE next_due_date
      END
    WHERE id = recurring_cost.id;
    
    generated_count := generated_count + 1;
  END LOOP;
  
  RETURN generated_count;
END;
$$ LANGUAGE plpgsql;

-- Função para criar custo automaticamente quando abastecimento for aprovado
CREATE OR REPLACE FUNCTION fn_auto_create_fuel_cost()
RETURNS TRIGGER AS $$
BEGIN
  -- Só criar custo se for aprovado e ainda não tiver custo associado
  IF NEW.status = 'Aprovado' AND OLD.status = 'Pendente' AND NEW.cost_id IS NULL THEN
    INSERT INTO costs (
      tenant_id,
      category,
      description,
      amount,
      cost_date,
      status,
      vehicle_id,
      customer_id,
      customer_name,
      contract_id,
      guest_id,
      auto_generated
    ) VALUES (
      NEW.tenant_id,
      'Combustível',
      'Abastecimento - ' || NEW.fuel_station || ' - ' || NEW.fuel_amount || 'L',
      NEW.total_cost,
      NEW.recorded_at::date,
      'Aprovado',
      NEW.vehicle_id,
      COALESCE(
        (SELECT customer_id FROM contracts WHERE id = NEW.contract_id),
        (SELECT id FROM customers WHERE id = (SELECT customer_id FROM guest_users WHERE id = NEW.guest_id))
      ),
      COALESCE(
        (SELECT c.name FROM contracts ct JOIN customers c ON ct.customer_id = c.id WHERE ct.id = NEW.contract_id),
        (SELECT g.name FROM guest_users g WHERE g.id = NEW.guest_id)
      ),
      NEW.contract_id,
      NEW.guest_id,
      TRUE
    );
    
    -- Atualizar o fuel_record com o ID do custo criado
    UPDATE fuel_records 
    SET cost_id = (SELECT id FROM costs WHERE vehicle_id = NEW.vehicle_id AND amount = NEW.total_cost AND cost_date = NEW.recorded_at::date ORDER BY created_at DESC LIMIT 1)
    WHERE id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para criar custo automaticamente quando abastecimento for aprovado
CREATE TRIGGER trg_auto_create_fuel_cost
  AFTER UPDATE ON fuel_records
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_create_fuel_cost();

-- Função para atualizar histórico de veículos
CREATE OR REPLACE FUNCTION fn_update_vehicle_history()
RETURNS TRIGGER AS $$
BEGIN
  -- Inserir registro no histórico baseado na tabela de origem
  IF TG_TABLE_NAME = 'costs' THEN
    INSERT INTO vehicle_history (
      tenant_id,
      vehicle_id,
      event_type,
      event_date,
      description,
      amount,
      reference_id,
      reference_table,
      metadata
    ) VALUES (
      NEW.tenant_id,
      NEW.vehicle_id,
      'cost',
      NEW.cost_date,
      'Custo: ' || NEW.category || ' - ' || NEW.description,
      NEW.amount,
      NEW.id,
      'costs',
      jsonb_build_object('category', NEW.category, 'status', NEW.status)
    );
  ELSIF TG_TABLE_NAME = 'service_notes' THEN
    INSERT INTO vehicle_history (
      tenant_id,
      vehicle_id,
      event_type,
      event_date,
      description,
      amount,
      reference_id,
      reference_table,
      metadata
    ) VALUES (
      NEW.tenant_id,
      NEW.vehicle_id,
      'maintenance',
      NEW.created_at,
      'Manutenção: ' || NEW.description,
      NEW.cost,
      NEW.id,
      'service_notes',
      jsonb_build_object('status', NEW.status)
    );
  ELSIF TG_TABLE_NAME = 'fuel_records' THEN
    INSERT INTO vehicle_history (
      tenant_id,
      vehicle_id,
      event_type,
      event_date,
      description,
      amount,
      reference_id,
      reference_table,
      metadata
    ) VALUES (
      NEW.tenant_id,
      NEW.vehicle_id,
      'fuel',
      NEW.recorded_at,
      'Abastecimento: ' || NEW.fuel_amount || 'L - ' || COALESCE(NEW.fuel_station, 'Posto não informado'),
      NEW.total_cost,
      NEW.id,
      'fuel_records',
      jsonb_build_object('fuel_amount', NEW.fuel_amount, 'unit_price', NEW.unit_price, 'status', NEW.status)
    );
  ELSIF TG_TABLE_NAME = 'driver_inspections' THEN
    INSERT INTO vehicle_history (
      tenant_id,
      vehicle_id,
      event_type,
      event_date,
      description,
      amount,
      reference_id,
      reference_table,
      metadata
    ) VALUES (
      NEW.tenant_id,
      NEW.vehicle_id,
      'inspection',
      NEW.created_at,
      'Inspeção: ' || NEW.inspection_type || ' - ' || NEW.driver_name,
      NULL,
      NEW.id,
      'driver_inspections',
      jsonb_build_object('inspection_type', NEW.inspection_type, 'fuel_level', NEW.fuel_level, 'odometer_reading', NEW.odometer_reading)
    );
  ELSIF TG_TABLE_NAME = 'fines' THEN
    INSERT INTO vehicle_history (
      tenant_id,
      vehicle_id,
      event_type,
      event_date,
      description,
      amount,
      reference_id,
      reference_table,
      metadata
    ) VALUES (
      NEW.tenant_id,
      NEW.vehicle_id,
      'fine',
      COALESCE(NEW.fine_date, NEW.created_at),
      'Multa: ' || COALESCE(NEW.description, 'Multa registrada'),
      NEW.amount,
      NEW.id,
      'fines',
      jsonb_build_object('fine_date', NEW.fine_date, 'status', NEW.status)
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para atualizar histórico de veículos
CREATE TRIGGER trg_costs_history
  AFTER INSERT ON costs
  FOR EACH ROW
  WHEN (NEW.vehicle_id IS NOT NULL)
  EXECUTE FUNCTION fn_update_vehicle_history();

CREATE TRIGGER trg_service_notes_history
  AFTER INSERT ON service_notes
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_history();

CREATE TRIGGER trg_fuel_records_history
  AFTER INSERT ON fuel_records
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_history();

CREATE TRIGGER trg_driver_inspections_history
  AFTER INSERT ON driver_inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_history();

CREATE TRIGGER trg_fines_history
  AFTER INSERT ON fines
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_history();

-- Função para estatísticas de evolução de preços do departamento de compras
CREATE OR REPLACE FUNCTION fn_purchase_price_evolution(
  p_tenant_id UUID DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
  p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '6 months',
  p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  month_year TEXT,
  category TEXT,
  avg_price NUMERIC,
  total_amount NUMERIC,
  total_count INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    TO_CHAR(c.cost_date, 'YYYY-MM') as month_year,
    c.category,
    AVG(c.amount) as avg_price,
    SUM(c.amount) as total_amount,
    COUNT(*)::INTEGER as total_count
  FROM costs c
  WHERE c.tenant_id = p_tenant_id
    AND c.cost_date >= p_start_date
    AND c.cost_date <= p_end_date
    AND c.category IN ('Compra', 'Manutenção', 'Funilaria')
  GROUP BY TO_CHAR(c.cost_date, 'YYYY-MM'), c.category
  ORDER BY month_year DESC, category;
END;
$$ LANGUAGE plpgsql;

-- Função para atualizar updated_at
CREATE OR REPLACE FUNCTION fn_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para atualizar updated_at
CREATE TRIGGER trg_guest_users_updated_at
  BEFORE UPDATE ON guest_users
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_updated_at();

CREATE TRIGGER trg_fuel_records_updated_at
  BEFORE UPDATE ON fuel_records
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_updated_at();

CREATE TRIGGER trg_driver_inspections_updated_at
  BEFORE UPDATE ON driver_inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_updated_at();

-- Função para lidar com a criação de cobranças de cliente a partir de custos
CREATE OR REPLACE FUNCTION fn_create_customer_charge_from_cost()
RETURNS TRIGGER AS $$
BEGIN
  -- Só criar cobrança se o custo tiver customer_id definido e for de uma categoria cobravável
  IF NEW.customer_id IS NOT NULL AND 
     NEW.category IN ('Excesso Km', 'Combustível', 'Diária Extra', 'Avaria', 'Funilaria', 'Multa') AND
     NEW.status IN ('Pendente', 'Autorizado') THEN
    
    INSERT INTO public.customer_charges (
      tenant_id,
      customer_id,
      contract_id,
      vehicle_id,
      charge_type,
      description,
      amount,
      status,
      charge_date,
      due_date,
      generated_from,
      source_cost_ids
    ) VALUES (
      NEW.tenant_id,
      NEW.customer_id,
      NEW.contract_id,
      NEW.vehicle_id,
      CASE
        WHEN NEW.category = 'Excesso Km' THEN 'Excesso KM'
        WHEN NEW.category = 'Combustível' THEN 'Combustível'
        WHEN NEW.category = 'Diária Extra' THEN 'Diária Extra'
        ELSE 'Dano'
      END,
      NEW.description,
      NEW.amount,
      'Pendente',
      NEW.cost_date,
      NEW.cost_date + INTERVAL '7 days',
      'Automatic',
      ARRAY[NEW.id]
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para criar cobrança de cliente automaticamente quando custo for inserido
CREATE TRIGGER trg_create_customer_charge_from_cost
  AFTER INSERT ON costs
  FOR EACH ROW
  EXECUTE FUNCTION fn_create_customer_charge_from_cost();

-- Views para facilitar consultas
CREATE OR REPLACE VIEW vw_vehicle_complete_history AS
SELECT 
  vh.*,
  v.plate,
  v.model,
  v.year
FROM vehicle_history vh
JOIN vehicles v ON vh.vehicle_id = v.id
ORDER BY vh.event_date DESC;

CREATE OR REPLACE VIEW vw_fuel_records_detailed AS
SELECT 
  fr.*,
  v.plate,
  v.model,
  CASE 
    WHEN fr.guest_id IS NOT NULL THEN g.name
    WHEN fr.driver_employee_id IS NOT NULL THEN e.name
    ELSE fr.driver_name
  END as driver_full_name,
  c.contract_number,
  cust.name as customer_name
FROM fuel_records fr
JOIN vehicles v ON fr.vehicle_id = v.id
LEFT JOIN guest_users g ON fr.guest_id = g.id
LEFT JOIN employees e ON fr.driver_employee_id = e.id
LEFT JOIN contracts c ON fr.contract_id = c.id
LEFT JOIN customers cust ON c.customer_id = cust.id
ORDER BY fr.recorded_at DESC;

CREATE OR REPLACE VIEW vw_driver_inspections_detailed AS
SELECT 
  di.*,
  v.plate,
  v.model,
  CASE 
    WHEN di.guest_id IS NOT NULL THEN g.name
    WHEN di.driver_employee_id IS NOT NULL THEN e.name
    ELSE di.driver_name
  END as driver_full_name,
  c.contract_number,
  cust.name as customer_name
FROM driver_inspections di
JOIN vehicles v ON di.vehicle_id = v.id
LEFT JOIN guest_users g ON di.guest_id = g.id
LEFT JOIN employees e ON di.driver_employee_id = e.id
LEFT JOIN contracts c ON di.contract_id = c.id
LEFT JOIN customers cust ON c.customer_id = cust.id
ORDER BY di.created_at DESC; 