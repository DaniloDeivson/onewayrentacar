-- Adicionar política de INSERT para vehicles
-- Esta política permite que drivers criem veículos

-- Remover políticas conflitantes existentes
DROP POLICY IF EXISTS "Allow all operations for default tenant" ON vehicles;
DROP POLICY IF EXISTS "Users can manage their tenant vehicles" ON vehicles;
DROP POLICY IF EXISTS vehicles_access ON vehicles;
DROP POLICY IF EXISTS vehicles_insert ON vehicles;
DROP POLICY IF EXISTS vehicles_select ON vehicles;
DROP POLICY IF EXISTS vehicles_update ON vehicles;

-- Criar política de INSERT para vehicles
CREATE POLICY vehicles_insert ON vehicles
    FOR INSERT WITH CHECK (
        -- Admin pode criar qualquer veículo
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND role = 'Admin'
        )
        OR
        -- Driver pode criar veículos (serão associados automaticamente)
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND role = 'Driver'
        )
        OR
        -- Outros papéis com permissão de frota
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND (
                permissions->>'fleet' = 'true' OR
                role IN ('Manager', 'Mechanic', 'Inspector', 'Sales')
            )
        )
    );

-- Criar política de SELECT para vehicles
CREATE POLICY vehicles_select ON vehicles
    FOR SELECT USING (
        -- Admin pode ver tudo
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND role = 'Admin'
        )
        OR
        -- Driver pode ver veículos associados a ele
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = auth.uid() 
            AND vehicle_id = vehicles.id 
            AND active = true
        )
        OR
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

-- Criar política de UPDATE para vehicles
CREATE POLICY vehicles_update ON vehicles
    FOR UPDATE USING (
        -- Admin pode atualizar qualquer veículo
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND role = 'Admin'
        )
        OR
        -- Driver pode atualizar seus veículos
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = auth.uid() 
            AND vehicle_id = vehicles.id 
            AND active = true
        )
        OR
        -- Outros papéis com permissão de frota
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND (
                permissions->>'fleet' = 'true' OR
                role IN ('Manager', 'Mechanic', 'Inspector', 'Sales')
            )
        )
    );

-- Verificar se as políticas foram criadas
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'vehicles' 
        AND policyname = 'vehicles_insert'
        AND cmd = 'INSERT'
    ) THEN
        RAISE EXCEPTION 'Failed to create vehicles insert policy';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'vehicles' 
        AND policyname = 'vehicles_select'
        AND cmd = 'SELECT'
    ) THEN
        RAISE EXCEPTION 'Failed to create vehicles select policy';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'vehicles' 
        AND policyname = 'vehicles_update'
        AND cmd = 'UPDATE'
    ) THEN
        RAISE EXCEPTION 'Failed to create vehicles update policy';
    END IF;
END $$; 