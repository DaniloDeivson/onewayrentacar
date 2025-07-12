-- Fix for customer charge creation function
-- This fixes the null value constraint violation for customer_id

-- Drop the existing trigger if it exists
DROP TRIGGER IF EXISTS trg_create_customer_charge_from_cost ON costs;

-- Create or replace the function with proper null handling
CREATE OR REPLACE FUNCTION fn_create_customer_charge_from_cost()
RETURNS TRIGGER AS $$
BEGIN
  -- Only create charge if the cost has customer_id defined and is of a chargeable category
  IF NEW.customer_id IS NOT NULL AND 
     NEW.category IN ('Excesso Km', 'Combustível', 'Diária Extra', 'Avaria', 'Funilaria', 'Multa') AND
     NEW.status IN ('Pendente', 'Autorizado') THEN
    
    INSERT INTO public.customer_charges (
      tenant_id,
      customer_id,
      contract_id,
      vehicle_id,
      charge_type,
      description,
      amount,
      status,
      charge_date,
      due_date,
      generated_from,
      source_cost_ids
    ) VALUES (
      NEW.tenant_id,
      NEW.customer_id,
      NEW.contract_id,
      NEW.vehicle_id,
      CASE
        WHEN NEW.category = 'Excesso Km' THEN 'Excesso KM'
        WHEN NEW.category = 'Combustível' THEN 'Combustível'
        WHEN NEW.category = 'Diária Extra' THEN 'Diária Extra'
        ELSE 'Dano'
      END,
      NEW.description,
      NEW.amount,
      'Pendente',
      NEW.cost_date,
      NEW.cost_date + INTERVAL '7 days',
      'Automatic',
      ARRAY[NEW.id]
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
CREATE TRIGGER trg_create_customer_charge_from_cost
  AFTER INSERT ON costs
  FOR EACH ROW
  EXECUTE FUNCTION fn_create_customer_charge_from_cost();

-- Success message
SELECT 'Customer charge creation function fixed successfully - null customer_id values will now be properly handled' as message; 