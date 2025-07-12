-- Fix Critical Issues - Simple Migration
-- This migration fixes the most critical issues without complex functions

-- ============================================================================
-- 1. ADD MISSING COLUMNS
-- ============================================================================

-- Add cost_id column to fuel_records table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fuel_records' AND column_name = 'cost_id'
  ) THEN
    ALTER TABLE fuel_records ADD COLUMN cost_id UUID REFERENCES costs(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Add cost_id column to fines table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fines' AND column_name = 'cost_id'
  ) THEN
    ALTER TABLE fines ADD COLUMN cost_id UUID REFERENCES costs(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ============================================================================
-- 2. FIX VEHICLE MILEAGE UPDATE FROM INSPECTIONS
-- ============================================================================

-- Create function to update vehicle mileage from inspections
CREATE OR REPLACE FUNCTION fn_update_vehicle_mileage_from_inspection()
RETURNS TRIGGER AS $$
DECLARE
  v_current_mileage NUMERIC;
  v_inspection_mileage NUMERIC;
BEGIN
  -- Only process if mileage is provided
  IF NEW.mileage IS NOT NULL AND NEW.mileage > 0 THEN
    -- Get current vehicle mileage
    SELECT COALESCE(mileage, 0) INTO v_current_mileage
    FROM vehicles
    WHERE id = NEW.vehicle_id;
    
    v_inspection_mileage := NEW.mileage;
    
    -- Update vehicle mileage if inspection mileage is higher
    IF v_inspection_mileage > v_current_mileage THEN
      UPDATE vehicles
      SET 
        mileage = v_inspection_mileage,
        updated_at = now()
      WHERE id = NEW.vehicle_id;
      
      RAISE NOTICE 'Updated vehicle % mileage from % to %', NEW.vehicle_id, v_current_mileage, v_inspection_mileage;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for inspections to update vehicle mileage
DROP TRIGGER IF EXISTS tr_update_vehicle_mileage_from_inspection ON inspections;
CREATE TRIGGER tr_update_vehicle_mileage_from_inspection
  AFTER INSERT OR UPDATE ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_mileage_from_inspection();

-- ============================================================================
-- 3. FIX VEHICLE AVAILABILITY FOR FUTURE CONTRACTS
-- ============================================================================

-- Update the vehicle availability function to allow future contracts
CREATE OR REPLACE FUNCTION public.fn_available_vehicles(
  p_start_date date,
  p_end_date date,
  p_tenant_id uuid,
  p_exclude_contract_id uuid DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  plate text,
  model text,
  year integer,
  type text,
  status text
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.id,
    v.plate,
    v.model,
    v.year,
    v.type,
    v.status
  FROM public.vehicles v
  WHERE v.tenant_id = p_tenant_id
    AND v.status IN ('Disponível', 'Em Uso')
    AND NOT EXISTS (
      -- Check for active contracts that overlap with the requested period
      SELECT 1 
      FROM public.contracts c
      WHERE c.vehicle_id = v.id
        AND c.tenant_id = p_tenant_id
        AND c.status = 'Ativo'
        AND (
          (c.start_date <= p_end_date AND c.end_date >= p_start_date)
        )
        AND (p_exclude_contract_id IS NULL OR c.id != p_exclude_contract_id)
    )
    AND NOT EXISTS (
      -- Check for maintenance checkins that overlap with the requested period
      SELECT 1 
      FROM public.maintenance_checkins mc
      JOIN public.service_notes sn ON mc.service_note_id = sn.id
      WHERE sn.vehicle_id = v.id
        AND mc.tenant_id = p_tenant_id
        AND mc.checkout_at IS NULL
        AND (
          (mc.checkin_at::date <= p_end_date)
        )
    )
  ORDER BY v.plate;
END;
$$;

-- ============================================================================
-- 4. CREATE SIMPLE REPROCESSING FUNCTIONS
-- ============================================================================

-- Function to reprocess missing charges from inspections (simplified)
CREATE OR REPLACE FUNCTION fn_reprocess_missing_charges_simple()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER := 0;
  v_inspection RECORD;
  v_contract contracts%ROWTYPE;
  v_customer_id UUID;
  v_customer_name TEXT;
  v_checkout_inspection inspections%ROWTYPE;
  v_start_km INTEGER := 0;
  v_end_km INTEGER := 0;
  v_excess_km INTEGER := 0;
  v_excess_km_charge NUMERIC := 0;
BEGIN
  -- Find CheckIn inspections that have contract_id but no corresponding costs
  FOR v_inspection IN 
    SELECT i.* 
    FROM inspections i
    WHERE i.inspection_type = 'CheckIn' 
      AND i.contract_id IS NOT NULL
      AND i.tenant_id = '00000000-0000-0000-0000-000000000001'
      AND NOT EXISTS (
        SELECT 1 FROM costs c 
        WHERE c.contract_id = i.contract_id 
          AND c.category = 'Excesso Km'
          AND c.cost_date = i.inspected_at::date
      )
    LIMIT 10 -- Limit to avoid long running
  LOOP
    -- Load contract data
    SELECT * INTO v_contract FROM contracts WHERE id = v_inspection.contract_id;
    v_customer_id := v_contract.customer_id;
    SELECT name INTO v_customer_name FROM customers WHERE id = v_customer_id;

    -- Find corresponding CheckOut inspection
    SELECT * INTO v_checkout_inspection 
    FROM inspections 
    WHERE contract_id = v_inspection.contract_id 
      AND inspection_type = 'CheckOut' 
      AND vehicle_id = v_inspection.vehicle_id
    ORDER BY inspected_at DESC 
    LIMIT 1;

    -- Calculate excess km if possible
    IF v_checkout_inspection.id IS NOT NULL 
       AND v_inspection.mileage IS NOT NULL 
       AND v_checkout_inspection.mileage IS NOT NULL 
       AND v_contract.km_limit IS NOT NULL 
       AND v_contract.price_per_excess_km IS NOT NULL 
       AND v_contract.km_limit > 0 THEN
      
      v_start_km := v_checkout_inspection.mileage;
      v_end_km := v_inspection.mileage;
      v_excess_km := GREATEST(v_end_km - v_start_km - v_contract.km_limit, 0);
      v_excess_km_charge := v_excess_km * v_contract.price_per_excess_km;

      -- Create cost if there's excess km
      IF v_excess_km_charge > 0 THEN
        INSERT INTO costs(
          tenant_id, 
          department, 
          customer_id, 
          customer_name, 
          contract_id,
          category, 
          vehicle_id, 
          description, 
          amount, 
          cost_date, 
          status, 
          observations, 
          origin,
          created_at,
          updated_at
        ) VALUES (
          v_inspection.tenant_id, 
          'Cobrança', 
          v_customer_id, 
          v_customer_name, 
          v_inspection.contract_id,
          'Excesso Km', 
          v_inspection.vehicle_id,
          CONCAT('Excesso de ', v_excess_km, ' km — Cliente: ', v_customer_name),
          v_excess_km_charge, 
          v_inspection.inspected_at::date, 
          'Pendente',
          CONCAT('Contrato ', v_inspection.contract_id, ' - Km inicial: ', v_start_km, ', Km final: ', v_end_km, ' - Reprocessado'),
          'Sistema',
          now(),
          now()
        );
        v_count := v_count + 1;
      END IF;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 5. SUCCESS MESSAGE
-- ============================================================================

SELECT 'Critical issues have been fixed successfully!' as message; 