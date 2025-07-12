-- Limpar todas as políticas RLS conflitantes

-- 1. Remover políticas que permitem acesso total (muito permissivas)
DROP POLICY IF EXISTS "allow_all_fines" ON fines;
DROP POLICY IF EXISTS "fines_all_access" ON fines;
DROP POLICY IF EXISTS "Authenticated users can manage vehicles" ON vehicles;
DROP POLICY IF EXISTS "Allow vehicle updates for authenticated users" ON vehicles;

-- 2. Remover políticas antigas de tenant que podem estar conflitando
DROP POLICY IF EXISTS "Allow all operations for default tenant on costs" ON costs;
DROP POLICY IF EXISTS "Allow department-based access to costs" ON costs;
DROP POLICY IF EXISTS "Users can manage their tenant costs" ON costs;

DROP POLICY IF EXISTS "Allow all operations for default tenant on fines" ON fines;
DROP POLICY IF EXISTS "Users can manage their tenant fines" ON fines;

DROP POLICY IF EXISTS "Allow all operations for default tenant on inspections" ON inspections;
DROP POLICY IF EXISTS "Users can manage their tenant inspections" ON inspections;

DROP POLICY IF EXISTS "Allow tenant users to delete their vehicles" ON vehicles;
DROP POLICY IF EXISTS "Allow vehicle update for authenticated" ON vehicles;

-- 3. Manter apenas as políticas específicas que criamos
-- (costs_access, fines_access, inspections_access, vehicles_access, driver_vehicles_access)

-- 4. Garantir que o RLS está ativo em todas as tabelas
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE fines ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_vehicles ENABLE ROW LEVEL SECURITY;

-- 5. Verificar se as políticas específicas existem, se não, criar
DO $$
BEGIN
    -- Política para vehicles
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'vehicles' AND policyname = 'vehicles_access'
    ) THEN
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
    END IF;

    -- Política para costs
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'costs' AND policyname = 'costs_access'
    ) THEN
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
    END IF;

    -- Política para fines
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'fines' AND policyname = 'fines_access'
    ) THEN
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
    END IF;

    -- Política para inspections
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'inspections' AND policyname = 'inspections_access'
    ) THEN
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
    END IF;

    -- Política para driver_vehicles
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'driver_vehicles' AND policyname = 'driver_vehicles_access'
    ) THEN
        CREATE POLICY driver_vehicles_access ON driver_vehicles
            FOR SELECT USING (
                auth.uid() = driver_id OR 
                EXISTS (
                    SELECT 1 FROM employees 
                    WHERE id = auth.uid() 
                    AND role = 'Admin'
                )
            );
    END IF;
END $$; 