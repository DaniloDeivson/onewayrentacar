-- Implement Checklist Fixes - Complete System Integration
-- This migration implements all the fixes requested in the checklist

-- ============================================================================
-- 1. FIX KM ADICIONAL - Ensure excess KM charges are generated after inspection
-- ============================================================================

-- Update the inspection trigger to properly calculate and create excess KM charges
CREATE OR REPLACE FUNCTION fn_inspection_checkin_charges()
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
  v_contract_days INTEGER := 0;
  v_actual_days INTEGER := 0;
  v_extra_days INTEGER := 0;
  v_extra_day_charge NUMERIC := 0;
  v_fuel_level_start NUMERIC := 0;
  v_fuel_level_end NUMERIC := 0;
  v_fuel_difference NUMERIC := 0;
  v_fuel_charge NUMERIC := 0;
BEGIN
  -- Only process CheckIn inspections with contract_id
  IF NEW.inspection_type != 'CheckIn' OR NEW.contract_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get contract information
  SELECT * INTO v_contract FROM contracts WHERE id = NEW.contract_id;
  v_customer_id := v_contract.customer_id;
  SELECT name INTO v_customer_name FROM customers WHERE id = v_customer_id;

  -- Find corresponding CheckOut inspection
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
  v_extra_days := GREATEST(v_actual_days - v_contract_days, 0);
  v_extra_day_charge := v_extra_days * v_contract.daily_rate;

  -- Calculate fuel difference
  IF v_checkout_inspection.fuel_level IS NOT NULL AND NEW.fuel_level IS NOT NULL THEN
    v_fuel_level_start := v_checkout_inspection.fuel_level;
    v_fuel_level_end := NEW.fuel_level;
    v_fuel_difference := v_fuel_level_start - v_fuel_level_end;
    
    -- Only charge if fuel level decreased and contract has fuel price
    IF v_fuel_difference > 0 AND v_contract.price_per_liter IS NOT NULL THEN
      -- Estimate fuel capacity (50L as default) and calculate cost
      v_fuel_charge := (v_fuel_difference * 50) * v_contract.price_per_liter;
    END IF;
  END IF;

  -- Excess KM Charge
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

-- Recreate the trigger
DROP TRIGGER IF EXISTS tr_inspection_checkin_charges ON inspections;
CREATE TRIGGER tr_inspection_checkin_charges
  AFTER INSERT ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_inspection_checkin_charges();

-- ============================================================================
-- 2. FIX FUEL RECORDS - Ensure fuel records generate costs and charges
-- ============================================================================

-- Update fuel records trigger to create costs and charges
CREATE OR REPLACE FUNCTION fn_create_fuel_cost_from_fuel_records()
RETURNS TRIGGER AS $$
DECLARE
  v_contract_id UUID;
  v_customer_id UUID;
  v_customer_name TEXT;
  v_vehicle_plate TEXT;
  v_cost_id UUID;
BEGIN
  -- Only process if total_cost is provided
  IF NEW.total_cost IS NULL OR NEW.total_cost <= 0 THEN
    RETURN NEW;
  END IF;

  -- Get vehicle plate
  SELECT plate INTO v_vehicle_plate FROM vehicles WHERE id = NEW.vehicle_id;

  -- Get contract information if available
  IF NEW.contract_id IS NOT NULL THEN
    v_contract_id := NEW.contract_id;
    SELECT customer_id, c.name 
    INTO v_customer_id, v_customer_name
    FROM contracts ct
    JOIN customers c ON c.id = ct.customer_id
    WHERE ct.id = NEW.contract_id;
  END IF;

  -- Create cost entry for the fuel record
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
    CASE WHEN v_customer_id IS NOT NULL THEN 'Cobrança' ELSE NULL END,
    v_customer_id,
    v_customer_name,
    v_contract_id,
    'Combustível',
    NEW.vehicle_id,
    CONCAT('Abastecimento: ', COALESCE(NEW.fuel_station, 'Posto não informado'), ' - ', NEW.fuel_amount, 'L'),
    NEW.total_cost,
    NEW.recorded_at::date,
    'Pendente',
    CONCAT(
      'Abastecimento registrado por: ', NEW.driver_name,
      ' | Posto: ', COALESCE(NEW.fuel_station, 'Não informado'),
      ' | Litros: ', NEW.fuel_amount,
      ' | Preço/L: ', NEW.unit_price,
      ' | Veículo: ', COALESCE(v_vehicle_plate, 'N/A'),
      CASE WHEN v_customer_name IS NOT NULL THEN ' | Cliente: ' || v_customer_name ELSE '' END
    ),
    'Sistema',
    now(),
    now()
  ) RETURNING id INTO v_cost_id;
  
  -- Update the fuel record with the cost_id
  UPDATE fuel_records 
  SET cost_id = v_cost_id
  WHERE id = NEW.id;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error creating fuel cost from fuel record: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
