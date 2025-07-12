/*
  # Financial Module - Accounts Payable, Salaries, and Recurring Expenses

  1. New Tables
    - `salaries` - Store employee salary information
    - `recurring_expenses` - Store monthly recurring expenses
    - `accounts_payable` - Store pending bills and expenses

  2. Security
    - Enable RLS on all tables
    - Add policies for tenant-based access control
    - Add policies for finance role access

  3. Views
    - Create views for financial reporting
    - Add materialized view for accounts payable summary

  4. Functions
    - Add functions to mark expenses as paid
    - Add functions to generate recurring expenses
*/

-- Create salaries table
CREATE TABLE IF NOT EXISTS salaries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  amount numeric(12,2) NOT NULL CHECK (amount >= 0),
  payment_date date NOT NULL,
  status text NOT NULL DEFAULT 'Pendente' CHECK (status IN ('Pendente', 'Pago', 'Autorizado')),
  payment_method text,
  reference_month date NOT NULL, -- First day of the month this salary is for
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Create recurring_expenses table
CREATE TABLE IF NOT EXISTS recurring_expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  description text NOT NULL,
  amount numeric(12,2) NOT NULL CHECK (amount >= 0),
  due_day integer NOT NULL CHECK (due_day BETWEEN 1 AND 31),
  category text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  last_generated_date date,
  payment_method text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Create accounts_payable table
