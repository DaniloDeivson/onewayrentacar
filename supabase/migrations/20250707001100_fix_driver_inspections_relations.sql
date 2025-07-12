-- Fix driver inspections function to include relations
-- This migration updates the get_driver_inspections function to return inspections with all necessary relations

-- Drop the existing function
DROP FUNCTION IF EXISTS get_driver_inspections(uuid);

-- Create the updated function with relations
CREATE OR REPLACE FUNCTION get_driver_inspections(p_driver_id UUID)
RETURNS TABLE (
    -- All inspection fields
    id uuid,
    tenant_id uuid,
    vehicle_id uuid,
    contract_id uuid,
    customer_id uuid,
    employee_id uuid,
    inspection_type text,
    inspected_at timestamptz,
    inspected_by text,
    location text,
    mileage integer,
    fuel_level numeric,
    notes text,
    signature_url text,
    dashboard_photo_url text,
    dashboard_warning_light boolean,
    created_at timestamptz,
    updated_at timestamptz,
    -- Vehicle relations
    vehicle_plate text,
    vehicle_model text,
    vehicle_year integer,
    vehicle_type text,
    -- Employee relations
    employee_name text,
    employee_role text,
    -- Contract relations
    contract_number text,
    -- Customer relations
    customer_name text,
    -- Inspection items
    inspection_items json
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id,
        i.tenant_id,
        i.vehicle_id,
        i.contract_id,
        i.customer_id,
        i.employee_id,
        i.inspection_type,
        i.inspected_at,
        i.inspected_by,
        i.location,
        i.mileage,
        i.fuel_level,
        i.notes,
        i.signature_url,
        i.dashboard_photo_url,
        i.dashboard_warning_light,
        i.created_at,
        i.updated_at,
        -- Vehicle data
        v.plate as vehicle_plate,
        v.model as vehicle_model,
        v.year as vehicle_year,
        v.type as vehicle_type,
        -- Employee data
        e.name as employee_name,
        e.role as employee_role,
        -- Contract data
        c.contract_number,
        -- Customer data
        cust.name as customer_name,
        -- Inspection items as JSON
        COALESCE(
            (SELECT json_agg(
                json_build_object(
                    'id', ii.id,
                    'location', ii.location,
                    'description', ii.description,
                    'damage_type', ii.damage_type,
                    'severity', ii.severity,
                    'photo_url', ii.photo_url,
                    'requires_repair', ii.requires_repair
                )
            ) FROM inspection_items ii WHERE ii.inspection_id = i.id),
            '[]'::json
        ) as inspection_items
    FROM inspections i
    INNER JOIN vehicles v ON v.id = i.vehicle_id
    INNER JOIN driver_vehicles dv ON dv.vehicle_id = v.id
    LEFT JOIN employees e ON e.id = i.employee_id
    LEFT JOIN contracts c ON c.id = i.contract_id
    LEFT JOIN customers cust ON cust.id = i.customer_id
    WHERE dv.driver_id = p_driver_id
    AND dv.active = true
    ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 