DROP TRIGGER IF EXISTS tr_create_fuel_cost_from_fuel_records ON fuel_records;
CREATE TRIGGER tr_create_fuel_cost_from_fuel_records
  AFTER INSERT ON fuel_records
  FOR EACH ROW
  EXECUTE FUNCTION fn_create_fuel_cost_from_fuel_records();

-- ============================================================================
-- 3. FIX FINES - Ensure fines generate costs and charges with driver association
-- ============================================================================

-- Update fines trigger to create costs and charges
CREATE OR REPLACE FUNCTION fn_fine_postprocess()
RETURNS TRIGGER AS $$
DECLARE
  v_driver_name text;
  v_vehicle_plate text;
  v_employee_name text;
  v_customer_name text;
  v_contract_id UUID;
  v_cost_id UUID;
BEGIN
  -- Get driver name if available
  SELECT name INTO v_driver_name
  FROM employees
  WHERE id = NEW.driver_id;
  
  -- Get vehicle plate
  SELECT plate INTO v_vehicle_plate
  FROM vehicles
  WHERE id = NEW.vehicle_id;
  
  -- Get employee name
  SELECT name INTO v_employee_name
  FROM employees
  WHERE id = NEW.employee_id;
  
  -- Get customer name if not provided
  IF NEW.customer_id IS NOT NULL AND (NEW.customer_name IS NULL OR NEW.customer_name = '') THEN
    SELECT name INTO v_customer_name
    FROM customers
    WHERE id = NEW.customer_id;
  ELSE
    v_customer_name := NEW.customer_name;
  END IF;

  -- Get contract information if available
  IF NEW.contract_id IS NOT NULL THEN
    v_contract_id := NEW.contract_id;
  END IF;
  
  -- Create cost entry for the fine
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
    document_ref,
    observations,
    origin,
    created_by_employee_id,
    source_reference_id,
    source_reference_type,
    created_at,
    updated_at
  ) VALUES (
    NEW.tenant_id,
    CASE WHEN NEW.customer_id IS NOT NULL THEN 'Cobrança' ELSE NULL END,
    NEW.customer_id,
    v_customer_name,
    v_contract_id,
    'Multa',
    NEW.vehicle_id,
    CONCAT('Multa ', COALESCE(NEW.fine_number, 'SEM-NUMERO'), ' - ', NEW.infraction_type, 
           CASE WHEN v_customer_name IS NOT NULL THEN ' — Cliente: ' || v_customer_name ELSE '' END),
    NEW.amount,
    NEW.infraction_date,
    'Pendente',
    NEW.document_ref,
    CONCAT(
      'Multa registrada por: ', COALESCE(v_employee_name, 'Sistema'), 
      ' | Motorista: ', COALESCE(v_driver_name, 'Não informado'), 
      ' | Veículo: ', COALESCE(v_vehicle_plate, 'N/A'),
      ' | Vencimento: ', COALESCE(NEW.due_date::text, 'N/A'),
      CASE WHEN NEW.observations IS NOT NULL THEN ' | Obs: ' || NEW.observations ELSE '' END
    ),
    'Sistema',
    NEW.employee_id,
    NEW.id,
    'fine',
    now(),
    now()
  ) RETURNING id INTO v_cost_id;
  
  -- Update the fine with the cost_id
  UPDATE fines 
  SET cost_id = v_cost_id
  WHERE id = NEW.id;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Erro ao criar custo automático para multa %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
