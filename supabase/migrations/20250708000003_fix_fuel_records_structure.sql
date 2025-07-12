-- Fix Fuel Records Structure - Update table to be compatible with cost creation triggers
-- This migration updates the fuel_records table structure to match what the triggers expect

-- ============================================================================
-- 1. UPDATE FUEL_RECORDS TABLE STRUCTURE
-- ============================================================================

-- Add missing columns to fuel_records table
DO $$
BEGIN
  -- Add fuel_amount column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'fuel_amount'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN fuel_amount NUMERIC(8,2);
  END IF;

  -- Add unit_price column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'unit_price'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN unit_price NUMERIC(8,2);
  END IF;

  -- Add total_cost column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'total_cost'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN total_cost NUMERIC(10,2);
  END IF;

  -- Add fuel_station column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'fuel_station'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN fuel_station TEXT;
  END IF;

  -- Add driver_name column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'driver_name'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN driver_name TEXT;
  END IF;

  -- Add recorded_at column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'recorded_at'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN recorded_at TIMESTAMPTZ DEFAULT NOW();
  END IF;

  -- Add contract_id column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'contract_id'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN contract_id UUID REFERENCES contracts(id) ON DELETE SET NULL;
  END IF;

  -- Add guest_id column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'guest_id'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN guest_id UUID REFERENCES guest_users(id) ON DELETE SET NULL;
  END IF;

  -- Add driver_employee_id column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'driver_employee_id'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN driver_employee_id UUID REFERENCES employees(id) ON DELETE SET NULL;
  END IF;

  -- Add status column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'status'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected'));
  END IF;

  -- Add approved_by_employee_id column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'approved_by_employee_id'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN approved_by_employee_id UUID REFERENCES employees(id) ON DELETE SET NULL;
  END IF;

  -- Add approved_at column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'approved_at'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN approved_at TIMESTAMPTZ;
  END IF;

  -- Add updated_at column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
  END IF;

  -- Add notes column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'notes'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN notes TEXT;
  END IF;

  -- Add receipt_number column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'receipt_number'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN receipt_number TEXT;
  END IF;

  -- Add receipt_photo_url column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'receipt_photo_url'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN receipt_photo_url TEXT;
  END IF;

  -- Add dashboard_photo_url column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'dashboard_photo_url'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN dashboard_photo_url TEXT;
  END IF;

  RAISE NOTICE 'Added missing columns to fuel_records table';
END $$;

-- ============================================================================
-- 2. MIGRATE EXISTING DATA
-- ============================================================================

-- Update existing records to populate new columns
UPDATE fuel_records 
SET 
  total_cost = value,
  fuel_amount = 0, -- Will need to be updated manually
  unit_price = 0, -- Will need to be updated manually
  driver_name = COALESCE(
    (SELECT name FROM employees WHERE id = driver_id),
    'Motorista não identificado'
  ),
  recorded_at = date,
  status = 'pending'
WHERE total_cost IS NULL;

-- ============================================================================
-- 3. UPDATE CONSTRAINTS
-- ============================================================================

-- Add constraints for new columns
DO $$
BEGIN
  -- Add constraint for fuel_amount if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'fuel_records' AND constraint_name = 'fuel_records_fuel_amount_check'
  ) THEN
    ALTER TABLE fuel_records ADD CONSTRAINT fuel_records_fuel_amount_check CHECK (fuel_amount > 0);
  END IF;

  -- Add constraint for unit_price if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'fuel_records' AND constraint_name = 'fuel_records_unit_price_check'
  ) THEN
    ALTER TABLE fuel_records ADD CONSTRAINT fuel_records_unit_price_check CHECK (unit_price > 0);
  END IF;

  -- Add constraint for total_cost if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'fuel_records' AND constraint_name = 'fuel_records_total_cost_check'
  ) THEN
    ALTER TABLE fuel_records ADD CONSTRAINT fuel_records_total_cost_check CHECK (total_cost > 0);
  END IF;

  RAISE NOTICE 'Added constraints to fuel_records table';
END $$;

-- ============================================================================
-- 4. CREATE INDEXES
-- ============================================================================

-- Create indexes for better performance
DO $$
BEGIN
  -- Index on recorded_at if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'fuel_records' AND indexname = 'idx_fuel_records_recorded_at'
  ) THEN
    CREATE INDEX idx_fuel_records_recorded_at ON fuel_records(recorded_at);
  END IF;

  -- Index on vehicle_id and recorded_at if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'fuel_records' AND indexname = 'idx_fuel_records_vehicle_date'
  ) THEN
    CREATE INDEX idx_fuel_records_vehicle_date ON fuel_records(vehicle_id, recorded_at);
  END IF;

  -- Index on contract_id if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'fuel_records' AND indexname = 'idx_fuel_records_contract'
  ) THEN
    CREATE INDEX idx_fuel_records_contract ON fuel_records(contract_id);
  END IF;

  RAISE NOTICE 'Created indexes for fuel_records table';
END $$;

-- ============================================================================
-- 5. UPDATE TRIGGER FUNCTION
-- ============================================================================

-- Update the trigger function to handle the new structure
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
    CONCAT('Abastecimento: ', COALESCE(NEW.fuel_station, 'Posto não informado'), ' - ', COALESCE(NEW.fuel_amount, 0), 'L'),
    NEW.total_cost,
    NEW.recorded_at::date,
    'Pendente',
    CONCAT(
      'Abastecimento registrado por: ', COALESCE(NEW.driver_name, 'Motorista não identificado'),
      ' | Posto: ', COALESCE(NEW.fuel_station, 'Não informado'),
      ' | Litros: ', COALESCE(NEW.fuel_amount, 0),
      ' | Preço/L: ', COALESCE(NEW.unit_price, 0),
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

-- ============================================================================
-- 6. RECREATE TRIGGER
-- ============================================================================

-- Recreate the trigger
DROP TRIGGER IF EXISTS tr_create_fuel_cost_from_fuel_records ON fuel_records;
CREATE TRIGGER tr_create_fuel_cost_from_fuel_records
  AFTER INSERT ON fuel_records
  FOR EACH ROW
  EXECUTE FUNCTION fn_create_fuel_cost_from_fuel_records();

-- ============================================================================
-- 7. UPDATE RLS POLICIES
-- ============================================================================

-- Update RLS policies to include new columns
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
      WHERE e.id = auth.uid() AND e.active = true AND e.role IN ('Admin', 'Manager')
    )
  );

-- ============================================================================
-- 8. CREATE VIEW FOR DETAILED FUEL RECORDS
-- ============================================================================

-- Create or replace the detailed view
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
LEFT JOIN vehicles v ON v.id = fr.vehicle_id
LEFT JOIN contracts c ON c.id = fr.contract_id
LEFT JOIN customers cust ON cust.id = c.customer_id
LEFT JOIN guest_users g ON g.id = fr.guest_id
LEFT JOIN employees e ON e.id = fr.driver_employee_id
ORDER BY fr.recorded_at DESC;

-- ============================================================================
-- 9. VERIFICATION FUNCTION
-- ============================================================================

-- Create function to verify fuel records structure
CREATE OR REPLACE FUNCTION fn_verify_fuel_records_structure()
RETURNS TABLE (
  column_name text,
  data_type text,
  is_nullable text,
  column_default text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.column_name::text,
    c.data_type::text,
    c.is_nullable::text,
    c.column_default::text
  FROM information_schema.columns c
  WHERE c.table_name = 'fuel_records'
  ORDER BY c.ordinal_position;
END;
$$ LANGUAGE plpgsql; 