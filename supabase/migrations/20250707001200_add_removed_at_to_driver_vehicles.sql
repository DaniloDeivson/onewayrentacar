-- Add removed_at column to driver_vehicles table
-- This allows soft deletion of driver-vehicle assignments

ALTER TABLE driver_vehicles 
ADD COLUMN IF NOT EXISTS removed_at TIMESTAMPTZ;

-- Add index for better performance when filtering by active status
CREATE INDEX IF NOT EXISTS idx_driver_vehicles_active_removed 
ON driver_vehicles(active, removed_at);

-- Update existing policies to consider removed_at
DROP POLICY IF EXISTS driver_vehicles_select ON driver_vehicles;
CREATE POLICY driver_vehicles_select ON driver_vehicles
    FOR SELECT USING (
        (auth.uid() = driver_id AND (removed_at IS NULL OR active = true)) OR 
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND role = 'Admin'
        )
    );

-- Add update policy for drivers to deactivate their own assignments
DROP POLICY IF EXISTS driver_vehicles_update ON driver_vehicles;
CREATE POLICY driver_vehicles_update ON driver_vehicles
    FOR UPDATE USING (
        auth.uid() = driver_id OR
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = auth.uid() 
            AND role = 'Admin'
        )
    ); 