DROP TRIGGER IF EXISTS tr_fines_postprocess ON fines;
CREATE TRIGGER tr_fines_postprocess
  AFTER INSERT ON fines
  FOR EACH ROW
  EXECUTE FUNCTION fn_fine_postprocess();

-- ============================================================================
-- 4. FIX RECURRING COSTS - Ensure recurring costs generate monthly entries
-- ============================================================================

-- Update recurring costs function to generate monthly costs
CREATE OR REPLACE FUNCTION fn_generate_recurring_costs()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    recurring_cost RECORD;
    new_cost_id UUID;
    next_date DATE;
    generated_count INTEGER := 0;
BEGIN
    -- Find all recurring costs that need to be generated
    FOR recurring_cost IN 
        SELECT 
            c.*,
            CASE 
                WHEN c.recurrence_type = 'monthly' THEN
                    COALESCE(c.next_due_date, c.cost_date) + INTERVAL '1 month'
                WHEN c.recurrence_type = 'weekly' THEN
                    COALESCE(c.next_due_date, c.cost_date) + INTERVAL '1 week'
                WHEN c.recurrence_type = 'yearly' THEN
                    COALESCE(c.next_due_date, c.cost_date) + INTERVAL '1 year'
                ELSE
                    COALESCE(c.next_due_date, c.cost_date) + INTERVAL '1 month'
            END as calculated_next_date
        FROM costs c
        WHERE c.is_recurring = true
        AND c.parent_recurring_cost_id IS NULL
        AND (
            c.next_due_date IS NULL 
            OR c.next_due_date <= CURRENT_DATE
        )
    LOOP
        -- Calculate next date based on recurrence type
        next_date := recurring_cost.calculated_next_date;
        
        -- Create new recurring cost
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
            supplier_id,
            supplier_name,
            created_by_name,
            is_recurring,
            recurrence_type,
            recurrence_day,
            next_due_date,
            parent_recurring_cost_id,
            auto_generated,
            guest_id
        ) VALUES (
            recurring_cost.tenant_id,
            'Custos Fixos',
            recurring_cost.vehicle_id,
            CONCAT(recurring_cost.description, ' (Gerado automaticamente)'),
            recurring_cost.amount,
            next_date,
            'Pendente',
            recurring_cost.document_ref,
            CONCAT('Custo recorrente gerado automaticamente - Origem: ', recurring_cost.origin),
            'Financeiro',
            recurring_cost.created_by_employee_id,
            recurring_cost.source_reference_id,
            recurring_cost.source_reference_type,
            recurring_cost.department,
            recurring_cost.customer_id,
            recurring_cost.customer_name,
            recurring_cost.contract_id,
            recurring_cost.supplier_id,
            recurring_cost.supplier_name,
            recurring_cost.created_by_name,
            false,
            recurring_cost.recurrence_type,
            recurring_cost.recurrence_day,
            next_date + CASE 
                WHEN recurring_cost.recurrence_type = 'monthly' THEN INTERVAL '1 month'
                WHEN recurring_cost.recurrence_type = 'weekly' THEN INTERVAL '1 week'
                WHEN recurring_cost.recurrence_type = 'yearly' THEN INTERVAL '1 year'
                ELSE INTERVAL '1 month'
            END,
            recurring_cost.id,
            true,
            recurring_cost.guest_id
        ) RETURNING id INTO new_cost_id;
        
        -- Update the next due date of the parent cost
        UPDATE costs 
        SET next_due_date = next_date + CASE 
            WHEN recurring_cost.recurrence_type = 'monthly' THEN INTERVAL '1 month'
            WHEN recurring_cost.recurrence_type = 'weekly' THEN INTERVAL '1 week'
            WHEN recurring_cost.recurrence_type = 'yearly' THEN INTERVAL '1 year'
            ELSE INTERVAL '1 month'
        END
        WHERE id = recurring_cost.id;
        
        generated_count := generated_count + 1;
    END LOOP;
    
    RETURN generated_count;
