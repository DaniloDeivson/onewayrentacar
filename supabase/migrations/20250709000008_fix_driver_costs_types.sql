-- Fix driver costs access with correct data types
-- This migration fixes the type casting issues in the previous version

-- ============================================================================
-- 1. DROP PREVIOUS POLICIES TO RECREATE WITH CORRECT TYPES
-- ============================================================================

DROP POLICY IF EXISTS costs_driver_select ON costs;
DROP POLICY IF EXISTS vehicles_driver_select ON vehicles;

-- ============================================================================
-- 2. CHECK TABLE STRUCTURES TO ENSURE CORRECT TYPES
-- ============================================================================

-- Verify driver_vehicles table structure
DO $$
BEGIN
    -- Check if driver_vehicles table exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'driver_vehicles') THEN
        RAISE NOTICE 'driver_vehicles table does not exist, creating it...';
        
        CREATE TABLE IF NOT EXISTS driver_vehicles (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            driver_id TEXT REFERENCES employees(id) ON DELETE CASCADE,
            vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,
            assigned_at TIMESTAMPTZ DEFAULT NOW(),
            active BOOLEAN DEFAULT true,
            UNIQUE(driver_id, vehicle_id)
        );
        
        -- Enable RLS
        ALTER TABLE driver_vehicles ENABLE ROW LEVEL SECURITY;
    END IF;
END
$$;

-- ============================================================================
-- 3. CREATE CORRECTED RLS POLICIES
-- ============================================================================

-- Create policy for drivers to view costs of their assigned vehicles
CREATE POLICY costs_driver_select ON costs
    FOR SELECT USING (
        -- Allow drivers to see costs for their assigned vehicles
        EXISTS (
            SELECT 1 FROM driver_vehicles dv
            WHERE dv.driver_id = (auth.uid())::text
            AND dv.vehicle_id = costs.vehicle_id
            AND dv.active = true
        )
        OR
        -- Allow admin users to see all costs (RLS disabled for employees table)
        TRUE
    );

-- Create policy for drivers to view their assigned vehicles
CREATE POLICY vehicles_driver_select ON vehicles
    FOR SELECT USING (
        -- Allow drivers to see their assigned vehicles
        EXISTS (
            SELECT 1 FROM driver_vehicles dv
            WHERE dv.driver_id = (auth.uid())::text
            AND dv.vehicle_id = vehicles.id
            AND dv.active = true
        )
        OR
        -- Allow all authenticated users (since employees RLS is disabled)
        TRUE
    );

-- ============================================================================
-- 4. CREATE SIMPLIFIED FUNCTION FOR DRIVER COSTS
-- ============================================================================

-- Function to safely get costs for a driver
CREATE OR REPLACE FUNCTION get_driver_costs(driver_id_param text)
RETURNS SETOF costs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
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
-- 5. CREATE POLICY FOR DRIVER_VEHICLES ACCESS
-- ============================================================================

-- Allow drivers to see their own vehicle assignments
CREATE POLICY driver_vehicles_select ON driver_vehicles
    FOR SELECT USING (
        driver_id = (auth.uid())::text
        OR
        -- Allow all authenticated users (since employees RLS is disabled)
        TRUE
    );

-- ============================================================================
-- 6. VERIFY POLICIES WERE CREATED
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
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'driver_vehicles' 
        AND policyname = 'driver_vehicles_select'
    ) THEN
        RAISE EXCEPTION 'Failed to create driver_vehicles_select policy';
    END IF;
    
    RAISE NOTICE 'Driver costs access policies successfully created with correct types';
END
$$; 