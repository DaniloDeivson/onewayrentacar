-- Fix inspection_items trigger conflict
-- Remove the problematic trigger that was incorrectly applied to inspection_items

-- The trigger trg_inspections_update_vehicle_status was incorrectly applied to inspection_items
-- This trigger should only be on inspections table, not inspection_items
DROP TRIGGER IF EXISTS trg_inspections_update_vehicle_status ON inspection_items;

-- Ensure the trigger is only on inspections table (where it belongs)
DROP TRIGGER IF EXISTS trg_inspections_update_vehicle_status ON inspections;
CREATE TRIGGER trg_inspections_update_vehicle_status
  AFTER INSERT ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_status_on_inspection();

-- Log the fix
DO $$
BEGIN
  RAISE NOTICE 'Fixed inspection_items trigger conflict - removed incorrectly applied trigger';
END $$; 