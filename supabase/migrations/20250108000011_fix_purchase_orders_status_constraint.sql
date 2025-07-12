-- Fix purchase_orders status constraint to include 'Aprovada'
-- Drop the existing constraint
ALTER TABLE purchase_orders 
DROP CONSTRAINT IF EXISTS purchase_orders_status_check;

-- Add the new constraint with 'Aprovada' included
ALTER TABLE purchase_orders 
ADD CONSTRAINT purchase_orders_status_check 
CHECK (status IN ('Pending', 'Received', 'Cancelled', 'Aprovada'));

-- Update any existing records that might have invalid status
-- (This is a safety measure, but shouldn't be needed)
UPDATE purchase_orders 
SET status = 'Pending' 
WHERE status NOT IN ('Pending', 'Received', 'Cancelled', 'Aprovada'); 