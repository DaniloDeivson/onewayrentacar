-- Create customer_charges table and related functions

-- 1. Create customer_charges table
CREATE TABLE IF NOT EXISTS public.customer_charges (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
    customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    contract_id uuid REFERENCES public.contracts(id) ON DELETE CASCADE,
    vehicle_id uuid REFERENCES public.vehicles(id) ON DELETE SET NULL,
    charge_type text NOT NULL CHECK (charge_type IN ('Dano', 'Excesso KM', 'Combustível', 'Diária Extra', 'Multa')),
    description text,
    amount numeric(10,2) NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'Pendente' CHECK (status IN ('Pendente', 'Pago', 'Cancelado')),
    charge_date date NOT NULL DEFAULT CURRENT_DATE,
    due_date date,
    source_cost_ids uuid[] DEFAULT '{}',
    generated_from text DEFAULT 'Manual' CHECK (generated_from IN ('Manual', 'Automatic')),
    created_at timestamp with time zone DEFAULT NOW(),
    updated_at timestamp with time zone DEFAULT NOW(),
    created_by_employee_id uuid REFERENCES public.employees(id) ON DELETE SET NULL
);

-- 2. Create indexes (only if they don't exist)
CREATE INDEX IF NOT EXISTS idx_customer_charges_tenant_id ON public.customer_charges(tenant_id);
CREATE INDEX IF NOT EXISTS idx_customer_charges_customer_id ON public.customer_charges(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_charges_contract_id ON public.customer_charges(contract_id);
CREATE INDEX IF NOT EXISTS idx_customer_charges_status ON public.customer_charges(status);
CREATE INDEX IF NOT EXISTS idx_customer_charges_charge_type ON public.customer_charges(charge_type);

-- 3. Create or replace trigger function
CREATE OR REPLACE FUNCTION public.update_customer_charges_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Drop and recreate trigger to avoid conflicts
DROP TRIGGER IF EXISTS customer_charges_updated_at ON public.customer_charges;
CREATE TRIGGER customer_charges_updated_at
    BEFORE UPDATE ON public.customer_charges
    FOR EACH ROW
    EXECUTE FUNCTION public.update_customer_charges_updated_at();

-- 5. Enable RLS (safe to run multiple times)
ALTER TABLE public.customer_charges ENABLE ROW LEVEL SECURITY;

-- 6. Drop existing policies and recreate them
DROP POLICY IF EXISTS "Enable read access for all users" ON public.customer_charges;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.customer_charges;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.customer_charges;

CREATE POLICY "Enable read access for all users" ON public.customer_charges
    FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users" ON public.customer_charges
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Enable update for authenticated users" ON public.customer_charges
    FOR UPDATE USING (auth.uid() IS NOT NULL);

-- 7. Create or replace function to generate customer charges
CREATE OR REPLACE FUNCTION public.fn_generate_customer_charges(
    p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
    p_contract_id uuid DEFAULT NULL
)
RETURNS TABLE (
    charges_generated integer,
    total_amount numeric
) AS $$
DECLARE
    v_charges_count integer := 0;
    v_total_amount numeric := 0;
    v_charge_record record;
BEGIN
    FOR v_charge_record IN
        SELECT 
            c.customer_id,
            c.contract_id,
            c.vehicle_id,
            CASE 
                WHEN c.category = 'Avaria' THEN 'Dano'
                WHEN c.category = 'Funilaria' THEN 'Dano'
                WHEN c.category = 'Multa' THEN 'Dano'
                WHEN c.category = 'Excesso Km' THEN 'Excesso KM'
                WHEN c.category = 'Combustível' THEN 'Combustível'
                WHEN c.category = 'Diária Extra' THEN 'Diária Extra'
                ELSE 'Dano'
            END as charge_type,
            SUM(c.amount) as total_amount,
            STRING_AGG(c.description, '; ') as combined_description,
            ARRAY_AGG(c.id) as cost_ids,
            MAX(c.cost_date) as latest_cost_date
        FROM public.costs c
        WHERE c.tenant_id = p_tenant_id
            AND c.status IN ('Pendente', 'Autorizado', 'Pago')
            AND c.category IN ('Avaria', 'Funilaria', 'Multa', 'Excesso Km', 'Combustível', 'Diária Extra')
            AND c.customer_id IS NOT NULL
            AND c.contract_id IS NOT NULL
            AND (p_contract_id IS NULL OR c.contract_id = p_contract_id)
        GROUP BY c.customer_id, c.contract_id, c.vehicle_id, 
                 CASE 
                     WHEN c.category = 'Avaria' THEN 'Dano'
                     WHEN c.category = 'Funilaria' THEN 'Dano'
                     WHEN c.category = 'Multa' THEN 'Dano'
                     WHEN c.category = 'Excesso Km' THEN 'Excesso KM'
                     WHEN c.category = 'Combustível' THEN 'Combustível'
                     WHEN c.category = 'Diária Extra' THEN 'Diária Extra'
                     ELSE 'Dano'
                 END
        HAVING SUM(c.amount) > 0
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM public.customer_charges cc 
            WHERE cc.contract_id = v_charge_record.contract_id 
                AND cc.charge_type = v_charge_record.charge_type
                AND cc.source_cost_ids && v_charge_record.cost_ids
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
                v_charge_record.customer_id,
                v_charge_record.contract_id,
                v_charge_record.vehicle_id,
                v_charge_record.charge_type,
                COALESCE(v_charge_record.combined_description, 'Cobrança gerada automaticamente'),
                v_charge_record.total_amount,
                'Pendente',
                v_charge_record.latest_cost_date,
                v_charge_record.latest_cost_date + INTERVAL '30 days',
                v_charge_record.cost_ids,
                'Automatic'
            );
            
            v_charges_count := v_charges_count + 1;
            v_total_amount := v_total_amount + v_charge_record.total_amount;
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT v_charges_count, v_total_amount;
END;
$$ LANGUAGE plpgsql;

-- 8. Create or replace function for statistics
CREATE OR REPLACE FUNCTION public.fn_customer_charges_statistics(
    p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid
)
RETURNS TABLE (
    total_charges integer,
    pending_charges integer,
    paid_charges integer,
    total_amount numeric,
    pending_amount numeric,
    paid_amount numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::integer as total_charges,
        COUNT(*) FILTER (WHERE status = 'Pendente')::integer as pending_charges,
        COUNT(*) FILTER (WHERE status = 'Pago')::integer as paid_charges,
        COALESCE(SUM(amount), 0) as total_amount,
        COALESCE(SUM(amount) FILTER (WHERE status = 'Pendente'), 0) as pending_amount,
        COALESCE(SUM(amount) FILTER (WHERE status = 'Pago'), 0) as paid_amount
    FROM public.customer_charges
    WHERE tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql;

-- 9. Verification queries
SELECT 'customer_charges table created successfully' as message
WHERE EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'customer_charges' 
    AND table_schema = 'public'
);

SELECT 'Functions created successfully' as message
WHERE EXISTS (
    SELECT 1 FROM information_schema.routines 
    WHERE routine_name = 'fn_generate_customer_charges' 
    AND routine_schema = 'public'
);

-- Success message
SELECT 'Migration completed successfully! The customer charges system is now ready.' as final_message; 