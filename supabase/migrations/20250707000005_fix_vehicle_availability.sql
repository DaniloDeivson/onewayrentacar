-- Fix Vehicle Availability - Ensure vehicle availability is properly checked for contracts
-- This migration fixes the issue where vehicle availability is not being properly validated

-- 1. Drop and recreate the vehicle availability function with proper logic
DROP FUNCTION IF EXISTS public.fn_available_vehicles(date, date, uuid, uuid);

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

-- 2. Create a function to check vehicle availability for specific dates
CREATE OR REPLACE FUNCTION public.fn_check_vehicle_availability(
  p_vehicle_id uuid,
  p_start_date date,
  p_end_date date,
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
  p_exclude_contract_id uuid DEFAULT NULL
)
RETURNS TABLE (
  is_available boolean,
  conflict_reason text,
  conflicting_contract_id uuid,
  conflicting_maintenance_id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_contract_conflict uuid;
  v_maintenance_conflict uuid;
  v_vehicle_status text;
BEGIN
  -- Check vehicle status
  SELECT status INTO v_vehicle_status
  FROM vehicles
  WHERE id = p_vehicle_id AND tenant_id = p_tenant_id;
  
  -- If vehicle is inactive, it's not available
  IF v_vehicle_status = 'Inativo' OR v_vehicle_status IS NULL THEN
    RETURN QUERY SELECT false, 'Veículo inativo', NULL::uuid, NULL::uuid;
    RETURN;
  END IF;
  
  -- Check for contract conflicts
  SELECT c.id INTO v_contract_conflict
  FROM public.contracts c
  WHERE c.vehicle_id = p_vehicle_id
    AND c.tenant_id = p_tenant_id
    AND c.status = 'Ativo'
    AND (c.start_date <= p_end_date AND c.end_date >= p_start_date)
    AND (p_exclude_contract_id IS NULL OR c.id != p_exclude_contract_id)
  LIMIT 1;

  -- Check for maintenance conflicts
  SELECT mc.id INTO v_maintenance_conflict
  FROM public.maintenance_checkins mc
  JOIN public.service_notes sn ON mc.service_note_id = sn.id
  WHERE sn.vehicle_id = p_vehicle_id
    AND mc.tenant_id = p_tenant_id
    AND mc.checkout_at IS NULL
    AND (mc.checkin_at::date <= p_end_date)
  LIMIT 1;

  -- Return availability status
  IF v_contract_conflict IS NOT NULL THEN
    RETURN QUERY SELECT false, 'Em contrato ativo', v_contract_conflict, NULL::uuid;
  ELSIF v_maintenance_conflict IS NOT NULL THEN
    RETURN QUERY SELECT false, 'Em manutenção', NULL::uuid, v_maintenance_conflict;
  ELSE
    RETURN QUERY SELECT true, 'Disponível', NULL::uuid, NULL::uuid;
  END IF;
END;
$$;

-- 3. Create a function to validate contract dates before insertion/update
CREATE OR REPLACE FUNCTION fn_validate_contract_availability()
RETURNS TRIGGER AS $$
DECLARE
  v_availability RECORD;
  v_conflict_info RECORD;
BEGIN
  -- Skip validation for cancelled contracts
  IF NEW.status = 'Cancelado' THEN
    RETURN NEW;
  END IF;
  
  -- Check availability for single vehicle contracts
  IF NOT NEW.uses_multiple_vehicles AND NEW.vehicle_id IS NOT NULL THEN
    SELECT * INTO v_availability
    FROM fn_check_vehicle_availability(
      NEW.vehicle_id, 
      NEW.start_date, 
      NEW.end_date, 
      NEW.tenant_id, 
      CASE WHEN TG_OP = 'UPDATE' THEN OLD.id ELSE NULL END
    );
    
    IF NOT v_availability.is_available THEN
      -- Get conflict details
      IF v_availability.conflicting_contract_id IS NOT NULL THEN
        SELECT 
          c.id,
          c.contract_number,
          cu.name as customer_name,
          c.start_date,
          c.end_date
        INTO v_conflict_info
        FROM contracts c
        JOIN customers cu ON cu.id = c.customer_id
        WHERE c.id = v_availability.conflicting_contract_id;
        
        RAISE EXCEPTION 'Veículo não disponível no período solicitado. Conflito com contrato % (% - % a %) do cliente %', 
          v_conflict_info.contract_number,
          v_conflict_info.customer_name,
          v_conflict_info.start_date,
          v_conflict_info.end_date,
          v_conflict_info.customer_name;
      ELSIF v_availability.conflicting_maintenance_id IS NOT NULL THEN
        RAISE EXCEPTION 'Veículo não disponível no período solicitado. Veículo em manutenção.';
      ELSE
        RAISE EXCEPTION 'Veículo não disponível no período solicitado. %', v_availability.conflict_reason;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Create trigger for contract validation
DROP TRIGGER IF EXISTS tr_validate_contract_availability ON contracts;
CREATE TRIGGER tr_validate_contract_availability
  BEFORE INSERT OR UPDATE ON contracts
  FOR EACH ROW
  EXECUTE FUNCTION fn_validate_contract_availability();

-- 5. Create a function to check multiple vehicle availability
CREATE OR REPLACE FUNCTION fn_check_multiple_vehicle_availability(
  p_vehicle_ids uuid[],
  p_start_date date,
  p_end_date date,
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
  p_exclude_contract_id uuid DEFAULT NULL
)
RETURNS TABLE (
  vehicle_id uuid,
  plate text,
  model text,
  year integer,
  is_available boolean,
  conflict_reason text,
  conflicting_contract_id uuid,
  conflicting_maintenance_id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_vehicle_id uuid;
  v_availability RECORD;
BEGIN
  FOREACH v_vehicle_id IN ARRAY p_vehicle_ids
  LOOP
    SELECT * INTO v_availability
    FROM fn_check_vehicle_availability(
      v_vehicle_id, 
      p_start_date, 
      p_end_date, 
      p_tenant_id, 
      p_exclude_contract_id
    );
    
    RETURN QUERY
    SELECT 
      v_vehicle_id,
      v.plate,
      v.model,
      v.year,
      v_availability.is_available,
      v_availability.conflict_reason,
      v_availability.conflicting_contract_id,
      v_availability.conflicting_maintenance_id
    FROM vehicles v
    WHERE v.id = v_vehicle_id;
  END LOOP;
END;
$$;

-- 6. Create a function to get vehicle availability calendar
CREATE OR REPLACE FUNCTION fn_get_vehicle_availability_calendar(
  p_vehicle_id uuid,
  p_start_date date,
  p_end_date date,
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid
)
RETURNS TABLE (
  date date,
  is_available boolean,
  contract_id uuid,
  contract_number text,
  customer_name text,
  maintenance_id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_current_date date;
  v_contract_info RECORD;
  v_maintenance_info RECORD;
BEGIN
  v_current_date := p_start_date;
  
  WHILE v_current_date <= p_end_date LOOP
    -- Check for contracts on this date
    SELECT 
      c.id,
      c.contract_number,
      cu.name
    INTO v_contract_info
    FROM contracts c
    JOIN customers cu ON cu.id = c.customer_id
    WHERE c.vehicle_id = p_vehicle_id
      AND c.tenant_id = p_tenant_id
      AND c.status = 'Ativo'
      AND c.start_date <= v_current_date
      AND c.end_date >= v_current_date
    LIMIT 1;
    
    -- Check for maintenance on this date
    SELECT mc.id
    INTO v_maintenance_info
    FROM maintenance_checkins mc
    JOIN service_notes sn ON mc.service_note_id = sn.id
    WHERE sn.vehicle_id = p_vehicle_id
      AND mc.tenant_id = p_tenant_id
      AND mc.checkout_at IS NULL
      AND mc.checkin_at::date <= v_current_date
    LIMIT 1;
    
    RETURN QUERY SELECT 
      v_current_date,
      v_contract_info.id IS NULL AND v_maintenance_info.id IS NULL,
      v_contract_info.id,
      v_contract_info.contract_number,
      v_contract_info.name,
      v_maintenance_info.id;
    
    v_current_date := v_current_date + INTERVAL '1 day';
  END LOOP;
END;
$$;

-- 7. Create a function to find available vehicles for a date range
CREATE OR REPLACE FUNCTION fn_find_available_vehicles_for_range(
  p_start_date date,
  p_end_date date,
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
  p_vehicle_type text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  plate text,
  model text,
  year integer,
  type text,
  status text,
  availability_percentage numeric
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_vehicle RECORD;
  v_total_days integer;
  v_available_days integer;
  v_calendar RECORD;
BEGIN
  v_total_days := (p_end_date - p_start_date + 1);
  
  FOR v_vehicle IN 
    SELECT v.*
    FROM vehicles v
    WHERE v.tenant_id = p_tenant_id
      AND v.status IN ('Disponível', 'Em Uso')
      AND (p_vehicle_type IS NULL OR v.type = p_vehicle_type)
  LOOP
    v_available_days := 0;
    
    -- Count available days for this vehicle
    FOR v_calendar IN 
      SELECT * FROM fn_get_vehicle_availability_calendar(
        v_vehicle.id, 
        p_start_date, 
        p_end_date, 
        p_tenant_id
      )
    LOOP
      IF v_calendar.is_available THEN
        v_available_days := v_available_days + 1;
      END IF;
    END LOOP;
    
    -- Only return vehicles that have at least some availability
    IF v_available_days > 0 THEN
      RETURN QUERY SELECT 
        v_vehicle.id,
        v_vehicle.plate,
        v_vehicle.model,
        v_vehicle.year,
        v_vehicle.type,
        v_vehicle.status,
        ROUND((v_available_days::numeric / v_total_days::numeric) * 100, 2);
    END IF;
  END LOOP;
END;
$$;

-- 8. Create a function to validate contract vehicle changes
CREATE OR REPLACE FUNCTION fn_validate_contract_vehicle_change()
RETURNS TRIGGER AS $$
DECLARE
  v_availability RECORD;
BEGIN
  -- Only validate if vehicle_id changed
  IF TG_OP = 'UPDATE' AND OLD.vehicle_id = NEW.vehicle_id THEN
    RETURN NEW;
  END IF;
  
  -- Check availability for the new vehicle
  SELECT * INTO v_availability
  FROM fn_check_vehicle_availability(
    NEW.vehicle_id, 
    NEW.start_date, 
    NEW.end_date, 
    NEW.tenant_id, 
    NEW.id
  );
  
  IF NOT v_availability.is_available THEN
    RAISE EXCEPTION 'Veículo não disponível no período do contrato. %', v_availability.conflict_reason;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 9. Create trigger for contract vehicle changes
DROP TRIGGER IF EXISTS tr_validate_contract_vehicle_change ON contracts;
CREATE TRIGGER tr_validate_contract_vehicle_change
  BEFORE UPDATE ON contracts
  FOR EACH ROW
  EXECUTE FUNCTION fn_validate_contract_vehicle_change();

-- 10. Test the availability functions
SELECT 'Testing vehicle availability functions...' as status;

-- Test basic availability
SELECT * FROM fn_available_vehicles(
  '2025-01-01'::date,
  '2025-01-10'::date,
  '00000000-0000-0000-0000-000000000001'::uuid
) LIMIT 5;

-- Test availability calendar for a specific vehicle
SELECT * FROM fn_get_vehicle_availability_calendar(
  (SELECT id FROM vehicles WHERE tenant_id = '00000000-0000-0000-0000-000000000001' LIMIT 1),
  '2025-01-01'::date,
  '2025-01-31'::date
) LIMIT 10; 