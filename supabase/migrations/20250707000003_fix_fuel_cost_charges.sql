-- Fix Fuel Cost Charges - Ensure fuel costs are properly created and converted to customer charges
-- This migration fixes the issue where fuel costs are not being created and charged to customers

-- 1. Create a function to handle fuel cost creation from fuel records
CREATE OR REPLACE FUNCTION fn_create_fuel_cost_from_fuel_records()
RETURNS TRIGGER AS $$
DECLARE
  v_contract_id UUID;
  v_customer_id UUID;
  v_customer_name TEXT;
  v_vehicle_plate TEXT;
  v_cost_id UUID;
BEGIN
  -- Get contract information if available
  SELECT 
    c.id,
    c.customer_id,
    cu.name,
    v.plate
  INTO v_contract_id, v_customer_id, v_customer_name, v_vehicle_plate
  FROM contracts c
  LEFT JOIN customers cu ON cu.id = c.customer_id
  LEFT JOIN vehicles v ON v.id = NEW.vehicle_id
  WHERE c.vehicle_id = NEW.vehicle_id 
    AND c.status = 'Ativo' 
    AND c.start_date <= NEW.recorded_at::date 
    AND c.end_date >= NEW.recorded_at::date
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
  
  RAISE NOTICE 'Fuel cost created: % for fuel record %', v_cost_id, NEW.id;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error creating fuel cost from fuel record: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Create trigger for fuel records to create fuel costs
DROP TRIGGER IF EXISTS tr_create_fuel_cost_from_fuel_records ON fuel_records;
CREATE TRIGGER tr_create_fuel_cost_from_fuel_records
  AFTER INSERT ON fuel_records
  FOR EACH ROW
  EXECUTE FUNCTION fn_create_fuel_cost_from_fuel_records();

-- 3. Create a function to check if maintenance_checkins has fuel_cost column
CREATE OR REPLACE FUNCTION fn_check_maintenance_fuel_cost_column()
RETURNS BOOLEAN AS $$
DECLARE
  v_column_exists BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'maintenance_checkins' 
      AND column_name = 'fuel_cost'
  ) INTO v_column_exists;
  
  RETURN v_column_exists;
END;
$$ LANGUAGE plpgsql;

-- 4. Create a function to handle fuel cost creation from maintenance checkins (if column exists)
CREATE OR REPLACE FUNCTION fn_create_fuel_cost_from_maintenance()
RETURNS TRIGGER AS $$
DECLARE
  v_contract_id UUID;
  v_customer_id UUID;
  v_customer_name TEXT;
  v_vehicle_plate TEXT;
  v_cost_id UUID;
  v_fuel_cost NUMERIC;
  v_fuel_type TEXT;
  v_fuel_liters NUMERIC;
BEGIN
  -- Check if fuel_cost column exists and has value
  IF fn_check_maintenance_fuel_cost_column() THEN
    -- Get fuel cost from the record
    EXECUTE 'SELECT fuel_cost, fuel_type, fuel_liters FROM maintenance_checkins WHERE id = $1' 
      INTO v_fuel_cost, v_fuel_type, v_fuel_liters
      USING NEW.id;
    
    -- Only process if fuel_cost is provided and greater than 0
    IF v_fuel_cost IS NOT NULL AND v_fuel_cost > 0 THEN
      -- Get contract information if available
      SELECT 
        c.id,
        c.customer_id,
        cu.name,
        v.plate
      INTO v_contract_id, v_customer_id, v_customer_name, v_vehicle_plate
      FROM service_notes sn
      LEFT JOIN contracts c ON c.vehicle_id = sn.vehicle_id 
        AND c.status = 'Ativo' 
        AND c.start_date <= NEW.checkin_at::date 
        AND c.end_date >= NEW.checkin_at::date
      LEFT JOIN customers cu ON cu.id = c.customer_id
      LEFT JOIN vehicles v ON v.id = sn.vehicle_id
      WHERE sn.id = NEW.service_note_id;
      
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
        NEW.tenant_id,
        CASE WHEN v_customer_id IS NOT NULL THEN 'Cobrança' ELSE NULL END,
        v_customer_id,
        v_customer_name,
        v_contract_id,
        'Combustível',
        (SELECT vehicle_id FROM service_notes WHERE id = NEW.service_note_id),
        CONCAT('Combustível: ', COALESCE(v_fuel_type, 'Gasolina'), ' - ', COALESCE(v_fuel_liters, 0), 'L'),
        v_fuel_cost,
        NEW.checkin_at::date,
        'Pendente',
        CONCAT(
          'Manutenção: ', NEW.id,
          ' | Tipo: ', COALESCE(v_fuel_type, 'Gasolina'),
          ' | Litros: ', COALESCE(v_fuel_liters, 0),
          ' | Veículo: ', COALESCE(v_vehicle_plate, 'N/A'),
          CASE WHEN v_customer_name IS NOT NULL THEN ' | Cliente: ' || v_customer_name ELSE '' END
        ),
        'Manutencao',
        now(),
        now()
      ) RETURNING id INTO v_cost_id;
      
      RAISE NOTICE 'Fuel cost created: % for maintenance %', v_cost_id, NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error creating fuel cost from maintenance: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Create trigger for maintenance checkins to create fuel costs (only if column exists)
