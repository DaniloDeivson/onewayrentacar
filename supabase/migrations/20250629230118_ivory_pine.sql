/*
  # Fix recurring expenses due on the 1st of each month

  1. Changes
    - Update the fn_generate_recurring_expenses function to handle the 1st of the month correctly
    - Add a function to generate recurring expenses for the current month
    - Fix the date calculation for recurring expenses
    - Ensure all recurring expenses are properly displayed in accounts payable

  2. Security
    - No changes to RLS policies
    - Maintains data integrity with updated functions
*/

-- Update the function to generate recurring expenses
CREATE OR REPLACE FUNCTION fn_generate_recurring_expenses(
  p_tenant_id uuid, 
  p_month date
)
RETURNS integer AS $$
DECLARE
  v_expense recurring_expenses%ROWTYPE;
  v_due_date date;
  v_count integer := 0;
  v_month_start date;
  v_month_end date;
BEGIN
  -- Calculate month boundaries
  v_month_start := date_trunc('month', p_month);
  v_month_end := (date_trunc('month', p_month) + interval '1 month - 1 day')::date;
  
  -- For each active recurring expense
  FOR v_expense IN 
    SELECT * FROM recurring_expenses 
    WHERE tenant_id = p_tenant_id AND is_active = true
  LOOP
    -- Calculate due date for the month
    -- Handle case where due_day is greater than days in month
    BEGIN
      v_due_date := make_date(
        extract(year from v_month_start)::int,
        extract(month from v_month_start)::int,
        LEAST(v_expense.due_day, extract(day from v_month_end)::int)
      );
    EXCEPTION WHEN OTHERS THEN
      -- Fallback to last day of month if date is invalid
      v_due_date := v_month_end;
    END;
    
    -- Check if this expense has already been generated for this month
    IF NOT EXISTS (
      SELECT 1 FROM accounts_payable 
      WHERE recurring_expense_id = v_expense.id 
        AND date_trunc('month', due_date) = date_trunc('month', p_month)
    ) THEN
      -- Create new account payable entry
      INSERT INTO accounts_payable (
        tenant_id,
        description,
        amount,
        due_date,
        category,
        status,
        payment_method,
        recurring_expense_id,
        notes
      ) VALUES (
        p_tenant_id,
        v_expense.description,
        v_expense.amount,
        v_due_date,
        v_expense.category,
        'Pendente',
        v_expense.payment_method,
        v_expense.id,
        'Gerado automaticamente de despesa recorrente para ' || to_char(v_month_start, 'MM/YYYY')
      );
      
      -- Update last generated date
      UPDATE recurring_expenses
      SET last_generated_date = p_month
      WHERE id = v_expense.id;
      
      v_count := v_count + 1;
    END IF;
  END LOOP;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Create a function to generate recurring expenses for the current month
CREATE OR REPLACE FUNCTION fn_generate_current_month_expenses(p_tenant_id uuid)
RETURNS integer AS $$
BEGIN
  RETURN fn_generate_recurring_expenses(p_tenant_id, CURRENT_DATE);
END;
$$ LANGUAGE plpgsql;

-- Create a function to check for missing recurring expenses
CREATE OR REPLACE FUNCTION fn_check_missing_recurring_expenses(p_tenant_id uuid)
RETURNS TABLE (
  expense_id uuid,
  description text,
  amount numeric,
  due_day integer,
  category text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    re.id as expense_id,
    re.description,
    re.amount,
    re.due_day,
    re.category
  FROM recurring_expenses re
  WHERE re.tenant_id = p_tenant_id
    AND re.is_active = true
    AND NOT EXISTS (
      SELECT 1 FROM accounts_payable ap
      WHERE ap.recurring_expense_id = re.id
        AND date_trunc('month', ap.due_date) = date_trunc('month', CURRENT_DATE)
    );
END;
$$ LANGUAGE plpgsql;

-- Generate any missing recurring expenses for the current month
SELECT fn_generate_current_month_expenses('00000000-0000-0000-0000-000000000001');

-- Refresh the materialized view
REFRESH MATERIALIZED VIEW mv_accounts_payable_summary;

-- Create a trigger function to automatically generate recurring expenses for new months
CREATE OR REPLACE FUNCTION fn_auto_generate_monthly_expenses()
RETURNS TRIGGER AS $$
DECLARE
  v_current_month date;
BEGIN
  -- Get the current month
  v_current_month := date_trunc('month', CURRENT_DATE);
  
  -- Generate recurring expenses for the current month if not already generated
  PERFORM fn_generate_recurring_expenses(NEW.tenant_id, v_current_month);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to automatically generate recurring expenses when a new recurring expense is created
CREATE TRIGGER trg_auto_generate_monthly_expenses
  AFTER INSERT ON recurring_expenses
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_generate_monthly_expenses();