-- Função para atualizar a quilometragem do veículo no check-out de manutenção
CREATE OR REPLACE FUNCTION fn_update_vehicle_mileage_on_checkout()
RETURNS TRIGGER AS $$
DECLARE
  v_vehicle_id uuid;
  v_service_note_mileage numeric;
  v_current_vehicle_mileage numeric;
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
      -- Buscar a quilometragem atual do veículo
      SELECT mileage INTO v_current_vehicle_mileage
      FROM vehicles
      WHERE id = v_vehicle_id;
      
      -- Só atualizar se a quilometragem da manutenção for maior que a atual
      IF v_current_vehicle_mileage IS NULL OR v_service_note_mileage > v_current_vehicle_mileage THEN
        UPDATE vehicles
        SET 
          mileage = v_service_note_mileage,
          updated_at = now()
        WHERE id = v_vehicle_id;
        
        -- Log da atualização
        RAISE NOTICE 'Quilometragem do veículo % atualizada de % para % km no check-out da manutenção %', 
          v_vehicle_id, 
          COALESCE(v_current_vehicle_mileage, 0), 
          v_service_note_mileage,
          NEW.service_note_id;
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

-- Criar o trigger para atualizar quilometragem no check-out
DROP TRIGGER IF EXISTS tr_update_vehicle_mileage_on_checkout ON maintenance_checkins;
CREATE TRIGGER tr_update_vehicle_mileage_on_checkout
  AFTER UPDATE ON maintenance_checkins
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_mileage_on_checkout();

-- Comentário explicativo
COMMENT ON FUNCTION fn_update_vehicle_mileage_on_checkout() IS 'Atualiza a quilometragem do veículo com base na quilometragem registrada na ordem de serviço quando um check-out de manutenção é realizado';
COMMENT ON TRIGGER tr_update_vehicle_mileage_on_checkout ON maintenance_checkins IS 'Trigger que atualiza a quilometragem do veículo no check-out de manutenção'; 