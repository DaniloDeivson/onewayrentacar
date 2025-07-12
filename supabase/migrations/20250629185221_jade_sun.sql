/*
  # Fix costs table source_reference_type constraint

  1. Changes
    - Drop the existing check constraint on costs.source_reference_type
    - Add a new check constraint that includes 'fine' as a valid value
    - This allows the fine creation trigger to properly set source_reference_type to 'fine'

  2. Security
    - No changes to RLS policies
    - Maintains data integrity with updated constraint
*/

-- Drop the existing constraint
ALTER TABLE costs DROP CONSTRAINT IF EXISTS costs_source_reference_type_check;

-- Add the updated constraint that includes 'fine' as a valid value
ALTER TABLE costs ADD CONSTRAINT costs_source_reference_type_check 
  CHECK (source_reference_type = ANY (ARRAY['inspection_item'::text, 'service_note'::text, 'manual'::text, 'system'::text, 'fine'::text]));