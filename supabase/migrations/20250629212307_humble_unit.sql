-- Fix the issue with deleting employees that are referenced in maintenance_checkins
-- by adding a trigger that deactivates employees instead of deleting them

-- Create a function to handle employee deletion attempts
CREATE OR REPLACE FUNCTION fn_handle_employee_delete()
RETURNS TRIGGER AS $$
BEGIN
  -- Instead of deleting, update the employee to be inactive
  UPDATE employees
  SET 
    active = false,
    updated_at = now()
  WHERE id = OLD.id;
  
  -- Prevent the actual deletion
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to intercept DELETE operations on employees
DROP TRIGGER IF EXISTS trg_prevent_employee_delete ON employees;
CREATE TRIGGER trg_prevent_employee_delete
  BEFORE DELETE ON employees
  FOR EACH ROW
  EXECUTE FUNCTION fn_handle_employee_delete();

-- Add a status column to costs table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'costs' AND column_name = 'status'
  ) THEN
    ALTER TABLE costs ADD COLUMN status text NOT NULL DEFAULT 'Pendente' 
      CHECK (status IN ('Pendente', 'Pago', 'Autorizado'));
  ELSE
    -- Update the constraint to include 'Autorizado'
    ALTER TABLE costs DROP CONSTRAINT IF EXISTS costs_status_check;
    ALTER TABLE costs ADD CONSTRAINT costs_status_check 
      CHECK (status IN ('Pendente', 'Pago', 'Autorizado'));
  END IF;
END $$;