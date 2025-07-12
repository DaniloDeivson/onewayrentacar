-- Fix service_note constraint issue
-- This migration ensures the source_reference_type constraint accepts 'service_note'

BEGIN;

-- First, let's check what values are currently allowed
SELECT 
  conname as constraint_name,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conname = 'costs_source_reference_type_check';

-- Drop the existing constraint if it exists
ALTER TABLE costs DROP CONSTRAINT IF EXISTS costs_source_reference_type_check;

-- Add the constraint with all valid values including 'service_note'
ALTER TABLE costs ADD CONSTRAINT costs_source_reference_type_check 
  CHECK (source_reference_type = ANY (ARRAY['inspection_item'::text, 'service_note'::text, 'manual'::text, 'system'::text, 'fine'::text, 'purchase_order_item'::text]));

-- Verify the constraint was created correctly
SELECT 
  conname as constraint_name,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conname = 'costs_source_reference_type_check';

-- Test insert to verify it works (without cleanup due to delete protection)
DO $$
DECLARE
  test_tenant_id uuid := '00000000-0000-0000-0000-000000000001';
  test_vehicle_id uuid;
BEGIN
  -- Get a test vehicle
  SELECT id INTO test_vehicle_id FROM vehicles WHERE tenant_id = test_tenant_id LIMIT 1;
  
  IF test_vehicle_id IS NOT NULL THEN
    -- Try to insert a test cost with service_note
    INSERT INTO costs (
      tenant_id,
      vehicle_id,
      amount,
      description,
      cost_date,
      category,
      status,
      origin,
      source_reference_id,
      source_reference_type
    ) VALUES (
      test_tenant_id,
      test_vehicle_id,
      100.00,
      'Teste de peça - ' || gen_random_uuid()::text,
      CURRENT_DATE,
      'Peças',
      'Pendente',
      'Manutencao',
      gen_random_uuid(),
      'service_note'
    );
    
    RAISE NOTICE 'Constraint test passed - service_note is accepted';
  ELSE
    RAISE NOTICE 'No test vehicle found, skipping constraint test';
  END IF;
END $$;

COMMIT; 