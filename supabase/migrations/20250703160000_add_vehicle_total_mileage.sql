-- Função para calcular a quilometragem total de um veículo
CREATE OR REPLACE FUNCTION fn_calculate_vehicle_total_mileage(p_vehicle_id uuid)
RETURNS numeric AS $$
DECLARE
  v_total_mileage numeric;
  v_initial_mileage numeric;
  v_latest_inspection_mileage numeric;
BEGIN
  -- Pegar quilometragem inicial do veículo
  SELECT COALESCE(mileage, 0)
  INTO v_initial_mileage
  FROM vehicles
  WHERE id = p_vehicle_id;

  -- Pegar a última quilometragem registrada em inspeções
  SELECT COALESCE(MAX(mileage), 0)
  INTO v_latest_inspection_mileage
  FROM inspections
  WHERE vehicle_id = p_vehicle_id
  AND mileage IS NOT NULL;

  -- Retornar o maior valor entre a quilometragem inicial e a última registrada
  RETURN GREATEST(v_initial_mileage, v_latest_inspection_mileage);
EXCEPTION
  WHEN OTHERS THEN
    -- Em caso de erro, retornar a quilometragem inicial
    RETURN v_initial_mileage;
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar a quilometragem do veículo após uma inspeção
CREATE OR REPLACE FUNCTION fn_update_vehicle_mileage()
RETURNS TRIGGER AS $$
BEGIN
  -- Se houver quilometragem na inspeção
  IF NEW.mileage IS NOT NULL THEN
    -- Atualizar a quilometragem do veículo se for maior que a atual
    UPDATE vehicles
    SET mileage = NEW.mileage,
        updated_at = NOW()
    WHERE id = NEW.vehicle_id
    AND (mileage IS NULL OR mileage < NEW.mileage);
  END IF;
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Erro ao atualizar quilometragem do veículo: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar o trigger na tabela de inspeções
DROP TRIGGER IF EXISTS tr_update_vehicle_mileage ON inspections;
CREATE TRIGGER tr_update_vehicle_mileage
  AFTER INSERT OR UPDATE ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_mileage(); 