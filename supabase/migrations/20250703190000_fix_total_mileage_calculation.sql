-- SQL de diagnóstico para verificar se o trigger está funcionando
-- Execute este primeiro para verificar se tudo está funcionando corretamente

-- 1. Verificar se o trigger existe
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'tr_update_vehicle_mileage_on_checkout';

-- 2. Verificar se a função existe
SELECT 
    proname as function_name,
    prosrc as function_source
FROM pg_proc 
WHERE proname = 'fn_update_vehicle_mileage_on_checkout';

-- 3. Atualizar a função de cálculo de quilometragem total para incluir ordens de serviço
CREATE OR REPLACE FUNCTION fn_calculate_vehicle_total_mileage(p_vehicle_id uuid)
RETURNS numeric AS $$
DECLARE
  v_vehicle_mileage numeric;
  v_latest_inspection_mileage numeric;
  v_latest_service_note_mileage numeric;
  v_total_mileage numeric;
BEGIN
  -- Pegar quilometragem atual do veículo
  SELECT COALESCE(mileage, 0)
  INTO v_vehicle_mileage
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
    v_vehicle_mileage, 
    v_latest_inspection_mileage, 
    v_latest_service_note_mileage
  );

  RETURN v_total_mileage;
EXCEPTION
  WHEN OTHERS THEN
    -- Em caso de erro, retornar a quilometragem do veículo
    RETURN v_vehicle_mileage;
END;
$$ LANGUAGE plpgsql;

-- 4. Atualizar a função de trigger para também considerar ordens de serviço
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
      SELECT COALESCE(mileage, 0) INTO v_current_vehicle_mileage
      FROM vehicles
      WHERE id = v_vehicle_id;
      
      -- Só atualizar se a quilometragem da manutenção for maior que a atual
      IF v_service_note_mileage > v_current_vehicle_mileage THEN
        UPDATE vehicles
        SET 
          mileage = v_service_note_mileage,
          updated_at = now()
        WHERE id = v_vehicle_id;
        
        -- Log da atualização
        RAISE NOTICE 'Quilometragem do veículo % atualizada de % para % km no check-out da manutenção %', 
          v_vehicle_id, 
          v_current_vehicle_mileage, 
          v_service_note_mileage,
          NEW.service_note_id;
      ELSE
        -- Log quando não atualiza
        RAISE NOTICE 'Quilometragem do veículo % NÃO atualizada. Atual: % km, Manutenção: % km', 
          v_vehicle_id, 
          v_current_vehicle_mileage, 
          v_service_note_mileage;
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

-- 5. Recriar o trigger para garantir que está funcionando
DROP TRIGGER IF EXISTS tr_update_vehicle_mileage_on_checkout ON maintenance_checkins;
CREATE TRIGGER tr_update_vehicle_mileage_on_checkout
  AFTER UPDATE ON maintenance_checkins
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_mileage_on_checkout();

-- 6. Criar uma função auxiliar para testar o sistema
CREATE OR REPLACE FUNCTION fn_test_mileage_update(p_vehicle_id uuid)
RETURNS TABLE (
  vehicle_mileage numeric,
  max_inspection_mileage numeric,
  max_service_note_mileage numeric,
  calculated_total numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (SELECT COALESCE(mileage, 0) FROM vehicles WHERE id = p_vehicle_id),
    (SELECT COALESCE(MAX(mileage), 0) FROM inspections WHERE vehicle_id = p_vehicle_id AND mileage IS NOT NULL),
    (SELECT COALESCE(MAX(mileage), 0) FROM service_notes WHERE vehicle_id = p_vehicle_id AND mileage IS NOT NULL),
    fn_calculate_vehicle_total_mileage(p_vehicle_id);
END;
$$ LANGUAGE plpgsql;

-- Comentários
COMMENT ON FUNCTION fn_calculate_vehicle_total_mileage(uuid) IS 'Calcula a quilometragem total do veículo considerando veículo, inspeções e ordens de serviço';
COMMENT ON FUNCTION fn_test_mileage_update(uuid) IS 'Função de teste para verificar o cálculo de quilometragem total'; 