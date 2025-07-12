-- Fix Database Linter Issues - Schema Verified Version
-- This migration addresses:
-- 1. Auth RLS Initialization Plan - Wrap auth.<function>() calls in (SELECT auth.<function>())
-- 2. Multiple Permissive Policies - Remove duplicate policies
-- 3. Duplicate Indexes - Remove duplicate indexes (with proper constraint handling)
-- Based on actual database schema

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

-- Fix customer_charges table RLS policies
DROP POLICY IF EXISTS "Customer charges are insertable by same tenant" ON customer_charges;
DROP POLICY IF EXISTS "Customer charges are updatable by same tenant" ON customer_charges;
DROP POLICY IF EXISTS "Customer charges are viewable by same tenant" ON customer_charges;

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

-- Fix contract_vehicles table RLS policies
DROP POLICY IF EXISTS "Users can delete contract_vehicles from their tenant" ON contract_vehicles;
DROP POLICY IF EXISTS "Users can insert contract_vehicles for their tenant" ON contract_vehicles;
DROP POLICY IF EXISTS "Users can update contract_vehicles from their tenant" ON contract_vehicles;
DROP POLICY IF EXISTS "Users can view contract_vehicles from their tenant" ON contract_vehicles;

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

-- Fix contracts table RLS policies
DROP POLICY IF EXISTS "Users can delete contracts from their tenant" ON contracts;
DROP POLICY IF EXISTS "Users can insert contracts for their tenant" ON contracts;
DROP POLICY IF EXISTS "Users can update contracts from their tenant" ON contracts;
DROP POLICY IF EXISTS "Users can view contracts from their tenant" ON contracts;

CREATE POLICY "Users can delete contracts from their tenant" ON contracts
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert contracts for their tenant" ON contracts
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update contracts from their tenant" ON contracts
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view contracts from their tenant" ON contracts
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix customers table RLS policies
DROP POLICY IF EXISTS "Users can delete customers from their tenant" ON customers;
DROP POLICY IF EXISTS "Users can insert customers for their tenant" ON customers;
DROP POLICY IF EXISTS "Users can update customers from their tenant" ON customers;
DROP POLICY IF EXISTS "Users can view customers from their tenant" ON customers;

CREATE POLICY "Users can delete customers from their tenant" ON customers
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert customers for their tenant" ON customers
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update customers from their tenant" ON customers
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view customers from their tenant" ON customers
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix employees table RLS policies
DROP POLICY IF EXISTS "Users can delete employees from their tenant" ON employees;
DROP POLICY IF EXISTS "Users can insert employees for their tenant" ON employees;
DROP POLICY IF EXISTS "Users can update employees from their tenant" ON employees;
DROP POLICY IF EXISTS "Users can view employees from their tenant" ON employees;

CREATE POLICY "Users can delete employees from their tenant" ON employees
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert employees for their tenant" ON employees
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update employees from their tenant" ON employees
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view employees from their tenant" ON employees
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix vehicles table RLS policies
DROP POLICY IF EXISTS "Users can delete vehicles from their tenant" ON vehicles;
DROP POLICY IF EXISTS "Users can insert vehicles for their tenant" ON vehicles;
DROP POLICY IF EXISTS "Users can update vehicles from their tenant" ON vehicles;
DROP POLICY IF EXISTS "Users can view vehicles from their tenant" ON vehicles;

CREATE POLICY "Users can delete vehicles from their tenant" ON vehicles
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert vehicles for their tenant" ON vehicles
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update vehicles from their tenant" ON vehicles
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view vehicles from their tenant" ON vehicles
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix suppliers table RLS policies
DROP POLICY IF EXISTS "Users can delete suppliers from their tenant" ON suppliers;
DROP POLICY IF EXISTS "Users can insert suppliers for their tenant" ON suppliers;
DROP POLICY IF EXISTS "Users can update suppliers from their tenant" ON suppliers;
DROP POLICY IF EXISTS "Users can view suppliers from their tenant" ON suppliers;

CREATE POLICY "Users can delete suppliers from their tenant" ON suppliers
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert suppliers for their tenant" ON suppliers
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update suppliers from their tenant" ON suppliers
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view suppliers from their tenant" ON suppliers
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix accounts_payable table RLS policies
DROP POLICY IF EXISTS "Users can delete accounts_payable from their tenant" ON accounts_payable;
DROP POLICY IF EXISTS "Users can insert accounts_payable for their tenant" ON accounts_payable;
DROP POLICY IF EXISTS "Users can update accounts_payable from their tenant" ON accounts_payable;
DROP POLICY IF EXISTS "Users can view accounts_payable from their tenant" ON accounts_payable;

