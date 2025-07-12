/*
  # Financial Module Functions

  1. Functions
    - `fn_financial_summary` - Returns financial summary statistics
    - `fn_mark_cost_as_paid` - Marks a cost as paid and updates related records
    - `fn_mark_salary_as_paid` - Marks a salary as paid and updates related records
    - `fn_refresh_financial_views` - Refreshes financial materialized views
*/

-- Create function to get financial summary
CREATE OR REPLACE FUNCTION fn_financial_summary(p_tenant_id uuid)
RETURNS TABLE (
  total_pending numeric,
  total_paid numeric,
  total_overdue numeric,
  overdue_count bigint,
  upcoming_payments numeric,
  upcoming_count bigint,
  salary_total numeric,
  recurring_total numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    -- Total pending amount
    COALESCE(SUM(amount) FILTER (WHERE status = 'Pendente'), 0) as total_pending,
    
    -- Total paid amount
    COALESCE(SUM(amount) FILTER (WHERE status = 'Pago'), 0) as total_paid,
    
    -- Total overdue amount
    COALESCE(SUM(amount) FILTER (WHERE status = 'Pendente' AND due_date < CURRENT_DATE), 0) as total_overdue,
    
    -- Count of overdue accounts
    COUNT(*) FILTER (WHERE status = 'Pendente' AND due_date < CURRENT_DATE) as overdue_count,
    
    -- Upcoming payments (next 7 days)
    COALESCE(SUM(amount) FILTER (
      WHERE status = 'Pendente' 
      AND due_date >= CURRENT_DATE 
      AND due_date <= CURRENT_DATE + interval '7 days'
    ), 0) as upcoming_payments,
    
    -- Count of upcoming payments
    COUNT(*) FILTER (
      WHERE status = 'Pendente' 
      AND due_date >= CURRENT_DATE 
      AND due_date <= CURRENT_DATE + interval '7 days'
    ) as upcoming_count,
    
    -- Total salary amount
    COALESCE(SUM(amount) FILTER (WHERE category = 'Salário' AND status = 'Pendente'), 0) as salary_total,
    
    -- Total recurring expenses amount
    COALESCE(SUM(amount) FILTER (
      WHERE recurring_expense_id IS NOT NULL 
      AND status = 'Pendente'
    ), 0) as recurring_total
  FROM accounts_payable
  WHERE tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to mark a cost as paid and update related records
CREATE OR REPLACE FUNCTION fn_mark_cost_as_paid(p_cost_id uuid)
RETURNS void AS $$
BEGIN
  -- Update cost status
  UPDATE costs
  SET 
    status = 'Pago',
    updated_at = now()
  WHERE id = p_cost_id;
  
  -- Update related accounts payable if exists
  UPDATE accounts_payable
  SET 
    status = 'Pago',
    updated_at = now()
  WHERE cost_id = p_cost_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to mark a salary as paid and update related records
CREATE OR REPLACE FUNCTION fn_mark_salary_as_paid(p_salary_id uuid)
RETURNS void AS $$
BEGIN
  -- Update salary status
  UPDATE salaries
  SET 
    status = 'Pago',
    updated_at = now()
  WHERE id = p_salary_id;
  
  -- Update related accounts payable if exists
  UPDATE accounts_payable
  SET 
    status = 'Pago',
    updated_at = now()
  WHERE salary_id = p_salary_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to refresh financial views
CREATE OR REPLACE FUNCTION fn_refresh_financial_views()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_accounts_payable_summary;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to refresh views when accounts payable changes
CREATE OR REPLACE FUNCTION trg_refresh_financial_views()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM fn_refresh_financial_views();
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on accounts_payable table
DROP TRIGGER IF EXISTS trg_accounts_payable_refresh_views ON accounts_payable;
CREATE TRIGGER trg_accounts_payable_refresh_views
  AFTER INSERT OR UPDATE OR DELETE ON accounts_payable
  FOR EACH STATEMENT
  EXECUTE FUNCTION trg_refresh_financial_views();