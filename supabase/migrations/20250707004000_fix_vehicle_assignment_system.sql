-- Fix Vehicle Assignment System - Improve vehicle assignment through contracts
-- This migration improves the vehicle assignment system to work through contracts

-- ============================================================================
-- 1. IMPROVE DRIVER VEHICLES TABLE
-- ============================================================================

-- Add contract_id to driver_vehicles to track which contract assigned the vehicle
ALTER TABLE driver_vehicles 
ADD COLUMN IF NOT EXISTS contract_id UUID REFERENCES contracts(id) ON DELETE SET NULL;

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_driver_vehicles_contract 
ON driver_vehicles(contract_id);

-- ============================================================================
-- 2. CREATE FUNCTION TO AUTO-ASSIGN VEHICLES FROM CONTRACTS
-- ============================================================================

-- Function to automatically assign vehicles to drivers when contracts are created
CREATE OR REPLACE FUNCTION fn_auto_assign_vehicles_from_contract()
RETURNS TRIGGER AS $$
DECLARE
  v_contract_vehicle RECORD;
BEGIN
  -- Only process for new active contracts
  IF TG_OP = 'INSERT' AND NEW.status = 'Ativo' THEN
    -- For each vehicle in the contract, create driver-vehicle assignment
    FOR v_contract_vehicle IN 
      SELECT cv.vehicle_id, NEW.driver_id as driver_id, NEW.id as contract_id
      FROM contract_vehicles cv
      WHERE cv.contract_id = NEW.id
    LOOP
      -- Insert or update driver-vehicle assignment
      INSERT INTO driver_vehicles (
        driver_id, 
        vehicle_id, 
        contract_id,
        active, 
        assigned_at
      ) VALUES (
        v_contract_vehicle.driver_id,
        v_contract_vehicle.vehicle_id,
        v_contract_vehicle.contract_id,
        true,
        NOW()
      )
      ON CONFLICT (driver_id, vehicle_id) 
      DO UPDATE SET 
        contract_id = EXCLUDED.contract_id,
        active = true,
        assigned_at = NOW(),
        removed_at = NULL;
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for contracts to auto-assign vehicles
DROP TRIGGER IF EXISTS tr_auto_assign_vehicles_from_contract ON contracts;
CREATE TRIGGER tr_auto_assign_vehicles_from_contract
  AFTER INSERT ON contracts
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_assign_vehicles_from_contract();

-- ============================================================================
-- 3. CREATE FUNCTION TO REMOVE ASSIGNMENTS WHEN CONTRACTS END
-- ============================================================================

-- Function to remove vehicle assignments when contracts end
CREATE OR REPLACE FUNCTION fn_remove_vehicle_assignments_on_contract_end()
RETURNS TRIGGER AS $$
BEGIN
  -- When contract status changes from 'Ativo' to something else
  IF OLD.status = 'Ativo' AND NEW.status != 'Ativo' THEN
    -- Deactivate driver-vehicle assignments for this contract
    UPDATE driver_vehicles 
    SET 
      active = false,
      removed_at = NOW()
    WHERE contract_id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for contracts to remove assignments when they end
DROP TRIGGER IF EXISTS tr_remove_vehicle_assignments_on_contract_end ON contracts;
CREATE TRIGGER tr_remove_vehicle_assignments_on_contract_end
  AFTER UPDATE ON contracts
  FOR EACH ROW
  EXECUTE FUNCTION fn_remove_vehicle_assignments_on_contract_end();

-- ============================================================================
-- 4. CREATE FUNCTION TO GET DRIVER ASSIGNED VEHICLES
-- ============================================================================

-- Function to get vehicles assigned to a driver through active contracts
CREATE OR REPLACE FUNCTION fn_get_driver_assigned_vehicles(p_driver_id UUID)
RETURNS TABLE (
  vehicle_id UUID,
  plate TEXT,
  model TEXT,
  year INTEGER,
  type TEXT,
  status TEXT,
  contract_id UUID,
  contract_number TEXT,
  assignment_date TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.id as vehicle_id,
    v.plate,
    v.model,
    v.year,
    v.type,
    v.status,
    dv.contract_id,
    c.contract_number,
    dv.assigned_at as assignment_date
  FROM driver_vehicles dv
  JOIN vehicles v ON v.id = dv.vehicle_id
  LEFT JOIN contracts c ON c.id = dv.contract_id
  WHERE dv.driver_id = p_driver_id
    AND dv.active = true
    AND (dv.removed_at IS NULL OR dv.removed_at > NOW())
    AND v.status != 'Inativo'
  ORDER BY dv.assigned_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 5. UPDATE EXISTING ASSIGNMENTS FROM CONTRACTS
-- ============================================================================

-- Update existing driver_vehicles to include contract_id where possible
UPDATE driver_vehicles dv
SET contract_id = cv.contract_id
FROM contract_vehicles cv
WHERE dv.driver_id = cv.driver_id
  AND dv.vehicle_id = cv.vehicle_id
  AND dv.contract_id IS NULL;

-- ============================================================================
-- 6. CREATE ADMIN FUNCTION TO MANUALLY ASSIGN VEHICLES
-- ============================================================================

-- Function for admin to manually assign vehicles to drivers
CREATE OR REPLACE FUNCTION fn_admin_assign_vehicle_to_driver(
  p_driver_id UUID,
  p_vehicle_id UUID,
  p_contract_id UUID DEFAULT NULL
)
RETURNS driver_vehicles AS $$
DECLARE
  result_record driver_vehicles;
BEGIN
  -- Check if user is admin
  IF NOT EXISTS (
    SELECT 1 FROM employees 
    WHERE id = auth.uid() 
    AND role = 'Admin'
  ) THEN
    RAISE EXCEPTION 'Apenas administradores podem atribuir veículos manualmente';
  END IF;

  -- Check if driver exists and is active
  IF NOT EXISTS (
    SELECT 1 FROM employees 
    WHERE id = p_driver_id 
    AND active = true
  ) THEN
    RAISE EXCEPTION 'Motorista não encontrado ou inativo';
  END IF;

  -- Check if vehicle exists and is available
  IF NOT EXISTS (
    SELECT 1 FROM vehicles 
    WHERE id = p_vehicle_id 
    AND status != 'Inativo'
  ) THEN
    RAISE EXCEPTION 'Veículo não encontrado ou inativo';
  END IF;

  -- Insert or update assignment
  INSERT INTO driver_vehicles (
    driver_id, 
    vehicle_id, 
    contract_id,
    active, 
    assigned_at
  ) VALUES (
    p_driver_id,
    p_vehicle_id,
    p_contract_id,
    true,
    NOW()
  )
  ON CONFLICT (driver_id, vehicle_id) 
  DO UPDATE SET 
    contract_id = COALESCE(EXCLUDED.contract_id, driver_vehicles.contract_id),
    active = true,
    assigned_at = NOW(),
    removed_at = NULL
  RETURNING * INTO result_record;
  
  RETURN result_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 7. SUCCESS MESSAGE
-- ============================================================================

SELECT 'Vehicle assignment system has been improved successfully!' as message; 