-- Fix KM Excess Charges - Ensure excess km costs are properly converted to customer charges
-- This migration fixes the issue where excess km costs are created but not converted to customer charges

-- 1. Update the rental checkout function to ensure customer_id is properly set
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

-- 2. Create a function to reprocess existing inspections that didn't create charges
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

-- 3. Execute the reprocessing function
SELECT fn_reprocess_missing_charges() as reprocessed_charges;

-- 4. Create a function to verify charges are being created
CREATE OR REPLACE FUNCTION fn_verify_charges_creation()
RETURNS TABLE (
  inspection_id UUID,
  contract_id UUID,
  customer_name TEXT,
  inspection_date DATE,
  has_excess_km_cost BOOLEAN,
  has_extra_days_cost BOOLEAN,
  has_fuel_cost BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    i.id as inspection_id,
    i.contract_id,
    c.name as customer_name,
    i.inspected_at::date as inspection_date,
    EXISTS (
      SELECT 1 FROM costs co 
      WHERE co.contract_id = i.contract_id 
        AND co.category = 'Excesso Km'
        AND co.cost_date = i.inspected_at::date
    ) as has_excess_km_cost,
    EXISTS (
      SELECT 1 FROM costs co 
      WHERE co.contract_id = i.contract_id 
        AND co.category = 'Diária Extra'
        AND co.cost_date = i.inspected_at::date
    ) as has_extra_days_cost,
    EXISTS (
      SELECT 1 FROM costs co 
      WHERE co.contract_id = i.contract_id 
        AND co.category = 'Combustível'
        AND co.cost_date = i.inspected_at::date
    ) as has_fuel_cost
  FROM inspections i
  JOIN contracts ct ON ct.id = i.contract_id
  JOIN customers c ON c.id = ct.customer_id
  WHERE i.inspection_type = 'CheckIn' 
    AND i.contract_id IS NOT NULL
    AND i.tenant_id = '00000000-0000-0000-0000-000000000001'
  ORDER BY i.inspected_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 5. Test the verification function
SELECT * FROM fn_verify_charges_creation() LIMIT 10; 