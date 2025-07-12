/*
  # Service Order Parts Integration

  1. New Tables
    - `service_order_parts`
      - `id` (uuid, primary key)
      - `tenant_id` (uuid, foreign key to tenants)
      - `service_note_id` (uuid, foreign key to service_notes)
      - `part_id` (uuid, foreign key to parts)
      - `quantity_used` (integer)
      - `unit_cost_at_time` (numeric)
      - `total_cost` (computed column)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on `service_order_parts` table
    - Add policies for authenticated users to manage their tenant data
    - Add policy for default tenant access

  3. Automation
    - Trigger to handle stock reduction and cost creation when parts are used
    - Trigger to reverse stock when parts usage is deleted
    - Functions to maintain data consistency
*/

-- Create service_order_parts junction table
CREATE TABLE IF NOT EXISTS service_order_parts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  service_note_id uuid REFERENCES service_notes(id) ON DELETE CASCADE,
  part_id uuid REFERENCES parts(id) ON DELETE CASCADE,
  quantity_used integer NOT NULL CHECK (quantity_used > 0),
  unit_cost_at_time numeric(12,2) NOT NULL CHECK (unit_cost_at_time >= 0),
  total_cost numeric(12,2) GENERATED ALWAYS AS (quantity_used * unit_cost_at_time) STORED,
  created_at timestamptz DEFAULT now()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_service_order_parts_service_note ON service_order_parts(service_note_id);
CREATE INDEX IF NOT EXISTS idx_service_order_parts_part ON service_order_parts(part_id);
CREATE INDEX IF NOT EXISTS idx_service_order_parts_tenant ON service_order_parts(tenant_id);

-- Enable RLS
ALTER TABLE service_order_parts ENABLE ROW LEVEL SECURITY;

-- Create policies for service_order_parts
CREATE POLICY "Allow all operations for default tenant on service_order_parts"
  ON service_order_parts
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Users can manage their tenant service order parts"
  ON service_order_parts
  FOR ALL
  TO authenticated
  USING (tenant_id IN (
    SELECT tenants.id
    FROM tenants
    WHERE auth.uid() IS NOT NULL
  ))
  WITH CHECK (tenant_id IN (
    SELECT tenants.id
    FROM tenants
    WHERE auth.uid() IS NOT NULL
  ));

-- Function to handle parts usage in service orders
CREATE OR REPLACE FUNCTION handle_service_order_parts()
RETURNS TRIGGER AS $$
DECLARE
  v_part_name TEXT;
  v_part_quantity INTEGER;
  v_vehicle_id UUID;
BEGIN
  -- Get part information
  SELECT name, quantity INTO v_part_name, v_part_quantity
  FROM parts 
  WHERE id = NEW.part_id;

  -- Get service order vehicle information
  SELECT vehicle_id INTO v_vehicle_id
  FROM service_notes 
  WHERE id = NEW.service_note_id;

  -- Check if we have enough stock
  IF v_part_quantity < NEW.quantity_used THEN
    RAISE EXCEPTION 'Insufficient stock for part %. Available: %, Required: %', 
      v_part_name, v_part_quantity, NEW.quantity_used;
  END IF;

  -- Update parts quantity
  UPDATE parts 
  SET quantity = quantity - NEW.quantity_used,
      updated_at = now()
  WHERE id = NEW.part_id;

  -- Create stock movement record
  INSERT INTO stock_movements (
    tenant_id,
    part_id,
    service_note_id,
    type,
    quantity,
    movement_date,
    created_at
  ) VALUES (
    NEW.tenant_id,
    NEW.part_id,
    NEW.service_note_id,
    'Saída',
    NEW.quantity_used,
    CURRENT_DATE,
    now()
  );

  -- Create cost record
  INSERT INTO costs (
    tenant_id,
    category,
    vehicle_id,
    description,
    amount,
    cost_date,
    status,
    document_ref,
    observations,
    created_at
  ) VALUES (
    NEW.tenant_id,
    'Avulsa',
    v_vehicle_id,
    CONCAT('Peça utilizada: ', v_part_name, ' (Qtde: ', NEW.quantity_used, ')'),
    NEW.total_cost,
    CURRENT_DATE,
    'Pendente',
    CONCAT('OS-', NEW.service_note_id),
    CONCAT('Lançamento automático via Ordem de Serviço'),
    now()
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for automatic processing
CREATE TRIGGER trg_service_order_parts_handle
  AFTER INSERT ON service_order_parts
  FOR EACH ROW
  EXECUTE FUNCTION handle_service_order_parts();

-- Function to reverse parts usage (for deletions/corrections)
CREATE OR REPLACE FUNCTION reverse_service_order_parts()
RETURNS TRIGGER AS $$
BEGIN
  -- Return parts to stock
  UPDATE parts 
  SET quantity = quantity + OLD.quantity_used,
      updated_at = now()
  WHERE id = OLD.part_id;

  -- Create reverse stock movement
  INSERT INTO stock_movements (
    tenant_id,
    part_id,
    service_note_id,
    type,
    quantity,
    movement_date,
    created_at
  ) VALUES (
    OLD.tenant_id,
    OLD.part_id,
    OLD.service_note_id,
    'Entrada',
    OLD.quantity_used,
    CURRENT_DATE,
    now()
  );

  -- Note: We don't automatically delete the cost record as it may need manual review
  -- But we could mark it as "Cancelled" or similar

  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for reversals
CREATE TRIGGER trg_service_order_parts_reverse
  AFTER DELETE ON service_order_parts
  FOR EACH ROW
  EXECUTE FUNCTION reverse_service_order_parts();