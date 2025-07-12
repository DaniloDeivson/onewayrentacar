-- Fix Vehicle Availability Function Overload and Support Future Contracts
-- This migration resolves the function overload issue and allows future contracts

-- 1. Drop all existing fn_available_vehicles functions to resolve overload
DROP FUNCTION IF EXISTS public.fn_available_vehicles(date, date, uuid, uuid);
DROP FUNCTION IF EXISTS public.fn_available_vehicles(text, text, uuid, uuid);
DROP FUNCTION IF EXISTS public.fn_available_vehicles(date, date, uuid);
DROP FUNCTION IF EXISTS public.fn_available_vehicles(text, text, uuid);

-- 2. Create a single, unified function that accepts text dates and converts them
CREATE OR REPLACE FUNCTION public.fn_available_vehicles(
  p_start_date text,
  p_end_date text,
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
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
DECLARE
  v_start_date date;
  v_end_date date;
BEGIN
  -- Convert text to date with validation
  BEGIN
    v_start_date := p_start_date::date;
    v_end_date := p_end_date::date;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Datas inválidas: % e %', p_start_date, p_end_date;
  END;

  -- Validate date range
  IF v_start_date >= v_end_date THEN
    RAISE EXCEPTION 'Data de início deve ser anterior à data de fim';
  END IF;

  -- Return available vehicles for the date range
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
          (c.start_date <= v_end_date AND c.end_date >= v_start_date)
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
          (mc.checkin_at::date <= v_end_date)
        )
    )
  ORDER BY v.plate;
END;
$$;

-- 3. Create a function to check individual vehicle availability
CREATE OR REPLACE FUNCTION public.fn_check_vehicle_availability(
  p_vehicle_id uuid,
  p_start_date text,
  p_end_date text,
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
  v_start_date date;
  v_end_date date;
  v_contract_conflict uuid;
  v_maintenance_conflict uuid;
  v_vehicle_status text;
BEGIN
  -- Convert text to date
  v_start_date := p_start_date::date;
  v_end_date := p_end_date::date;

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
    AND (c.start_date <= v_end_date AND c.end_date >= v_start_date)
    AND (p_exclude_contract_id IS NULL OR c.id != p_exclude_contract_id)
  LIMIT 1;

  -- Check for maintenance conflicts
  SELECT mc.id INTO v_maintenance_conflict
  FROM public.maintenance_checkins mc
  JOIN public.service_notes sn ON mc.service_note_id = sn.id
  WHERE sn.vehicle_id = p_vehicle_id
    AND mc.tenant_id = p_tenant_id
    AND mc.checkout_at IS NULL
    AND (mc.checkin_at::date <= v_end_date)
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

-- 4. Create a function to get all available vehicles (for backward compatibility)
CREATE OR REPLACE FUNCTION public.fn_get_all_available_vehicles(
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid
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
  ORDER BY v.plate;
END;
$$;

-- 5. Create a function to validate contract dates for future contracts
CREATE OR REPLACE FUNCTION public.fn_validate_future_contract(
  p_vehicle_id uuid,
  p_start_date text,
  p_end_date text,
  p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
  p_exclude_contract_id uuid DEFAULT NULL
)
RETURNS TABLE (
  is_valid boolean,
  message text,
  conflicts jsonb
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_start_date date;
  v_end_date date;
  v_conflicts jsonb;
  v_availability RECORD;
BEGIN
  -- Convert text to date
  v_start_date := p_start_date::date;
  v_end_date := p_end_date::date;

  -- Check if dates are in the future
  IF v_start_date <= CURRENT_DATE THEN
    RETURN QUERY SELECT false, 'Data de início deve ser futura', '[]'::jsonb;
    RETURN;
  END IF;

  -- Check vehicle availability
  SELECT * INTO v_availability
  FROM fn_check_vehicle_availability(
    p_vehicle_id, 
    p_start_date, 
    p_end_date, 
    p_tenant_id, 
    p_exclude_contract_id
  );

  -- Build conflicts object
  v_conflicts := jsonb_build_object(
    'contract_conflicts', (
      SELECT jsonb_agg(jsonb_build_object(
        'contract_id', c.id,
        'contract_number', c.contract_number,
        'customer_name', cu.name,
        'start_date', c.start_date,
        'end_date', c.end_date
      ))
      FROM contracts c
      JOIN customers cu ON cu.id = c.customer_id
      WHERE c.vehicle_id = p_vehicle_id
        AND c.tenant_id = p_tenant_id
        AND c.status = 'Ativo'
        AND (c.start_date <= v_end_date AND c.end_date >= v_start_date)
        AND (p_exclude_contract_id IS NULL OR c.id != p_exclude_contract_id)
    ),
    'maintenance_conflicts', (
      SELECT jsonb_agg(jsonb_build_object(
        'maintenance_id', mc.id,
        'checkin_at', mc.checkin_at,
        'service_note_id', mc.service_note_id
      ))
      FROM maintenance_checkins mc
      JOIN service_notes sn ON mc.service_note_id = sn.id
      WHERE sn.vehicle_id = p_vehicle_id
        AND mc.tenant_id = p_tenant_id
        AND mc.checkout_at IS NULL
        AND (mc.checkin_at::date <= v_end_date)
    )
  );

  -- Return validation result
  IF v_availability.is_available THEN
    RETURN QUERY SELECT true, 'Contrato futuro válido', v_conflicts;
  ELSE
    RETURN QUERY SELECT false, v_availability.conflict_reason, v_conflicts;
  END IF;
END;
$$;

-- 6. Test the functions
SELECT 'Testing fn_available_vehicles with text dates' as test;
SELECT * FROM fn_available_vehicles(
  '2025-01-01',
  '2025-01-31',
  '00000000-0000-0000-0000-000000000001'::uuid,
  NULL
);

SELECT 'Testing fn_get_all_available_vehicles' as test;
SELECT * FROM fn_get_all_available_vehicles();

-- 7. Show function status
SELECT 
  'Function Status' as test,
  proname as function_name,
  CASE 
    WHEN prosrc IS NOT NULL THEN '✅ Created'
    ELSE '❌ Missing'
  END as status
FROM pg_proc 
WHERE proname IN ('fn_available_vehicles', 'fn_get_all_available_vehicles', 'fn_check_vehicle_availability', 'fn_validate_future_contract'); 