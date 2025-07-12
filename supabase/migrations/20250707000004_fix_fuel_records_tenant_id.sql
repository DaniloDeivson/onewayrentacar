-- Fix Fuel Records Tenant ID - Add tenant_id column if it doesn't exist
-- This migration ensures the fuel_records table has the tenant_id column

-- 1. Add tenant_id column to fuel_records if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' 
      AND column_name = 'tenant_id'
  ) THEN
    ALTER TABLE fuel_records 
    ADD COLUMN tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE DEFAULT '00000000-0000-0000-0000-000000000001'::uuid;
    
    -- Update existing records to have the default tenant_id
    UPDATE fuel_records 
    SET tenant_id = '00000000-0000-0000-0000-000000000001'::uuid 
    WHERE tenant_id IS NULL;
    
    -- Make tenant_id NOT NULL after setting default values
    ALTER TABLE fuel_records ALTER COLUMN tenant_id SET NOT NULL;
    
    RAISE NOTICE 'Added tenant_id column to fuel_records table';
  ELSE
    RAISE NOTICE 'tenant_id column already exists in fuel_records table';
  END IF;
END $$;

-- 2. Create index on tenant_id if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'fuel_records' 
      AND indexname = 'idx_fuel_records_tenant'
  ) THEN
    CREATE INDEX idx_fuel_records_tenant ON fuel_records(tenant_id);
    RAISE NOTICE 'Created index on fuel_records.tenant_id';
  ELSE
    RAISE NOTICE 'Index on fuel_records.tenant_id already exists';
  END IF;
END $$;

-- 3. Update RLS policies to use tenant_id
DROP POLICY IF EXISTS "Employees can view all fuel records" ON fuel_records;
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

DROP POLICY IF EXISTS "Admins can manage all fuel records" ON fuel_records;
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

-- 4. Update the reprocess function to handle the case where tenant_id might not exist
CREATE OR REPLACE FUNCTION fn_reprocess_missing_fuel_costs()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER := 0;
  v_fuel_record RECORD;
  v_tenant_id UUID := '00000000-0000-0000-0000-000000000001'::uuid;
BEGIN
  -- Process fuel records that don't have associated costs
  FOR v_fuel_record IN 
    SELECT fr.*, v.plate
    FROM fuel_records fr
    JOIN vehicles v ON v.id = fr.vehicle_id
    WHERE (fr.tenant_id = v_tenant_id OR fr.tenant_id IS NULL)
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
        COALESCE(v_fuel_record.tenant_id, v_tenant_id),
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

-- 5. Update the verify function to handle the case where tenant_id might not exist
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
  WHERE (fr.tenant_id = '00000000-0000-0000-0000-000000000001'::uuid OR fr.tenant_id IS NULL)
  
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
    AND (mc.tenant_id = '00000000-0000-0000-0000-000000000001'::uuid OR mc.tenant_id IS NULL)
  
  ORDER BY source_type, source_id;
END;
$$ LANGUAGE plpgsql; 