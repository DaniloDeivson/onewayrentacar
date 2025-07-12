-- Fix All Critical Issues - Comprehensive Migration
-- This migration fixes all the critical issues identified in the system

-- ============================================================================
-- 1. FIX KM ADICIONAL NOT GENERATING CHARGES
-- ============================================================================

-- Update the rental checkout function to ensure customer charges are created
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

  -- Excess KM Charge - Ensure customer_id is set
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

-- ============================================================================
-- 2. FIX FUEL RECORDS NOT GENERATING COSTS
-- ============================================================================

-- Add cost_id column to fuel_records table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'cost_id'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN cost_id UUID REFERENCES costs(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Create function to create fuel costs from fuel records
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

  -- Get contract information if available
  IF NEW.contract_id IS NOT NULL THEN
    v_contract_id := NEW.contract_id;
    SELECT 
      c.customer_id,
      cu.name
    INTO v_customer_id, v_customer_name
    FROM contracts c
    LEFT JOIN customers cu ON cu.id = c.customer_id
    WHERE c.id = NEW.contract_id;
  ELSE
    -- Try to find active contract for the vehicle
    SELECT 
      c.id,
      c.customer_id,
      cu.name
    INTO v_contract_id, v_customer_id, v_customer_name
    FROM contracts c
    LEFT JOIN customers cu ON cu.id = c.customer_id
    WHERE c.vehicle_id = NEW.vehicle_id 
      AND c.status = 'Ativo' 
      AND c.start_date <= NEW.recorded_at::date 
      AND c.end_date >= NEW.recorded_at::date
    LIMIT 1;
  END IF;

  -- Get vehicle plate
  SELECT plate INTO v_vehicle_plate
  FROM vehicles
  WHERE id = NEW.vehicle_id;

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

-- Create trigger for fuel records to create fuel costs
DROP TRIGGER IF EXISTS tr_create_fuel_cost_from_fuel_records ON fuel_records;
CREATE TRIGGER tr_create_fuel_cost_from_fuel_records
  AFTER INSERT ON fuel_records
  FOR EACH ROW
  EXECUTE FUNCTION fn_create_fuel_cost_from_fuel_records();

-- ============================================================================
-- 3. FIX FINES NOT GENERATING CHARGES
-- ============================================================================

-- Update the fine postprocess function to ensure customer charges are created
CREATE OR REPLACE FUNCTION fn_fine_postprocess()
RETURNS TRIGGER AS $$
DECLARE
  v_driver_name text;
  v_vehicle_plate text;
  v_employee_name text;
  v_customer_id UUID;
  v_customer_name TEXT;
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
  
  -- Get customer and contract information if available
  IF NEW.customer_id IS NOT NULL THEN
    v_customer_id := NEW.customer_id;
    v_customer_name := NEW.customer_name;
    v_contract_id := NEW.contract_id;
  ELSE
    -- Try to find active contract for the vehicle
    SELECT 
      c.id,
      c.customer_id,
      cu.name
    INTO v_contract_id, v_customer_id, v_customer_name
    FROM contracts c
    JOIN customers cu ON cu.id = c.customer_id
    WHERE c.vehicle_id = NEW.vehicle_id 
      AND c.status = 'Ativo' 
      AND c.start_date <= NEW.infraction_date 
      AND c.end_date >= NEW.infraction_date
    LIMIT 1;
  END IF;
  
  -- Create cost entry for the fine
  INSERT INTO costs (
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
    CASE WHEN v_customer_id IS NOT NULL THEN 'Cobrança' ELSE NULL END,
    v_customer_id,
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
    -- Log error but don't fail the fine creation
    RAISE WARNING 'Erro ao criar custo automático para multa %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add cost_id column to fines table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fines' AND column_name = 'cost_id'
  ) THEN
    ALTER TABLE fines ADD COLUMN cost_id UUID REFERENCES costs(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ============================================================================
-- 4. FIX RECURRING COSTS NOT BEING GENERATED
-- ============================================================================

-- Create function to generate recurring costs monthly
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
    -- Buscar todos os custos recorrentes que precisam ser gerados
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
        -- Calcular próxima data baseada no tipo de recorrência
        next_date := recurring_cost.calculated_next_date;
        
        -- Criar novo custo recorrente
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
            recurring_cost.category,
            recurring_cost.vehicle_id,
            recurring_cost.description,
            recurring_cost.amount,
            CURRENT_DATE,
            'Pendente',
            recurring_cost.document_ref,
            recurring_cost.observations,
            'Recorrente',
            recurring_cost.created_by_employee_id,
            recurring_cost.source_reference_id,
            recurring_cost.source_reference_type,
            'Financeiro',
            recurring_cost.customer_id,
            recurring_cost.customer_name,
            recurring_cost.contract_id,
            recurring_cost.supplier_id,
            recurring_cost.supplier_name,
            recurring_cost.created_by_name,
            false, -- Não é o custo pai
            recurring_cost.recurrence_type,
            recurring_cost.recurrence_day,
            next_date,
            recurring_cost.id,
            true,
            recurring_cost.guest_id
        ) RETURNING id INTO new_cost_id;
        
        -- Atualizar a próxima data de vencimento do custo pai
        UPDATE costs 
        SET next_due_date = next_date
        WHERE id = recurring_cost.id;
        
        generated_count := generated_count + 1;
    END LOOP;
    
    RETURN generated_count;
END;
$$;

-- ============================================================================
-- 5. FIX VEHICLE MILEAGE NOT BEING UPDATED
-- ============================================================================

-- Create function to update vehicle mileage from inspections
CREATE OR REPLACE FUNCTION fn_update_vehicle_mileage_from_inspection()
RETURNS TRIGGER AS $$
DECLARE
  v_current_mileage NUMERIC;
  v_inspection_mileage NUMERIC;
BEGIN
  -- Only process if mileage is provided
  IF NEW.mileage IS NOT NULL AND NEW.mileage > 0 THEN
    -- Get current vehicle mileage
    SELECT COALESCE(mileage, 0) INTO v_current_mileage
    FROM vehicles
    WHERE id = NEW.vehicle_id;
    
    v_inspection_mileage := NEW.mileage;
    
    -- Update vehicle mileage if inspection mileage is higher
    IF v_inspection_mileage > v_current_mileage THEN
      UPDATE vehicles
      SET 
        mileage = v_inspection_mileage,
        updated_at = now()
      WHERE id = NEW.vehicle_id;
      
      RAISE NOTICE 'Updated vehicle % mileage from % to %', NEW.vehicle_id, v_current_mileage, v_inspection_mileage;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for inspections to update vehicle mileage
DROP TRIGGER IF EXISTS tr_update_vehicle_mileage_from_inspection ON inspections;
CREATE TRIGGER tr_update_vehicle_mileage_from_inspection
  AFTER INSERT OR UPDATE ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_mileage_from_inspection();

-- ============================================================================
-- 6. FIX VEHICLE AVAILABILITY FOR FUTURE CONTRACTS
-- ============================================================================

-- Update the vehicle availability function to allow future contracts
CREATE OR REPLACE FUNCTION public.fn_available_vehicles(
  p_start_date date,
  p_end_date date,
  p_tenant_id uuid,
  p_exclude_contract_id uuid DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  plate text,
  model text,
  year integer,
  type text,
  status text
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.id,
    v.plate,
    v.model,
    v.year,
    v.type,
    v.status
  FROM public.vehicles v
  WHERE v.tenant_id = p_tenant_id
    AND v.status IN ('Disponível', 'Em Uso')
    AND NOT EXISTS (
      -- Check for active contracts that overlap with the requested period
      SELECT 1 
      FROM public.contracts c
      WHERE c.vehicle_id = v.id
        AND c.tenant_id = p_tenant_id
        AND c.status = 'Ativo'
        AND (
          (c.start_date <= p_end_date AND c.end_date >= p_start_date)
        )
        AND (p_exclude_contract_id IS NULL OR c.id != p_exclude_contract_id)
    )
    AND NOT EXISTS (
      -- Check for maintenance checkins that overlap with the requested period
      SELECT 1 
      FROM public.maintenance_checkins mc
      JOIN public.service_notes sn ON mc.service_note_id = sn.id
      WHERE sn.vehicle_id = v.id
        AND mc.tenant_id = p_tenant_id
        AND mc.checkout_at IS NULL
        AND (
          (mc.checkin_at::date <= p_end_date)
        )
    )
  ORDER BY v.plate;
END;
$$;

-- ============================================================================
-- 7. FIX MECHANICS LIST IN MAINTENANCE
-- ============================================================================

-- Create function to get only mechanics for maintenance dropdowns
CREATE OR REPLACE FUNCTION fn_get_mechanics_for_maintenance()
RETURNS TABLE (
  id text,
  name text,
  employee_code text,
  role text,
  active boolean
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    e.id,
    e.name,
    e.employee_code,
    e.role,
    e.active
  FROM employees e
  WHERE e.tenant_id = '00000000-0000-0000-0000-000000000001'
    AND e.active = true
    AND e.role = 'Mechanic'
  ORDER BY e.name;
END;
$$;

-- ============================================================================
-- 8. CREATE REPROCESSING FUNCTIONS
-- ============================================================================

-- Function to reprocess missing charges from inspections
CREATE OR REPLACE FUNCTION fn_reprocess_missing_charges()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER := 0;
  v_inspection RECORD;
  v_contract contracts%ROWTYPE;
  v_customer_id UUID;
  v_customer_name TEXT;
  v_checkout_inspection inspections%ROWTYPE;
  v_start_km INTEGER := 0;
  v_end_km INTEGER := 0;
  v_excess_km INTEGER := 0;
  v_excess_km_charge NUMERIC := 0;
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
          AND c.category = 'Excesso Km'
          AND c.cost_date = i.inspected_at::date
      )
  LOOP
    -- Load contract data
    SELECT * INTO v_contract FROM contracts WHERE id = v_inspection.contract_id;
    v_customer_id := v_contract.customer_id;
    SELECT name INTO v_customer_name FROM customers WHERE id = v_customer_id;

    -- Find corresponding CheckOut inspection
    SELECT * INTO v_checkout_inspection 
    FROM inspections 
    WHERE contract_id = v_inspection.contract_id 
      AND inspection_type = 'CheckOut' 
      AND vehicle_id = v_inspection.vehicle_id
    ORDER BY inspected_at DESC 
    LIMIT 1;

    -- Calculate excess km if possible
    IF v_checkout_inspection.id IS NOT NULL 
       AND v_inspection.mileage IS NOT NULL 
       AND v_checkout_inspection.mileage IS NOT NULL 
       AND v_contract.km_limit IS NOT NULL 
       AND v_contract.price_per_excess_km IS NOT NULL 
       AND v_contract.km_limit > 0 THEN
      
      v_start_km := v_checkout_inspection.mileage;
      v_end_km := v_inspection.mileage;
      v_excess_km := GREATEST(v_end_km - v_start_km - v_contract.km_limit, 0);
      v_excess_km_charge := v_excess_km * v_contract.price_per_excess_km;

      -- Create cost if there's excess km
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
          v_inspection.tenant_id, 
          'Cobrança', 
          v_customer_id, 
          v_customer_name, 
          v_inspection.contract_id,
          'Excesso Km', 
          v_inspection.vehicle_id,
          CONCAT('Excesso de ', v_excess_km, ' km — Cliente: ', v_customer_name),
          v_excess_km_charge, 
          v_inspection.inspected_at::date, 
          'Pendente',
          CONCAT('Contrato ', v_inspection.contract_id, ' - Km inicial: ', v_start_km, ', Km final: ', v_end_km, ' - Reprocessado'),
          'Sistema',
          now(),
          now()
        );
        v_count := v_count + 1;
      END IF;
    END IF;
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
    SELECT fr.*, v.plate
    FROM fuel_records fr
    JOIN vehicles v ON v.id = fr.vehicle_id
    WHERE fr.tenant_id = '00000000-0000-0000-0000-000000000001'
      AND (fr.cost_id IS NULL OR fr.cost_id = '')
      AND fr.total_cost > 0
  LOOP
    -- Get contract information
    DECLARE
      v_contract_id UUID;
      v_customer_id UUID;
      v_customer_name TEXT;
    BEGIN
      SELECT 
        c.id,
        c.customer_id,
        cu.name
      INTO v_contract_id, v_customer_id, v_customer_name
      FROM contracts c
      LEFT JOIN customers cu ON cu.id = c.customer_id
      WHERE c.vehicle_id = v_fuel_record.vehicle_id 
        AND c.status = 'Ativo' 
        AND c.start_date <= v_fuel_record.recorded_at::date 
        AND c.end_date >= v_fuel_record.recorded_at::date
      LIMIT 1;
      
      -- Create cost entry
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
        v_fuel_record.tenant_id,
        CASE WHEN v_customer_id IS NOT NULL THEN 'Cobrança' ELSE NULL END,
        v_customer_id,
        v_customer_name,
        v_contract_id,
        'Combustível',
        v_fuel_record.vehicle_id,
        CONCAT('Abastecimento: ', COALESCE(v_fuel_record.fuel_station, 'Posto não informado'), ' - ', v_fuel_record.fuel_amount, 'L'),
        v_fuel_record.total_cost,
        v_fuel_record.recorded_at::date,
        'Pendente',
        CONCAT(
          'Abastecimento registrado por: ', v_fuel_record.driver_name,
          ' | Posto: ', COALESCE(v_fuel_record.fuel_station, 'Não informado'),
          ' | Litros: ', v_fuel_record.fuel_amount,
          ' | Preço/L: ', v_fuel_record.unit_price,
          ' | Veículo: ', v_fuel_record.plate,
          ' | Reprocessado',
          CASE WHEN v_customer_name IS NOT NULL THEN ' | Cliente: ' || v_customer_name ELSE '' END
        ),
        'Sistema',
        now(),
        now()
      );
      
      v_count := v_count + 1;
    END;
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
      AND f.amount > 0
  LOOP
    -- Get contract information
    DECLARE
      v_contract_id UUID;
      v_customer_id UUID;
      v_customer_name TEXT;
      v_cost_id UUID;
    BEGIN
      SELECT 
        c.id,
        c.customer_id,
        cu.name
      INTO v_contract_id, v_customer_id, v_customer_name
      FROM contracts c
      LEFT JOIN customers cu ON cu.id = c.customer_id
      WHERE c.vehicle_id = v_fine.vehicle_id 
        AND c.status = 'Ativo' 
        AND c.start_date <= v_fine.infraction_date 
        AND c.end_date >= v_fine.infraction_date
      LIMIT 1;
      
      -- Create cost entry
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
        v_fine.tenant_id,
        CASE WHEN v_customer_id IS NOT NULL THEN 'Cobrança' ELSE NULL END,
        v_customer_id,
        v_customer_name,
        v_contract_id,
        'Multa',
        v_fine.vehicle_id,
        CONCAT('Multa ', COALESCE(v_fine.fine_number, 'SEM-NUMERO'), ' - ', v_fine.infraction_type, 
               CASE WHEN v_customer_name IS NOT NULL THEN ' — Cliente: ' || v_customer_name ELSE '' END),
        v_fine.amount,
        v_fine.infraction_date,
        'Pendente',
        v_fine.document_ref,
        CONCAT('Multa reprocessada - Vencimento: ', COALESCE(v_fine.due_date::text, 'N/A')),
        'Sistema',
        v_fine.employee_id,
        v_fine.id,
        'fine',
        now(),
        now()
      ) RETURNING id INTO v_cost_id;
      
      -- Update the fine with the cost_id
      UPDATE fines 
      SET cost_id = v_cost_id
      WHERE id = v_fine.id;
      
      v_count := v_count + 1;
    END;
  END LOOP;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 9. EXECUTE REPROCESSING
-- ============================================================================

-- Execute reprocessing functions
SELECT 'Reprocessing missing charges...' as message;
SELECT fn_reprocess_missing_charges() as reprocessed_charges;

SELECT 'Reprocessing missing fuel costs...' as message;
SELECT fn_reprocess_missing_fuel_costs() as reprocessed_fuel_costs;

SELECT 'Reprocessing missing fine costs...' as message;
SELECT fn_reprocess_missing_fine_costs() as reprocessed_fine_costs;

-- ============================================================================
-- 10. SUCCESS MESSAGE
-- ============================================================================

SELECT 'All critical issues have been fixed successfully!' as message; 