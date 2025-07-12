-- Add check constraint to ensure valid roles
DO $$ 
BEGIN
    -- Adicionar 'Driver' como um valor válido para a coluna role
    ALTER TABLE employees 
    DROP CONSTRAINT IF EXISTS employees_role_check;
    
    ALTER TABLE employees 
    ADD CONSTRAINT employees_role_check 
    CHECK (role IN ('Admin', 'Sales', 'Mechanic', 'User', 'Driver'));
END $$;

-- Create driver_vehicles table to track which vehicles a driver can manage
CREATE TABLE IF NOT EXISTS driver_vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    active BOOLEAN DEFAULT true,
    UNIQUE(driver_id, vehicle_id)
);

-- RLS Policies for driver_vehicles
ALTER TABLE driver_vehicles ENABLE ROW LEVEL SECURITY;

CREATE POLICY driver_vehicles_select ON driver_vehicles
    FOR SELECT USING (
        auth.uid() = driver_id OR 
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND permissions->>'admin' = 'true'
        )
    );

-- Update vehicles policies to allow drivers to see their vehicles
CREATE POLICY vehicles_driver_select ON vehicles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = auth.uid() 
            AND vehicle_id = vehicles.id 
            AND active = true
        ) OR
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND permissions->>'admin' = 'true'
        )
    );

-- Update inspections policies for drivers
CREATE POLICY inspections_driver_insert ON inspections
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = auth.uid() 
            AND vehicle_id = inspections.vehicle_id 
            AND active = true
        )
    );

CREATE POLICY inspections_driver_select ON inspections
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = auth.uid() 
            AND vehicle_id = inspections.vehicle_id
        ) OR
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND permissions->>'admin' = 'true'
        )
    );

-- Function to assign vehicle to driver
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

    -- Inserir associação
    INSERT INTO driver_vehicles (driver_id, vehicle_id)
    VALUES (p_driver_id, p_vehicle_id)
    RETURNING * INTO result_record;
    
    RETURN result_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para converter usuário existente em motorista
CREATE OR REPLACE FUNCTION convert_to_driver(
    p_user_id UUID
) RETURNS employees AS $$
BEGIN
    -- Atualizar permissões do usuário
    UPDATE employees 
    SET 
        role = 'Driver',
        roles_extra = ARRAY_APPEND(
            COALESCE(roles_extra, ARRAY[]::text[]), 
            'Driver'
        ),
        permissions = jsonb_set(
            COALESCE(permissions, '{}'::jsonb),
            '{fleet}',
            'true'::jsonb
        )
    WHERE id = p_user_id
    RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 