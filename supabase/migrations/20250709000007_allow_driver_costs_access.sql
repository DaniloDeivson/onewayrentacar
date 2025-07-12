-- Allow drivers to access costs for their assigned vehicles
-- This migration creates RLS policies for drivers to see costs of their vehicles

-- ============================================================================
-- 1. CREATE RLS POLICY FOR DRIVERS TO VIEW COSTS
-- ============================================================================

-- Create policy for drivers to view costs of their assigned vehicles
CREATE POLICY costs_driver_select ON costs
    FOR SELECT USING (
        -- Allow drivers to see costs for their assigned vehicles
        EXISTS (
            SELECT 1 FROM driver_vehicles dv
            WHERE dv.driver_id::uuid = auth.uid()
            AND dv.vehicle_id = costs.vehicle_id
            AND dv.active = true
        )
        OR
        -- Allow admin users to see all costs
        EXISTS (
            SELECT 1 FROM employees e
            WHERE e.id::uuid = auth.uid()
            AND (
                e.role = 'Admin'
                OR e.permissions->>'admin' = 'true'
                OR e.permissions->>'costs' = 'true'
            )
        )
    );

-- ============================================================================
-- 2. ENSURE DRIVERS CAN VIEW RELATED VEHICLE AND CUSTOMER DATA
-- ============================================================================

-- Update vehicles policy to allow drivers to see their vehicles (if not exists)
DROP POLICY IF EXISTS vehicles_driver_select ON vehicles;
CREATE POLICY vehicles_driver_select ON vehicles
    FOR SELECT USING (
        -- Allow drivers to see their assigned vehicles
        EXISTS (
            SELECT 1 FROM driver_vehicles dv
            WHERE dv.driver_id::uuid = auth.uid()
            AND dv.vehicle_id = vehicles.id
            AND dv.active = true
        )
        OR
        -- Allow admin users to see all vehicles
        EXISTS (
            SELECT 1 FROM employees e
            WHERE e.id::uuid = auth.uid()
            AND (
                e.role = 'Admin'
                OR e.permissions->>'admin' = 'true'
                OR e.permissions->>'fleet' = 'true'
            )
        )
    );

-- ============================================================================
-- 3. CREATE FUNCTION TO GET DRIVER COSTS
-- ============================================================================

-- Function to safely get costs for a driver
CREATE OR REPLACE FUNCTION get_driver_costs(driver_id_param text)
RETURNS SETOF costs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Verify the user is a driver and can access this data
    IF NOT EXISTS (
        SELECT 1 FROM employees 
        WHERE id = driver_id_param 
        AND role = 'Driver'
        AND active = true
    ) THEN
        RAISE EXCEPTION 'User is not an active driver';
    END IF;

    -- Return costs for vehicles assigned to this driver
    RETURN QUERY
    SELECT c.*
    FROM costs c
    WHERE EXISTS (
        SELECT 1 FROM driver_vehicles dv
        WHERE dv.driver_id = driver_id_param
        AND dv.vehicle_id = c.vehicle_id
        AND dv.active = true
    )
    ORDER BY c.cost_date DESC, c.created_at DESC;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_driver_costs(text) TO authenticated;

-- ============================================================================
-- 4. VERIFY POLICIES WERE CREATED
-- ============================================================================

-- Verify the policies exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'costs' 
        AND policyname = 'costs_driver_select'
    ) THEN
        RAISE EXCEPTION 'Failed to create costs_driver_select policy';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'vehicles' 
        AND policyname = 'vehicles_driver_select'
    ) THEN
        RAISE EXCEPTION 'Failed to create vehicles_driver_select policy';
    END IF;
    
    RAISE NOTICE 'Driver costs access policies successfully created';
END
$$; 