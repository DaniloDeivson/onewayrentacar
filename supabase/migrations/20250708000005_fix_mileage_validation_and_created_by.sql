-- Fix Mileage Validation and Created By Name Issues
-- This migration fixes two critical issues:
-- 1. Mileage validation is too restrictive and prevents necessary corrections
-- 2. created_by_name should show the logged user's name, not "Sistema"

-- ============================================================================
-- 1. FIX MILEAGE VALIDATION - ALLOW CORRECTIONS
-- ============================================================================

-- Update the mileage validation function to be less restrictive
-- Allow mileage corrections when they are reasonable (within 10% of current mileage)
CREATE OR REPLACE FUNCTION fn_validate_inspection_mileage()
RETURNS TRIGGER AS $$
DECLARE
  v_current_vehicle_mileage NUMERIC;
  v_original_inspection_mileage NUMERIC;
  v_tolerance NUMERIC;
BEGIN
  -- Only validate if mileage is provided
  IF NEW.mileage IS NOT NULL AND NEW.mileage > 0 THEN
    
    -- Get current vehicle mileage
    SELECT COALESCE(mileage, 0) INTO v_current_vehicle_mileage
    FROM vehicles
    WHERE id = NEW.vehicle_id;
    
    -- Calculate tolerance (10% of current mileage, minimum 1000 km)
    v_tolerance := GREATEST(v_current_vehicle_mileage * 0.1, 1000);
    
    -- If this is an UPDATE (editing existing inspection)
    IF TG_OP = 'UPDATE' THEN
      -- Get the original mileage from the inspection being updated
      SELECT COALESCE(mileage, 0) INTO v_original_inspection_mileage
      FROM inspections
      WHERE id = NEW.id;
      
      -- Allow corrections within tolerance, but prevent major decreases
      IF NEW.mileage < (v_original_inspection_mileage - v_tolerance) THEN
        RAISE EXCEPTION 'A quilometragem não pode ser diminuída significativamente. Valor original: % km, Valor novo: % km. Tolerância: % km. A quilometragem só pode ser corrigida dentro de uma margem razoável.', 
          v_original_inspection_mileage, NEW.mileage, v_tolerance;
      END IF;
    END IF;
    
    -- For both INSERT and UPDATE, ensure mileage is not significantly less than current vehicle mileage
    -- Allow small corrections (within tolerance)
    IF NEW.mileage < (v_current_vehicle_mileage - v_tolerance) THEN
      RAISE EXCEPTION 'A quilometragem não pode ser significativamente menor que a quilometragem atual do veículo. Quilometragem atual: % km, Valor informado: % km, Tolerância: % km. A quilometragem só pode ser corrigida dentro de uma margem razoável.', 
        v_current_vehicle_mileage, NEW.mileage, v_tolerance;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. FIX SERVICE NOTE MILEAGE VALIDATION
-- ============================================================================

-- Update service note mileage validation to be less restrictive
CREATE OR REPLACE FUNCTION fn_validate_service_note_mileage()
RETURNS TRIGGER AS $$
DECLARE
  v_current_vehicle_mileage NUMERIC;
  v_original_service_note_mileage NUMERIC;
  v_tolerance NUMERIC;
BEGIN
  -- Only validate if mileage is provided
  IF NEW.mileage IS NOT NULL AND NEW.mileage > 0 THEN
    
    -- Get current vehicle mileage
    SELECT COALESCE(mileage, 0) INTO v_current_vehicle_mileage
    FROM vehicles
    WHERE id = NEW.vehicle_id;
    
    -- Calculate tolerance (10% of current mileage, minimum 1000 km)
    v_tolerance := GREATEST(v_current_vehicle_mileage * 0.1, 1000);
    
    -- If this is an UPDATE (editing existing service note)
    IF TG_OP = 'UPDATE' THEN
      -- Get the original mileage from the service note being updated
      SELECT COALESCE(mileage, 0) INTO v_original_service_note_mileage
      FROM service_notes
      WHERE id = NEW.id;
      
      -- Allow corrections within tolerance, but prevent major decreases
      IF NEW.mileage < (v_original_service_note_mileage - v_tolerance) THEN
        RAISE EXCEPTION 'A quilometragem não pode ser diminuída significativamente. Valor original: % km, Valor novo: % km. Tolerância: % km. A quilometragem só pode ser corrigida dentro de uma margem razoável.', 
          v_original_service_note_mileage, NEW.mileage, v_tolerance;
      END IF;
    END IF;
    
    -- For both INSERT and UPDATE, ensure mileage is not significantly less than current vehicle mileage
    IF NEW.mileage < (v_current_vehicle_mileage - v_tolerance) THEN
      RAISE EXCEPTION 'A quilometragem não pode ser significativamente menor que a quilometragem atual do veículo. Quilometragem atual: % km, Valor informado: % km, Tolerância: % km. A quilometragem só pode ser corrigida dentro de uma margem razoável.', 
        v_current_vehicle_mileage, NEW.mileage, v_tolerance;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 3. FIX FUEL RECORD MILEAGE VALIDATION
