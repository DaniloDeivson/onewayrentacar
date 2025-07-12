-- Create suppliers table if it doesn't exist
CREATE TABLE IF NOT EXISTS suppliers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  contact_info jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for suppliers
CREATE INDEX IF NOT EXISTS idx_suppliers_tenant_id ON suppliers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name);

-- Enable RLS on suppliers
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;

-- Create purchase_orders table if it doesn't exist
CREATE TABLE IF NOT EXISTS purchase_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  supplier_id uuid NOT NULL REFERENCES suppliers(id),
  order_number text UNIQUE NOT NULL,
  order_date date NOT NULL,
  total_amount numeric(12,2) NOT NULL CHECK(total_amount >= 0),
  status text NOT NULL CHECK(status IN ('Pending', 'Received', 'Cancelled', 'Aprovada')),
  created_by_employee_id uuid REFERENCES employees(id),
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for purchase_orders
CREATE INDEX IF NOT EXISTS idx_purchase_orders_tenant_id ON purchase_orders(tenant_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id ON purchase_orders(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_order_date ON purchase_orders(order_date);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders(status);

-- Enable RLS on purchase_orders
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;

-- Create purchase_order_items table if it doesn't exist
CREATE TABLE IF NOT EXISTS purchase_order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_order_id uuid NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  part_id uuid REFERENCES parts(id),
  description text NOT NULL,
  quantity integer NOT NULL CHECK(quantity > 0),
  unit_price numeric(12,2) NOT NULL CHECK(unit_price >= 0),
  line_total numeric(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
  created_at timestamptz DEFAULT now()
);

-- Create indexes for purchase_order_items
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_purchase_order_id ON purchase_order_items(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_part_id ON purchase_order_items(part_id);

-- Enable RLS on purchase_order_items
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for suppliers
CREATE POLICY "Allow select for default tenant on suppliers"
  ON suppliers
  FOR SELECT
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Allow insert for default tenant on suppliers"
  ON suppliers
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Allow update for default tenant on suppliers"
  ON suppliers
  FOR UPDATE
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Allow delete for default tenant on suppliers"
  ON suppliers
  FOR DELETE
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

-- Create RLS policies for purchase_orders
CREATE POLICY "Allow select for default tenant on purchase_orders"
  ON purchase_orders
  FOR SELECT
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Allow insert for default tenant on purchase_orders"
  ON purchase_orders
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Allow update for default tenant on purchase_orders"
  ON purchase_orders
  FOR UPDATE
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

CREATE POLICY "Allow delete for default tenant on purchase_orders"
  ON purchase_orders
  FOR DELETE
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

-- Create RLS policies for purchase_order_items
CREATE POLICY "Allow select for default tenant on purchase_order_items"
  ON purchase_order_items
  FOR SELECT
  TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM purchase_orders po
    WHERE po.id = purchase_order_items.purchase_order_id
    AND po.tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  ));

CREATE POLICY "Allow insert for default tenant on purchase_order_items"
  ON purchase_order_items
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM purchase_orders po
    WHERE po.id = purchase_order_items.purchase_order_id
    AND po.tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  ));

CREATE POLICY "Allow update for default tenant on purchase_order_items"
  ON purchase_order_items
  FOR UPDATE
  TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM purchase_orders po
    WHERE po.id = purchase_order_items.purchase_order_id
    AND po.tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM purchase_orders po
    WHERE po.id = purchase_order_items.purchase_order_id
    AND po.tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  ));

CREATE POLICY "Allow delete for default tenant on purchase_order_items"
  ON purchase_order_items
  FOR DELETE
  TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM purchase_orders po
    WHERE po.id = purchase_order_items.purchase_order_id
    AND po.tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  ));

