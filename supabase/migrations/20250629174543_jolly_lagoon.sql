/*
  # Fix inspection trigger functions

  1. Database Functions
    - Update `fn_update_vehicle_status_on_inspection` to use correct field references
    - Update `fn_auto_create_damage_cost` to use correct field references
    - Ensure all trigger functions reference the correct column names

  2. Corrections
    - Change `NEW.inspection_id` to `NEW.id` in inspections table triggers
    - Ensure proper field references in all related functions
*/

-- Drop and recreate the vehicle status update function
DROP FUNCTION IF EXISTS fn_update_vehicle_status_on_inspection() CASCADE;

CREATE OR REPLACE FUNCTION fn_update_vehicle_status_on_inspection()
RETURNS TRIGGER AS $$
BEGIN
  -- For inspections table trigger (CheckOut with damages)
  IF TG_TABLE_NAME = 'inspections' THEN
    -- Only update vehicle status if it's a CheckOut inspection
    IF NEW.inspection_type = 'CheckOut' THEN
      -- Check if there are any inspection items that require repair
      IF EXISTS (
        SELECT 1 FROM inspection_items 
        WHERE inspection_id = NEW.id 
        AND requires_repair = true
      ) THEN
        -- Update vehicle status to maintenance
        UPDATE vehicles 
        SET status = 'Manutenção', updated_at = now()
        WHERE id = NEW.vehicle_id;
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  -- For inspection_items table trigger
  IF TG_TABLE_NAME = 'inspection_items' THEN
    -- Get the inspection details
    DECLARE
      inspection_record RECORD;
    BEGIN
      SELECT * INTO inspection_record 
      FROM inspections 
      WHERE id = NEW.inspection_id;
      
      -- Only update vehicle status if it's a CheckOut inspection and requires repair
      IF inspection_record.inspection_type = 'CheckOut' AND NEW.requires_repair = true THEN
        UPDATE vehicles 
        SET status = 'Manutenção', updated_at = now()
        WHERE id = inspection_record.vehicle_id;
      END IF;
      
      RETURN NEW;
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate the auto damage cost function
DROP FUNCTION IF EXISTS fn_auto_create_damage_cost() CASCADE;

CREATE OR REPLACE FUNCTION fn_auto_create_damage_cost()
RETURNS TRIGGER AS $$
DECLARE
  inspection_record RECORD;
  cost_description TEXT;
BEGIN
  -- Get inspection details
  SELECT i.*, v.plate, v.model 
  INTO inspection_record
  FROM inspections i
  JOIN vehicles v ON v.id = i.vehicle_id
  WHERE i.id = NEW.inspection_id;
  
  -- Only create cost for CheckOut inspections with damages that require repair
  IF inspection_record.inspection_type = 'CheckOut' AND NEW.requires_repair = true THEN
    -- Create description for the cost
    cost_description := format(
      'Dano detectado em %s - %s (%s): %s - %s',
      inspection_record.plate,
      inspection_record.model,
      NEW.location,
      NEW.damage_type,
      NEW.description
    );
    
    -- Insert cost record
    INSERT INTO costs (
      tenant_id,
      category,
      vehicle_id,
      description,
      amount,
      cost_date,
      status,
      observations
    ) VALUES (
      inspection_record.tenant_id,
      'Funilaria',
      inspection_record.vehicle_id,
      cost_description,
      0.00, -- Amount to be defined later
      CURRENT_DATE,
      'Pendente',
      format('Custo gerado automaticamente a partir da inspeção %s. Valor a ser definido após orçamento.', inspection_record.id)
    );
    
    -- Create damage notification record
    INSERT INTO damage_notifications (
      tenant_id,
      cost_id,
      inspection_item_id,
      notification_data,
      status
    ) VALUES (
      inspection_record.tenant_id,
      (SELECT id FROM costs WHERE description = cost_description ORDER BY created_at DESC LIMIT 1),
      NEW.id,
      jsonb_build_object(
        'vehicle_plate', inspection_record.plate,
        'vehicle_model', inspection_record.model,
        'damage_location', NEW.location,
        'damage_type', NEW.damage_type,
        'damage_description', NEW.description,
        'severity', NEW.severity,
        'inspection_date', inspection_record.inspected_at,
        'inspector', inspection_record.inspected_by
      ),
      'pending'
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate triggers with correct function references
DROP TRIGGER IF EXISTS trg_inspections_update_vehicle_status ON inspections;
CREATE TRIGGER trg_inspections_update_vehicle_status
  AFTER INSERT ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_vehicle_status_on_inspection();

DROP TRIGGER IF EXISTS trg_inspections_update_vehicle_status ON inspection_items;
CREATE TRIGGER trg_inspections_update_vehicle_status
  AFTER INSERT ON inspection_items
  FOR EACH ROW
  WHEN (NEW.requires_repair = true)
  EXECUTE FUNCTION fn_update_vehicle_status_on_inspection();

DROP TRIGGER IF EXISTS trg_inspection_items_auto_damage_cost ON inspection_items;
CREATE TRIGGER trg_inspection_items_auto_damage_cost
  AFTER INSERT ON inspection_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_create_damage_cost();

-- Create the inspection statistics function if it doesn't exist
CREATE OR REPLACE FUNCTION fn_inspection_statistics(
  p_tenant_id UUID,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
  total_inspections BIGINT,
  checkin_count BIGINT,
  checkout_count BIGINT,
  total_damages BIGINT,
  high_severity_damages BIGINT,
  total_estimated_costs NUMERIC,
  vehicles_in_maintenance BIGINT,
  average_damages_per_checkout NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  WITH inspection_stats AS (
    SELECT 
      COUNT(*) as total_insp,
      COUNT(*) FILTER (WHERE inspection_type = 'CheckIn') as checkin,
      COUNT(*) FILTER (WHERE inspection_type = 'CheckOut') as checkout
    FROM inspections i
    WHERE i.tenant_id = p_tenant_id
      AND (p_start_date IS NULL OR i.inspected_at::date >= p_start_date)
      AND (p_end_date IS NULL OR i.inspected_at::date <= p_end_date)
  ),
  damage_stats AS (
    SELECT 
      COUNT(*) as total_dam,
      COUNT(*) FILTER (WHERE severity = 'Alta') as high_sev,
      COALESCE(SUM(c.amount), 0) as total_costs
    FROM inspection_items ii
    JOIN inspections i ON i.id = ii.inspection_id
    LEFT JOIN costs c ON c.vehicle_id = i.vehicle_id 
      AND c.category = 'Funilaria'
      AND c.created_at::date = i.inspected_at::date
    WHERE i.tenant_id = p_tenant_id
      AND (p_start_date IS NULL OR i.inspected_at::date >= p_start_date)
      AND (p_end_date IS NULL OR i.inspected_at::date <= p_end_date)
  ),
  vehicle_maintenance AS (
    SELECT COUNT(*) as maint_count
    FROM vehicles v
    WHERE v.tenant_id = p_tenant_id
      AND v.status = 'Manutenção'
  )
  SELECT 
    is_stats.total_insp,
    is_stats.checkin,
    is_stats.checkout,
    d_stats.total_dam,
    d_stats.high_sev,
    d_stats.total_costs,
    vm.maint_count,
    CASE 
      WHEN is_stats.checkout > 0 THEN d_stats.total_dam::numeric / is_stats.checkout::numeric
      ELSE 0
    END
  FROM inspection_stats is_stats
  CROSS JOIN damage_stats d_stats
  CROSS JOIN vehicle_maintenance vm;
END;
$$ LANGUAGE plpgsql;