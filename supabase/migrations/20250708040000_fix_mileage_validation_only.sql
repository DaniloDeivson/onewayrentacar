-- ============================================================================
-- CORREÇÃO DA VALIDAÇÃO DE QUILOMETRAGEM
-- ============================================================================
-- Esta migração torna a validação de quilometragem mais flexível

-- Atualizar a função de validação de quilometragem para ser mais flexível
CREATE OR REPLACE FUNCTION fn_validate_inspection_mileage()
RETURNS TRIGGER AS $$
DECLARE
  v_current_vehicle_mileage NUMERIC;
  v_original_inspection_mileage NUMERIC;
  v_mileage_difference NUMERIC;
  v_allowed_tolerance NUMERIC := 0.10; -- 10% de tolerância
BEGIN
  -- Se não há quilometragem na inspeção, permitir
  IF NEW.mileage IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Obter quilometragem atual do veículo
  SELECT mileage INTO v_current_vehicle_mileage
  FROM vehicles
  WHERE id = NEW.vehicle_id;
  
  -- Se não conseguiu obter a quilometragem do veículo, permitir
  IF v_current_vehicle_mileage IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Se é uma atualização, verificar a quilometragem original
  IF TG_OP = 'UPDATE' THEN
    SELECT mileage INTO v_original_inspection_mileage
    FROM inspections
    WHERE id = NEW.id;
    
    -- Se a quilometragem original é menor que a atual do veículo, permitir correção
    IF v_original_inspection_mileage < v_current_vehicle_mileage THEN
      RETURN NEW;
    END IF;
  END IF;
  
  -- Calcular diferença percentual
  v_mileage_difference := ABS(NEW.mileage - v_current_vehicle_mileage) / v_current_vehicle_mileage;
  
  -- Permitir se a diferença está dentro da tolerância (10%)
  IF v_mileage_difference <= v_allowed_tolerance THEN
    RETURN NEW;
  END IF;
  
  -- Se a nova quilometragem é significativamente menor, verificar se é uma correção válida
  IF NEW.mileage < v_current_vehicle_mileage THEN
    -- Permitir correções que não sejam muito drásticas (máximo 20% menor)
    IF v_mileage_difference <= 0.20 THEN
      RAISE NOTICE 'Correção de quilometragem permitida';
      RETURN NEW;
    ELSE
      RAISE EXCEPTION 'A quilometragem não pode ser muito menor que a quilometragem atual do veículo. Quilometragem atual: % km, Valor informado: % km. Diferença máxima permitida: 20%%', 
                      v_current_vehicle_mileage, NEW.mileage;
    END IF;
  END IF;
  
  -- Se chegou até aqui, a quilometragem é maior, então permitir
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Verificar se a função foi atualizada
DO $$
BEGIN
  RAISE NOTICE 'Função fn_validate_inspection_mileage atualizada com sucesso!';
  RAISE NOTICE 'Agora permite correções de quilometragem dentro de margem razoável (20%%)';
END $$; 