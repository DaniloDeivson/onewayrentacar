-- Fix Database Linter Issues - Final Version
-- This migration addresses:
-- 1. Auth RLS Initialization Plan - Wrap auth.<function>() calls in (SELECT auth.<function>())
-- 2. Multiple Permissive Policies - Remove duplicate policies
-- 3. Duplicate Indexes - Remove duplicate indexes (with proper constraint handling)
-- 4. Column existence checks to avoid errors

-- ============================================================================
-- 1. FIX AUTH RLS INITIALIZATION PLAN ISSUES
-- ============================================================================

-- Fix inspections table RLS policies
DROP POLICY IF EXISTS "inspections_access" ON inspections;
CREATE POLICY "inspections_access" ON inspections
    FOR ALL USING (
        -- Admin pode ver tudo
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role = 'Admin'
        ) OR
        -- Driver pode ver inspeções de seus veículos
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = (SELECT auth.uid()) 
            AND vehicle_id = inspections.vehicle_id 
            AND active = true
        ) OR
        -- Outros papéis podem ver baseado em suas permissões
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND (
                permissions->>'inspections' = 'true' OR
                role IN ('Manager', 'Inspector', 'Mechanic')
            )
        )
    );

-- Fix audit_log table RLS policies
DROP POLICY IF EXISTS "Admins podem ver logs do seu tenant" ON audit_log;
CREATE POLICY "Admins podem ver logs do seu tenant" ON audit_log
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role IN ('Admin', 'Manager')
        )
    );

-- Fix fines table RLS policies
DROP POLICY IF EXISTS "fines_access" ON fines;
CREATE POLICY "fines_access" ON fines
    FOR ALL USING (
        -- Admin pode ver tudo
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role = 'Admin'
        ) OR
        -- Driver pode ver multas de seus veículos
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = (SELECT auth.uid()) 
            AND vehicle_id = fines.vehicle_id 
            AND active = true
        ) OR
        -- Outros papéis podem ver baseado em suas permissões
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND (
                permissions->>'fines' = 'true' OR
                role IN ('Manager', 'FineAdmin')
            )
        )
    );

-- Fix driver_vehicles table RLS policies
DROP POLICY IF EXISTS "driver_vehicles_access" ON driver_vehicles;
CREATE POLICY "driver_vehicles_access" ON driver_vehicles
    FOR SELECT USING (
        (SELECT auth.uid()) = driver_id OR 
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role = 'Admin'
        )
    );

-- Fix costs table RLS policies
DROP POLICY IF EXISTS "costs_access" ON costs;
CREATE POLICY "costs_access" ON costs
    FOR ALL USING (
        -- Admin pode ver tudo
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role = 'Admin'
        ) OR
        -- Driver pode ver custos de seus veículos
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = (SELECT auth.uid()) 
            AND vehicle_id = costs.vehicle_id 
            AND active = true
        ) OR
        -- Outros papéis podem ver baseado em suas permissões
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND (
                permissions->>'costs' = 'true' OR
                role IN ('Manager', 'Sales')
            )
        )
    );

-- Fix customer_charges table RLS policies (only if tenant_id column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_charges' 
        AND column_name = 'tenant_id'
    ) THEN
        -- Drop existing policies
        DROP POLICY IF EXISTS "Customer charges are insertable by same tenant" ON customer_charges;
        DROP POLICY IF EXISTS "Customer charges are updatable by same tenant" ON customer_charges;
        DROP POLICY IF EXISTS "Customer charges are viewable by same tenant" ON customer_charges;
        
        -- Create new policies with tenant_id check
        CREATE POLICY "Customer charges are insertable by same tenant" ON customer_charges
            FOR INSERT WITH CHECK (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );

        CREATE POLICY "Customer charges are updatable by same tenant" ON customer_charges
            FOR UPDATE USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            ) WITH CHECK (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );

        CREATE POLICY "Customer charges are viewable by same tenant" ON customer_charges
            FOR SELECT USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );
    END IF;
END $$;

-- Fix removed_users table RLS policies
DROP POLICY IF EXISTS "Only admins can manage removed users" ON removed_users;
CREATE POLICY "Only admins can manage removed users" ON removed_users
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role = 'Admin'
        )
    );