-- Create function to generate purchase order number
CREATE OR REPLACE FUNCTION fn_generate_purchase_order_number()
RETURNS TRIGGER AS $$
BEGIN
  -- If the order number is not provided, generate one automatically
  IF NEW.order_number IS NULL OR NEW.order_number = '' THEN
    NEW.order_number := CONCAT(
      'OC-',
      to_char(NEW.order_date, 'YYYYMMDD'),
      '-',
      UPPER(substr(md5(random()::text), 1, 6))
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for generating purchase order number
CREATE TRIGGER trg_generate_purchase_order_number
  BEFORE INSERT ON purchase_orders
  FOR EACH ROW
  EXECUTE FUNCTION fn_generate_purchase_order_number();

-- Create function to create cost entries from purchase order items
CREATE OR REPLACE FUNCTION fn_purchase_order_item_to_cost()
RETURNS TRIGGER AS $$
DECLARE
  v_po purchase_orders%ROWTYPE;
  v_supplier_name text;
BEGIN
  -- Get purchase order data
  SELECT * INTO v_po FROM purchase_orders WHERE id = NEW.purchase_order_id;
  
  -- Get supplier name
  SELECT name INTO v_supplier_name FROM suppliers WHERE id = v_po.supplier_id;
  
  -- Create cost entry
  INSERT INTO costs (
    tenant_id,
    category,
    description,
    amount,
    cost_date,
    status,
    document_ref,
    observations,
    origin,
    created_by_employee_id,
    source_reference_id,
    source_reference_type
  ) VALUES (
    v_po.tenant_id,
    'Avulsa',
    CONCAT('Compra: ', NEW.description, ' (OC ', v_po.order_number, ')'),
    NEW.line_total,
    v_po.order_date,
    'Pendente',
    v_po.order_number,
    CONCAT('Fornecedor: ', v_supplier_name, CASE WHEN v_po.notes IS NOT NULL THEN ' | Obs: ' || v_po.notes ELSE '' END),
    'Sistema',
    v_po.created_by_employee_id,
    NEW.id,
    'purchase_order_item'
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for creating cost entries
CREATE TRIGGER trg_purchase_order_item_to_cost
  AFTER INSERT ON purchase_order_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_purchase_order_item_to_cost();

-- Create function for purchase order statistics
CREATE OR REPLACE FUNCTION fn_purchase_order_statistics(p_tenant_id uuid)
RETURNS TABLE (
  total_orders bigint,
  pending_orders bigint,
  received_orders bigint,
  cancelled_orders bigint,
  total_amount numeric,
  pending_amount numeric,
  avg_order_amount numeric,
  most_ordered_part text,
  top_supplier text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::bigint as total_orders,
    COUNT(*) FILTER (WHERE po.status = 'Pending')::bigint as pending_orders,
    COUNT(*) FILTER (WHERE po.status = 'Received')::bigint as received_orders,
    COUNT(*) FILTER (WHERE po.status = 'Cancelled')::bigint as cancelled_orders,
    COALESCE(SUM(po.total_amount), 0) as total_amount,
    COALESCE(SUM(po.total_amount) FILTER (WHERE po.status = 'Pending'), 0) as pending_amount,
    COALESCE(AVG(po.total_amount), 0) as avg_order_amount,
    (
      SELECT p.name
      FROM purchase_order_items poi
      JOIN parts p ON p.id = poi.part_id
      JOIN purchase_orders po2 ON po2.id = poi.purchase_order_id
      WHERE po2.tenant_id = p_tenant_id AND p.id IS NOT NULL
      GROUP BY p.name
      ORDER BY COUNT(*) DESC
      LIMIT 1
    ) as most_ordered_part,
    (
      SELECT s.name
      FROM purchase_orders po3
      JOIN suppliers s ON s.id = po3.supplier_id
      WHERE po3.tenant_id = p_tenant_id
      GROUP BY s.name
      ORDER BY COUNT(*) DESC
      LIMIT 1
    ) as top_supplier
  FROM purchase_orders po
  WHERE po.tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql;

-- Create view for purchase orders with details
CREATE OR REPLACE VIEW vw_purchase_orders_detailed AS
SELECT 
  po.id,
  po.tenant_id,
  po.supplier_id,
  s.name as supplier_name,
  po.order_number,
  po.order_date,
  po.total_amount,
  po.status,
  po.notes,
  po.created_by_employee_id,
  e.name as created_by_name,
  e.role as created_by_role,
  po.created_at,
  po.updated_at,
  (
    SELECT COUNT(*) 
    FROM purchase_order_items poi 
    WHERE poi.purchase_order_id = po.id
  ) as item_count
FROM purchase_orders po
LEFT JOIN suppliers s ON s.id = po.supplier_id
LEFT JOIN employees e ON e.id = po.created_by_employee_id;

-- Create view for purchase order items with details
CREATE OR REPLACE VIEW vw_purchase_order_items_detailed AS
SELECT 
  poi.id,
  poi.purchase_order_id,
  po.tenant_id,
  po.order_number,
  po.supplier_id,
  s.name as supplier_name,
  poi.part_id,
  p.name as part_name,
  p.sku as part_sku,
  poi.description,
  poi.quantity,
  poi.unit_price,
  poi.line_total,
  po.status as order_status,
  po.order_date,
  poi.created_at
FROM purchase_order_items poi
JOIN purchase_orders po ON po.id = poi.purchase_order_id
LEFT JOIN suppliers s ON s.id = po.supplier_id
LEFT JOIN parts p ON p.id = poi.part_id;

-- Create trigger for updating updated_at on suppliers
CREATE TRIGGER trg_suppliers_updated_at
  BEFORE UPDATE ON suppliers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for updating updated_at on purchase_orders
CREATE TRIGGER trg_purchase_orders_updated_at
  BEFORE UPDATE ON purchase_orders
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Add purchase_order_item to source_reference_type in costs
ALTER TABLE costs DROP CONSTRAINT IF EXISTS costs_source_reference_type_check;
ALTER TABLE costs ADD CONSTRAINT costs_source_reference_type_check 
  CHECK (source_reference_type = ANY (ARRAY['inspection_item'::text, 'service_note'::text, 'manual'::text, 'system'::text, 'fine'::text, 'purchase_order_item'::text]));