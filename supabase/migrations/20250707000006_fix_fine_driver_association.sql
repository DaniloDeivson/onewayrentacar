-- Fix Fine Driver Association - Ensure driver_id is properly saved in fines
-- This migration fixes the issue where driver_id is not being properly associated in fines

-- 1. Update the fines table to ensure driver_id column exists and is properly configured
DO $$
BEGIN
  -- Add driver_id column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fines' AND column_name = 'driver_id'
  ) THEN
    ALTER TABLE fines ADD COLUMN driver_id UUID REFERENCES employees(id) ON DELETE SET NULL;
  END IF;
  
  -- Add index for better performance
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'fines' AND indexname = 'idx_fines_driver_id'
  ) THEN
    CREATE INDEX idx_fines_driver_id ON fines(driver_id);
  END IF;
END $$;

-- 2. Create a function to auto-assign driver from active contract
CREATE OR REPLACE FUNCTION fn_auto_assign_fine_driver()
RETURNS TRIGGER AS $$
DECLARE
  v_contract_driver_id UUID;
  v_contract_salesperson_id UUID;
BEGIN
  -- Only auto-assign if driver_id is not already set
  IF NEW.driver_id IS NULL THEN
    -- Try to find active contract for the vehicle on the infraction date
    SELECT 
      c.salesperson_id,
      c.driver_id
    INTO v_contract_salesperson_id, v_contract_driver_id
    FROM contracts c
    WHERE c.vehicle_id = NEW.vehicle_id 
      AND c.status = 'Ativo' 
      AND c.start_date <= NEW.infraction_date 
      AND c.end_date >= NEW.infraction_date
    LIMIT 1;
    
    -- Assign driver_id from contract if available
    IF v_contract_driver_id IS NOT NULL THEN
      NEW.driver_id := v_contract_driver_id;
    ELSIF v_contract_salesperson_id IS NOT NULL THEN
      -- Fallback to salesperson if no specific driver assigned
      NEW.driver_id := v_contract_salesperson_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create trigger for auto-assigning driver
DROP TRIGGER IF EXISTS tr_auto_assign_fine_driver ON fines;
CREATE TRIGGER tr_auto_assign_fine_driver
  BEFORE INSERT ON fines
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_assign_fine_driver();

-- 4. Create a function to update existing fines with missing driver assignments
CREATE OR REPLACE FUNCTION fn_update_missing_fine_drivers()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER := 0;
  v_fine RECORD;
  v_contract_driver_id UUID;
  v_contract_salesperson_id UUID;
BEGIN
  -- Find fines without driver_id
  FOR v_fine IN 
    SELECT f.*
    FROM fines f
    WHERE f.driver_id IS NULL
      AND f.tenant_id = '00000000-0000-0000-0000-000000000001'
  LOOP
    -- Try to find active contract for the vehicle on the infraction date
    SELECT 
      c.salesperson_id,
      c.driver_id
    INTO v_contract_salesperson_id, v_contract_driver_id
    FROM contracts c
    WHERE c.vehicle_id = v_fine.vehicle_id 
      AND c.status = 'Ativo' 
      AND c.start_date <= v_fine.infraction_date 
      AND c.end_date >= v_fine.infraction_date
    LIMIT 1;
    
    -- Update fine with driver_id if found
    IF v_contract_driver_id IS NOT NULL OR v_contract_salesperson_id IS NOT NULL THEN
      UPDATE fines
      SET 
        driver_id = COALESCE(v_contract_driver_id, v_contract_salesperson_id),
        updated_at = now()
      WHERE id = v_fine.id;
      
      v_count := v_count + 1;
      
      RAISE NOTICE 'Updated fine % with driver_id %', v_fine.id, COALESCE(v_contract_driver_id, v_contract_salesperson_id);
    END IF;
  END LOOP;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- 5. Create a function to validate driver assignment
CREATE OR REPLACE FUNCTION fn_validate_fine_driver()
RETURNS TRIGGER AS $$
DECLARE
  v_driver_exists BOOLEAN;
BEGIN
  -- If driver_id is provided, validate it exists
  IF NEW.driver_id IS NOT NULL THEN
    SELECT EXISTS(
      SELECT 1 FROM employees 
      WHERE id = NEW.driver_id 
        AND tenant_id = NEW.tenant_id
        AND active = true
    ) INTO v_driver_exists;
    
    IF NOT v_driver_exists THEN
      RAISE EXCEPTION 'Driver with ID % does not exist or is not active', NEW.driver_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Create trigger for driver validation
DROP TRIGGER IF EXISTS tr_validate_fine_driver ON fines;
CREATE TRIGGER tr_validate_fine_driver
  BEFORE INSERT OR UPDATE ON fines
  FOR EACH ROW
  EXECUTE FUNCTION fn_validate_fine_driver();

