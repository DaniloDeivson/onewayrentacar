-- Vehicle Deletion Safety - Prevent deletion of vehicles in active contracts
-- This migration implements safety checks and automatic contract deactivation

-- ============================================================================
-- 1. CREATE FUNCTION TO CHECK VEHICLE CONTRACT STATUS
-- ============================================================================

-- Function to check if vehicle is in active contract
CREATE OR REPLACE FUNCTION fn_check_vehicle_contract_status(p_vehicle_id UUID)
RETURNS TABLE (
  has_active_contract BOOLEAN,
  contract_id UUID,
  contract_number TEXT,
  customer_name TEXT,
  start_date DATE,
  end_date DATE,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    EXISTS(
      SELECT 1 FROM contract_vehicles cv
      JOIN contracts c ON c.id = cv.contract_id
      WHERE cv.vehicle_id = p_vehicle_id
        AND c.status = 'Ativo'
    ) as has_active_contract,
    c.id as contract_id,
    c.contract_number,
    cust.name as customer_name,
    c.start_date,
    c.end_date,
    c.status
  FROM contract_vehicles cv
  JOIN contracts c ON c.id = cv.contract_id
  JOIN customers cust ON cust.id = c.customer_id
  WHERE cv.vehicle_id = p_vehicle_id
    AND c.status = 'Ativo'
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 2. CREATE FUNCTION TO SAFELY DELETE VEHICLE
-- ============================================================================

-- Function to safely delete vehicle with contract deactivation
CREATE OR REPLACE FUNCTION fn_safe_delete_vehicle(p_vehicle_id UUID)
RETURNS JSON AS $$
DECLARE
  v_contract_info RECORD;
  v_result JSON;
  v_affected_contracts INTEGER := 0;
BEGIN
  -- Check if vehicle exists
  IF NOT EXISTS (SELECT 1 FROM vehicles WHERE id = p_vehicle_id) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Veículo não encontrado',
      'affected_contracts', 0
    );
  END IF;

  -- Get contract information
  SELECT * INTO v_contract_info
  FROM fn_check_vehicle_contract_status(p_vehicle_id);

  -- If vehicle has active contract, deactivate it
  IF v_contract_info.has_active_contract THEN
    -- Deactivate the contract
    UPDATE contracts 
    SET 
      status = 'Cancelado',
      updated_at = NOW()
    WHERE id = v_contract_info.contract_id;
    
    v_affected_contracts := 1;
    
    -- Remove driver-vehicle assignments for this contract
    UPDATE driver_vehicles 
    SET 
      active = false,
      removed_at = NOW()
    WHERE contract_id = v_contract_info.contract_id;
    
    RAISE NOTICE 'Contract % deactivated due to vehicle deletion', v_contract_info.contract_id;
  END IF;

  -- Now safely delete the vehicle
  DELETE FROM vehicles WHERE id = p_vehicle_id;

  -- Build result
  v_result := json_build_object(
    'success', true,
    'message', CASE 
      WHEN v_affected_contracts > 0 THEN 
        format('Veículo excluído. Contrato %s foi desativado automaticamente.', v_contract_info.contract_number)
      ELSE 
        'Veículo excluído com sucesso'
    END,
    'affected_contracts', v_affected_contracts,
    'contract_info', CASE 
      WHEN v_affected_contracts > 0 THEN 
        json_build_object(
          'contract_id', v_contract_info.contract_id,
          'contract_number', v_contract_info.contract_number,
          'customer_name', v_contract_info.customer_name,
          'start_date', v_contract_info.start_date,
          'end_date', v_contract_info.end_date
        )
      ELSE 
        NULL
    END
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 3. CREATE FUNCTION TO GET VEHICLE DELETION IMPACT
-- ============================================================================

-- Function to get impact analysis before vehicle deletion
CREATE OR REPLACE FUNCTION fn_get_vehicle_deletion_impact(p_vehicle_id UUID)
RETURNS JSON AS $$
DECLARE
  v_contract_info RECORD;
  v_driver_assignments INTEGER;
  v_inspections_count INTEGER;
  v_fuel_records_count INTEGER;
  v_fines_count INTEGER;
  v_result JSON;
BEGIN
  -- Check if vehicle exists
  IF NOT EXISTS (SELECT 1 FROM vehicles WHERE id = p_vehicle_id) THEN
    RETURN json_build_object(
      'vehicle_exists', false,
      'message', 'Veículo não encontrado'
    );
  END IF;

  -- Get contract information
  SELECT * INTO v_contract_info
  FROM fn_check_vehicle_contract_status(p_vehicle_id);

  -- Count related records
  SELECT COUNT(*) INTO v_driver_assignments
  FROM driver_vehicles 
  WHERE vehicle_id = p_vehicle_id AND active = true;

  SELECT COUNT(*) INTO v_inspections_count
  FROM inspections 
  WHERE vehicle_id = p_vehicle_id;

  SELECT COUNT(*) INTO v_fuel_records_count
  FROM fuel_records 
  WHERE vehicle_id = p_vehicle_id;

  SELECT COUNT(*) INTO v_fines_count
  FROM fines 
  WHERE vehicle_id = p_vehicle_id;

  -- Build impact analysis
  v_result := json_build_object(
    'vehicle_exists', true,
    'vehicle_plate', (SELECT plate FROM vehicles WHERE id = p_vehicle_id),
    'vehicle_model', (SELECT model FROM vehicles WHERE id = p_vehicle_id),
    'has_active_contract', v_contract_info.has_active_contract,
    'contract_info', CASE 
      WHEN v_contract_info.has_active_contract THEN 
        json_build_object(
          'contract_id', v_contract_info.contract_id,
          'contract_number', v_contract_info.contract_number,
          'customer_name', v_contract_info.customer_name,
          'start_date', v_contract_info.start_date,
          'end_date', v_contract_info.end_date,
          'status', v_contract_info.status
        )
      ELSE 
        NULL
    END,
    'impact_summary', json_build_object(
      'active_driver_assignments', v_driver_assignments,
      'total_inspections', v_inspections_count,
      'total_fuel_records', v_fuel_records_count,
      'total_fines', v_fines_count
    ),
    'warning_message', CASE 
      WHEN v_contract_info.has_active_contract THEN 
        format('ATENÇÃO: Este veículo está em contrato ativo (%s) com %s. A exclusão desativará automaticamente o contrato.', 
               v_contract_info.contract_number, v_contract_info.customer_name)
      ELSE 
        'Este veículo não possui contratos ativos.'
    END
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. CREATE TRIGGER TO PREVENT DIRECT VEHICLE DELETION
-- ============================================================================

-- Function to prevent direct vehicle deletion
CREATE OR REPLACE FUNCTION fn_prevent_vehicle_deletion()
RETURNS TRIGGER AS $$
DECLARE
  v_contract_info RECORD;
BEGIN
  -- Check if vehicle has active contract
  SELECT * INTO v_contract_info
  FROM fn_check_vehicle_contract_status(OLD.id);

  IF v_contract_info.has_active_contract THEN
    RAISE EXCEPTION 
      'Não é possível excluir veículo diretamente. Use fn_safe_delete_vehicle() para excluir veículos em contrato ativo. 
       Contrato afetado: % - Cliente: %', 
      v_contract_info.contract_number, 
      v_contract_info.customer_name;
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to prevent direct deletion
DROP TRIGGER IF EXISTS tr_prevent_vehicle_deletion ON vehicles;
CREATE TRIGGER tr_prevent_vehicle_deletion
  BEFORE DELETE ON vehicles
  FOR EACH ROW
  EXECUTE FUNCTION fn_prevent_vehicle_deletion();

-- ============================================================================
-- 5. CREATE FUNCTION TO BULK DELETE VEHICLES SAFELY
-- ============================================================================

-- Function to safely delete multiple vehicles
CREATE OR REPLACE FUNCTION fn_safe_delete_vehicles(p_vehicle_ids UUID[])
RETURNS JSON AS $$
DECLARE
  v_vehicle_id UUID;
  v_result JSON;
  v_total_results JSON := '[]'::json;
  v_success_count INTEGER := 0;
  v_error_count INTEGER := 0;
BEGIN
  -- Process each vehicle
  FOREACH v_vehicle_id IN ARRAY p_vehicle_ids
  LOOP
    BEGIN
      v_result := fn_safe_delete_vehicle(v_vehicle_id);
      v_total_results := v_total_results || v_result;
      
      IF (v_result->>'success')::boolean THEN
        v_success_count := v_success_count + 1;
      ELSE
        v_error_count := v_error_count + 1;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        v_error_count := v_error_count + 1;
        v_total_results := v_total_results || json_build_object(
          'success', false,
          'vehicle_id', v_vehicle_id,
          'message', SQLERRM
        );
    END;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'summary', json_build_object(
      'total_vehicles', array_length(p_vehicle_ids, 1),
      'successful_deletions', v_success_count,
      'failed_deletions', v_error_count
    ),
    'results', v_total_results
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 6. SUCCESS MESSAGE
-- ============================================================================

SELECT 'Vehicle deletion safety system has been implemented successfully!' as message; 