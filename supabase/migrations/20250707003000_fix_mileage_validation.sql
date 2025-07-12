-- Fix Mileage Validation - Prevent mileage from being decreased
-- This migration adds validation to ensure mileage can only increase

-- ============================================================================
-- 1. CREATE FUNCTION TO VALIDATE MILEAGE INSPECTIONS
-- ============================================================================

-- Function to validate mileage in inspections
CREATE OR REPLACE FUNCTION fn_validate_inspection_mileage()
RETURNS TRIGGER AS $$
DECLARE
  v_current_vehicle_mileage NUMERIC;
  v_original_inspection_mileage NUMERIC;
BEGIN
  -- Only validate if mileage is provided
  IF NEW.mileage IS NOT NULL AND NEW.mileage > 0 THEN
    
    -- Get current vehicle mileage
    SELECT COALESCE(mileage, 0) INTO v_current_vehicle_mileage
    FROM vehicles
    WHERE id = NEW.vehicle_id;
    
    -- If this is an UPDATE (editing existing inspection)
    IF TG_OP = 'UPDATE' THEN
      -- Get the original mileage from the inspection being updated
      SELECT COALESCE(mileage, 0) INTO v_original_inspection_mileage
      FROM inspections
      WHERE id = NEW.id;
      
      -- If the new mileage is less than the original inspection mileage, prevent the update
      IF NEW.mileage < v_original_inspection_mileage THEN
        RAISE EXCEPTION 'A quilometragem não pode ser diminuída. Valor original: % km, Valor novo: % km. A quilometragem só pode aumentar.', 
          v_original_inspection_mileage, NEW.mileage;
      END IF;
    END IF;
    
    -- For both INSERT and UPDATE, ensure mileage is not less than current vehicle mileage
    IF NEW.mileage < v_current_vehicle_mileage THEN
      RAISE EXCEPTION 'A quilometragem não pode ser menor que a quilometragem atual do veículo. Quilometragem atual: % km, Valor informado: % km. A quilometragem só pode aumentar.', 
        v_current_vehicle_mileage, NEW.mileage;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. CREATE TRIGGER FOR MILEAGE VALIDATION
-- ============================================================================

-- Create trigger for inspections to validate mileage
DROP TRIGGER IF EXISTS tr_validate_inspection_mileage ON inspections;
CREATE TRIGGER tr_validate_inspection_mileage
  BEFORE INSERT OR UPDATE ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_validate_inspection_mileage();

-- ============================================================================
-- 3. UPDATE EXISTING MILEAGE UPDATE FUNCTION
-- ============================================================================

-- Update the existing mileage update function to be more robust
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
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error updating vehicle mileage: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE FUNCTION TO VALIDATE MILEAGE IN MAINTENANCE
-- ============================================================================

-- Function to validate mileage in service notes
CREATE OR REPLACE FUNCTION fn_validate_service_note_mileage()
RETURNS TRIGGER AS $$
DECLARE
  v_current_vehicle_mileage NUMERIC;
  v_original_service_note_mileage NUMERIC;
BEGIN
  -- Only validate if mileage is provided
  IF NEW.mileage IS NOT NULL AND NEW.mileage > 0 THEN
    
    -- Get current vehicle mileage
    SELECT COALESCE(mileage, 0) INTO v_current_vehicle_mileage
    FROM vehicles
    WHERE id = NEW.vehicle_id;
    
    -- If this is an UPDATE (editing existing service note)
    IF TG_OP = 'UPDATE' THEN
      -- Get the original mileage from the service note being updated
      SELECT COALESCE(mileage, 0) INTO v_original_service_note_mileage
      FROM service_notes
      WHERE id = NEW.id;
      
      -- If the new mileage is less than the original service note mileage, prevent the update
      IF NEW.mileage < v_original_service_note_mileage THEN
        RAISE EXCEPTION 'A quilometragem não pode ser diminuída. Valor original: % km, Valor novo: % km. A quilometragem só pode aumentar.', 
          v_original_service_note_mileage, NEW.mileage;
      END IF;
    END IF;
    
    -- For both INSERT and UPDATE, ensure mileage is not less than current vehicle mileage
    IF NEW.mileage < v_current_vehicle_mileage THEN
      RAISE EXCEPTION 'A quilometragem não pode ser menor que a quilometragem atual do veículo. Quilometragem atual: % km, Valor informado: % km. A quilometragem só pode aumentar.', 
        v_current_vehicle_mileage, NEW.mileage;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for service notes to validate mileage
DROP TRIGGER IF EXISTS tr_validate_service_note_mileage ON service_notes;
CREATE TRIGGER tr_validate_service_note_mileage
  BEFORE INSERT OR UPDATE ON service_notes
  FOR EACH ROW
  EXECUTE FUNCTION fn_validate_service_note_mileage();

-- ============================================================================
-- 5. CREATE FUNCTION TO VALIDATE MILEAGE IN FUEL RECORDS
-- ============================================================================

-- Function to validate mileage in fuel records
CREATE OR REPLACE FUNCTION fn_validate_fuel_record_mileage()
RETURNS TRIGGER AS $$
DECLARE
  v_current_vehicle_mileage NUMERIC;
  v_original_fuel_record_mileage NUMERIC;
BEGIN
  -- Only validate if odometer_reading is provided
  IF NEW.odometer_reading IS NOT NULL AND NEW.odometer_reading > 0 THEN
    
    -- Get current vehicle mileage
    SELECT COALESCE(mileage, 0) INTO v_current_vehicle_mileage
    FROM vehicles
    WHERE id = NEW.vehicle_id;
    
    -- If this is an UPDATE (editing existing fuel record)
    IF TG_OP = 'UPDATE' THEN
      -- Get the original mileage from the fuel record being updated
      SELECT COALESCE(odometer_reading, 0) INTO v_original_fuel_record_mileage
      FROM fuel_records
      WHERE id = NEW.id;
      
      -- If the new mileage is less than the original fuel record mileage, prevent the update
      IF NEW.odometer_reading < v_original_fuel_record_mileage THEN
        RAISE EXCEPTION 'A quilometragem não pode ser diminuída. Valor original: % km, Valor novo: % km. A quilometragem só pode aumentar.', 
          v_original_fuel_record_mileage, NEW.odometer_reading;
      END IF;
    END IF;
    
    -- For both INSERT and UPDATE, ensure mileage is not less than current vehicle mileage
    IF NEW.odometer_reading < v_current_vehicle_mileage THEN
      RAISE EXCEPTION 'A quilometragem não pode ser menor que a quilometragem atual do veículo. Quilometragem atual: % km, Valor informado: % km. A quilometragem só pode aumentar.', 
        v_current_vehicle_mileage, NEW.odometer_reading;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for fuel records to validate mileage
DROP TRIGGER IF EXISTS tr_validate_fuel_record_mileage ON fuel_records;
CREATE TRIGGER tr_validate_fuel_record_mileage
  BEFORE INSERT OR UPDATE ON fuel_records
  FOR EACH ROW
  EXECUTE FUNCTION fn_validate_fuel_record_mileage();

-- ============================================================================
-- 6. SUCCESS MESSAGE
-- ============================================================================

SELECT 'Mileage validation has been implemented successfully!' as message; 