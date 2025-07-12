/*
  # Fine-Contract Integration and Customer Association

  1. Changes
    - Add contract_id and customer_id columns to fines table
    - Add customer_name column to fines table
    - Update fn_fine_postprocess to include contract and customer information
    - Update vw_fines_detailed view to include contract and customer information

  2. Security
    - Maintain existing RLS policies
    - No changes to access control
*/

-- Add new columns to fines table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'fines' AND column_name = 'contract_id'
  ) THEN
    ALTER TABLE fines ADD COLUMN contract_id UUID REFERENCES contracts(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'fines' AND column_name = 'customer_id'
  ) THEN
    ALTER TABLE fines ADD COLUMN customer_id UUID REFERENCES customers(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'fines' AND column_name = 'customer_name'
  ) THEN
    ALTER TABLE fines ADD COLUMN customer_name TEXT;
  END IF;
END $$;

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_fines_contract_id ON fines(contract_id);
CREATE INDEX IF NOT EXISTS idx_fines_customer_id ON fines(customer_id);

-- Update the function that creates costs from fines with better error handling
CREATE OR REPLACE FUNCTION fn_fine_postprocess()
RETURNS TRIGGER AS $$
DECLARE
  v_driver_name text;
  v_vehicle_plate text;
  v_employee_name text;
  v_customer_name text;
BEGIN
  -- Get driver name if available (check drivers table first, then employees)
  IF NEW.driver_id IS NOT NULL THEN
    SELECT name INTO v_driver_name
    FROM drivers
    WHERE id = NEW.driver_id;
    
    -- If not found in drivers, try employees table
    IF v_driver_name IS NULL THEN
      SELECT name INTO v_driver_name
      FROM employees
      WHERE id = NEW.driver_id;
    END IF;
  END IF;
  
  -- Get vehicle plate
  SELECT plate INTO v_vehicle_plate
  FROM vehicles
  WHERE id = NEW.vehicle_id;
  
  -- Get employee name
  IF NEW.employee_id IS NOT NULL THEN
    SELECT name INTO v_employee_name
    FROM employees
    WHERE id = NEW.employee_id;
  END IF;
  
  -- Get customer name if not provided
  IF NEW.customer_id IS NOT NULL AND (NEW.customer_name IS NULL OR NEW.customer_name = '') THEN
    SELECT name INTO v_customer_name
    FROM customers
    WHERE id = NEW.customer_id;
  ELSE
    v_customer_name := NEW.customer_name;
  END IF;
  
  -- Create cost entry for the fine with proper error handling
  BEGIN
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
      CASE WHEN NEW.customer_id IS NOT NULL THEN 'Cobrança' ELSE NULL END,
      NEW.customer_id,
      v_customer_name,
      NEW.contract_id
    );
  EXCEPTION
    WHEN OTHERS THEN
      -- Log error but don't fail the fine creation
      RAISE WARNING 'Erro ao criar custo automático para multa %: %', NEW.id, SQLERRM;
  END;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update the view for fines detailed
DROP VIEW IF EXISTS vw_fines_detailed;
CREATE VIEW vw_fines_detailed AS
SELECT 
  f.id,
  f.tenant_id,
  f.vehicle_id,
  v.plate as vehicle_plate,
  v.model as vehicle_model,
  v.year as vehicle_year,
  f.driver_id,
  d.name as driver_name,
  d.cpf as driver_cpf,
  f.employee_id,
  e.name as created_by_name,
  e.role as created_by_role,
  f.fine_number,
  f.infraction_type,
  f.amount,
  f.infraction_date,
  f.due_date,
  f.notified,
  f.status,
  f.document_ref,
  f.observations,
  f.contract_id,
  f.customer_id,
  f.customer_name,
  c.name as customer_name_from_db,
  ct.start_date as contract_start_date,
  ct.end_date as contract_end_date,
  f.created_at,
  f.updated_at,
  -- Campos calculados
  CASE 
    WHEN f.due_date < CURRENT_DATE AND f.status = 'Pendente' THEN true
    ELSE false
  END as is_overdue,
  CURRENT_DATE - f.due_date as days_overdue
FROM fines f
LEFT JOIN vehicles v ON v.id = f.vehicle_id
LEFT JOIN drivers d ON d.id = f.driver_id
LEFT JOIN employees e ON e.id = f.employee_id
LEFT JOIN customers c ON c.id = f.customer_id
LEFT JOIN contracts ct ON ct.id = f.contract_id;

-- Function to associate fines with contracts based on date
CREATE OR REPLACE FUNCTION fn_associate_fines_with_contracts()
RETURNS integer AS $$
DECLARE
  v_fine RECORD;
  v_contract RECORD;
  v_count integer := 0;
BEGIN
  -- For each fine without a contract
  FOR v_fine IN 
    SELECT * FROM fines 
    WHERE contract_id IS NULL 
      AND customer_id IS NULL
  LOOP
    -- Find a matching contract
    SELECT c.*, cu.name as customer_name INTO v_contract
    FROM contracts c
    JOIN customers cu ON cu.id = c.customer_id
    WHERE c.vehicle_id = v_fine.vehicle_id
      AND v_fine.infraction_date BETWEEN c.start_date AND c.end_date
    LIMIT 1;
    
    -- If found, update the fine
    IF v_contract.id IS NOT NULL THEN
      UPDATE fines
      SET 
        contract_id = v_contract.id,
        customer_id = v_contract.customer_id,
        customer_name = v_contract.customer_name
      WHERE id = v_fine.id;
      
      -- Also update the corresponding cost
      UPDATE costs
      SET 
        department = 'Cobrança',
        contract_id = v_contract.id,
        customer_id = v_contract.customer_id,
        customer_name = v_contract.customer_name,
        description = CONCAT('Multa ', v_fine.fine_number, ' - ', v_fine.infraction_type, ' — Cliente: ', v_contract.customer_name)
      WHERE source_reference_id = v_fine.id
        AND source_reference_type = 'fine';
      
      v_count := v_count + 1;
    END IF;
  END LOOP;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Run the association function to update existing fines
SELECT fn_associate_fines_with_contracts();