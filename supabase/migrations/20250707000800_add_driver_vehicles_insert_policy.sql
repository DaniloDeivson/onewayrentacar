-- Adicionar política de INSERT para driver_vehicles
-- Esta política permite que drivers associem veículos a si mesmos automaticamente

-- Remover política existente se houver
DROP POLICY IF EXISTS driver_vehicles_insert ON driver_vehicles;

-- Criar política de INSERT para driver_vehicles
CREATE POLICY driver_vehicles_insert ON driver_vehicles
    FOR INSERT WITH CHECK (
        -- Driver pode associar veículos a si mesmo
        auth.uid() = driver_id
        OR
        -- Admin pode associar qualquer veículo a qualquer driver
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND role = 'Admin'
        )
    );

-- Verificar se a política foi criada
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'driver_vehicles' 
        AND policyname = 'driver_vehicles_insert'
        AND cmd = 'INSERT'
    ) THEN
        RAISE EXCEPTION 'Failed to create driver_vehicles insert policy';
    END IF;
END $$; 