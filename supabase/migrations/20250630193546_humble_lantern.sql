-- Update the function that creates costs from fines
CREATE OR REPLACE FUNCTION fn_fine_postprocess()
RETURNS TRIGGER AS $$
DECLARE
  v_driver_name text;
  v_vehicle_plate text;
  v_employee_name text;
  v_customer_name text;
BEGIN
  -- Get driver name if available
  SELECT name INTO v_driver_name
  FROM drivers
  WHERE id = NEW.driver_id;
  
  -- Get vehicle plate
  SELECT plate INTO v_vehicle_plate
  FROM vehicles
  WHERE id = NEW.vehicle_id;
  
  -- Get employee name
  SELECT name INTO v_employee_name
  FROM employees
  WHERE id = NEW.employee_id;
  
  -- Get customer name if not provided
  IF NEW.customer_id IS NOT NULL AND (NEW.customer_name IS NULL OR NEW.customer_name = '') THEN
    SELECT name INTO v_customer_name
    FROM customers
    WHERE id = NEW.customer_id;
  ELSE
    v_customer_name := NEW.customer_name;
  END IF;
  
  -- Create cost entry for the fine
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
    source_reference_type,
    department,
    customer_id,
    customer_name,
    contract_id
  ) VALUES (
    NEW.tenant_id,
    'Multa',
    NEW.vehicle_id,
    CONCAT('Multa ', NEW.fine_number, ' - ', NEW.infraction_type, 
           CASE WHEN v_customer_name IS NOT NULL THEN ' — Cliente: ' || v_customer_name ELSE '' END),
    NEW.amount,
    NEW.infraction_date,
    'Pendente',
    NEW.document_ref,
    CONCAT(
      'Multa registrada por: ', COALESCE(v_employee_name, 'Sistema'), 
      ' | Motorista: ', COALESCE(v_driver_name, 'Não informado'), 
      ' | Veículo: ', COALESCE(v_vehicle_plate, 'N/A'),
      ' | Vencimento: ', NEW.due_date,
      CASE WHEN NEW.observations IS NOT NULL THEN ' | Obs: ' || NEW.observations ELSE '' END
    ),
    'Sistema',
    NEW.employee_id,
    NEW.id,
    'fine',
    CASE WHEN NEW.customer_id IS NOT NULL THEN 'Cobrança' ELSE NULL END,
    NEW.customer_id,
    v_customer_name,
    NEW.contract_id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;