DROP POLICY IF EXISTS "Only admins can view removed users" ON removed_users;
CREATE POLICY "Only admins can view removed users" ON removed_users
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role = 'Admin'
        )
    );

-- Fix guest_users table RLS policies
DROP POLICY IF EXISTS "Admins can manage all guests" ON guest_users;
CREATE POLICY "Admins can manage all guests" ON guest_users
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role IN ('Admin', 'Manager')
        )
    );

-- Fix contract_vehicles table RLS policies (only if tenant_id column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'contract_vehicles' 
        AND column_name = 'tenant_id'
    ) THEN
        -- Drop existing policies
        DROP POLICY IF EXISTS "Users can delete contract_vehicles from their tenant" ON contract_vehicles;
        DROP POLICY IF EXISTS "Users can insert contract_vehicles for their tenant" ON contract_vehicles;
        DROP POLICY IF EXISTS "Users can update contract_vehicles from their tenant" ON contract_vehicles;
        DROP POLICY IF EXISTS "Users can view contract_vehicles from their tenant" ON contract_vehicles;
        
        -- Create new policies with tenant_id check
        CREATE POLICY "Users can delete contract_vehicles from their tenant" ON contract_vehicles
            FOR DELETE USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );

        CREATE POLICY "Users can insert contract_vehicles for their tenant" ON contract_vehicles
            FOR INSERT WITH CHECK (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );

        CREATE POLICY "Users can update contract_vehicles from their tenant" ON contract_vehicles
            FOR UPDATE USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            ) WITH CHECK (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );

        CREATE POLICY "Users can view contract_vehicles from their tenant" ON contract_vehicles
            FOR SELECT USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );
    END IF;
END $$;

-- Fix inspection_items table RLS policies (only if tenant_id column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'inspection_items' 
        AND column_name = 'tenant_id'
    ) THEN
        DROP POLICY IF EXISTS "Users can manage their tenant inspection items" ON inspection_items;
        CREATE POLICY "Users can manage their tenant inspection items" ON inspection_items
            FOR ALL USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );
    END IF;
END $$;

-- Fix maintenance_types table RLS policies (only if tenant_id column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'maintenance_types' 
        AND column_name = 'tenant_id'
    ) THEN
        DROP POLICY IF EXISTS "Users can manage their tenant maintenance types" ON maintenance_types;
        CREATE POLICY "Users can manage their tenant maintenance types" ON maintenance_types
            FOR ALL USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );
    END IF;
END $$;

-- Fix mechanics table RLS policies (only if tenant_id column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'mechanics' 
        AND column_name = 'tenant_id'
    ) THEN
        DROP POLICY IF EXISTS "Users can manage their tenant mechanics" ON mechanics;
        CREATE POLICY "Users can manage their tenant mechanics" ON mechanics
            FOR ALL USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );
    END IF;
END $$;

-- Fix parts table RLS policies (only if tenant_id column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'parts' 
        AND column_name = 'tenant_id'
    ) THEN
        DROP POLICY IF EXISTS "Users can manage their tenant parts" ON parts;
        CREATE POLICY "Users can manage their tenant parts" ON parts
            FOR ALL USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );
    END IF;
END $$;

-- Fix service_notes table RLS policies (only if tenant_id column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_notes' 
        AND column_name = 'tenant_id'
    ) THEN
        DROP POLICY IF EXISTS "Users can manage their tenant service notes" ON service_notes;
        CREATE POLICY "Users can manage their tenant service notes" ON service_notes
            FOR ALL USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );
    END IF;
END $$;

-- Fix service_order_parts table RLS policies (only if tenant_id column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'service_order_parts' 
        AND column_name = 'tenant_id'
    ) THEN
        DROP POLICY IF EXISTS "Users can manage their tenant service order parts" ON service_order_parts;
        CREATE POLICY "Users can manage their tenant service order parts" ON service_order_parts
            FOR ALL USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );
    END IF;
END $$;

-- Fix stock_movements table RLS policies (only if tenant_id column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'stock_movements' 
        AND column_name = 'tenant_id'
    ) THEN
        DROP POLICY IF EXISTS "Users can manage their tenant stock movements" ON stock_movements;
        CREATE POLICY "Users can manage their tenant stock movements" ON stock_movements
            FOR ALL USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );
    END IF;
