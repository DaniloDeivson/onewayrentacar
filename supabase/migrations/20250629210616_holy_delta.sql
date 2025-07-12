/*
  # Add permissions column to employees table

  1. Changes
    - Add `permissions` column to `employees` table
    - Column type: JSONB for storing user access permissions
    - Default value: empty JSON object `{}`
    - Allow null values for backward compatibility

  2. Security
    - No RLS changes needed as existing policies will cover the new column
    - Column will inherit existing table permissions

  3. Notes
    - This column will store user access permissions for different system modules
    - Default empty object ensures existing records work without issues
    - JSONB type allows efficient querying and indexing if needed later
*/

-- Add permissions column to employees table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'employees' AND column_name = 'permissions'
  ) THEN
    ALTER TABLE employees ADD COLUMN permissions JSONB DEFAULT '{}';
  END IF;
END $$;

-- Update existing records to have empty permissions object if null
UPDATE employees 
SET permissions = '{}' 
WHERE permissions IS NULL;