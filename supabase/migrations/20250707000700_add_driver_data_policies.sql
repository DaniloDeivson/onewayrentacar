-- Função para verificar se um veículo está associado a um motorista
CREATE OR REPLACE FUNCTION is_driver_vehicle(p_vehicle_id UUID, p_driver_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM driver_vehicles
        WHERE vehicle_id = p_vehicle_id
        AND driver_id = p_driver_id
        AND active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para buscar custos associados ao motorista
CREATE OR REPLACE FUNCTION get_driver_costs(p_driver_id UUID)
RETURNS SETOF costs AS $$
BEGIN
    RETURN QUERY
    SELECT c.*
    FROM costs c
    INNER JOIN vehicles v ON v.id = c.vehicle_id
    INNER JOIN driver_vehicles dv ON dv.vehicle_id = v.id
    WHERE dv.driver_id = p_driver_id
    AND dv.active = true
    ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para buscar inspeções associadas ao motorista
CREATE OR REPLACE FUNCTION get_driver_inspections(p_driver_id UUID)
RETURNS SETOF inspections AS $$
BEGIN
    RETURN QUERY
    SELECT i.*
    FROM inspections i
    INNER JOIN vehicles v ON v.id = i.vehicle_id
    INNER JOIN driver_vehicles dv ON dv.vehicle_id = v.id
    WHERE dv.driver_id = p_driver_id
    AND dv.active = true
    ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Políticas para veículos
DROP POLICY IF EXISTS vehicles_driver_select ON vehicles;
CREATE POLICY vehicles_driver_select ON vehicles
    FOR SELECT TO authenticated
    USING (
        -- Admin vê tudo
        (SELECT role FROM employees WHERE id = auth.uid()) = 'Admin'
        OR
        -- Motorista vê apenas seus veículos
        (
            (SELECT role FROM employees WHERE id = auth.uid()) = 'Driver'
            AND
            is_driver_vehicle(id, auth.uid())
        )
    );

-- Políticas para custos
DROP POLICY IF EXISTS costs_driver_select ON costs;
CREATE POLICY costs_driver_select ON costs
    FOR SELECT TO authenticated
    USING (
        -- Admin vê tudo
        (SELECT role FROM employees WHERE id = auth.uid()) = 'Admin'
        OR
        -- Motorista vê apenas custos dos seus veículos
        (
            (SELECT role FROM employees WHERE id = auth.uid()) = 'Driver'
            AND
            is_driver_vehicle(vehicle_id, auth.uid())
        )
    );

-- Políticas para inspeções
DROP POLICY IF EXISTS inspections_driver_select ON inspections;
CREATE POLICY inspections_driver_select ON inspections
    FOR SELECT TO authenticated
    USING (
        -- Admin vê tudo
        (SELECT role FROM employees WHERE id = auth.uid()) = 'Admin'
        OR
        -- Motorista vê apenas inspeções dos seus veículos
        (
            (SELECT role FROM employees WHERE id = auth.uid()) = 'Driver'
            AND
            is_driver_vehicle(vehicle_id, auth.uid())
        )
    );

-- Políticas de inserção para motoristas
DROP POLICY IF EXISTS costs_driver_insert ON costs;
CREATE POLICY costs_driver_insert ON costs
    FOR INSERT TO authenticated
    WITH CHECK (
        -- Admin pode inserir para qualquer veículo
        (SELECT role FROM employees WHERE id = auth.uid()) = 'Admin'
        OR
        -- Motorista só pode inserir para seus veículos
        (
            (SELECT role FROM employees WHERE id = auth.uid()) = 'Driver'
            AND
            is_driver_vehicle(vehicle_id, auth.uid())
        )
    );

DROP POLICY IF EXISTS inspections_driver_insert ON inspections;
CREATE POLICY inspections_driver_insert ON inspections
    FOR INSERT TO authenticated
    WITH CHECK (
        -- Admin pode inserir para qualquer veículo
        (SELECT role FROM employees WHERE id = auth.uid()) = 'Admin'
        OR
        -- Motorista só pode inserir para seus veículos
        (
            (SELECT role FROM employees WHERE id = auth.uid()) = 'Driver'
            AND
            is_driver_vehicle(vehicle_id, auth.uid())
        )
    ); 