-- Fix Fine Charges - Ensure fines are properly converted to customer charges
-- This migration fixes the issue where fines are not being converted to customer charges

-- 1. Update the fine postprocess function to ensure customer charges are created
CREATE OR REPLACE FUNCTION fn_fine_postprocess()
RETURNS TRIGGER AS $$
DECLARE
  v_driver_name text;
  v_vehicle_plate text;
  v_employee_name text;
  v_customer_id UUID;
  v_customer_name TEXT;
  v_contract_id UUID;
  v_cost_id UUID;
BEGIN
  -- Get driver name if available
  SELECT name INTO v_driver_name
  FROM employees
  WHERE id = NEW.driver_id;
  
  -- Get vehicle plate
  SELECT plate INTO v_vehicle_plate
  FROM vehicles
  WHERE id = NEW.vehicle_id;
  
  -- Get employee name
  SELECT name INTO v_employee_name
  FROM employees
  WHERE id = NEW.employee_id;
  
  -- Get customer and contract information if available
  IF NEW.customer_id IS NOT NULL THEN
    v_customer_id := NEW.customer_id;
    v_customer_name := NEW.customer_name;
    v_contract_id := NEW.contract_id;
  ELSE
    -- Try to find active contract for the vehicle
    SELECT 
      c.id,
      c.customer_id,
      cu.name
    INTO v_contract_id, v_customer_id, v_customer_name
    FROM contracts c
    JOIN customers cu ON cu.id = c.customer_id
    WHERE c.vehicle_id = NEW.vehicle_id 
      AND c.status = 'Ativo' 
      AND c.start_date <= NEW.infraction_date 
      AND c.end_date >= NEW.infraction_date
    LIMIT 1;
  END IF;
  
  -- Create cost entry for the fine
  INSERT INTO costs (
    tenant_id,
    department,
    customer_id,
    customer_name,
    contract_id,
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
    created_at,
    updated_at
  ) VALUES (
    NEW.tenant_id,
    CASE WHEN v_customer_id IS NOT NULL THEN 'Cobrança' ELSE NULL END,
    v_customer_id,
    v_customer_name,
    v_contract_id,
    'Multa',
    NEW.vehicle_id,
    CONCAT('Multa ', COALESCE(NEW.fine_number, 'SEM-NUMERO'), ' - ', NEW.infraction_type, 
           CASE WHEN v_customer_name IS NOT NULL THEN ' — Cliente: ' || v_customer_name ELSE '' END),
    NEW.amount,
    NEW.infraction_date,
    'Pendente',
    NEW.document_ref,
    CONCAT(
      'Multa registrada por: ', COALESCE(v_employee_name, 'Sistema'), 
      ' | Motorista: ', COALESCE(v_driver_name, 'Não informado'), 
      ' | Veículo: ', COALESCE(v_vehicle_plate, 'N/A'),
      ' | Vencimento: ', COALESCE(NEW.due_date::text, 'N/A'),
      CASE WHEN NEW.observations IS NOT NULL THEN ' | Obs: ' || NEW.observations ELSE '' END
    ),
    'Sistema',
    NEW.employee_id,
    NEW.id,
    'fine',
    now(),
    now()
  ) RETURNING id INTO v_cost_id;
  
  -- Update the fine with the cost_id
  UPDATE fines 
  SET cost_id = v_cost_id
  WHERE id = NEW.id;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the fine creation
    RAISE WARNING 'Erro ao criar custo automático para multa %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Add cost_id column to fines table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fines' AND column_name = 'cost_id'
  ) THEN
    ALTER TABLE fines ADD COLUMN cost_id UUID REFERENCES costs(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 3. Create a function to reprocess existing fines that didn't create costs
CREATE OR REPLACE FUNCTION fn_reprocess_missing_fine_costs()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER := 0;
  v_fine RECORD;
  v_driver_name text;
  v_vehicle_plate text;
  v_employee_name text;
  v_customer_id UUID;
  v_customer_name TEXT;
  v_contract_id UUID;
  v_cost_id UUID;
BEGIN
  -- Find fines that don't have associated costs
  FOR v_fine IN 
    SELECT f.*
    FROM fines f
    WHERE f.cost_id IS NULL
      AND f.tenant_id = '00000000-0000-0000-0000-000000000001'
  LOOP
    -- Get driver name if available
    SELECT name INTO v_driver_name
    FROM employees
    WHERE id = v_fine.driver_id;
    
    -- Get vehicle plate
    SELECT plate INTO v_vehicle_plate
    FROM vehicles
    WHERE id = v_fine.vehicle_id;
    
    -- Get employee name
    SELECT name INTO v_employee_name
    FROM employees
    WHERE id = v_fine.employee_id;
    
    -- Get customer and contract information if available
    IF v_fine.customer_id IS NOT NULL THEN
      v_customer_id := v_fine.customer_id;
      v_customer_name := v_fine.customer_name;
      v_contract_id := v_fine.contract_id;
    ELSE
      -- Try to find active contract for the vehicle
      SELECT 
        c.id,
        c.customer_id,
        cu.name
      INTO v_contract_id, v_customer_id, v_customer_name
      FROM contracts c
      JOIN customers cu ON cu.id = c.customer_id
      WHERE c.vehicle_id = v_fine.vehicle_id 
        AND c.status = 'Ativo' 
        AND c.start_date <= v_fine.infraction_date 
        AND c.end_date >= v_fine.infraction_date
      LIMIT 1;
    END IF;
    
    -- Create cost entry for the fine
    INSERT INTO costs (
      tenant_id,
      department,
      customer_id,
      customer_name,
      contract_id,
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
      created_at,
      updated_at
    ) VALUES (
      v_fine.tenant_id,
      CASE WHEN v_customer_id IS NOT NULL THEN 'Cobrança' ELSE NULL END,
      v_customer_id,
      v_customer_name,
      v_contract_id,
      'Multa',
      v_fine.vehicle_id,
      CONCAT('Multa ', COALESCE(v_fine.fine_number, 'SEM-NUMERO'), ' - ', v_fine.infraction_type, 
             CASE WHEN v_customer_name IS NOT NULL THEN ' — Cliente: ' || v_customer_name ELSE '' END),
      v_fine.amount,
      v_fine.infraction_date,
      'Pendente',
      v_fine.document_ref,
      CONCAT(
        'Multa registrada por: ', COALESCE(v_employee_name, 'Sistema'), 
        ' | Motorista: ', COALESCE(v_driver_name, 'Não informado'), 
        ' | Veículo: ', COALESCE(v_vehicle_plate, 'N/A'),
        ' | Vencimento: ', COALESCE(v_fine.due_date::text, 'N/A'),
        ' | Reprocessado',
        CASE WHEN v_fine.observations IS NOT NULL THEN ' | Obs: ' || v_fine.observations ELSE '' END
      ),
      'Sistema',
      v_fine.employee_id,
      v_fine.id,
      'fine',
      now(),
      now()
    ) RETURNING id INTO v_cost_id;
    
    -- Update the fine with the cost_id
    UPDATE fines 
    SET cost_id = v_cost_id
    WHERE id = v_fine.id;
    
    v_count := v_count + 1;
  END LOOP;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- 4. Create a function to verify fine cost creation
CREATE OR REPLACE FUNCTION fn_verify_fine_costs()
RETURNS TABLE (
  fine_id uuid,
  fine_number text,
  vehicle_plate text,
  driver_name text,
  amount numeric,
  has_cost boolean,
  cost_id uuid,
  customer_name text,
  contract_id uuid
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    f.id as fine_id,
    f.fine_number,
    v.plate as vehicle_plate,
    e.name as driver_name,
    f.amount,
    f.cost_id IS NOT NULL as has_cost,
    f.cost_id,
    c.customer_name,
    c.contract_id
  FROM fines f
  JOIN vehicles v ON v.id = f.vehicle_id
  LEFT JOIN employees e ON e.id = f.driver_id
  LEFT JOIN costs c ON c.id = f.cost_id
  WHERE f.tenant_id = '00000000-0000-0000-0000-000000000001'
  ORDER BY f.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 5. Execute the reprocessing function
SELECT 'Reprocessing missing fine costs...' as status;
SELECT fn_reprocess_missing_fine_costs() as reprocessed_fine_costs;

-- 6. Test the verification function
SELECT * FROM fn_verify_fine_costs() WHERE has_cost = false LIMIT 10; 