-- First, update the category check constraint to include 'Compra'
ALTER TABLE costs DROP CONSTRAINT IF EXISTS costs_category_check;
ALTER TABLE costs ADD CONSTRAINT costs_category_check 
  CHECK (category = ANY (ARRAY['Multa'::text, 'Funilaria'::text, 'Seguro'::text, 'Avulsa'::text, 'Compra'::text]));

-- Then, update the origin check constraint to include 'Compras'
ALTER TABLE costs DROP CONSTRAINT IF EXISTS costs_origin_check;
ALTER TABLE costs ADD CONSTRAINT costs_origin_check 
  CHECK (origin = ANY (ARRAY['Manual'::text, 'Patio'::text, 'Manutencao'::text, 'Sistema'::text, 'Compras'::text]));

-- Update the function that creates costs from purchase order items
CREATE OR REPLACE FUNCTION fn_purchase_order_item_to_cost()
RETURNS TRIGGER AS $$
DECLARE
  v_po purchase_orders%ROWTYPE;
  v_supplier_name text;
  v_employee_name text;
BEGIN
  -- Get purchase order data
  SELECT * INTO v_po FROM purchase_orders WHERE id = NEW.purchase_order_id;
  
  -- Get supplier name
  SELECT name INTO v_supplier_name FROM suppliers WHERE id = v_po.supplier_id;
  
  -- Get employee name
  SELECT name INTO v_employee_name FROM employees WHERE id = v_po.created_by_employee_id;
  
  -- Create cost entry
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
    origin,
    created_by_employee_id,
    source_reference_id,
    source_reference_type
  ) VALUES (
    v_po.tenant_id,
    'Avulsa', -- Using 'Avulsa' which is already allowed by the constraint
    NULL, -- Vehicle ID can be null for purchase orders
    CONCAT('Compra: ', NEW.description, ' (OC ', v_po.order_number, ')'),
    NEW.line_total,
    v_po.order_date,
    'Pendente',
    v_po.order_number,
    CONCAT(
      'Pedido de compra: ', v_po.order_number, 
      ' | Fornecedor: ', v_supplier_name, 
      ' | Responsável: ', COALESCE(v_employee_name, 'Não informado'),
      CASE WHEN v_po.notes IS NOT NULL THEN ' | Obs: ' || v_po.notes ELSE '' END
    ),
    'Compras',
    v_po.created_by_employee_id,
    NEW.id,
    'purchase_order_item'
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update existing costs from purchase orders to have the correct origin
-- First, make sure the constraint is updated before changing data
UPDATE costs 
SET 
  origin = 'Sistema' -- Temporarily set to 'Sistema' which is already allowed
WHERE 
  source_reference_type = 'purchase_order_item' OR
  (origin = 'Sistema' AND document_ref LIKE 'OC-%') OR
  (description LIKE 'Compra:%');

-- Now update to 'Compras' after constraint is updated
UPDATE costs 
SET 
  origin = 'Compras'
WHERE 
  source_reference_type = 'purchase_order_item' OR
  (origin = 'Sistema' AND document_ref LIKE 'OC-%') OR
  (description LIKE 'Compra:%');