-- Corrigir acesso completo para drivers
-- 1. Primeiro, remover políticas antigas que podem estar conflitando

-- Remover políticas antigas de vehicles
DROP POLICY IF EXISTS vehicles_driver_select ON vehicles;
DROP POLICY IF EXISTS vehicles_select ON vehicles;
DROP POLICY IF EXISTS vehicles_access ON vehicles;

-- Remover políticas antigas de inspections  
DROP POLICY IF EXISTS inspections_driver_insert ON inspections;
DROP POLICY IF EXISTS inspections_driver_select ON inspections;
DROP POLICY IF EXISTS inspections_access ON inspections;

-- Remover políticas antigas de costs
DROP POLICY IF EXISTS costs_driver_select ON costs;
DROP POLICY IF EXISTS costs_driver_insert ON costs;
DROP POLICY IF EXISTS costs_access ON costs;

-- Remover políticas antigas de fines
DROP POLICY IF EXISTS fines_driver_select ON fines;
DROP POLICY IF EXISTS fines_access ON fines;

-- Remover políticas antigas de driver_vehicles
DROP POLICY IF EXISTS driver_vehicles_select ON driver_vehicles;

-- Remover funções existentes que podem ter conflitos
DROP FUNCTION IF EXISTS is_driver_vehicle(uuid,uuid) CASCADE;
DROP FUNCTION IF EXISTS get_driver_vehicles(uuid);
DROP FUNCTION IF EXISTS get_driver_costs(uuid);
DROP FUNCTION IF EXISTS get_driver_inspections(uuid);
DROP FUNCTION IF EXISTS get_driver_fines(uuid);

-- 2. Recriar políticas mais permissivas para drivers

-- Política para vehicles - permitir que drivers vejam seus veículos OU todos se for admin
CREATE POLICY vehicles_access ON vehicles
    FOR SELECT USING (
        -- Admin pode ver tudo
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND role = 'Admin'
        ) OR
        -- Driver pode ver veículos associados a ele
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = auth.uid() 
            AND vehicle_id = vehicles.id 
            AND active = true
        ) OR
        -- Outros papéis podem ver baseado em suas permissões
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND (
                permissions->>'fleet' = 'true' OR
                role IN ('Manager', 'Mechanic', 'Inspector', 'Sales')
            )
        )
    );

-- Política para inspections - permitir que drivers vejam inspeções de seus veículos
CREATE POLICY inspections_access ON inspections
    FOR ALL USING (
        -- Admin pode ver tudo
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND role = 'Admin'
        ) OR
        -- Driver pode ver inspeções de seus veículos
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = auth.uid() 
            AND vehicle_id = inspections.vehicle_id 
            AND active = true
        ) OR
        -- Outros papéis podem ver baseado em suas permissões
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND (
                permissions->>'inspections' = 'true' OR
                role IN ('Manager', 'Inspector', 'Mechanic')
            )
        )
    );

-- Política para costs - permitir que drivers vejam custos de seus veículos
CREATE POLICY costs_access ON costs
    FOR ALL USING (
        -- Admin pode ver tudo
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND role = 'Admin'
        ) OR
        -- Driver pode ver custos de seus veículos
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = auth.uid() 
            AND vehicle_id = costs.vehicle_id 
            AND active = true
        ) OR
        -- Outros papéis podem ver baseado em suas permissões
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND (
                permissions->>'costs' = 'true' OR
                role IN ('Manager', 'Sales')
            )
        )
    );

-- Política para fines - permitir que drivers vejam multas de seus veículos
CREATE POLICY fines_access ON fines
    FOR ALL USING (
        -- Admin pode ver tudo
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND role = 'Admin'
        ) OR
        -- Driver pode ver multas de seus veículos
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = auth.uid() 
            AND vehicle_id = fines.vehicle_id 
            AND active = true
        ) OR
        -- Outros papéis podem ver baseado em suas permissões
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND (
                permissions->>'fines' = 'true' OR
                role IN ('Manager', 'FineAdmin')
            )
        )
    );

-- Política para driver_vehicles
CREATE POLICY driver_vehicles_access ON driver_vehicles
    FOR SELECT USING (
        auth.uid() = driver_id OR 
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND role = 'Admin'
        )
    );

-- 3. Atualizar funções para drivers com verificações mais simples

-- Função para buscar veículos do driver (já existe, mas vamos garantir que funciona)
CREATE OR REPLACE FUNCTION get_driver_vehicles(p_driver_id UUID)
RETURNS SETOF vehicles AS $$
BEGIN
    -- Verificar se é um driver ou admin
    IF NOT EXISTS (
        SELECT 1 FROM employees 
        WHERE id = p_driver_id 
        AND (role = 'Driver' OR role = 'Admin')
    ) THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT v.*
    FROM vehicles v
    INNER JOIN driver_vehicles dv ON dv.vehicle_id = v.id
    WHERE dv.driver_id = p_driver_id
    AND dv.active = true
    ORDER BY v.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para buscar custos do driver
CREATE OR REPLACE FUNCTION get_driver_costs(p_driver_id UUID)
RETURNS SETOF costs AS $$
BEGIN
    -- Verificar se é um driver ou admin
    IF NOT EXISTS (
        SELECT 1 FROM employees 
        WHERE id = p_driver_id 
        AND (role = 'Driver' OR role = 'Admin')
    ) THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT c.*
    FROM costs c
    INNER JOIN driver_vehicles dv ON dv.vehicle_id = c.vehicle_id
    WHERE dv.driver_id = p_driver_id
    AND dv.active = true
    ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para buscar inspeções do driver
CREATE OR REPLACE FUNCTION get_driver_inspections(p_driver_id UUID)
RETURNS SETOF inspections AS $$
BEGIN
    -- Verificar se é um driver ou admin
    IF NOT EXISTS (
        SELECT 1 FROM employees 
        WHERE id = p_driver_id 
        AND (role = 'Driver' OR role = 'Admin')
    ) THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT i.*
    FROM inspections i
    INNER JOIN driver_vehicles dv ON dv.vehicle_id = i.vehicle_id
    WHERE dv.driver_id = p_driver_id
    AND dv.active = true
    ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para buscar multas do driver
CREATE OR REPLACE FUNCTION get_driver_fines(p_driver_id UUID)
RETURNS SETOF fines AS $$
BEGIN
    -- Verificar se é um driver ou admin
    IF NOT EXISTS (
        SELECT 1 FROM employees 
        WHERE id = p_driver_id 
        AND (role = 'Driver' OR role = 'Admin')
    ) THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT f.*
    FROM fines f
    INNER JOIN driver_vehicles dv ON dv.vehicle_id = f.vehicle_id
    WHERE dv.driver_id = p_driver_id
    AND dv.active = true
    ORDER BY f.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Função auxiliar para verificar se um veículo pertence ao driver
CREATE OR REPLACE FUNCTION is_driver_vehicle(driver_id UUID, vehicle_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM driver_vehicles 
        WHERE driver_vehicles.driver_id = is_driver_vehicle.driver_id 
        AND driver_vehicles.vehicle_id = is_driver_vehicle.vehicle_id 
        AND active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 