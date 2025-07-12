-- Fix Vehicle Mileage Update - Ensure vehicle mileage is properly updated after inspections
-- This migration fixes the issue where vehicle mileage is not being updated in the vehicle history

-- 1. Create a function to update vehicle mileage from inspections
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

-- 2. Create trigger for inspections to update vehicle mileage
DROP TRIGGER IF EXISTS tr_update_vehicle_mileage_from_inspection ON inspections;
CREATE TRIGGER tr_update_vehicle_mileage_from_inspection
  AFTER INSERT OR UPDATE ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_mileage_from_inspection();

-- 3. Create a function to sync vehicle mileages from maintenance checkins
CREATE OR REPLACE FUNCTION fn_sync_vehicle_mileages_from_maintenance()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER := 0;
  v_maintenance RECORD;
  v_current_mileage NUMERIC;
BEGIN
  -- Process maintenance checkins with mileage information
  FOR v_maintenance IN 
    SELECT 
      mc.id,
      sn.vehicle_id,
      sn.mileage as service_mileage,
      v.plate,
      v.mileage as current_mileage
    FROM maintenance_checkins mc
    JOIN service_notes sn ON mc.service_note_id = sn.id
    JOIN vehicles v ON v.id = sn.vehicle_id
    WHERE mc.checkout_at IS NOT NULL
      AND sn.mileage IS NOT NULL
      AND sn.mileage > 0
      AND mc.tenant_id = '00000000-0000-0000-0000-000000000001'
  LOOP
    v_current_mileage := COALESCE(v_maintenance.current_mileage, 0);
    
    -- Update vehicle mileage if service mileage is higher
    IF v_maintenance.service_mileage > v_current_mileage THEN
      UPDATE vehicles
      SET 
        mileage = v_maintenance.service_mileage,
        updated_at = now()
      WHERE id = v_maintenance.vehicle_id;
      
      v_count := v_count + 1;
      RAISE NOTICE 'Updated vehicle % (%) mileage from % to %', 
        v_maintenance.plate, v_maintenance.vehicle_id, v_current_mileage, v_maintenance.service_mileage;
    END IF;
  END LOOP;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- 4. Create a function to verify vehicle mileage updates
CREATE OR REPLACE FUNCTION fn_verify_vehicle_mileages()
RETURNS TABLE (
  vehicle_id uuid,
  plate text,
  model text,
  current_mileage numeric,
  last_inspection_mileage numeric,
  last_maintenance_mileage numeric,
  needs_update boolean,
  suggested_mileage numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.id as vehicle_id,
    v.plate,
    v.model,
    COALESCE(v.mileage, 0) as current_mileage,
    COALESCE(i.mileage, 0) as last_inspection_mileage,
    COALESCE(sn.mileage, 0) as last_maintenance_mileage,
    CASE 
      WHEN COALESCE(i.mileage, 0) > COALESCE(v.mileage, 0) OR COALESCE(sn.mileage, 0) > COALESCE(v.mileage, 0) 
      THEN true 
      ELSE false 
    END as needs_update,
    GREATEST(
      COALESCE(v.mileage, 0),
      COALESCE(i.mileage, 0),
      COALESCE(sn.mileage, 0)
    ) as suggested_mileage
  FROM vehicles v
  LEFT JOIN LATERAL (
    SELECT mileage
    FROM inspections
    WHERE vehicle_id = v.id
      AND mileage IS NOT NULL
      AND mileage > 0
    ORDER BY created_at DESC
    LIMIT 1
  ) i ON true
  LEFT JOIN LATERAL (
    SELECT sn.mileage
    FROM maintenance_checkins mc
    JOIN service_notes sn ON mc.service_note_id = sn.id
    WHERE sn.vehicle_id = v.id
      AND sn.mileage IS NOT NULL
      AND sn.mileage > 0
      AND mc.checkout_at IS NOT NULL
    ORDER BY mc.checkout_at DESC
    LIMIT 1
  ) sn ON true
  WHERE v.tenant_id = '00000000-0000-0000-0000-000000000001'
  ORDER BY v.plate;
END;
$$ LANGUAGE plpgsql;

-- 5. Execute the sync function
SELECT 'Syncing vehicle mileages from maintenance...' as status;
SELECT fn_sync_vehicle_mileages_from_maintenance() as updated_vehicles;

-- 6. Test the verification function
SELECT * FROM fn_verify_vehicle_mileages() WHERE needs_update = true LIMIT 10; 