END;
$$;

-- ============================================================================
-- 5. FIX PAYROLL - Create costs when salary is marked as paid
-- ============================================================================

-- Create function to handle payroll cost generation
CREATE OR REPLACE FUNCTION fn_create_payroll_cost()
RETURNS TRIGGER AS $$
DECLARE
  v_employee_name TEXT;
BEGIN
  -- Only process when status changes to 'Pago'
  IF NEW.status = 'Pago' AND OLD.status != 'Pago' THEN
    -- Get employee name
    SELECT name INTO v_employee_name FROM employees WHERE id = NEW.employee_id;
    
    -- Create cost entry for payroll
    INSERT INTO costs(
      tenant_id,
      category,
      description,
      amount,
      cost_date,
      status,
      observations,
      origin,
      created_by_employee_id,
      source_reference_id,
      source_reference_type,
      created_at,
      updated_at
    ) VALUES (
      NEW.tenant_id,
      'Folha de Pagamento',
      CONCAT('Salário - ', v_employee_name),
      NEW.salary_amount,
      NEW.payment_date,
      'Pago',
      CONCAT('Pagamento de salário para ', v_employee_name, ' - Referência: ', NEW.payment_reference),
      'Financeiro > Folha',
      NEW.paid_by_employee_id,
      NEW.id,
      'payroll',
      now(),
      now()
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for payroll (if payroll table exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payroll') THEN
    DROP TRIGGER IF EXISTS tr_create_payroll_cost ON payroll;
    CREATE TRIGGER tr_create_payroll_cost
      AFTER UPDATE ON payroll
      FOR EACH ROW
      EXECUTE FUNCTION fn_create_payroll_cost();
  END IF;
END $$;

-- ============================================================================
-- 6. FIX RECURRING ACCOUNTS - Create costs when marked as paid
-- ============================================================================

-- Create function to handle recurring accounts cost generation
CREATE OR REPLACE FUNCTION fn_create_recurring_account_cost()
RETURNS TRIGGER AS $$
DECLARE
  v_account_name TEXT;
BEGIN
  -- Only process when status changes to 'Pago'
  IF NEW.status = 'Pago' AND OLD.status != 'Pago' THEN
    -- Get account name
    v_account_name := COALESCE(NEW.account_name, 'Conta Recorrente');
    
    -- Create cost entry for recurring account
    INSERT INTO costs(
      tenant_id,
      category,
      description,
      amount,
      cost_date,
      status,
      observations,
      origin,
      created_by_employee_id,
      source_reference_id,
      source_reference_type,
      created_at,
      updated_at
    ) VALUES (
      NEW.tenant_id,
      'Contas Recorrentes',
      CONCAT('Conta Recorrente - ', v_account_name),
      NEW.amount,
      NEW.payment_date,
      'Pago',
      CONCAT('Pagamento de conta recorrente: ', v_account_name, ' - Referência: ', NEW.payment_reference),
      'Financeiro',
      NEW.paid_by_employee_id,
      NEW.id,
      'recurring_account',
      now(),
      now()
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for recurring accounts (if table exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'recurring_accounts') THEN
    DROP TRIGGER IF EXISTS tr_create_recurring_account_cost ON recurring_accounts;
    CREATE TRIGGER tr_create_recurring_account_cost
      AFTER UPDATE ON recurring_accounts
      FOR EACH ROW
      EXECUTE FUNCTION fn_create_recurring_account_cost();
  END IF;
END $$;

-- ============================================================================
-- 7. FIX COSTS FILTER FOR DRIVERS - Show only costs related to driver's vehicles
-- ============================================================================

-- Update RLS policy for costs to filter by driver's vehicles
DROP POLICY IF EXISTS costs_access ON costs;

CREATE POLICY costs_access ON costs
    FOR ALL USING (
        -- Admin can see everything
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND role = 'Admin'
        ) OR
        -- Manager can see everything
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND role = 'Manager'
        ) OR
        -- Driver can only see costs of their assigned vehicles
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = auth.uid() 
            AND vehicle_id = costs.vehicle_id 
            AND active = true
        ) OR
        -- Other roles can see based on their permissions
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND (
                permissions->>'costs' = 'true' OR
                role IN ('Sales', 'Finance')
            )
        )
    );

