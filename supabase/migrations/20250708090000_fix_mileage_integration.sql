-- ============================================================================
-- CORREÇÃO DA INTEGRAÇÃO DE QUILOMETRAGEM
-- ============================================================================
-- Esta migração melhora a integração da quilometragem considerando
-- todos os registros: veículo, inspeções, ordens de serviço e abastecimentos

-- Atualizar a função de cálculo para incluir registros de abastecimento
CREATE OR REPLACE FUNCTION fn_calculate_vehicle_total_mileage(p_vehicle_id uuid)
RETURNS numeric AS $$
DECLARE
  v_initial_mileage numeric;
  v_current_mileage numeric;
  v_latest_inspection_mileage numeric;
  v_latest_service_note_mileage numeric;
  v_latest_fuel_record_mileage numeric;
  v_total_mileage numeric;
BEGIN
  -- Pegar quilometragem inicial (original do veículo)
  SELECT COALESCE(initial_mileage, 0), COALESCE(mileage, 0)
  INTO v_initial_mileage, v_current_mileage
  FROM vehicles
  WHERE id = p_vehicle_id;

  -- Pegar a maior quilometragem registrada em inspeções
  SELECT COALESCE(MAX(mileage), 0)
  INTO v_latest_inspection_mileage
  FROM inspections
  WHERE vehicle_id = p_vehicle_id
  AND mileage IS NOT NULL;

  -- Pegar a maior quilometragem registrada em ordens de serviço
  SELECT COALESCE(MAX(mileage), 0)
  INTO v_latest_service_note_mileage
  FROM service_notes
  WHERE vehicle_id = p_vehicle_id
  AND mileage IS NOT NULL;

  -- Pegar a maior quilometragem registrada em abastecimentos
  SELECT COALESCE(MAX(mileage), 0)
  INTO v_latest_fuel_record_mileage
  FROM fuel_records
  WHERE vehicle_id = p_vehicle_id
  AND mileage IS NOT NULL;

  -- Retornar o maior valor entre todas as fontes
  v_total_mileage := GREATEST(
    v_initial_mileage,
    v_current_mileage,
    v_latest_inspection_mileage, 
    v_latest_service_note_mileage,
    v_latest_fuel_record_mileage
  );

  RETURN v_total_mileage;
END;
$$ LANGUAGE plpgsql;

-- Criar uma função para sincronizar quilometragens de abastecimentos
CREATE OR REPLACE FUNCTION fn_sync_fuel_record_mileages()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER := 0;
  v_fuel_record RECORD;
  v_current_mileage NUMERIC;
BEGIN
  -- Processar registros de abastecimento com quilometragem
  FOR v_fuel_record IN 
    SELECT 
      fr.id,
      fr.vehicle_id,
      fr.mileage as fuel_mileage,
      v.plate,
      v.mileage as current_mileage
    FROM fuel_records fr
    JOIN vehicles v ON v.id = fr.vehicle_id
    WHERE fr.mileage IS NOT NULL
      AND fr.mileage > 0
      AND fr.tenant_id = '00000000-0000-0000-0000-000000000001'
  LOOP
    v_current_mileage := COALESCE(v_fuel_record.current_mileage, 0);
    
    -- Atualizar quilometragem do veículo se a do abastecimento for maior
    IF v_fuel_record.fuel_mileage > v_current_mileage THEN
      UPDATE vehicles
      SET 
        mileage = v_fuel_record.fuel_mileage,
        updated_at = now()
      WHERE id = v_fuel_record.vehicle_id;
      
      v_count := v_count + 1;
      RAISE NOTICE 'Updated vehicle % (%) mileage from % to % via fuel record', 
        v_fuel_record.plate, v_fuel_record.vehicle_id, v_current_mileage, v_fuel_record.fuel_mileage;
    END IF;
  END LOOP;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Executar a sincronização de quilometragens de abastecimentos
SELECT 'Syncing fuel record mileages...' as status;
SELECT fn_sync_fuel_record_mileages() as updated_vehicles;

-- Comentários
COMMENT ON FUNCTION fn_calculate_vehicle_total_mileage(uuid) IS 'Calcula a quilometragem total do veículo considerando veículo, inspeções, ordens de serviço e abastecimentos';
COMMENT ON FUNCTION fn_sync_fuel_record_mileages() IS 'Sincroniza quilometragens de registros de abastecimento com a quilometragem do veículo'; 