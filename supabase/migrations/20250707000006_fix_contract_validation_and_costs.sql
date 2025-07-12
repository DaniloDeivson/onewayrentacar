-- Fix contract validation and recurring costs
-- This migration adjusts the contract validation to properly handle future contracts
-- and ensures recurring costs are updated when contract recurrence is modified

-- Add missing columns to costs table
ALTER TABLE costs 
ADD COLUMN IF NOT EXISTS first_occurrence date,
ADD COLUMN IF NOT EXISTS last_occurrence date;

-- Clean up duplicate contract_id/category combinations
WITH duplicates AS (
  SELECT contract_id, category, array_agg(id ORDER BY created_at DESC) as cost_ids
  FROM costs 
  WHERE contract_id IS NOT NULL
  GROUP BY contract_id, category
  HAVING COUNT(*) > 1
)
UPDATE costs c
SET category = c.category || '_' || NOW()::text
FROM duplicates d
WHERE c.id = ANY(d.cost_ids[2:]);

-- Add unique index for contract costs
CREATE UNIQUE INDEX IF NOT EXISTS costs_contract_category_unique 
ON costs (contract_id, category) 
WHERE contract_id IS NOT NULL;

-- 1. Update contract validation function to handle future contracts properly
CREATE OR REPLACE FUNCTION fn_validate_contract_availability()
RETURNS TRIGGER AS $$
DECLARE
  v_availability RECORD;
  v_conflict_info RECORD;
  v_current_date date := CURRENT_DATE;
  v_conflict_count integer;
BEGIN
  -- Skip validation for cancelled contracts
  IF NEW.status = 'Cancelado' THEN
    RETURN NEW;
  END IF;
  
  -- For future contracts (start_date > current_date), only check other future contracts
  -- Skip validation against current contracts that will end before the new contract starts
  IF NEW.start_date > v_current_date THEN
    -- Check if there are any active contracts that overlap with the future period
    SELECT COUNT(*) INTO v_conflict_count
    FROM contracts c
    WHERE c.vehicle_id = NEW.vehicle_id
      AND c.tenant_id = NEW.tenant_id
      AND c.status = 'Ativo'
      AND c.id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
      AND (
        -- Only check contracts that overlap with our future period
        (c.start_date <= NEW.end_date AND c.end_date >= NEW.start_date)
        AND
        -- For current contracts, only consider if they extend into our period
        (c.end_date >= NEW.start_date)
      );
      
    IF v_conflict_count > 0 THEN
      RAISE EXCEPTION 'Veículo não disponível no período selecionado. Há conflitos com outros contratos.';
    END IF;
    
    RETURN NEW;
  END IF;
  
  -- For current/past contracts, use the regular availability check
  IF NOT NEW.uses_multiple_vehicles AND NEW.vehicle_id IS NOT NULL THEN
    SELECT * INTO v_availability
    FROM fn_check_vehicle_availability(
      NEW.vehicle_id, 
      NEW.start_date, 
      NEW.end_date, 
      NEW.tenant_id, 
      CASE WHEN TG_OP = 'UPDATE' THEN OLD.id ELSE NULL END
    );
    
    IF NOT v_availability.is_available THEN
      IF v_availability.conflicting_contract_id IS NOT NULL THEN
        SELECT 
          c.id,
          c.contract_number,
          cu.name as customer_name,
          c.start_date,
          c.end_date
        INTO v_conflict_info
        FROM contracts c
        JOIN customers cu ON cu.id = c.customer_id
        WHERE c.id = v_availability.conflicting_contract_id;
        
        RAISE EXCEPTION 'Veículo não disponível no período solicitado. Conflito com contrato % (% - % a %) do cliente %', 
          v_conflict_info.contract_number,
          v_conflict_info.customer_name,
          v_conflict_info.start_date,
          v_conflict_info.end_date,
          v_conflict_info.customer_name;
      ELSIF v_availability.conflicting_maintenance_id IS NOT NULL THEN
        RAISE EXCEPTION 'Veículo não disponível no período solicitado. Veículo em manutenção.';
      ELSE
        RAISE EXCEPTION 'Veículo não disponível no período solicitado. %', v_availability.conflict_reason;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Create a trigger to update recurring costs when contract recurrence is modified
