/*
  # Fix inspection and cost system

  1. New Columns
    - Add contract_id, customer_id, mileage, and fuel_level to inspections table
    - Add department, customer_id, customer_name, and contract_id to costs table
    - Add km_limit, price_per_excess_km, and price_per_liter to contracts table
  
  2. Functions
    - Create function to handle rental checkout process
    - Update damage cost creation to include customer and contract information
  
  3. Views
    - Update costs detailed view to include new fields
*/

-- 1. Add new columns to inspections table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'contract_id'
  ) THEN
    ALTER TABLE inspections ADD COLUMN contract_id UUID REFERENCES contracts(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'customer_id'
  ) THEN
    ALTER TABLE inspections ADD COLUMN customer_id UUID REFERENCES customers(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'mileage'
  ) THEN
    ALTER TABLE inspections ADD COLUMN mileage INTEGER;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'fuel_level'
  ) THEN
    ALTER TABLE inspections ADD COLUMN fuel_level NUMERIC(3,2) CHECK (fuel_level >= 0 AND fuel_level <= 1);
  END IF;
END $$;

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_inspections_contract ON inspections(contract_id);
CREATE INDEX IF NOT EXISTS idx_inspections_customer ON inspections(customer_id);

-- 2. Add new columns to costs table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'costs' AND column_name = 'department'
  ) THEN
    ALTER TABLE costs ADD COLUMN department TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'costs' AND column_name = 'customer_id'
  ) THEN
    ALTER TABLE costs ADD COLUMN customer_id UUID REFERENCES customers(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'costs' AND column_name = 'customer_name'
  ) THEN
    ALTER TABLE costs ADD COLUMN customer_name TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'costs' AND column_name = 'contract_id'
  ) THEN
    ALTER TABLE costs ADD COLUMN contract_id UUID REFERENCES contracts(id);
  END IF;
END $$;

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_costs_department ON costs(department);
CREATE INDEX IF NOT EXISTS idx_costs_customer ON costs(customer_id);
CREATE INDEX IF NOT EXISTS idx_costs_contract ON costs(contract_id);

-- 3. Add columns to contracts table if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'contracts' AND column_name = 'km_limit'
  ) THEN
    ALTER TABLE contracts ADD COLUMN km_limit INTEGER;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'contracts' AND column_name = 'price_per_excess_km'
  ) THEN
    ALTER TABLE contracts ADD COLUMN price_per_excess_km NUMERIC(12,2);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'contracts' AND column_name = 'price_per_liter'
  ) THEN
    ALTER TABLE contracts ADD COLUMN price_per_liter NUMERIC(12,2);
  END IF;
END $$;

-- 4. Create function to handle rental checkout process
CREATE OR REPLACE FUNCTION fn_handle_rental_checkout()
RETURNS TRIGGER AS $$
DECLARE
  v_contract contracts%ROWTYPE;
  v_customer_id UUID;
  v_customer_name TEXT;
  v_checkout_inspection inspections%ROWTYPE;
  v_start_km INTEGER := 0;
  v_end_km INTEGER := 0;
  v_excess_km INTEGER := 0;
  v_excess_km_charge NUMERIC := 0;
  v_contract_days INTEGER;
  v_actual_days INTEGER;
  v_extra_days INTEGER := 0;
  v_extra_day_charge NUMERIC := 0;
  v_fuel_level_start NUMERIC := 0;
  v_fuel_level_end NUMERIC := 0;
  v_fuel_difference NUMERIC := 0;
  v_fuel_charge NUMERIC := 0;
  v_damage_charge NUMERIC := 0;
