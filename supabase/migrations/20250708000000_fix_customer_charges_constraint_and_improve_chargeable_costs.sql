-- Fix customer_charges constraint and improve chargeable costs function
-- This migration fixes the charge_type constraint violation and improves the chargeable costs display

-- 1. Fix the charge_type constraint to include 'Multa' and remove 'Combustível'
ALTER TABLE public.customer_charges 
DROP CONSTRAINT IF EXISTS customer_charges_charge_type_check;

ALTER TABLE public.customer_charges 
ADD CONSTRAINT customer_charges_charge_type_check 
CHECK (charge_type IN ('Dano', 'Excesso KM', 'Diária Extra', 'Multa'));

-- 2. Update the function to get chargeable costs with better data structure
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

-- 3. Create a function to generate charges from selected costs
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

-- 4. Success message
SELECT 'Customer charges constraint fixed and chargeable costs function improved successfully!' as message; 