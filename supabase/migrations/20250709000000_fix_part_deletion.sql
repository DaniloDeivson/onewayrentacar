-- Fix part deletion foreign key constraint issue
-- This migration addresses the problem where parts cannot be deleted due to foreign key constraints

-- Step 1: Create a comprehensive safe deletion function for parts
CREATE OR REPLACE FUNCTION safe_delete_part(p_part_id uuid)
RETURNS void AS $$
BEGIN
  -- Step 1: Delete all stock_movements records for this part
  DELETE FROM stock_movements WHERE part_id = p_part_id;
  
  -- Step 2: Delete all service_order_parts records for this part
  DELETE FROM service_order_parts WHERE part_id = p_part_id;
  
  -- Step 3: Delete all purchase_order_items records for this part
  DELETE FROM purchase_order_items WHERE part_id = p_part_id;
  
  -- Step 4: Finally delete the part
  DELETE FROM parts WHERE id = p_part_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION safe_delete_part(uuid) TO authenticated;

-- Step 3: Update foreign key constraints to be more permissive where appropriate
-- For stock_movements, we want CASCADE to work properly
ALTER TABLE stock_movements DROP CONSTRAINT IF EXISTS stock_movements_part_id_fkey;
ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_part_id_fkey 
  FOREIGN KEY (part_id) REFERENCES parts(id) ON DELETE CASCADE;

-- For service_order_parts, we want CASCADE to work properly
ALTER TABLE service_order_parts DROP CONSTRAINT IF EXISTS service_order_parts_part_id_fkey;
ALTER TABLE service_order_parts ADD CONSTRAINT service_order_parts_part_id_fkey 
  FOREIGN KEY (part_id) REFERENCES parts(id) ON DELETE CASCADE;

-- For purchase_order_items, we want CASCADE to work properly
ALTER TABLE purchase_order_items DROP CONSTRAINT IF EXISTS purchase_order_items_part_id_fkey;
ALTER TABLE purchase_order_items ADD CONSTRAINT purchase_order_items_part_id_fkey 
  FOREIGN KEY (part_id) REFERENCES parts(id) ON DELETE CASCADE;

-- Step 4: Create a trigger to automatically handle part deletion
CREATE OR REPLACE FUNCTION handle_part_deletion()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete all related records before deleting the part
  DELETE FROM stock_movements WHERE part_id = OLD.id;
  DELETE FROM service_order_parts WHERE part_id = OLD.id;
  DELETE FROM purchase_order_items WHERE part_id = OLD.id;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Create the trigger
DROP TRIGGER IF EXISTS trg_part_deletion ON parts;
CREATE TRIGGER trg_part_deletion
  BEFORE DELETE ON parts
  FOR EACH ROW
  EXECUTE FUNCTION handle_part_deletion();

-- Step 6: Clean up any existing orphaned records
DELETE FROM stock_movements 
WHERE part_id NOT IN (SELECT id FROM parts);

DELETE FROM service_order_parts 
WHERE part_id NOT IN (SELECT id FROM parts);

DELETE FROM purchase_order_items 
WHERE part_id NOT IN (SELECT id FROM parts); 