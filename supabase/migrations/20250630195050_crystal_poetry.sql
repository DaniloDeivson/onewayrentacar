/*
  # Add updated_at column to maintenance_checkins table

  1. Changes
    - Add `updated_at` column to `maintenance_checkins` table
    - Set default value to `now()`
    - Add trigger to automatically update the column on row modifications

  2. Security
    - No changes to existing RLS policies
*/

-- Add updated_at column to maintenance_checkins table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'maintenance_checkins' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE maintenance_checkins ADD COLUMN updated_at timestamptz DEFAULT now();
  END IF;
END $$;

-- Update existing records to have the updated_at value
UPDATE maintenance_checkins 
SET updated_at = created_at 
WHERE updated_at IS NULL;

-- Ensure the trigger exists for updating updated_at column
-- (This trigger should already exist from other tables, but we'll make sure)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add trigger to maintenance_checkins if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE trigger_name = 'trg_maintenance_checkins_updated_at'
    AND event_object_table = 'maintenance_checkins'
  ) THEN
    CREATE TRIGGER trg_maintenance_checkins_updated_at
      BEFORE UPDATE ON maintenance_checkins
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
  END IF;
END $$;