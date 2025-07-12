-- Fix multiple issues: customers RLS, suppliers FK, chargeable costs function, and date validation
-- This migration addresses all the reported issues

-- 1. Fix customers table RLS policies
-- Drop existing policies to recreate them properly
DROP POLICY IF EXISTS "Allow all operations for default tenant on customers" ON customers;
DROP POLICY IF EXISTS "Users can manage their tenant customers" ON customers;

-- Create proper RLS policies for customers table
CREATE POLICY "Allow all operations for default tenant on customers"
  ON customers
  FOR ALL
  TO authenticated
  USING (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid)
  WITH CHECK (tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

-- Additional policy for authenticated users to manage customers
CREATE POLICY "Users can manage their tenant customers"
  ON customers
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM employees 
      WHERE id = auth.uid() 
      AND active = true
      AND (role = 'Admin' OR role = 'Manager')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM employees 
      WHERE id = auth.uid() 
      AND active = true
      AND (role = 'Admin' OR role = 'Manager')
    )
  );

-- Ensure RLS is enabled
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- 2. Fix suppliers foreign key constraint issue
-- Add CASCADE DELETE to purchase_orders_supplier_id_fkey
ALTER TABLE purchase_orders 
DROP CONSTRAINT IF EXISTS purchase_orders_supplier_id_fkey;

ALTER TABLE purchase_orders 
ADD CONSTRAINT purchase_orders_supplier_id_fkey 
FOREIGN KEY (supplier_id) 
REFERENCES suppliers(id) 
ON DELETE CASCADE;

-- 3. Fix the chargeable costs function to return all costs
DROP FUNCTION IF EXISTS public.fn_get_chargeable_costs(uuid);

CREATE OR REPLACE FUNCTION public.fn_get_chargeable_costs(
    p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid
)
RETURNS TABLE (
    cost_id uuid,
    category text,
    description text,
    amount numeric,
    status text,
    customer_name text,
    vehicle_plate text,
    contract_id text,
    charge_type text,
    charge_date text,
    origin text,
    created_by_name text,
    vehicle_model text,
    contract_number text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id as cost_id,
        c.category::text,
        c.description::text,
        c.amount,
        c.status::text,
        COALESCE(cust.name, '')::text as customer_name,
        COALESCE(v.plate, '')::text as vehicle_plate,
        COALESCE(c.contract_id::text, '') as contract_id,
        CASE 
            WHEN c.category = 'Avaria' THEN 'Dano'
            WHEN c.category = 'Funilaria' THEN 'Dano'
            WHEN c.category = 'Multa' THEN 'Multa'
            WHEN c.category = 'Excesso Km' THEN 'Excesso KM'
            WHEN c.category = 'Diária Extra' THEN 'Diária Extra'
            ELSE 'Dano'
        END as charge_type,
        c.cost_date::text as charge_date,
        COALESCE(c.origin, 'Manual')::text as origin,
        COALESCE(c.created_by_name, 'Sistema')::text as created_by_name,
        COALESCE(v.model, '')::text as vehicle_model,
        COALESCE(ct.contract_number, '')::text as contract_number
    FROM public.costs c
    LEFT JOIN public.customers cust ON c.customer_id = cust.id
    LEFT JOIN public.vehicles v ON c.vehicle_id = v.id
    LEFT JOIN public.contracts ct ON c.contract_id = ct.id
    WHERE c.tenant_id = p_tenant_id
        AND c.status IN ('Pendente', 'Autorizado', 'Pago')
        AND c.category IN ('Avaria', 'Funilaria', 'Multa', 'Excesso Km', 'Diária Extra')
    ORDER BY c.cost_date DESC;
END;
$$ LANGUAGE plpgsql;

-- 4. Fix the generate charges from selected costs function
DROP FUNCTION IF EXISTS public.fn_generate_charges_from_selected_costs(uuid, uuid[]);

CREATE OR REPLACE FUNCTION public.fn_generate_charges_from_selected_costs(
    p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
    p_cost_ids uuid[] DEFAULT '{}'::uuid[]
)
RETURNS TABLE (
    charges_generated integer,
    total_amount numeric
) AS $$
DECLARE
    v_charges_count integer := 0;
    v_total_amount numeric := 0;
    v_cost_record record;
BEGIN
    -- Generate charges for each selected cost
    FOR v_cost_record IN
        SELECT 
            c.id,
            c.customer_id,
            c.contract_id,
            c.vehicle_id,
            CASE 
                WHEN c.category = 'Avaria' THEN 'Dano'
                WHEN c.category = 'Funilaria' THEN 'Dano'
                WHEN c.category = 'Multa' THEN 'Multa'
                WHEN c.category = 'Excesso Km' THEN 'Excesso KM'
                WHEN c.category = 'Diária Extra' THEN 'Diária Extra'
                ELSE 'Dano'
            END as charge_type,
            c.description,
            c.amount,
            c.cost_date
        FROM public.costs c
        WHERE c.id = ANY(p_cost_ids)
            AND c.tenant_id = p_tenant_id
            AND c.customer_id IS NOT NULL
    LOOP
        -- Check if charge already exists for this cost
        IF NOT EXISTS (
            SELECT 1 FROM public.customer_charges cc 
            WHERE cc.source_cost_ids && ARRAY[v_cost_record.id]
        ) THEN
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
                source_cost_ids,
                generated_from
            ) VALUES (
                p_tenant_id,
                v_cost_record.customer_id,
                v_cost_record.contract_id,
                v_cost_record.vehicle_id,
                v_cost_record.charge_type,
                v_cost_record.description,
                v_cost_record.amount,
                'Pendente',
                v_cost_record.cost_date,
                v_cost_record.cost_date + INTERVAL '30 days',
                ARRAY[v_cost_record.id],
                'Manual'
            );
            
            v_charges_count := v_charges_count + 1;
            v_total_amount := v_total_amount + v_cost_record.amount;
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT v_charges_count, v_total_amount;
END;
$$ LANGUAGE plpgsql;

