-- Add recurrence fields to contracts table
-- This allows contracts to be marked as recurring with automatic renewal

-- Add recurrence fields to contracts table
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT FALSE;
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS recurrence_type TEXT CHECK (recurrence_type IN ('monthly', 'weekly', 'yearly'));
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS recurrence_day INTEGER CHECK (recurrence_day >= 1 AND recurrence_day <= 31);
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS auto_renew BOOLEAN DEFAULT FALSE;
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS next_renewal_date DATE;

-- Create indexes for recurrence fields
CREATE INDEX IF NOT EXISTS idx_contracts_recurring ON contracts(is_recurring);
CREATE INDEX IF NOT EXISTS idx_contracts_next_renewal ON contracts(next_renewal_date);

-- Function to generate recurring contracts
CREATE OR REPLACE FUNCTION fn_generate_recurring_contracts()
RETURNS INTEGER AS $$
DECLARE
  recurring_contract contracts%ROWTYPE;
  generated_count INTEGER := 0;
  new_start_date DATE;
  new_end_date DATE;
BEGIN
  FOR recurring_contract IN 
    SELECT * FROM contracts 
    WHERE is_recurring = TRUE 
    AND auto_renew = TRUE
    AND next_renewal_date <= CURRENT_DATE
    AND status = 'Ativo'
  LOOP
    -- Calculate new dates based on recurrence type
    new_start_date := recurring_contract.next_renewal_date;
    
    CASE recurring_contract.recurrence_type
      WHEN 'monthly' THEN
        new_end_date := new_start_date + INTERVAL '1 month' - INTERVAL '1 day';
      WHEN 'weekly' THEN
        new_end_date := new_start_date + INTERVAL '1 week' - INTERVAL '1 day';
      WHEN 'yearly' THEN
        new_end_date := new_start_date + INTERVAL '1 year' - INTERVAL '1 day';
      ELSE
        new_end_date := new_start_date + INTERVAL '1 month' - INTERVAL '1 day';
    END CASE;
    
    -- Create new contract based on the recurring one
    INSERT INTO contracts (
      tenant_id,
      name,
      customer_id,
      vehicle_id,
      start_date,
      end_date,
      daily_rate,
      status,
      salesperson_id,
      km_limit,
      price_per_excess_km,
      price_per_liter,
      uses_multiple_vehicles,
      is_recurring,
      recurrence_type,
      recurrence_day,
      auto_renew,
      next_renewal_date,
      guest_id
    ) VALUES (
      recurring_contract.tenant_id,
      recurring_contract.name || ' (Renovação automática)',
      recurring_contract.customer_id,
      recurring_contract.vehicle_id,
      new_start_date,
      new_end_date,
      recurring_contract.daily_rate,
      'Ativo',
      recurring_contract.salesperson_id,
      recurring_contract.km_limit,
      recurring_contract.price_per_excess_km,
      recurring_contract.price_per_liter,
      recurring_contract.uses_multiple_vehicles,
      TRUE,
      recurring_contract.recurrence_type,
      recurring_contract.recurrence_day,
      TRUE,
      new_end_date + INTERVAL '1 day',
      recurring_contract.guest_id
    );
    
    -- Update next renewal date for the original contract
    UPDATE contracts 
    SET next_renewal_date = new_end_date + INTERVAL '1 day'
    WHERE id = recurring_contract.id;
    
    generated_count := generated_count + 1;
  END LOOP;
  
  RETURN generated_count;
END;
$$ LANGUAGE plpgsql;

-- Success message
SELECT 'Contract recurrence fields added successfully!' as message; 