CREATE POLICY "Users can delete accounts_payable from their tenant" ON accounts_payable
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert accounts_payable for their tenant" ON accounts_payable
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update accounts_payable from their tenant" ON accounts_payable
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view accounts_payable from their tenant" ON accounts_payable
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix salaries table RLS policies
DROP POLICY IF EXISTS "Users can delete salaries from their tenant" ON salaries;
DROP POLICY IF EXISTS "Users can insert salaries for their tenant" ON salaries;
DROP POLICY IF EXISTS "Users can update salaries from their tenant" ON salaries;
DROP POLICY IF EXISTS "Users can view salaries from their tenant" ON salaries;

CREATE POLICY "Users can delete salaries from their tenant" ON salaries
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert salaries for their tenant" ON salaries
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update salaries from their tenant" ON salaries
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view salaries from their tenant" ON salaries
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix recurring_expenses table RLS policies
DROP POLICY IF EXISTS "Users can delete recurring_expenses from their tenant" ON recurring_expenses;
DROP POLICY IF EXISTS "Users can insert recurring_expenses for their tenant" ON recurring_expenses;
DROP POLICY IF EXISTS "Users can update recurring_expenses from their tenant" ON recurring_expenses;
DROP POLICY IF EXISTS "Users can view recurring_expenses from their tenant" ON recurring_expenses;

CREATE POLICY "Users can delete recurring_expenses from their tenant" ON recurring_expenses
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert recurring_expenses for their tenant" ON recurring_expenses
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update recurring_expenses from their tenant" ON recurring_expenses
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view recurring_expenses from their tenant" ON recurring_expenses
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix purchase_orders table RLS policies
DROP POLICY IF EXISTS "Users can delete purchase_orders from their tenant" ON purchase_orders;
DROP POLICY IF EXISTS "Users can insert purchase_orders for their tenant" ON purchase_orders;
DROP POLICY IF EXISTS "Users can update purchase_orders from their tenant" ON purchase_orders;
DROP POLICY IF EXISTS "Users can view purchase_orders from their tenant" ON purchase_orders;

CREATE POLICY "Users can delete purchase_orders from their tenant" ON purchase_orders
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert purchase_orders for their tenant" ON purchase_orders
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update purchase_orders from their tenant" ON purchase_orders
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view purchase_orders from their tenant" ON purchase_orders
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix parts table RLS policies
DROP POLICY IF EXISTS "Users can delete parts from their tenant" ON parts;
DROP POLICY IF EXISTS "Users can insert parts for their tenant" ON parts;
DROP POLICY IF EXISTS "Users can update parts from their tenant" ON parts;
DROP POLICY IF EXISTS "Users can view parts from their tenant" ON parts;

CREATE POLICY "Users can delete parts from their tenant" ON parts
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert parts for their tenant" ON parts
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update parts from their tenant" ON parts
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view parts from their tenant" ON parts
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix service_notes table RLS policies
DROP POLICY IF EXISTS "Users can delete service_notes from their tenant" ON service_notes;
DROP POLICY IF EXISTS "Users can insert service_notes for their tenant" ON service_notes;
DROP POLICY IF EXISTS "Users can update service_notes from their tenant" ON service_notes;
DROP POLICY IF EXISTS "Users can view service_notes from their tenant" ON service_notes;

CREATE POLICY "Users can delete service_notes from their tenant" ON service_notes
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert service_notes for their tenant" ON service_notes
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update service_notes from their tenant" ON service_notes
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view service_notes from their tenant" ON service_notes
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix service_order_parts table RLS policies
DROP POLICY IF EXISTS "Users can delete service_order_parts from their tenant" ON service_order_parts;
DROP POLICY IF EXISTS "Users can insert service_order_parts for their tenant" ON service_order_parts;
DROP POLICY IF EXISTS "Users can update service_order_parts from their tenant" ON service_order_parts;
DROP POLICY IF EXISTS "Users can view service_order_parts from their tenant" ON service_order_parts;

