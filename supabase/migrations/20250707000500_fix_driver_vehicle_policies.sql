-- Remove políticas existentes que podem estar muito permissivas
DROP POLICY IF EXISTS vehicles_driver_select ON vehicles;
DROP POLICY IF EXISTS vehicles_select_policy ON vehicles;

-- Política para motoristas verem apenas seus veículos
CREATE POLICY vehicles_driver_select ON vehicles
    FOR SELECT USING (
        -- Se for motorista, só vê veículos associados a ele
        (
            EXISTS (
                SELECT 1 FROM employees e 
                WHERE e.id = auth.uid() 
                AND e.role = 'Driver'
                AND EXISTS (
                    SELECT 1 FROM driver_vehicles dv 
                    WHERE dv.driver_id = auth.uid() 
                    AND dv.vehicle_id = vehicles.id 
                    AND dv.active = true
                )
            )
        )
        -- Se for admin, vê todos
        OR (
            EXISTS (
                SELECT 1 FROM employees e
                WHERE e.id = auth.uid() 
                AND e.role = 'Admin'
                AND e.active = true
            )
        )
    );

-- Política para motoristas verem apenas suas próprias inspeções
DROP POLICY IF EXISTS inspections_driver_select ON inspections;
CREATE POLICY inspections_driver_select ON inspections
    FOR SELECT USING (
        -- Se for motorista, só vê inspeções de seus veículos
        (
            EXISTS (
                SELECT 1 FROM employees e 
                WHERE e.id = auth.uid() 
                AND e.role = 'Driver'
                AND EXISTS (
                    SELECT 1 FROM driver_vehicles dv 
                    WHERE dv.driver_id = auth.uid() 
                    AND dv.vehicle_id = inspections.vehicle_id 
                    AND dv.active = true
                )
            )
        )
        -- Se for admin, vê todas
        OR (
            EXISTS (
                SELECT 1 FROM employees e
                WHERE e.id = auth.uid() 
                AND e.role = 'Admin'
                AND e.active = true
            )
        )
    );

-- Política para motoristas criarem inspeções apenas para seus veículos
DROP POLICY IF EXISTS inspections_driver_insert ON inspections;
CREATE POLICY inspections_driver_insert ON inspections
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM driver_vehicles dv 
            WHERE dv.driver_id = auth.uid() 
            AND dv.vehicle_id = vehicle_id 
            AND dv.active = true
        )
    );

-- Política para motoristas verem apenas seus próprios custos
DROP POLICY IF EXISTS costs_driver_select ON costs;
CREATE POLICY costs_driver_select ON costs
    FOR SELECT USING (
        -- Se for motorista, só vê custos de seus veículos
        (
            EXISTS (
                SELECT 1 FROM employees e 
                WHERE e.id = auth.uid() 
                AND e.role = 'Driver'
                AND EXISTS (
                    SELECT 1 FROM driver_vehicles dv 
                    WHERE dv.driver_id = auth.uid() 
                    AND dv.vehicle_id = costs.vehicle_id 
                    AND dv.active = true
                )
            )
        )
        -- Se for admin, vê todos
        OR (
            EXISTS (
                SELECT 1 FROM employees e
                WHERE e.id = auth.uid() 
                AND e.role = 'Admin'
                AND e.active = true
            )
        )
    );

-- Política para motoristas registrarem custos apenas para seus veículos
DROP POLICY IF EXISTS costs_driver_insert ON costs;
CREATE POLICY costs_driver_insert ON costs
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM driver_vehicles dv 
            WHERE dv.driver_id = auth.uid() 
            AND dv.vehicle_id = vehicle_id 
            AND dv.active = true
        )
    ); 