CREATE OR REPLACE FUNCTION fn_update_contract_recurring_costs()
RETURNS TRIGGER AS $$
BEGIN
  -- If recurrence settings changed
  IF (OLD.is_recurring IS DISTINCT FROM NEW.is_recurring) OR 
     (OLD.recurrence_type IS DISTINCT FROM NEW.recurrence_type) OR
     (OLD.recurrence_day IS DISTINCT FROM NEW.recurrence_day) OR
     (OLD.daily_rate IS DISTINCT FROM NEW.daily_rate) THEN
    
    -- If recurrence was disabled, delete recurring costs
    IF NOT NEW.is_recurring THEN
      DELETE FROM costs 
      WHERE contract_id = NEW.id 
        AND category = 'recurring_contract'
        AND tenant_id = NEW.tenant_id;
    ELSE
      -- Update or create recurring costs
      WITH recurring_cost AS (
        SELECT 
          NEW.id as contract_id,
          NEW.tenant_id,
          NEW.customer_id,
          NEW.vehicle_id,
          NEW.daily_rate as amount,
          'recurring_contract' as category,
          NEW.recurrence_type,
          NEW.recurrence_day,
          NEW.start_date as first_occurrence,
          NEW.end_date as last_occurrence
      )
      INSERT INTO costs (
        contract_id,
        tenant_id,
        customer_id,
        vehicle_id,
        amount,
        category,
        recurrence_type,
        recurrence_day,
        first_occurrence,
        last_occurrence,
        description,
        cost_date,
        status,
        origin
      )
      SELECT 
        contract_id,
        tenant_id,
        customer_id,
        vehicle_id,
        amount,
        category,
        recurrence_type,
        recurrence_day,
        first_occurrence,
        last_occurrence,
        'Custo recorrente do contrato',
        first_occurrence,
        'Pendente',
        'Contrato'
      FROM recurring_cost
      ON CONFLICT (contract_id, category) 
      DO UPDATE SET
        amount = EXCLUDED.amount,
        recurrence_type = EXCLUDED.recurrence_type,
        recurrence_day = EXCLUDED.recurrence_day,
        first_occurrence = EXCLUDED.first_occurrence,
        last_occurrence = EXCLUDED.last_occurrence,
        updated_at = NOW();
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for recurring costs
DROP TRIGGER IF EXISTS tr_update_contract_recurring_costs ON contracts;
CREATE TRIGGER tr_update_contract_recurring_costs
  AFTER UPDATE ON contracts
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_contract_recurring_costs();

-- 3. Create a function to populate recurring costs for existing contracts
CREATE OR REPLACE FUNCTION fn_populate_existing_recurring_costs()
RETURNS void AS $$
DECLARE
  v_contract RECORD;
BEGIN
  -- Loop through all active contracts that have recurrence enabled but no recurring costs
  FOR v_contract IN 
    SELECT 
      c.id,
      c.tenant_id,
      c.customer_id,
      c.vehicle_id,
      c.daily_rate,
      c.recurrence_type,
      c.recurrence_day,
      c.start_date,
      c.end_date
    FROM contracts c
    WHERE c.status = 'Ativo'
      AND c.is_recurring = true
      AND NOT EXISTS (
        SELECT 1 FROM costs 
        WHERE contract_id = c.id 
        AND category = 'recurring_contract'
      )
  LOOP
    -- Create recurring cost for each contract
    INSERT INTO costs (
      contract_id,
      tenant_id, 
      customer_id,
      vehicle_id,
      amount,
      category,
      recurrence_type,
      recurrence_day,
      first_occurrence,
      last_occurrence,
      description,
      cost_date,
      status,
      origin
    ) VALUES (
      v_contract.id,
      v_contract.tenant_id,
      v_contract.customer_id,
      v_contract.vehicle_id,
      v_contract.daily_rate,
      'recurring_contract',
      v_contract.recurrence_type,
      v_contract.recurrence_day,
      v_contract.start_date,
      v_contract.end_date,
      'Custo recorrente do contrato',
      v_contract.start_date,
      'Pendente',
      'Contrato'
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Execute the function to populate existing recurring costs
SELECT fn_populate_existing_recurring_costs(); 