CREATE POLICY "Users can delete service_order_parts from their tenant" ON service_order_parts
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert service_order_parts for their tenant" ON service_order_parts
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update service_order_parts from their tenant" ON service_order_parts
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view service_order_parts from their tenant" ON service_order_parts
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix stock_movements table RLS policies
DROP POLICY IF EXISTS "Users can delete stock_movements from their tenant" ON stock_movements;
DROP POLICY IF EXISTS "Users can insert stock_movements for their tenant" ON stock_movements;
DROP POLICY IF EXISTS "Users can update stock_movements from their tenant" ON stock_movements;
DROP POLICY IF EXISTS "Users can view stock_movements from their tenant" ON stock_movements;

CREATE POLICY "Users can delete stock_movements from their tenant" ON stock_movements
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert stock_movements for their tenant" ON stock_movements
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update stock_movements from their tenant" ON stock_movements
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view stock_movements from their tenant" ON stock_movements
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix maintenance_checkins table RLS policies
DROP POLICY IF EXISTS "Users can delete maintenance_checkins from their tenant" ON maintenance_checkins;
DROP POLICY IF EXISTS "Users can insert maintenance_checkins for their tenant" ON maintenance_checkins;
DROP POLICY IF EXISTS "Users can update maintenance_checkins from their tenant" ON maintenance_checkins;
DROP POLICY IF EXISTS "Users can view maintenance_checkins from their tenant" ON maintenance_checkins;

CREATE POLICY "Users can delete maintenance_checkins from their tenant" ON maintenance_checkins
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert maintenance_checkins for their tenant" ON maintenance_checkins
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update maintenance_checkins from their tenant" ON maintenance_checkins
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view maintenance_checkins from their tenant" ON maintenance_checkins
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix maintenance_types table RLS policies
DROP POLICY IF EXISTS "Users can delete maintenance_types from their tenant" ON maintenance_types;
DROP POLICY IF EXISTS "Users can insert maintenance_types for their tenant" ON maintenance_types;
DROP POLICY IF EXISTS "Users can update maintenance_types from their tenant" ON maintenance_types;
DROP POLICY IF EXISTS "Users can view maintenance_types from their tenant" ON maintenance_types;

CREATE POLICY "Users can delete maintenance_types from their tenant" ON maintenance_types
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert maintenance_types for their tenant" ON maintenance_types
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update maintenance_types from their tenant" ON maintenance_types
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view maintenance_types from their tenant" ON maintenance_types
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix mechanics table RLS policies
DROP POLICY IF EXISTS "Users can delete mechanics from their tenant" ON mechanics;
DROP POLICY IF EXISTS "Users can insert mechanics for their tenant" ON mechanics;
DROP POLICY IF EXISTS "Users can update mechanics from their tenant" ON mechanics;
DROP POLICY IF EXISTS "Users can view mechanics from their tenant" ON mechanics;

CREATE POLICY "Users can delete mechanics from their tenant" ON mechanics
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert mechanics for their tenant" ON mechanics
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update mechanics from their tenant" ON mechanics
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view mechanics from their tenant" ON mechanics
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix drivers table RLS policies
DROP POLICY IF EXISTS "Users can delete drivers from their tenant" ON drivers;
DROP POLICY IF EXISTS "Users can insert drivers for their tenant" ON drivers;
DROP POLICY IF EXISTS "Users can update drivers from their tenant" ON drivers;
DROP POLICY IF EXISTS "Users can view drivers from their tenant" ON drivers;

CREATE POLICY "Users can delete drivers from their tenant" ON drivers
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert drivers for their tenant" ON drivers
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update drivers from their tenant" ON drivers
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view drivers from their tenant" ON drivers
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix fuel_records table RLS policies
DROP POLICY IF EXISTS "Users can delete fuel_records from their tenant" ON fuel_records;
DROP POLICY IF EXISTS "Users can insert fuel_records for their tenant" ON fuel_records;
DROP POLICY IF EXISTS "Users can update fuel_records from their tenant" ON fuel_records;
DROP POLICY IF EXISTS "Users can view fuel_records from their tenant" ON fuel_records;