BEGIN
  -- Only trigger on CheckIn with contract_id
  IF NEW.inspection_type <> 'CheckIn' OR NEW.contract_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Load contract and customer data
  SELECT * INTO v_contract FROM contracts WHERE id = NEW.contract_id;
  v_customer_id := v_contract.customer_id;
  SELECT name INTO v_customer_name FROM customers WHERE id = v_customer_id;

  -- Set customer_id on inspection
  UPDATE inspections SET customer_id = v_customer_id WHERE id = NEW.id;

  -- Find the corresponding CheckOut inspection
  SELECT * INTO v_checkout_inspection 
  FROM inspections 
  WHERE contract_id = NEW.contract_id 
    AND inspection_type = 'CheckOut' 
    AND vehicle_id = NEW.vehicle_id
  ORDER BY inspected_at DESC 
  LIMIT 1;

  -- Calculate excess kilometers if mileage is recorded
  IF v_checkout_inspection.id IS NOT NULL AND NEW.mileage IS NOT NULL AND v_checkout_inspection.mileage IS NOT NULL THEN
    v_start_km := v_checkout_inspection.mileage;
    v_end_km := NEW.mileage;
    
    -- Calculate excess km if contract has km_limit
    IF v_contract.km_limit IS NOT NULL AND v_contract.price_per_excess_km IS NOT NULL AND v_contract.km_limit > 0 THEN
      v_excess_km := GREATEST(v_end_km - v_start_km - v_contract.km_limit, 0);
      v_excess_km_charge := v_excess_km * v_contract.price_per_excess_km;
    END IF;
  END IF;

  -- Calculate extra days
  v_contract_days := (v_contract.end_date - v_contract.start_date) + 1;
  v_actual_days := (NEW.inspected_at::date - v_contract.start_date) + 1;
  
  IF v_actual_days > v_contract_days THEN
    v_extra_days := v_actual_days - v_contract_days;
    v_extra_day_charge := v_extra_days * v_contract.daily_rate;
  END IF;

  -- Calculate fuel charge if fuel levels are recorded
  IF v_checkout_inspection.id IS NOT NULL AND 
     v_checkout_inspection.fuel_level IS NOT NULL AND 
     NEW.fuel_level IS NOT NULL AND
     v_contract.price_per_liter IS NOT NULL THEN
    
    v_fuel_level_start := v_checkout_inspection.fuel_level;
    v_fuel_level_end := NEW.fuel_level;
    
    -- Calculate fuel difference (negative means customer used fuel)
    v_fuel_difference := v_fuel_level_end - v_fuel_level_start;
    
    -- If fuel level is lower than when checked out
    IF v_fuel_difference < 0 THEN
      -- Convert to positive and calculate charge
      -- Assuming a standard 60-liter tank for simplicity
      v_fuel_charge := ABS(v_fuel_difference) * 60 * v_contract.price_per_liter;
    END IF;
  END IF;

  -- Calculate damage charge from inspection items
  SELECT COALESCE(SUM(c.amount), 0) INTO v_damage_charge
  FROM inspection_items ii
  JOIN costs c ON c.source_reference_id = ii.id AND c.source_reference_type = 'inspection_item'
  WHERE ii.inspection_id = NEW.id;

  -- Insert costs for each charge type if amount > 0
  -- Excess Kilometers
  IF v_excess_km_charge > 0 THEN
    INSERT INTO costs(
      tenant_id, 
      department, 
      customer_id, 
      customer_name, 
      contract_id,
      category, 
      vehicle_id, 
      description, 
      amount, 
      cost_date, 
      status, 
      observations, 
      origin,
      created_at,
      updated_at
    ) VALUES (
      NEW.tenant_id, 
      'Cobrança', 
      v_customer_id, 
      v_customer_name, 
      NEW.contract_id,
      'Excesso Km', 
      NEW.vehicle_id,
      CONCAT('Excesso de ', v_excess_km, ' km — Cliente: ', v_customer_name),
      v_excess_km_charge, 
      NEW.inspected_at::date, 
      'Pendente',
      CONCAT('Contrato ', NEW.contract_id, ' - Km inicial: ', v_start_km, ', Km final: ', v_end_km),
      'Sistema',
      now(),
      now()
    );
  END IF;

  -- Extra Days
  IF v_extra_day_charge > 0 THEN
    INSERT INTO costs(
      tenant_id, 
      department, 
      customer_id, 
      customer_name, 
      contract_id,
      category, 
      vehicle_id, 
      description, 
      amount, 
      cost_date, 
      status, 
      observations, 
      origin,
      created_at,
      updated_at
    ) VALUES (
      NEW.tenant_id, 
      'Cobrança', 
      v_customer_id, 
      v_customer_name, 
      NEW.contract_id,
      'Diária Extra', 
      NEW.vehicle_id,
      CONCAT('Atraso de ', v_extra_days, ' dias — Cliente: ', v_customer_name),
      v_extra_day_charge, 
      NEW.inspected_at::date, 
      'Pendente',
      CONCAT('Contrato ', NEW.contract_id, ' - Data prevista: ', v_contract.end_date, ', Data efetiva: ', NEW.inspected_at::date),
      'Sistema',
      now(),
      now()
    );
  END IF;

  -- Fuel Charge
  IF v_fuel_charge > 0 THEN
    INSERT INTO costs(
      tenant_id, 
      department, 
      customer_id, 
      customer_name, 
      contract_id,
      category, 
      vehicle_id, 
      description, 
      amount, 
      cost_date, 
      status, 
      observations, 
      origin,
      created_at,
      updated_at
    ) VALUES (
      NEW.tenant_id, 
      'Cobrança', 
      v_customer_id, 
      v_customer_name, 
      NEW.contract_id,
      'Combustível', 
      NEW.vehicle_id,
      CONCAT('Reabastecer ', ROUND(ABS(v_fuel_difference) * 100), '% — Cliente: ', v_customer_name),
      v_fuel_charge, 
      NEW.inspected_at::date, 
      'Pendente',
      CONCAT('Contrato ', NEW.contract_id, ' - Nível inicial: ', ROUND(v_fuel_level_start * 100), '%, Nível final: ', ROUND(v_fuel_level_end * 100), '%'),
      'Sistema',
      now(),
      now()
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Create trigger for rental checkout
DROP TRIGGER IF EXISTS trg_rental_checkout ON inspections;
CREATE TRIGGER trg_rental_checkout
  AFTER INSERT ON inspections
  FOR EACH ROW
  WHEN (NEW.inspection_type = 'CheckIn' AND NEW.contract_id IS NOT NULL)
  EXECUTE FUNCTION fn_handle_rental_checkout();

-- 6. Update damage cost creation to include customer and contract information
CREATE OR REPLACE FUNCTION fn_auto_create_damage_cost()
RETURNS TRIGGER AS $$
DECLARE
  inspection_record RECORD;
  vehicle_record RECORD;
  contract_record RECORD;
  customer_record RECORD;
  cost_description TEXT;
  inspector_employee_id UUID;
  new_cost_id UUID;
  inspection_type_label TEXT;
BEGIN
  -- Get inspection details
  SELECT * INTO inspection_record
  FROM inspections
  WHERE id = NEW.inspection_id;
  
  -- Get vehicle details
  SELECT * INTO vehicle_record
  FROM vehicles
  WHERE id = inspection_record.vehicle_id;
  
  -- Get contract and customer details if available
  IF inspection_record.contract_id IS NOT NULL THEN
    SELECT * INTO contract_record
    FROM contracts
    WHERE id = inspection_record.contract_id;
    
    SELECT * INTO customer_record
    FROM customers
    WHERE id = contract_record.customer_id;
  END IF;
  
  -- Create costs for both CheckIn and CheckOut when damages require repair
  IF NEW.requires_repair = true THEN
    
    -- Try to find employee by name (inspector)
    SELECT id INTO inspector_employee_id
    FROM employees 
    WHERE LOWER(name) = LOWER(inspection_record.inspected_by)
      AND tenant_id = inspection_record.tenant_id
      AND active = true
    LIMIT 1;
    
    -- Set category and labels based on inspection type
    IF inspection_record.inspection_type = 'CheckIn' THEN
      inspection_type_label := 'Check-In (Entrada)';
    ELSE
      inspection_type_label := 'Check-Out (Saída)';
    END IF;
    
    -- Create description for the cost
    cost_description := CONCAT(
      'Dano detectado em ', inspection_type_label, ' - ', NEW.location, ': ', NEW.damage_type,
      CASE WHEN customer_record.name IS NOT NULL THEN ' — Cliente: ' || customer_record.name ELSE '' END
    );
    
    -- Insert cost record with origin tracking and customer/contract info if available
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
      source_reference_type,
      department,
      customer_id,
      customer_name,
      contract_id,
      created_at,
      updated_at
    ) VALUES (
      inspection_record.tenant_id,
      'Funilaria',
      inspection_record.vehicle_id,
      cost_description,
      0.00, -- Amount to be defined later
      CURRENT_DATE,
      'Pendente',
      format('PATIO-%s-%s-ITEM-%s', inspection_record.inspection_type, inspection_record.id, NEW.id),
      format(
        'Custo gerado automaticamente pelo controle de pátio (%s). ' ||
        'Veículo: %s - %s. Inspetor: %s. Data da inspeção: %s. ' ||
        'Severidade: %s. Local: %s. Tipo: %s. ' ||
        'Descrição: %s. ' ||
        CASE WHEN contract_record.id IS NOT NULL THEN 'Contrato: ' || contract_record.id || '. ' ELSE '' END ||
        'Valor a ser definido após orçamento.',
        inspection_type_label,
        vehicle_record.plate,
        vehicle_record.model,
        inspection_record.inspected_by,
        inspection_record.inspected_at::date,
        NEW.severity,
        NEW.location,
        NEW.damage_type,
        NEW.description
      ),
      'Patio',
      inspector_employee_id,
      NEW.id,
      'inspection_item',
      CASE WHEN inspection_record.contract_id IS NOT NULL THEN 'Cobrança' ELSE NULL END,
      CASE WHEN inspection_record.contract_id IS NOT NULL THEN contract_record.customer_id ELSE NULL END,
      CASE WHEN inspection_record.contract_id IS NOT NULL THEN customer_record.name ELSE NULL END,
      inspection_record.contract_id,
      NOW(),
      NOW()
    ) RETURNING id INTO new_cost_id;
    
    -- Create damage notification record
    INSERT INTO damage_notifications (
      tenant_id,
      cost_id,
      inspection_item_id,
      notification_data,
      status,
      created_at
    ) VALUES (
      inspection_record.tenant_id,
      new_cost_id,
      NEW.id,
      jsonb_build_object(
        'cost_id', new_cost_id,
        'item_id', NEW.id,
        'inspection_id', NEW.inspection_id,
        'vehicle_plate', vehicle_record.plate,
        'vehicle_model', vehicle_record.model,
        'damage_location', NEW.location,
        'damage_type', NEW.damage_type,
        'severity', NEW.severity,
        'description', NEW.description,
        'requires_repair', NEW.requires_repair,
        'timestamp', NOW(),
        'customer_id', CASE WHEN inspection_record.contract_id IS NOT NULL THEN contract_record.customer_id ELSE NULL END,
        'customer_name', CASE WHEN inspection_record.contract_id IS NOT NULL THEN customer_record.name ELSE NULL END,
        'contract_id', inspection_record.contract_id
      ),
      'pending',
      NOW()
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Drop existing policy if it exists
DROP POLICY IF EXISTS "Allow department-based access to costs" ON costs;

-- Create new policy for department-based access
CREATE POLICY "Allow department-based access to costs"
  ON costs
  FOR ALL
  TO authenticated
  USING (
    tenant_id = '00000000-0000-0000-0000-000000000001'::uuid AND
    (
      department IS NULL OR
      EXISTS (
        SELECT 1 FROM employees e
        WHERE e.id = auth.uid() AND
        (
          e.role IN ('Admin', 'Manager') OR
          (e.permissions->>'finance')::boolean = true OR
          (e.permissions->>department)::boolean = true
        )
      )
    )
  )
  WITH CHECK (
    tenant_id = '00000000-0000-0000-0000-000000000001'::uuid AND
    (
      department IS NULL OR
      EXISTS (
        SELECT 1 FROM employees e
        WHERE e.id = auth.uid() AND
        (
          e.role IN ('Admin', 'Manager') OR
          (e.permissions->>'finance')::boolean = true OR
          (e.permissions->>department)::boolean = true
        )
      )
    )
  );

-- 8. Update view for costs detailed to include customer and contract information
DROP VIEW IF EXISTS vw_costs_detailed;
CREATE VIEW vw_costs_detailed AS
SELECT 
  c.id,
  c.tenant_id,
  c.category,
  c.vehicle_id,
  v.plate as vehicle_plate,
  v.model as vehicle_model,
  c.description,
  c.amount,
  c.cost_date,
  c.status,
  c.document_ref,
  c.observations,
  c.origin,
  c.source_reference_type,
  c.source_reference_id,
  c.department,
  c.customer_id,
  c.customer_name,
  c.contract_id,
  COALESCE(e.name, 'Sistema') as created_by_name,
  COALESCE(e.role, 'Sistema') as created_by_role,
  e.employee_code as created_by_code,
  CASE 
    WHEN c.origin = 'Patio' THEN 
      CASE 
        WHEN c.document_ref LIKE '%CheckIn%' THEN 'Controle de Pátio (Check-In)'
        WHEN c.document_ref LIKE '%CheckOut%' THEN 'Controle de Pátio (Check-Out)'
        ELSE 'Controle de Pátio'
      END
    WHEN c.origin = 'Manutencao' THEN 
      CASE 
        WHEN c.document_ref LIKE '%PART%' THEN 'Manutenção (Peças)'
        WHEN c.document_ref LIKE '%OS%' THEN 'Manutenção (Ordem de Serviço)'
        ELSE 'Manutenção'
      END
    WHEN c.origin = 'Manual' THEN 'Lançamento Manual'
    WHEN c.origin = 'Sistema' THEN 'Sistema'
    WHEN c.origin = 'Compras' THEN 'Compras'
    ELSE c.origin
  END as origin_description,
  CASE 
    WHEN c.amount = 0 AND c.status = 'Pendente' THEN true
    ELSE false
  END as is_amount_to_define,
  c.created_at,
  c.updated_at
FROM costs c
LEFT JOIN vehicles v ON v.id = c.vehicle_id
LEFT JOIN employees e ON e.id = c.created_by_employee_id
ORDER BY c.created_at DESC;

-- 9. Create function to get pending damage notifications
CREATE OR REPLACE FUNCTION fn_get_pending_damage_notifications()
RETURNS SETOF damage_notifications AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM damage_notifications
  WHERE status = 'pending'
  ORDER BY created_at ASC
  LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- 10. Create functions to mark notifications as sent or failed
CREATE OR REPLACE FUNCTION fn_mark_notification_sent(p_notification_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE damage_notifications
  SET status = 'sent', sent_at = NOW()
  WHERE id = p_notification_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_mark_notification_failed(p_notification_id UUID, p_error_message TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE damage_notifications
  SET status = 'failed', error_message = p_error_message
  WHERE id = p_notification_id;
END;
$$ LANGUAGE plpgsql;