-- 5. Fix the available vehicles function to handle date validation better
CREATE OR REPLACE FUNCTION public.fn_available_vehicles(
    p_start_date text,
    p_end_date text,
    p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
    p_exclude_contract_id uuid DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    plate text,
    model text,
    year integer,
    status text
) AS $$
BEGIN
    -- Validate dates
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION 'Datas de início e fim são obrigatórias';
    END IF;

    -- Check if start date is before end date
    IF p_start_date::date >= p_end_date::date THEN
        RAISE EXCEPTION 'Data de início deve ser anterior à data de fim';
    END IF;

    RETURN QUERY
    SELECT 
        v.id,
        v.plate,
        v.model,
        v.year,
        v.status
    FROM public.vehicles v
    WHERE v.tenant_id = p_tenant_id
        AND v.active = true
        AND v.status = 'Disponível'
        AND NOT EXISTS (
            SELECT 1 
            FROM public.contracts c
            WHERE c.vehicle_id = v.id
                AND c.status = 'Ativo'
                AND (
                    (c.start_date <= p_end_date::date AND c.end_date >= p_start_date::date)
                    OR (c.start_date <= p_end_date::date AND c.end_date >= p_start_date::date)
                )
                AND (p_exclude_contract_id IS NULL OR c.id != p_exclude_contract_id)
        )
        AND NOT EXISTS (
            SELECT 1 
            FROM public.contract_vehicles cv
            JOIN public.contracts c ON cv.contract_id = c.id
            WHERE cv.vehicle_id = v.id
                AND c.status = 'Ativo'
                AND (
                    (c.start_date <= p_end_date::date AND c.end_date >= p_start_date::date)
                    OR (c.start_date <= p_end_date::date AND c.end_date >= p_start_date::date)
                )
                AND (p_exclude_contract_id IS NULL OR c.id != p_exclude_contract_id)
        )
    ORDER BY v.plate;
END;
$$ LANGUAGE plpgsql;

-- 6. Success message
SELECT 'Multiple issues fixed successfully!' as message; 