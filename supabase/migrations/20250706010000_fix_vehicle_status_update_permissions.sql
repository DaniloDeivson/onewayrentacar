-- Fix vehicle status update permissions
-- This migration ensures vehicles can be updated when contracts are cancelled/finalized

-- Drop existing restrictive policies (if any)
DROP POLICY IF EXISTS "Users can update vehicle status from their tenant" ON vehicles;
DROP POLICY IF EXISTS "Allow vehicle status updates for contract changes" ON vehicles;

-- Create a simple policy that allows vehicle updates for authenticated users
CREATE POLICY "Allow vehicle updates for authenticated users" ON vehicles
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Verify the policy was created
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'vehicles' 
        AND policyname = 'Allow vehicle updates for authenticated users'
        AND cmd = 'UPDATE'
    ) THEN
        RAISE EXCEPTION 'Failed to create vehicle update policy';
    END IF;
END $$; 