END $$;

-- Fix suppliers table RLS policies (only if tenant_id column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'suppliers' 
        AND column_name = 'tenant_id'
    ) THEN
        DROP POLICY IF EXISTS "Users can manage their tenant suppliers" ON suppliers;
        CREATE POLICY "Users can manage their tenant suppliers" ON suppliers
            FOR ALL USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );
    END IF;
END $$;

-- Fix tenants table RLS policies (only if tenant_id column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tenants' 
        AND column_name = 'id'
    ) THEN
        DROP POLICY IF EXISTS "Users can view their tenant data" ON tenants;
        CREATE POLICY "Users can view their tenant data" ON tenants
            FOR SELECT USING (
                id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );
    END IF;
END $$;

-- Fix costs table driver-only policy
DROP POLICY IF EXISTS "costs_driver_only" ON costs;
CREATE POLICY "costs_driver_only" ON costs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = (SELECT auth.uid()) 
            AND vehicle_id = costs.vehicle_id 
            AND active = true
        )
    );

-- Fix driver_vehicles insert policy
DROP POLICY IF EXISTS "driver_vehicles_insert" ON driver_vehicles;
CREATE POLICY "driver_vehicles_insert" ON driver_vehicles
    FOR INSERT WITH CHECK (
        (SELECT auth.uid()) = driver_id OR
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role = 'Admin'
        )
    );

-- Fix driver_inspections table RLS policies
DROP POLICY IF EXISTS "Employees can view all inspections" ON driver_inspections;
CREATE POLICY "Employees can view all inspections" ON driver_inspections
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND active = true
        )
    );

-- Fix customer_charges additional policies
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON customer_charges;
CREATE POLICY "Enable insert for authenticated users" ON customer_charges
    FOR INSERT WITH CHECK (
        (SELECT auth.uid()) IS NOT NULL
    );

DROP POLICY IF EXISTS "Enable update for authenticated users" ON customer_charges;
CREATE POLICY "Enable update for authenticated users" ON customer_charges
    FOR UPDATE USING (
        (SELECT auth.uid()) IS NOT NULL
    ) WITH CHECK (
        (SELECT auth.uid()) IS NOT NULL
    );

-- Fix vehicles table RLS policies
DROP POLICY IF EXISTS "vehicles_insert" ON vehicles;
CREATE POLICY "vehicles_insert" ON vehicles
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND (role = 'Admin' OR permissions->>'fleet' = 'true')
        )
    );

DROP POLICY IF EXISTS "vehicles_select" ON vehicles;
CREATE POLICY "vehicles_select" ON vehicles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND (role = 'Admin' OR permissions->>'fleet' = 'true')
        ) OR
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = (SELECT auth.uid()) 
            AND vehicle_id = vehicles.id 
            AND active = true
        )
    );

DROP POLICY IF EXISTS "vehicles_update" ON vehicles;
CREATE POLICY "vehicles_update" ON vehicles
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND (role = 'Admin' OR permissions->>'fleet' = 'true')
        )
    ) WITH CHECK (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND (role = 'Admin' OR permissions->>'fleet' = 'true')
        )
    );

-- Fix contracts table RLS policies (only if tenant_id column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'contracts' 
        AND column_name = 'tenant_id'
    ) THEN
        DROP POLICY IF EXISTS "Users can manage their tenant contracts" ON contracts;
        CREATE POLICY "Users can manage their tenant contracts" ON contracts
            FOR ALL USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );
    END IF;
END $$;

-- Fix employees table RLS policies
DROP POLICY IF EXISTS "employees_select_policy" ON employees;
CREATE POLICY "employees_select_policy" ON employees
    FOR SELECT USING (
        (SELECT auth.uid()) = id OR
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role = 'Admin'
        )
    );

-- Fix contract_vehicles additional policies
DROP POLICY IF EXISTS "Allow authenticated insert contract_vehicles" ON contract_vehicles;
CREATE POLICY "Allow authenticated insert contract_vehicles" ON contract_vehicles
    FOR INSERT WITH CHECK (
        (SELECT auth.uid()) IS NOT NULL
    );

