-- Função para buscar veículos associados ao motorista
CREATE OR REPLACE FUNCTION get_driver_vehicles(p_driver_id UUID)
RETURNS SETOF vehicles AS $$
BEGIN
    RETURN QUERY
    SELECT v.*
    FROM vehicles v
    INNER JOIN driver_vehicles dv ON dv.vehicle_id = v.id
    WHERE dv.driver_id = p_driver_id
    AND dv.active = true
    ORDER BY v.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 