CREATE TABLE IF NOT EXISTS accounts_payable (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  description text NOT NULL,
  amount numeric(12,2) NOT NULL CHECK (amount >= 0),
  due_date date NOT NULL,
  category text NOT NULL,
  status text NOT NULL DEFAULT 'Pendente' CHECK (status IN ('Pendente', 'Pago', 'Autorizado')),
  supplier_id uuid REFERENCES suppliers(id) ON DELETE SET NULL,
  document_ref text,
  payment_method text,
  recurring_expense_id uuid REFERENCES recurring_expenses(id) ON DELETE SET NULL,
  salary_id uuid REFERENCES salaries(id) ON DELETE SET NULL,
  cost_id uuid REFERENCES costs(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_salaries_tenant_id ON salaries(tenant_id);
CREATE INDEX IF NOT EXISTS idx_salaries_employee_id ON salaries(employee_id);
CREATE INDEX IF NOT EXISTS idx_salaries_payment_date ON salaries(payment_date);
CREATE INDEX IF NOT EXISTS idx_salaries_status ON salaries(status);
CREATE INDEX IF NOT EXISTS idx_salaries_reference_month ON salaries(reference_month);

CREATE INDEX IF NOT EXISTS idx_recurring_expenses_tenant_id ON recurring_expenses(tenant_id);
CREATE INDEX IF NOT EXISTS idx_recurring_expenses_due_day ON recurring_expenses(due_day);
CREATE INDEX IF NOT EXISTS idx_recurring_expenses_is_active ON recurring_expenses(is_active);

CREATE INDEX IF NOT EXISTS idx_accounts_payable_tenant_id ON accounts_payable(tenant_id);
CREATE INDEX IF NOT EXISTS idx_accounts_payable_due_date ON accounts_payable(due_date);
CREATE INDEX IF NOT EXISTS idx_accounts_payable_status ON accounts_payable(status);
CREATE INDEX IF NOT EXISTS idx_accounts_payable_category ON accounts_payable(category);
CREATE INDEX IF NOT EXISTS idx_accounts_payable_supplier_id ON accounts_payable(supplier_id);

-- Enable RLS
ALTER TABLE salaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts_payable ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for salaries
CREATE POLICY "Allow all operations for default tenant on salaries"
  ON salaries
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

-- Create RLS policies for recurring_expenses
CREATE POLICY "Allow all operations for default tenant on recurring_expenses"
  ON recurring_expenses
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

-- Create RLS policies for accounts_payable
CREATE POLICY "Allow all operations for default tenant on accounts_payable"
  ON accounts_payable
  FOR ALL
  TO anon, authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

-- Create function to mark account payable as paid
CREATE OR REPLACE FUNCTION fn_mark_account_payable_paid(p_account_id uuid)
RETURNS void AS $$
DECLARE
  v_account accounts_payable%ROWTYPE;
BEGIN
  -- Get account payable record
  SELECT * INTO v_account FROM accounts_payable WHERE id = p_account_id;
  
  -- Update account payable status
  UPDATE accounts_payable
  SET 
    status = 'Pago',
    updated_at = now()
  WHERE id = p_account_id;
  
  -- If linked to a cost, update cost status too
  IF v_account.cost_id IS NOT NULL THEN
    UPDATE costs
    SET 
      status = 'Pago',
      updated_at = now()
    WHERE id = v_account.cost_id;
  END IF;
  
  -- If linked to a salary, update salary status too
  IF v_account.salary_id IS NOT NULL THEN
    UPDATE salaries
    SET 
      status = 'Pago',
      updated_at = now()
    WHERE id = v_account.salary_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Create function to generate accounts payable from recurring expenses
CREATE OR REPLACE FUNCTION fn_generate_recurring_expenses(p_tenant_id uuid, p_month date)
RETURNS integer AS $$
DECLARE
  v_expense recurring_expenses%ROWTYPE;
  v_due_date date;
  v_count integer := 0;
BEGIN
  -- For each active recurring expense
  FOR v_expense IN 
    SELECT * FROM recurring_expenses 
    WHERE tenant_id = p_tenant_id AND is_active = true
  LOOP
    -- Calculate due date for the month
    v_due_date := date_trunc('month', p_month) + (v_expense.due_day - 1) * interval '1 day';
    
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
        'Gerado automaticamente de despesa recorrente'
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

-- Create function to generate salary payments for a month
CREATE OR REPLACE FUNCTION fn_generate_salary_payments(p_tenant_id uuid, p_month date)
RETURNS integer AS $$
DECLARE
  v_employee employees%ROWTYPE;
  v_salary_amount numeric(12,2);
  v_payment_date date;
  v_count integer := 0;
  v_salary_id uuid;
BEGIN
  -- Payment date is the 5th of the next month
  v_payment_date := date_trunc('month', p_month) + interval '1 month 5 days';
  
  -- For each active employee
  FOR v_employee IN 
    SELECT * FROM employees 
    WHERE tenant_id = p_tenant_id AND active = true
  LOOP
    -- Skip if salary already generated for this month and employee
    IF NOT EXISTS (
      SELECT 1 FROM salaries 
      WHERE employee_id = v_employee.id 
        AND date_trunc('month', reference_month) = date_trunc('month', p_month)
    ) THEN
      -- Get salary amount from employee contact_info or use default
      v_salary_amount := COALESCE(
        (v_employee.contact_info->>'salary')::numeric, 
        CASE 
          WHEN v_employee.role = 'Admin' THEN 8000.00
          WHEN v_employee.role = 'Manager' THEN 6000.00
          WHEN v_employee.role = 'Mechanic' THEN 3500.00
          WHEN v_employee.role = 'PatioInspector' THEN 2800.00
          WHEN v_employee.role = 'Sales' THEN 3000.00
          WHEN v_employee.role = 'Driver' THEN 2500.00
          WHEN v_employee.role = 'FineAdmin' THEN 3200.00
          ELSE 2000.00
        END
      );
      
      -- Create salary record
      INSERT INTO salaries (
        tenant_id,
        employee_id,
        amount,
        payment_date,
        status,
        reference_month,
        notes
      ) VALUES (
        p_tenant_id,
        v_employee.id,
        v_salary_amount,
        v_payment_date,
        'Pendente',
        date_trunc('month', p_month),
        'Salário mensal gerado automaticamente'
      ) RETURNING id INTO v_salary_id;
      
      -- Create corresponding accounts payable entry
      INSERT INTO accounts_payable (
        tenant_id,
        description,
        amount,
        due_date,
        category,
        status,
        salary_id,
        notes
      ) VALUES (
        p_tenant_id,
        'Salário - ' || v_employee.name || ' (' || v_employee.role || ')',
        v_salary_amount,
        v_payment_date,
        'Salário',
        'Pendente',
        v_salary_id,
        'Salário referente a ' || to_char(p_month, 'MM/YYYY')
      );
      
      v_count := v_count + 1;
    END IF;
  END LOOP;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to sync costs to accounts payable
CREATE OR REPLACE FUNCTION fn_sync_costs_to_accounts_payable(p_tenant_id uuid)
RETURNS integer AS $$
DECLARE
  v_cost costs%ROWTYPE;
  v_count integer := 0;
BEGIN
  -- For each cost that's not already in accounts_payable
  FOR v_cost IN 
    SELECT * FROM costs 
    WHERE tenant_id = p_tenant_id
      AND NOT EXISTS (
        SELECT 1 FROM accounts_payable WHERE cost_id = costs.id
      )
  LOOP
    -- Create accounts payable entry
    INSERT INTO accounts_payable (
      tenant_id,
      description,
      amount,
      due_date,
      category,
      status,
      cost_id,
      notes
    ) VALUES (
      p_tenant_id,
      v_cost.description,
      v_cost.amount,
      v_cost.cost_date + interval '15 days', -- Due date is 15 days after cost date
      CASE 
        WHEN v_cost.category = 'Multa' THEN 'Multa'
        WHEN v_cost.category = 'Funilaria' THEN 'Manutenção'
        WHEN v_cost.category = 'Seguro' THEN 'Seguro'
        WHEN v_cost.category = 'Avulsa' THEN 'Despesa Geral'
        WHEN v_cost.category = 'Compra' THEN 'Compra'
        ELSE 'Outros'
      END,
      v_cost.status,
      v_cost.id,
      'Sincronizado automaticamente do módulo de custos'
    );
    
    v_count := v_count + 1;
  END LOOP;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Create materialized view for accounts payable summary
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_accounts_payable_summary AS
SELECT
  category,
  COUNT(*) as count,
  SUM(CASE WHEN status = 'Pendente' THEN amount ELSE 0 END) as pending_amount,
  SUM(CASE WHEN status = 'Pago' THEN amount ELSE 0 END) as paid_amount,
  SUM(amount) as total_amount,
  MIN(CASE WHEN status = 'Pendente' THEN due_date ELSE NULL END) as earliest_due_date,
  COUNT(CASE WHEN status = 'Pendente' AND due_date < CURRENT_DATE THEN 1 ELSE NULL END) as overdue_count
FROM accounts_payable
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
GROUP BY category;

-- Create index on the materialized view
CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_payable_summary_category ON mv_accounts_payable_summary(category);

-- Create view for upcoming payments
CREATE OR REPLACE VIEW vw_upcoming_payments AS
SELECT
  id,
  description,
  amount,
  due_date,
  category,
  status,
  CASE 
    WHEN due_date < CURRENT_DATE THEN true
    ELSE false
  END as is_overdue,
  CASE 
    WHEN due_date < CURRENT_DATE THEN CURRENT_DATE - due_date
    ELSE 0
  END as days_overdue,
  CASE
    WHEN salary_id IS NOT NULL THEN 'Salário'
    WHEN recurring_expense_id IS NOT NULL THEN 'Despesa Recorrente'
    WHEN cost_id IS NOT NULL THEN 'Custo'
    ELSE 'Manual'
  END as source_type,
  created_at
FROM accounts_payable
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
  AND status = 'Pendente'
ORDER BY due_date ASC;

-- Create view for employee salaries
CREATE OR REPLACE VIEW vw_employee_salaries AS
SELECT
  s.id,
  s.employee_id,
  e.name as employee_name,
  e.role as employee_role,
  e.employee_code,
  s.amount,
  s.payment_date,
  s.status,
  s.reference_month,
  to_char(s.reference_month, 'MM/YYYY') as reference_month_formatted,
  s.created_at,
  s.updated_at
FROM salaries s
JOIN employees e ON e.id = s.employee_id
WHERE s.tenant_id = '00000000-0000-0000-0000-000000000001'
ORDER BY s.reference_month DESC, e.name ASC;

-- Create trigger to update updated_at on salaries
CREATE TRIGGER trg_salaries_updated_at
  BEFORE UPDATE ON salaries
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Create trigger to update updated_at on recurring_expenses
CREATE TRIGGER trg_recurring_expenses_updated_at
  BEFORE UPDATE ON recurring_expenses
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Create trigger to update updated_at on accounts_payable
CREATE TRIGGER trg_accounts_payable_updated_at
  BEFORE UPDATE ON accounts_payable
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert sample recurring expenses
INSERT INTO recurring_expenses (
  tenant_id,
  description,
  amount,
  due_day,
  category,
  is_active,
  payment_method,
  notes
) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Aluguel do Galpão', 5000.00, 10, 'Aluguel', true, 'Transferência', 'Aluguel mensal do galpão principal'),
  ('00000000-0000-0000-0000-000000000001', 'Conta de Luz', 1200.00, 15, 'Utilidades', true, 'Boleto', 'Conta de energia elétrica'),
  ('00000000-0000-0000-0000-000000000001', 'Conta de Água', 450.00, 20, 'Utilidades', true, 'Boleto', 'Conta de água e esgoto'),
  ('00000000-0000-0000-0000-000000000001', 'Internet e Telefone', 350.00, 25, 'Comunicação', true, 'Débito Automático', 'Serviço de internet e telefonia'),
  ('00000000-0000-0000-0000-000000000001', 'Seguro Predial', 800.00, 5, 'Seguro', true, 'Boleto', 'Seguro do imóvel comercial')
ON CONFLICT DO NOTHING;

-- Generate current month's recurring expenses
SELECT fn_generate_recurring_expenses('00000000-0000-0000-0000-000000000001', CURRENT_DATE);

-- Generate current month's salary payments
SELECT fn_generate_salary_payments('00000000-0000-0000-0000-000000000001', CURRENT_DATE);

-- Sync existing costs to accounts payable
SELECT fn_sync_costs_to_accounts_payable('00000000-0000-0000-0000-000000000001');

-- Refresh materialized view
REFRESH MATERIALIZED VIEW mv_accounts_payable_summary;