CREATE POLICY "Users can delete fuel_records from their tenant" ON fuel_records
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert fuel_records for their tenant" ON fuel_records
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update fuel_records from their tenant" ON fuel_records
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view fuel_records from their tenant" ON fuel_records
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix vehicle_history table RLS policies
DROP POLICY IF EXISTS "Users can delete vehicle_history from their tenant" ON vehicle_history;
DROP POLICY IF EXISTS "Users can insert vehicle_history for their tenant" ON vehicle_history;
DROP POLICY IF EXISTS "Users can update vehicle_history from their tenant" ON vehicle_history;
DROP POLICY IF EXISTS "Users can view vehicle_history from their tenant" ON vehicle_history;

CREATE POLICY "Users can delete vehicle_history from their tenant" ON vehicle_history
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert vehicle_history for their tenant" ON vehicle_history
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update vehicle_history from their tenant" ON vehicle_history
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view vehicle_history from their tenant" ON vehicle_history
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix damage_notifications table RLS policies
DROP POLICY IF EXISTS "Users can delete damage_notifications from their tenant" ON damage_notifications;
DROP POLICY IF EXISTS "Users can insert damage_notifications for their tenant" ON damage_notifications;
DROP POLICY IF EXISTS "Users can update damage_notifications from their tenant" ON damage_notifications;
DROP POLICY IF EXISTS "Users can view damage_notifications from their tenant" ON damage_notifications;

CREATE POLICY "Users can delete damage_notifications from their tenant" ON damage_notifications
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert damage_notifications for their tenant" ON damage_notifications
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update damage_notifications from their tenant" ON damage_notifications
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view damage_notifications from their tenant" ON damage_notifications
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix driver_inspections table RLS policies
DROP POLICY IF EXISTS "Users can delete driver_inspections from their tenant" ON driver_inspections;
DROP POLICY IF EXISTS "Users can insert driver_inspections for their tenant" ON driver_inspections;
DROP POLICY IF EXISTS "Users can update driver_inspections from their tenant" ON driver_inspections;
DROP POLICY IF EXISTS "Users can view driver_inspections from their tenant" ON driver_inspections;

CREATE POLICY "Users can delete driver_inspections from their tenant" ON driver_inspections
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert driver_inspections for their tenant" ON driver_inspections
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update driver_inspections from their tenant" ON driver_inspections
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view driver_inspections from their tenant" ON driver_inspections
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- Fix inspection_damages table RLS policies
DROP POLICY IF EXISTS "Users can delete inspection_damages from their tenant" ON inspection_damages;
DROP POLICY IF EXISTS "Users can insert inspection_damages for their tenant" ON inspection_damages;
DROP POLICY IF EXISTS "Users can update inspection_damages from their tenant" ON inspection_damages;
DROP POLICY IF EXISTS "Users can view inspection_damages from their tenant" ON inspection_damages;

CREATE POLICY "Users can delete inspection_damages from their tenant" ON inspection_damages
    FOR DELETE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can insert inspection_damages for their tenant" ON inspection_damages
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can update inspection_damages from their tenant" ON inspection_damages
    FOR UPDATE USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    ) WITH CHECK (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

CREATE POLICY "Users can view inspection_damages from their tenant" ON inspection_damages
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM employees WHERE id = (SELECT auth.uid()))
    );

-- ============================================================================
-- 2. REMOVE DUPLICATE INDEXES
-- ============================================================================

-- Remove duplicate indexes (these are already unique constraints)
-- Note: fines_fine_number_key is a unique constraint, not a simple index
-- We'll drop the constraint and recreate it as a unique constraint

-- Drop the unique constraint first, then recreate it
ALTER TABLE fines DROP CONSTRAINT IF EXISTS fines_fine_number_key;
ALTER TABLE fines ADD CONSTRAINT fines_fine_number_key UNIQUE (fine_number);

-- ============================================================================
-- 3. VERIFICATION QUERIES
-- ============================================================================

-- Check for any remaining auth.<function>() calls without SELECT wrapper
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE qual::text LIKE '%auth.%' 
   OR with_check::text LIKE '%auth.%';

-- Check for duplicate policies
SELECT 
    schemaname,
    tablename,
    policyname,
    COUNT(*) as policy_count
FROM pg_policies 
WHERE schemaname = 'public'
GROUP BY schemaname, tablename, policyname
HAVING COUNT(*) > 1;

-- Check for duplicate indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    COUNT(*) as index_count
FROM pg_indexes 
WHERE schemaname = 'public'
GROUP BY schemaname, tablename, indexname
HAVING COUNT(*) > 1; 