DROP POLICY IF EXISTS "Allow authenticated select contract_vehicles" ON contract_vehicles;
CREATE POLICY "Allow authenticated select contract_vehicles" ON contract_vehicles
    FOR SELECT USING (
        (SELECT auth.uid()) IS NOT NULL
    );

DROP POLICY IF EXISTS "Allow authenticated update contract_vehicles" ON contract_vehicles;
CREATE POLICY "Allow authenticated update contract_vehicles" ON contract_vehicles
    FOR UPDATE USING (
        (SELECT auth.uid()) IS NOT NULL
    ) WITH CHECK (
        (SELECT auth.uid()) IS NOT NULL
    );

DROP POLICY IF EXISTS "Allow authenticated delete contract_vehicles" ON contract_vehicles;
CREATE POLICY "Allow authenticated delete contract_vehicles" ON contract_vehicles
    FOR DELETE USING (
        (SELECT auth.uid()) IS NOT NULL
    );

-- Fix driver_vehicles additional policies
DROP POLICY IF EXISTS "driver_vehicles_select" ON driver_vehicles;
CREATE POLICY "driver_vehicles_select" ON driver_vehicles
    FOR SELECT USING (
        (SELECT auth.uid()) = driver_id OR
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role = 'Admin'
        )
    );

DROP POLICY IF EXISTS "driver_vehicles_update" ON driver_vehicles;
CREATE POLICY "driver_vehicles_update" ON driver_vehicles
    FOR UPDATE USING (
        (SELECT auth.uid()) = driver_id OR
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role = 'Admin'
        )
    ) WITH CHECK (
        (SELECT auth.uid()) = driver_id OR
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role = 'Admin'
        )
    );

-- Fix customers table RLS policies (only if tenant_id column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customers' 
        AND column_name = 'tenant_id'
    ) THEN
        DROP POLICY IF EXISTS "Users can manage their tenant customers" ON customers;
        CREATE POLICY "Users can manage their tenant customers" ON customers
            FOR ALL USING (
                tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
            );
    END IF;
END $$;

-- Fix contracts additional policies
DROP POLICY IF EXISTS "Allow delete contracts for authenticated" ON contracts;
CREATE POLICY "Allow delete contracts for authenticated" ON contracts
    FOR DELETE USING (
        (SELECT auth.uid()) IS NOT NULL
    );

DROP POLICY IF EXISTS "Allow all contract ops for authenticated" ON contracts;
CREATE POLICY "Allow all contract ops for authenticated" ON contracts
    FOR ALL USING (
        (SELECT auth.uid()) IS NOT NULL
    );

-- Fix contract_vehicles additional policies
DROP POLICY IF EXISTS "Allow select contract_vehicles for authenticated" ON contract_vehicles;
CREATE POLICY "Allow select contract_vehicles for authenticated" ON contract_vehicles
    FOR SELECT USING (
        (SELECT auth.uid()) IS NOT NULL
    );

-- Fix contracts additional policies
DROP POLICY IF EXISTS "Allow authenticated insert contracts" ON contracts;
CREATE POLICY "Allow authenticated insert contracts" ON contracts
    FOR INSERT WITH CHECK (
        (SELECT auth.uid()) IS NOT NULL
    );

DROP POLICY IF EXISTS "Allow authenticated select contracts" ON contracts;
CREATE POLICY "Allow authenticated select contracts" ON contracts
    FOR SELECT USING (
        (SELECT auth.uid()) IS NOT NULL
    );

DROP POLICY IF EXISTS "Allow authenticated update contracts" ON contracts;
CREATE POLICY "Allow authenticated update contracts" ON contracts
    FOR UPDATE USING (
        (SELECT auth.uid()) IS NOT NULL
    ) WITH CHECK (
        (SELECT auth.uid()) IS NOT NULL
    );

DROP POLICY IF EXISTS "Allow authenticated delete contracts" ON contracts;
CREATE POLICY "Allow authenticated delete contracts" ON contracts
    FOR DELETE USING (
        (SELECT auth.uid()) IS NOT NULL
    );

