-- Add created_by fields to inspections table
-- This migration adds the missing fields for tracking who created the inspection

-- 1. Add created_by_employee_id column to inspections table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'created_by_employee_id'
  ) THEN
    ALTER TABLE inspections ADD COLUMN created_by_employee_id UUID REFERENCES employees(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 2. Add created_by_name column to inspections table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'created_by_name'
  ) THEN
    ALTER TABLE inspections ADD COLUMN created_by_name TEXT;
  END IF;
END $$;

-- 3. Add tenant_id column to inspections table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'tenant_id'
  ) THEN
    ALTER TABLE inspections ADD COLUMN tenant_id UUID DEFAULT '00000000-0000-0000-0000-000000000001'::uuid;
  END IF;
END $$;

-- 4. Add employee_id column to inspections table if it doesn't exist (for backward compatibility)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'employee_id'
  ) THEN
    ALTER TABLE inspections ADD COLUMN employee_id UUID REFERENCES employees(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 5. Add inspected_by column to inspections table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'inspected_by'
  ) THEN
    ALTER TABLE inspections ADD COLUMN inspected_by TEXT;
  END IF;
END $$;

-- 6. Add contract_id column to inspections table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'contract_id'
  ) THEN
    ALTER TABLE inspections ADD COLUMN contract_id UUID REFERENCES contracts(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 7. Add customer_id column to inspections table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'customer_id'
  ) THEN
    ALTER TABLE inspections ADD COLUMN customer_id UUID REFERENCES customers(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 8. Add location column to inspections table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'location'
  ) THEN
    ALTER TABLE inspections ADD COLUMN location TEXT;
  END IF;
END $$;

-- 9. Add dashboard_photo_url column to inspections table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'dashboard_photo_url'
  ) THEN
    ALTER TABLE inspections ADD COLUMN dashboard_photo_url TEXT;
  END IF;
END $$;

-- 10. Add dashboard_warning_light column to inspections table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'dashboard_warning_light'
  ) THEN
    ALTER TABLE inspections ADD COLUMN dashboard_warning_light BOOLEAN DEFAULT false;
  END IF;
END $$;

-- 11. Create indexes for the new columns
CREATE INDEX IF NOT EXISTS idx_inspections_created_by_employee ON inspections(created_by_employee_id);
CREATE INDEX IF NOT EXISTS idx_inspections_tenant ON inspections(tenant_id);
CREATE INDEX IF NOT EXISTS idx_inspections_employee ON inspections(employee_id);
CREATE INDEX IF NOT EXISTS idx_inspections_contract ON inspections(contract_id);
CREATE INDEX IF NOT EXISTS idx_inspections_customer ON inspections(customer_id);

-- 12. Update existing inspections to set default values
UPDATE inspections 
SET 
  tenant_id = '00000000-0000-0000-0000-000000000001'::uuid,
  created_by_name = 'Sistema'
WHERE tenant_id IS NULL OR created_by_name IS NULL;

-- 13. Show the updated table structure
SELECT 
  'Updated Inspections Table Structure' as info,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'inspections' 
ORDER BY ordinal_position; 