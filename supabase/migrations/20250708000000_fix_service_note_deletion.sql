-- Fix service note deletion foreign key constraint issue
-- This migration addresses the problem where stock_movements records
-- reference deleted service_notes, causing foreign key violations

-- Clean up any orphaned stock_movements records by setting service_note_id to NULL
UPDATE stock_movements 
SET service_note_id = NULL 
WHERE service_note_id IS NOT NULL 
  AND service_note_id NOT IN (SELECT id FROM service_notes);

-- Create a function to safely delete service notes
CREATE OR REPLACE FUNCTION safe_delete_service_note(p_service_note_id uuid)
RETURNS void AS $$
BEGIN
  -- First, set all stock_movements service_note_id to NULL for this service note
  UPDATE stock_movements 
  SET service_note_id = NULL 
  WHERE service_note_id = p_service_note_id;
  
  -- Then delete the service note
  DELETE FROM service_notes WHERE id = p_service_note_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a trigger to automatically handle stock_movements when service_notes are deleted
CREATE OR REPLACE FUNCTION handle_service_note_deletion()
RETURNS TRIGGER AS $$
BEGIN
  -- Set service_note_id to NULL in stock_movements before deleting the service note
  UPDATE stock_movements 
  SET service_note_id = NULL 
  WHERE service_note_id = OLD.id;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
DROP TRIGGER IF EXISTS trg_service_note_deletion ON service_notes;
CREATE TRIGGER trg_service_note_deletion
  BEFORE DELETE ON service_notes
  FOR EACH ROW
  EXECUTE FUNCTION handle_service_note_deletion();

-- Verify the foreign key constraint is properly set
-- If needed, drop and recreate the constraint
ALTER TABLE stock_movements DROP CONSTRAINT IF EXISTS stock_movements_service_note_id_fkey;
ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_service_note_id_fkey 
  FOREIGN KEY (service_note_id) REFERENCES service_notes(id) ON DELETE SET NULL; 