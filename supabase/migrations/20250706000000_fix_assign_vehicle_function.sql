-- Fix assign_vehicle_to_driver function
CREATE OR REPLACE FUNCTION assign_vehicle_to_driver(
    p_driver_id UUID,
    p_vehicle_id UUID
) RETURNS driver_vehicles AS $$
DECLARE
    result_record driver_vehicles;
BEGIN
    -- Verificar se o usuário é um motorista
    IF NOT EXISTS (
        SELECT 1 FROM employees 
        WHERE id = p_driver_id 
        AND (
            role = 'Driver' 
            OR 'Driver' = ANY(roles_extra)
            OR permissions->>'fleet' = 'true'
        )
    ) THEN
        RAISE EXCEPTION 'Usuário não tem permissão de motorista';
    END IF;

    -- Verificar se a associação já existe
    SELECT * INTO result_record 
    FROM driver_vehicles 
    WHERE driver_id = p_driver_id 
    AND vehicle_id = p_vehicle_id;
    
    -- Se já existe, apenas retornar o registro existente
    IF FOUND THEN
        -- Reativar se estava inativo
        UPDATE driver_vehicles 
        SET active = true, assigned_at = NOW()
        WHERE driver_id = p_driver_id 
        AND vehicle_id = p_vehicle_id
        RETURNING * INTO result_record;
        
        RETURN result_record;
    END IF;

    -- Inserir nova associação
    INSERT INTO driver_vehicles (driver_id, vehicle_id, active)
    VALUES (p_driver_id, p_vehicle_id, true)
    RETURNING * INTO result_record;
    
    RETURN result_record;
EXCEPTION
    WHEN unique_violation THEN
        -- Se houver violação de unicidade, tentar atualizar
        UPDATE driver_vehicles 
        SET active = true, assigned_at = NOW()
        WHERE driver_id = p_driver_id 
        AND vehicle_id = p_vehicle_id
        RETURNING * INTO result_record;
        
        RETURN result_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Também criar uma função para remover associação
CREATE OR REPLACE FUNCTION unassign_vehicle_from_driver(
    p_driver_id UUID,
    p_vehicle_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE driver_vehicles 
    SET active = false
    WHERE driver_id = p_driver_id 
    AND vehicle_id = p_vehicle_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 