-- ============================================================================
-- 8. ADD REQUIRED FIELDS TO FUEL RECORDS
-- ============================================================================

-- Add required fields to fuel_records if they don't exist
DO $$
BEGIN
  -- Add invoice_number field if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'invoice_number'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN invoice_number TEXT;
  END IF;
  
  -- Add current_km field if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'current_km'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN current_km INTEGER;
  END IF;
  
  -- Add invoice_photo_url field if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'invoice_photo_url'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN invoice_photo_url TEXT;
  END IF;
END $$;

-- ============================================================================
-- 9. CREATE FUNCTION TO REPROCESS MISSING CHARGES
-- ============================================================================

-- Function to reprocess missing charges from inspections
CREATE OR REPLACE FUNCTION fn_reprocess_missing_inspection_charges()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER := 0;
  v_inspection RECORD;
BEGIN
  -- Find CheckIn inspections that have contract_id but no corresponding costs
  FOR v_inspection IN 
    SELECT i.* 
    FROM inspections i
    WHERE i.inspection_type = 'CheckIn' 
      AND i.contract_id IS NOT NULL
      AND i.tenant_id = '00000000-0000-0000-0000-000000000001'
      AND NOT EXISTS (
        SELECT 1 FROM costs c 
        WHERE c.contract_id = i.contract_id 
          AND c.category IN ('Excesso Km', 'Diária Extra', 'Combustível')
          AND c.cost_date = i.inspected_at::date
      )
  LOOP
    -- Trigger the charge generation manually
    PERFORM fn_inspection_checkin_charges() FROM inspections WHERE id = v_inspection.id;
    v_count := v_count + 1;
  END LOOP;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Function to reprocess missing fuel costs
CREATE OR REPLACE FUNCTION fn_reprocess_missing_fuel_costs()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER := 0;
  v_fuel_record RECORD;
BEGIN
  -- Process fuel records that don't have associated costs
  FOR v_fuel_record IN 
    SELECT fr.*
    FROM fuel_records fr
    WHERE fr.tenant_id = '00000000-0000-0000-0000-000000000001'
      AND fr.cost_id IS NULL
      AND fr.total_cost > 0
  LOOP
    -- Trigger the cost generation manually
    PERFORM fn_create_fuel_cost_from_fuel_records() FROM fuel_records WHERE id = v_fuel_record.id;
    v_count := v_count + 1;
  END LOOP;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Function to reprocess missing fine costs
CREATE OR REPLACE FUNCTION fn_reprocess_missing_fine_costs()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER := 0;
  v_fine RECORD;
BEGIN
  -- Process fines that don't have associated costs
  FOR v_fine IN 
    SELECT f.*
    FROM fines f
    WHERE f.tenant_id = '00000000-0000-0000-0000-000000000001'
      AND f.cost_id IS NULL
  LOOP
    -- Trigger the cost generation manually
    PERFORM fn_fine_postprocess() FROM fines WHERE id = v_fine.id;
    v_count := v_count + 1;
  END LOOP;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 10. EXECUTE REPROCESSING FUNCTIONS
-- ============================================================================

-- Execute reprocessing functions to fix existing data
SELECT 'Reprocessing inspection charges: ' || fn_reprocess_missing_inspection_charges() as result;
SELECT 'Reprocessing fuel costs: ' || fn_reprocess_missing_fuel_costs() as result;
SELECT 'Reprocessing fine costs: ' || fn_reprocess_missing_fine_costs() as result;

-- ============================================================================
-- 11. SUCCESS MESSAGE
-- ============================================================================

SELECT 'All checklist fixes have been implemented successfully!' as message; 