-- 7. Create a function to get fine details with driver information
CREATE OR REPLACE FUNCTION fn_get_fine_details_with_driver(p_fine_id uuid)
RETURNS TABLE (
  fine_id uuid,
  fine_number text,
  infraction_type text,
  amount numeric,
  infraction_date date,
  due_date date,
  status text,
  vehicle_plate text,
  vehicle_model text,
  driver_id uuid,
  driver_name text,
  driver_role text,
  driver_code text,
  employee_id uuid,
  employee_name text,
  employee_role text,
  customer_id uuid,
  customer_name text,
  contract_id uuid,
  contract_number text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    f.id as fine_id,
    f.fine_number,
    f.infraction_type,
    f.amount,
    f.infraction_date,
    f.due_date,
    f.status,
    v.plate as vehicle_plate,
    v.model as vehicle_model,
    f.driver_id,
    d.name as driver_name,
    d.role as driver_role,
    d.employee_code as driver_code,
    f.employee_id,
    e.name as employee_name,
    e.role as employee_role,
    f.customer_id,
    f.customer_name,
    f.contract_id,
    c.contract_number
  FROM fines f
  JOIN vehicles v ON v.id = f.vehicle_id
  LEFT JOIN employees d ON d.id = f.driver_id
  LEFT JOIN employees e ON e.id = f.employee_id
  LEFT JOIN contracts c ON c.id = f.contract_id
  WHERE f.id = p_fine_id;
END;
$$ LANGUAGE plpgsql;

-- 8. Create a function to get fines by driver
CREATE OR REPLACE FUNCTION fn_get_fines_by_driver(p_driver_id uuid)
RETURNS TABLE (
  fine_id uuid,
  fine_number text,
  infraction_type text,
  amount numeric,
  infraction_date date,
  due_date date,
  status text,
  vehicle_plate text,
  vehicle_model text,
  customer_name text,
  contract_number text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    f.id as fine_id,
    f.fine_number,
    f.infraction_type,
    f.amount,
    f.infraction_date,
    f.due_date,
    f.status,
    v.plate as vehicle_plate,
    v.model as vehicle_model,
    f.customer_name,
    c.contract_number
  FROM fines f
  JOIN vehicles v ON v.id = f.vehicle_id
  LEFT JOIN contracts c ON c.id = f.contract_id
  WHERE f.driver_id = p_driver_id
    AND f.tenant_id = '00000000-0000-0000-0000-000000000001'
  ORDER BY f.infraction_date DESC;
END;
$$ LANGUAGE plpgsql;

-- 9. Create a function to verify fine driver associations
CREATE OR REPLACE FUNCTION fn_verify_fine_driver_associations()
RETURNS TABLE (
  fine_id uuid,
  fine_number text,
  vehicle_plate text,
  has_driver boolean,
  driver_name text,
  driver_role text,
  auto_assigned boolean,
  contract_driver text,
  contract_salesperson text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    f.id as fine_id,
    f.fine_number,
    v.plate as vehicle_plate,
    f.driver_id IS NOT NULL as has_driver,
    d.name as driver_name,
    d.role as driver_role,
    CASE 
      WHEN f.driver_id IS NOT NULL AND f.driver_id IN (
        SELECT DISTINCT COALESCE(c.driver_id, c.salesperson_id)
        FROM contracts c
        WHERE c.vehicle_id = f.vehicle_id 
          AND c.status = 'Ativo' 
          AND c.start_date <= f.infraction_date 
          AND c.end_date >= f.infraction_date
      ) THEN true
      ELSE false
    END as auto_assigned,
    cd.name as contract_driver,
    cs.name as contract_salesperson
  FROM fines f
  JOIN vehicles v ON v.id = f.vehicle_id
  LEFT JOIN employees d ON d.id = f.driver_id
  LEFT JOIN contracts c ON c.vehicle_id = f.vehicle_id 
    AND c.status = 'Ativo' 
    AND c.start_date <= f.infraction_date 
    AND c.end_date >= f.infraction_date
  LEFT JOIN employees cd ON cd.id = c.driver_id
  LEFT JOIN employees cs ON cs.id = c.salesperson_id
  WHERE f.tenant_id = '00000000-0000-0000-0000-000000000001'
  ORDER BY f.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 10. Execute the update function
SELECT 'Updating missing fine driver associations...' as status;
SELECT fn_update_missing_fine_drivers() as updated_fines;

-- 11. Test the verification function
SELECT * FROM fn_verify_fine_driver_associations() WHERE has_driver = false LIMIT 10; 