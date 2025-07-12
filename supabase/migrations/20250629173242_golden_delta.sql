/*
  # Create inspection statistics function

  1. New Functions
    - `fn_inspection_statistics` - Returns comprehensive inspection statistics
      - Total inspections count
      - Check-in vs check-out counts  
      - Total damage items
      - High severity damage count
      - Total estimated costs from related damage costs
      - Vehicles currently in maintenance
      - Average damages per checkout inspection

  2. Implementation Details
    - Uses existing schema structure with costs table for damage estimates
    - Links inspection items to costs via damage_notifications table
    - Calculates statistics based on inspection types and damage severity
    - Returns statistics for specified tenant
*/

CREATE OR REPLACE FUNCTION fn_inspection_statistics(p_tenant_id uuid)
RETURNS TABLE (
  total_inspections bigint,
  checkin_count bigint,
  checkout_count bigint,
  total_damages bigint,
  high_severity_damages bigint,
  total_estimated_costs numeric,
  vehicles_in_maintenance bigint,
  average_damages_per_checkout numeric
) 
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH inspection_stats AS (
    SELECT 
      COUNT(*) as total_inspections,
      COUNT(*) FILTER (WHERE i.inspection_type = 'CheckIn') as checkin_count,
      COUNT(*) FILTER (WHERE i.inspection_type = 'CheckOut') as checkout_count
    FROM inspections i
    WHERE i.tenant_id = p_tenant_id
  ),
  damage_stats AS (
    SELECT 
      COUNT(*) as total_damages,
      COUNT(*) FILTER (WHERE ii.severity = 'Alta') as high_severity_damages
    FROM inspection_items ii
    JOIN inspections i ON ii.inspection_id = i.id
    WHERE i.tenant_id = p_tenant_id
  ),
  cost_stats AS (
    SELECT 
      COALESCE(SUM(c.amount), 0) as total_estimated_costs
    FROM costs c
    JOIN damage_notifications dn ON c.id = dn.cost_id
    JOIN inspection_items ii ON dn.inspection_item_id = ii.id
    JOIN inspections i ON ii.inspection_id = i.id
    WHERE i.tenant_id = p_tenant_id
      AND c.category = 'Funilaria'
  ),
  maintenance_vehicles AS (
    SELECT 
      COUNT(DISTINCT v.id) as vehicles_in_maintenance
    FROM vehicles v
    WHERE v.tenant_id = p_tenant_id
      AND v.status = 'Manutenção'
  ),
  checkout_damage_avg AS (
    SELECT 
      CASE 
        WHEN COUNT(DISTINCT i.id) FILTER (WHERE i.inspection_type = 'CheckOut') > 0 
        THEN COUNT(ii.id)::numeric / COUNT(DISTINCT i.id) FILTER (WHERE i.inspection_type = 'CheckOut')
        ELSE 0
      END as avg_damages_per_checkout
    FROM inspections i
    LEFT JOIN inspection_items ii ON i.id = ii.inspection_id
    WHERE i.tenant_id = p_tenant_id
  )
  SELECT 
    is_stats.total_inspections,
    is_stats.checkin_count,
    is_stats.checkout_count,
    d_stats.total_damages,
    d_stats.high_severity_damages,
    c_stats.total_estimated_costs,
    m_vehicles.vehicles_in_maintenance,
    cd_avg.avg_damages_per_checkout
  FROM inspection_stats is_stats
  CROSS JOIN damage_stats d_stats
  CROSS JOIN cost_stats c_stats
  CROSS JOIN maintenance_vehicles m_vehicles
  CROSS JOIN checkout_damage_avg cd_avg;
END;
$$;