-- ============================================================================

-- Update fuel record mileage validation to be less restrictive
CREATE OR REPLACE FUNCTION fn_validate_fuel_record_mileage()
RETURNS TRIGGER AS $$
DECLARE
  v_current_vehicle_mileage NUMERIC;
  v_original_fuel_record_mileage NUMERIC;
  v_tolerance NUMERIC;
BEGIN
  -- Only validate if odometer_reading is provided
  IF NEW.odometer_reading IS NOT NULL AND NEW.odometer_reading > 0 THEN
    
    -- Get current vehicle mileage
    SELECT COALESCE(mileage, 0) INTO v_current_vehicle_mileage
    FROM vehicles
    WHERE id = NEW.vehicle_id;
    
    -- Calculate tolerance (10% of current mileage, minimum 1000 km)
    v_tolerance := GREATEST(v_current_vehicle_mileage * 0.1, 1000);
    
    -- If this is an UPDATE (editing existing fuel record)
    IF TG_OP = 'UPDATE' THEN
      -- Get the original mileage from the fuel record being updated
      SELECT COALESCE(odometer_reading, 0) INTO v_original_fuel_record_mileage
      FROM fuel_records
      WHERE id = NEW.id;
      
      -- Allow corrections within tolerance, but prevent major decreases
      IF NEW.odometer_reading < (v_original_fuel_record_mileage - v_tolerance) THEN
        RAISE EXCEPTION 'A quilometragem não pode ser diminuída significativamente. Valor original: % km, Valor novo: % km. Tolerância: % km. A quilometragem só pode ser corrigida dentro de uma margem razoável.', 
          v_original_fuel_record_mileage, NEW.odometer_reading, v_tolerance;
      END IF;
    END IF;
    
    -- For both INSERT and UPDATE, ensure mileage is not significantly less than current vehicle mileage
    IF NEW.odometer_reading < (v_current_vehicle_mileage - v_tolerance) THEN
      RAISE EXCEPTION 'A quilometragem não pode ser significativamente menor que a quilometragem atual do veículo. Quilometragem atual: % km, Valor informado: % km, Tolerância: % km. A quilometragem só pode ser corrigida dentro de uma margem razoável.', 
        v_current_vehicle_mileage, NEW.odometer_reading, v_tolerance;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. FIX CREATED_BY_NAME ISSUE - CREATE TRIGGER TO SET USER NAME
-- ============================================================================

-- Create a function to automatically set created_by_name from the logged user
CREATE OR REPLACE FUNCTION fn_set_created_by_name()
RETURNS TRIGGER AS $$
DECLARE
  v_user_name TEXT;
  v_employee_name TEXT;
BEGIN
  -- Try to get the employee name from the current user
  SELECT name INTO v_employee_name
  FROM employees
  WHERE auth_user_id = auth.uid()
    AND tenant_id = NEW.tenant_id
    AND active = true
  LIMIT 1;
  
  -- If employee found, use their name, otherwise use a default
  IF v_employee_name IS NOT NULL AND v_employee_name != '' THEN
    v_user_name := v_employee_name;
  ELSE
    -- Try to get user name from auth.users
    SELECT raw_user_meta_data->>'name' INTO v_user_name
    FROM auth.users
    WHERE id = auth.uid();
    
    -- If still no name, use a fallback
    IF v_user_name IS NULL OR v_user_name = '' THEN
      v_user_name := 'Usuário do Sistema';
    END IF;
  END IF;
  
  -- Set the created_by_name if it's not already set or if it's "Sistema"
  IF NEW.created_by_name IS NULL OR NEW.created_by_name = 'Sistema' OR NEW.created_by_name = '' THEN
    NEW.created_by_name := v_user_name;
  END IF;
  
  -- Set created_by_employee_id if not set
  IF NEW.created_by_employee_id IS NULL THEN
    SELECT id INTO NEW.created_by_employee_id
    FROM employees
    WHERE auth_user_id = auth.uid()
      AND tenant_id = NEW.tenant_id
      AND active = true
    LIMIT 1;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for inspections to set created_by_name
DROP TRIGGER IF EXISTS tr_set_inspection_created_by ON inspections;
CREATE TRIGGER tr_set_inspection_created_by
  BEFORE INSERT ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_set_created_by_name();

-- ============================================================================
-- 5. UPDATE EXISTING RECORDS WITH CORRECT CREATED_BY_NAME
-- ============================================================================

-- First, ensure the created_by_name column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'inspections' AND column_name = 'created_by_name'
  ) THEN
    -- Update existing inspections that have "Sistema" as created_by_name
    UPDATE inspections 
    SET created_by_name = 'Usuário do Sistema'
    WHERE created_by_name = 'Sistema' 
      OR created_by_name IS NULL 
      OR created_by_name = '';
  END IF;
END $$;

-- ============================================================================
-- 6. SUCCESS MESSAGE
-- ============================================================================

SELECT 'Mileage validation and created_by_name issues have been fixed successfully!' as message; 