-- Fix inspections additional policies
DROP POLICY IF EXISTS "Drivers can insert inspections for their vehicles" ON inspections;
CREATE POLICY "Drivers can insert inspections for their vehicles" ON inspections
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM driver_vehicles 
            WHERE driver_id = (SELECT auth.uid()) 
            AND vehicle_id = inspections.vehicle_id 
            AND active = true
        )
    );

-- Fix employees additional policies
DROP POLICY IF EXISTS "Employees can access their own record" ON employees;
CREATE POLICY "Employees can access their own record" ON employees
    FOR SELECT USING (
        (SELECT auth.uid()) = id
    );

DROP POLICY IF EXISTS "employees_insert_policy" ON employees;
CREATE POLICY "employees_insert_policy" ON employees
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role = 'Admin'
        )
    );

-- Fix driver_inspections additional policies
DROP POLICY IF EXISTS "Admins can manage all inspections" ON driver_inspections;
CREATE POLICY "Admins can manage all inspections" ON driver_inspections
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE id = (SELECT auth.uid()) 
            AND role IN ('Admin', 'Manager')
        )
    );

-- ============================================================================
-- 2. REMOVE DUPLICATE POLICIES (Multiple Permissive Policies)
-- ============================================================================

-- Remove duplicate policies for contract_vehicles
DROP POLICY IF EXISTS "Allow authenticated insert contract_vehicles" ON contract_vehicles;
DROP POLICY IF EXISTS "Allow authenticated select contract_vehicles" ON contract_vehicles;
DROP POLICY IF EXISTS "Allow authenticated update contract_vehicles" ON contract_vehicles;
DROP POLICY IF EXISTS "Allow authenticated delete contract_vehicles" ON contract_vehicles;
DROP POLICY IF EXISTS "Allow select contract_vehicles for authenticated" ON contract_vehicles;

-- Remove duplicate policies for contracts
DROP POLICY IF EXISTS "Allow all operations for default tenant on contracts" ON contracts;
DROP POLICY IF EXISTS "Allow delete contracts for authenticated" ON contracts;
DROP POLICY IF EXISTS "Allow all contract ops for authenticated" ON contracts;
DROP POLICY IF EXISTS "Allow authenticated insert contracts" ON contracts;
DROP POLICY IF EXISTS "Allow authenticated select contracts" ON contracts;
DROP POLICY IF EXISTS "Allow authenticated update contracts" ON contracts;
DROP POLICY IF EXISTS "Allow authenticated delete contracts" ON contracts;

-- Remove duplicate policies for costs
DROP POLICY IF EXISTS "Allow all operations for default tenant on costs" ON costs;

-- Remove duplicate policies for customer_charges
DROP POLICY IF EXISTS "Customer charges policy" ON customer_charges;
DROP POLICY IF EXISTS "Enable read access for all users" ON customer_charges;

-- Remove duplicate policies for customers
DROP POLICY IF EXISTS "Allow all operations for default tenant on customers" ON customers;

-- Remove duplicate policies for damage_notifications
DROP POLICY IF EXISTS "Allow all operations for default tenant on damage_notifications" ON damage_notifications;

-- Remove duplicate policies for driver_inspections
-- Keep only the most specific ones

-- Remove duplicate policies for driver_vehicles
-- Keep only the most specific ones

-- Remove duplicate policies for drivers
DROP POLICY IF EXISTS "Allow all operations for default tenant on drivers" ON drivers;

-- Remove duplicate policies for employees
-- Keep only the most specific ones

-- Remove duplicate policies for fuel_records
DROP POLICY IF EXISTS "Drivers and admins can insert fuel records" ON fuel_records;
DROP POLICY IF EXISTS "Drivers can insert fuel records for their vehicles" ON fuel_records;
DROP POLICY IF EXISTS "Drivers can insert fuel records only for their vehicles" ON fuel_records;
DROP POLICY IF EXISTS "Drivers can insert their own fuel records" ON fuel_records;

-- Remove duplicate policies for inspection_items
DROP POLICY IF EXISTS "Allow all operations for default tenant on inspection_items" ON inspection_items;

-- Remove duplicate policies for inspections
-- Keep only the most specific ones