DO $$
BEGIN
  IF fn_check_maintenance_fuel_cost_column() THEN
    DROP TRIGGER IF EXISTS tr_create_fuel_cost_from_maintenance ON maintenance_checkins;
    CREATE TRIGGER tr_create_fuel_cost_from_maintenance
      AFTER INSERT OR UPDATE ON maintenance_checkins
      FOR EACH ROW
      EXECUTE FUNCTION fn_create_fuel_cost_from_maintenance();
  END IF;
END $$;

-- 6. Create a function to reprocess existing fuel records that didn't create costs
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
      AND NOT EXISTS (
        SELECT 1 FROM costs c 
        WHERE c.vehicle_id = fr.vehicle_id 
          AND c.amount = fr.total_cost 
          AND c.cost_date = fr.recorded_at::date
          AND c.category = 'Combustível'
      )
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

-- 7. Create a function to verify fuel cost creation
CREATE OR REPLACE FUNCTION fn_verify_fuel_costs()
RETURNS TABLE (
  source_type text,
  source_id uuid,
  vehicle_plate text,
  fuel_amount numeric,
  fuel_cost numeric,
  has_cost boolean,
  cost_id uuid,
  customer_name text
) AS $$
BEGIN
  -- Check fuel records
  RETURN QUERY
  SELECT 
    'fuel_record'::text as source_type,
    fr.id as source_id,
    v.plate as vehicle_plate,
    fr.fuel_amount,
    fr.total_cost as fuel_cost,
    EXISTS(
      SELECT 1 FROM costs c 
      WHERE c.vehicle_id = fr.vehicle_id 
        AND c.amount = fr.total_cost 
        AND c.cost_date = fr.recorded_at::date
        AND c.category = 'Combustível'
    ) as has_cost,
    c.id as cost_id,
    cu.name as customer_name
  FROM fuel_records fr
  JOIN vehicles v ON v.id = fr.vehicle_id
  LEFT JOIN costs c ON c.vehicle_id = fr.vehicle_id 
    AND c.amount = fr.total_cost 
    AND c.cost_date = fr.recorded_at::date
    AND c.category = 'Combustível'
  LEFT JOIN customers cu ON cu.id = c.customer_id
  WHERE fr.tenant_id = '00000000-0000-0000-0000-000000000001'
  
  UNION ALL
  
  -- Check maintenance checkins if fuel_cost column exists
  SELECT 
    'maintenance'::text as source_type,
    mc.id as source_id,
    v.plate as vehicle_plate,
    mc.fuel_liters as fuel_amount,
    mc.fuel_cost,
    EXISTS(
      SELECT 1 FROM costs c 
      WHERE c.vehicle_id = sn.vehicle_id 
        AND c.amount = mc.fuel_cost 
        AND c.cost_date = mc.checkin_at::date
        AND c.category = 'Combustível'
    ) as has_cost,
    c.id as cost_id,
    cu.name as customer_name
  FROM maintenance_checkins mc
  JOIN service_notes sn ON mc.service_note_id = sn.id
  JOIN vehicles v ON v.id = sn.vehicle_id
  LEFT JOIN costs c ON c.vehicle_id = sn.vehicle_id 
    AND c.amount = mc.fuel_cost 
    AND c.cost_date = mc.checkin_at::date
    AND c.category = 'Combustível'
  LEFT JOIN customers cu ON cu.id = c.customer_id
  WHERE fn_check_maintenance_fuel_cost_column()
    AND mc.fuel_cost IS NOT NULL 
    AND mc.fuel_cost > 0
    AND mc.tenant_id = '00000000-0000-0000-0000-000000000001'
  
  ORDER BY source_type, source_id;
END;
$$ LANGUAGE plpgsql;

-- 8. Execute the reprocessing function
SELECT 'Reprocessing missing fuel costs...' as status;
SELECT fn_reprocess_missing_fuel_costs() as reprocessed_fuel_costs;

-- 9. Test the verification function
SELECT * FROM fn_verify_fuel_costs() WHERE has_cost = false LIMIT 10; 