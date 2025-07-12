-- Adicionar campo para preservar quilometragem inicial
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS initial_mileage numeric DEFAULT 0;

-- Migrar dados existentes: preservar a quilometragem atual como inicial
UPDATE vehicles 
SET initial_mileage = COALESCE(mileage, 0)
WHERE initial_mileage IS NULL OR initial_mileage = 0;

-- Atualizar a função de cálculo para usar initial_mileage como base
CREATE OR REPLACE FUNCTION fn_calculate_vehicle_total_mileage(p_vehicle_id uuid)
RETURNS numeric AS $$
DECLARE
  v_initial_mileage numeric;
  v_current_mileage numeric;
  v_latest_inspection_mileage numeric;
  v_latest_service_note_mileage numeric;
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

  -- Retornar o maior valor entre todas as fontes
  v_total_mileage := GREATEST(
    v_initial_mileage,
    v_current_mileage,
    v_latest_inspection_mileage, 
    v_latest_service_note_mileage
  );

  RETURN v_total_mileage;
END;
$$ LANGUAGE plpgsql;

-- Modificar o trigger para não alterar a quilometragem inicial
CREATE OR REPLACE FUNCTION fn_update_vehicle_mileage_on_checkout()
RETURNS TRIGGER AS $$
DECLARE
  v_vehicle_id uuid;
  v_service_note_mileage numeric;
  v_current_vehicle_mileage numeric;
  v_initial_mileage numeric;
BEGIN
  -- Só processar quando for um check-out (checkout_at foi definido)
  IF NEW.checkout_at IS NOT NULL AND OLD.checkout_at IS NULL THEN
    -- Buscar o vehicle_id e a quilometragem da service_note
    SELECT sn.vehicle_id, sn.mileage
    INTO v_vehicle_id, v_service_note_mileage
    FROM service_notes sn
    WHERE sn.id = NEW.service_note_id;
    
    -- Se temos vehicle_id e quilometragem registrada na ordem de serviço
    IF v_vehicle_id IS NOT NULL AND v_service_note_mileage IS NOT NULL THEN
      -- Buscar quilometragem atual e inicial do veículo
      SELECT COALESCE(mileage, 0), COALESCE(initial_mileage, 0)
      INTO v_current_vehicle_mileage, v_initial_mileage
      FROM vehicles
      WHERE id = v_vehicle_id;
      
      -- Se initial_mileage não foi definida ainda, definir como a quilometragem atual
      IF v_initial_mileage = 0 AND v_current_vehicle_mileage > 0 THEN
        UPDATE vehicles
        SET initial_mileage = v_current_vehicle_mileage
        WHERE id = v_vehicle_id;
        v_initial_mileage := v_current_vehicle_mileage;
      END IF;
      
      -- Só atualizar se a quilometragem da manutenção for maior que a atual
      IF v_service_note_mileage > v_current_vehicle_mileage THEN
        UPDATE vehicles
        SET 
          mileage = v_service_note_mileage,
          updated_at = now()
        WHERE id = v_vehicle_id;
        
        -- Log da atualização
        RAISE NOTICE 'Quilometragem do veículo % atualizada de % para % km (inicial: % km)', 
          v_vehicle_id, 
          v_current_vehicle_mileage, 
          v_service_note_mileage,
          v_initial_mileage;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Erro ao atualizar quilometragem do veículo no check-out da manutenção: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar uma view para facilitar consultas com quilometragem inicial e total
CREATE OR REPLACE VIEW vw_vehicles_with_mileage AS
SELECT 
  v.*,
  v.initial_mileage as original_mileage,
  fn_calculate_vehicle_total_mileage(v.id) as total_mileage,
  v.mileage as current_mileage
FROM vehicles v;

-- Função para definir quilometragem inicial de um veículo (usar apenas no cadastro)
CREATE OR REPLACE FUNCTION fn_set_initial_mileage(p_vehicle_id uuid, p_initial_mileage numeric)
RETURNS void AS $$
BEGIN
  UPDATE vehicles 
  SET 
    initial_mileage = p_initial_mileage,
    mileage = GREATEST(COALESCE(mileage, 0), p_initial_mileage),
    updated_at = now()
  WHERE id = p_vehicle_id;
END;
$$ LANGUAGE plpgsql;

-- Comentários
COMMENT ON COLUMN vehicles.initial_mileage IS 'Quilometragem inicial/original do veículo no momento do cadastro';
COMMENT ON FUNCTION fn_set_initial_mileage(uuid, numeric) IS 'Define a quilometragem inicial de um veículo (usar apenas no cadastro/edição manual)';
COMMENT ON VIEW vw_vehicles_with_mileage IS 'View com quilometragem inicial, atual e total calculada do veículo'; 