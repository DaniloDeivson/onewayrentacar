-- Fix costs source_reference_type constraint to include 'purchase_order'
-- Drop the existing constraint
ALTER TABLE costs 
DROP CONSTRAINT IF EXISTS costs_source_reference_type_check;

-- Add the new constraint with 'purchase_order' included
ALTER TABLE costs 
ADD CONSTRAINT costs_source_reference_type_check 
CHECK (source_reference_type IN (
  'inspection_item',
  'service_note', 
  'manual',
  'system',
  'fine',
  'purchase_order_item',
  'purchase_order'
));

-- Update any existing records that might have 'purchase_order' as source_reference_type
-- This ensures data consistency
UPDATE costs 
SET source_reference_type = 'purchase_order_item' 
WHERE source_reference_type = 'purchase_order' 
AND source_reference_id IN (
  SELECT id FROM purchase_order_items
); 