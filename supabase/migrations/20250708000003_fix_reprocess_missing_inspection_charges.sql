-- Corrigir reprocessamento de inspeções para não chamar trigger
CREATE OR REPLACE FUNCTION fn_reprocess_missing_inspection_charges()
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
  v_contract_days INTEGER := 0;
  v_actual_days INTEGER := 0;
  v_extra_days INTEGER := 0;
  v_extra_day_charge NUMERIC := 0;
  v_fuel_level_start NUMERIC := 0;
  v_fuel_level_end NUMERIC := 0;
  v_fuel_difference NUMERIC := 0;
  v_fuel_charge NUMERIC := 0;
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
    -- Get contract information
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

    -- Calculate excess kilometers if mileage is recorded
    IF v_checkout_inspection.id IS NOT NULL AND v_inspection.mileage IS NOT NULL AND v_checkout_inspection.mileage IS NOT NULL THEN
      v_start_km := v_checkout_inspection.mileage;
      v_end_km := v_inspection.mileage;
      IF v_contract.km_limit IS NOT NULL AND v_contract.price_per_excess_km IS NOT NULL AND v_contract.km_limit > 0 THEN
        v_excess_km := GREATEST(v_end_km - v_start_km - v_contract.km_limit, 0);
        v_excess_km_charge := v_excess_km * v_contract.price_per_excess_km;
      END IF;
    END IF;

    -- Calculate extra days
    v_contract_days := (v_contract.end_date - v_contract.start_date) + 1;
    v_actual_days := (v_inspection.inspected_at::date - v_contract.start_date) + 1;
    v_extra_days := GREATEST(v_actual_days - v_contract_days, 0);
    v_extra_day_charge := v_extra_days * v_contract.daily_rate;

    -- Calculate fuel difference
    IF v_checkout_inspection.fuel_level IS NOT NULL AND v_inspection.fuel_level IS NOT NULL THEN
      v_fuel_level_start := v_checkout_inspection.fuel_level;
      v_fuel_level_end := v_inspection.fuel_level;
      v_fuel_difference := v_fuel_level_start - v_fuel_level_end;
      IF v_fuel_difference > 0 AND v_contract.price_per_liter IS NOT NULL THEN
        v_fuel_charge := (v_fuel_difference * 50) * v_contract.price_per_liter;
      END IF;
    END IF;

    -- Excess KM Charge
    IF v_excess_km_charge > 0 THEN
      INSERT INTO costs(
        tenant_id, department, customer_id, customer_name, contract_id,
        category, vehicle_id, description, amount, cost_date, status, observations, origin, created_at, updated_at
      ) VALUES (
        v_inspection.tenant_id, 'Cobrança', v_customer_id, v_customer_name, v_inspection.contract_id,
        'Excesso Km', v_inspection.vehicle_id,
        CONCAT('Excesso de ', v_excess_km, ' km — Cliente: ', v_customer_name),
        v_excess_km_charge, v_inspection.inspected_at::date, 'Pendente',
        CONCAT('Contrato ', v_inspection.contract_id, ' - Km inicial: ', v_start_km, ', Km final: ', v_end_km, ' - Reprocessado'),
        'Sistema', now(), now()
      );
    END IF;

    -- Extra Days
    IF v_extra_day_charge > 0 THEN
      INSERT INTO costs(
        tenant_id, department, customer_id, customer_name, contract_id,
        category, vehicle_id, description, amount, cost_date, status, observations, origin, created_at, updated_at
      ) VALUES (
        v_inspection.tenant_id, 'Cobrança', v_customer_id, v_customer_name, v_inspection.contract_id,
        'Diária Extra', v_inspection.vehicle_id,
        CONCAT('Atraso de ', v_extra_days, ' dias — Cliente: ', v_customer_name),
        v_extra_day_charge, v_inspection.inspected_at::date, 'Pendente',
        CONCAT('Contrato ', v_inspection.contract_id, ' - Data prevista: ', v_contract.end_date, ', Data efetiva: ', v_inspection.inspected_at::date, ' - Reprocessado'),
        'Sistema', now(), now()
      );
    END IF;

    -- Fuel Charge
    IF v_fuel_charge > 0 THEN
      INSERT INTO costs(
        tenant_id, department, customer_id, customer_name, contract_id,
        category, vehicle_id, description, amount, cost_date, status, observations, origin, created_at, updated_at
      ) VALUES (
        v_inspection.tenant_id, 'Cobrança', v_customer_id, v_customer_name, v_inspection.contract_id,
        'Combustível', v_inspection.vehicle_id,
        CONCAT('Reabastecer ', ROUND(ABS(v_fuel_difference) * 100), '% — Cliente: ', v_customer_name),
        v_fuel_charge, v_inspection.inspected_at::date, 'Pendente',
        CONCAT('Contrato ', v_inspection.contract_id, ' - Nível inicial: ', ROUND(v_fuel_level_start * 100), '%, Nível final: ', ROUND(v_fuel_level_end * 100), '% - Reprocessado'),
        'Sistema', now(), now()
      );
    END IF;

    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql; 