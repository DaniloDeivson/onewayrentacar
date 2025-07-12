-- Drop existing function first to avoid return type conflicts
DROP FUNCTION IF EXISTS fn_inspection_statistics(uuid);
DROP FUNCTION IF EXISTS fn_inspection_statistics(uuid, date, date);

-- Create the inspection statistics function
CREATE OR REPLACE FUNCTION fn_inspection_statistics(
  p_tenant_id uuid,
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL
)
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
SECURITY DEFINER
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
      AND (p_start_date IS NULL OR i.inspected_at::date >= p_start_date)
      AND (p_end_date IS NULL OR i.inspected_at::date <= p_end_date)
  ),
  damage_stats AS (
    SELECT 
      COUNT(*) as total_damages,
      COUNT(*) FILTER (WHERE ii.severity = 'Alta') as high_severity_damages,
      COALESCE(SUM(c.amount), 0) as total_estimated_costs
    FROM inspection_items ii
    JOIN inspections i ON ii.inspection_id = i.id
    LEFT JOIN damage_notifications dn ON dn.inspection_item_id = ii.id
    LEFT JOIN costs c ON c.id = dn.cost_id
    WHERE i.tenant_id = p_tenant_id
      AND (p_start_date IS NULL OR i.inspected_at::date >= p_start_date)
      AND (p_end_date IS NULL OR i.inspected_at::date <= p_end_date)
  ),
  vehicle_maintenance_stats AS (
    SELECT 
      COUNT(*) as vehicles_in_maintenance
    FROM vehicles v
    WHERE v.tenant_id = p_tenant_id
      AND v.status = 'Manutenção'
  ),
  checkout_damage_stats AS (
    SELECT 
      CASE 
        WHEN COUNT(*) FILTER (WHERE i.inspection_type = 'CheckOut') > 0 
        THEN ROUND(
          COUNT(ii.id)::numeric / 
          COUNT(*) FILTER (WHERE i.inspection_type = 'CheckOut')::numeric, 
          2
        )
        ELSE 0
      END as avg_damages_per_checkout
    FROM inspections i
    LEFT JOIN inspection_items ii ON ii.inspection_id = i.id
    WHERE i.tenant_id = p_tenant_id
      AND (p_start_date IS NULL OR i.inspected_at::date >= p_start_date)
      AND (p_end_date IS NULL OR i.inspected_at::date <= p_end_date)
  )
  SELECT 
    COALESCE(ins.total_inspections, 0),
    COALESCE(ins.checkin_count, 0),
    COALESCE(ins.checkout_count, 0),
    COALESCE(dmg.total_damages, 0),
    COALESCE(dmg.high_severity_damages, 0),
    COALESCE(dmg.total_estimated_costs, 0),
    COALESCE(vms.vehicles_in_maintenance, 0),
    COALESCE(cds.avg_damages_per_checkout, 0)
  FROM inspection_stats ins
  CROSS JOIN damage_stats dmg
  CROSS JOIN vehicle_maintenance_stats vms
  CROSS JOIN checkout_damage_stats cds;
END;
$$;