-- Remove duplicate policies for maintenance_types
DROP POLICY IF EXISTS "Allow all operations for default tenant on maintenance_types" ON maintenance_types;

-- Remove duplicate policies for mechanics
DROP POLICY IF EXISTS "Allow all operations for default tenant on mechanics" ON mechanics;

-- Remove duplicate policies for parts
DROP POLICY IF EXISTS "Allow all operations for default tenant on parts" ON parts;

-- Remove duplicate policies for removed_users
DROP POLICY IF EXISTS "Enable all operations for authenticated users" ON removed_users;

-- Remove duplicate policies for service_notes
DROP POLICY IF EXISTS "Allow all operations for default tenant on service_notes" ON service_notes;

-- Remove duplicate policies for service_order_parts
DROP POLICY IF EXISTS "Allow all operations for default tenant on service_order_parts" ON service_order_parts;

-- Remove duplicate policies for stock_movements
DROP POLICY IF EXISTS "Allow all operations for default tenant on stock_movements" ON stock_movements;

-- Remove duplicate policies for suppliers
DROP POLICY IF EXISTS "Allow all operations for default tenant on suppliers" ON suppliers;
DROP POLICY IF EXISTS "Allow delete for default tenant on suppliers" ON suppliers;
DROP POLICY IF EXISTS "Allow insert for default tenant on suppliers" ON suppliers;
DROP POLICY IF EXISTS "Allow select for default tenant on suppliers" ON suppliers;
DROP POLICY IF EXISTS "Allow update for default tenant on suppliers" ON suppliers;

-- Remove duplicate policies for tenants
DROP POLICY IF EXISTS "Allow read access to default tenant" ON tenants;

-- ============================================================================
-- 3. REMOVE DUPLICATE INDEXES (with proper constraint handling)
-- ============================================================================

-- Remove duplicate indexes on employees table
DROP INDEX IF EXISTS idx_employees_tenant;
-- Keep idx_employees_tenant_id as it's more specific

-- Handle fines table constraints properly
DO $$
BEGIN
    -- Check if fines_fine_number_key is a constraint (not just an index)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'fines_fine_number_key' 
        AND table_name = 'fines'
    ) THEN
        -- It's a constraint, so we need to drop the constraint first
        ALTER TABLE fines DROP CONSTRAINT IF EXISTS fines_fine_number_key;
    ELSE
        -- It's just an index, we can drop it directly
        DROP INDEX IF EXISTS fines_fine_number_key;
    END IF;
    
    -- Keep fines_fine_number_unique as it's more descriptive
    -- If it doesn't exist, we can create it
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'fines_fine_number_unique' 
        AND table_name = 'fines'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'fines_fine_number_unique' 
        AND tablename = 'fines'
    ) THEN
        -- Create the unique constraint if it doesn't exist
        ALTER TABLE fines ADD CONSTRAINT fines_fine_number_unique UNIQUE (fine_number);
    END IF;
END $$;

-- ============================================================================
-- 4. VERIFICATION QUERIES
-- ============================================================================

-- Query to verify that auth.uid() calls are properly wrapped
-- SELECT 
--     schemaname,
--     tablename,
--     policyname,
--     cmd,
--     qual,
--     with_check
-- FROM pg_policies 
-- WHERE qual LIKE '%auth.uid()%' 
--    OR with_check LIKE '%auth.uid()%';

-- Query to verify no duplicate policies exist
-- SELECT 
--     schemaname,
--     tablename,
--     cmd,
--     COUNT(*) as policy_count
-- FROM pg_policies 
-- GROUP BY schemaname, tablename, cmd
-- HAVING COUNT(*) > 1;

-- Query to verify no duplicate indexes exist
-- SELECT 
--     schemaname,
--     tablename,
--     indexname,
--     indexdef,
--     COUNT(*) as index_count
-- FROM pg_indexes 
-- GROUP BY schemaname, tablename, indexname, indexdef
-- HAVING COUNT(*) > 1;

-- Query to verify constraints on fines table
-- SELECT 
--     constraint_name,
--     constraint_type
-- FROM information_schema.table_constraints 
-- WHERE table_name = 'fines' 
-- AND constraint_name LIKE '%fine_number%'; 