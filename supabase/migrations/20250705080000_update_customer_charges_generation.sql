-- Update customer charges generation function to include pending costs

-- Update the function to include pending costs and improve generation logic
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
    -- First, let's clean up any existing charges that might be duplicates
    DELETE FROM public.customer_charges 
    WHERE tenant_id = p_tenant_id 
        AND generated_from = 'Automatic'
        AND (p_contract_id IS NULL OR contract_id = p_contract_id);
    
    FOR v_charge_record IN
        SELECT 
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
            SUM(c.amount) as total_amount,
            STRING_AGG(c.description, '; ') as combined_description,
            ARRAY_AGG(c.id) as cost_ids,
            MAX(c.cost_date) as latest_cost_date
        FROM public.costs c
        WHERE c.tenant_id = p_tenant_id
            AND c.status IN ('Pendente', 'Autorizado', 'Pago')
            AND c.category IN ('Avaria', 'Funilaria', 'Multa', 'Excesso Km', 'Diária Extra')
            AND c.customer_id IS NOT NULL
            AND c.contract_id IS NOT NULL
            AND (p_contract_id IS NULL OR c.contract_id = p_contract_id)
        GROUP BY c.customer_id, c.contract_id, c.vehicle_id, 
                 CASE 
                     WHEN c.category = 'Avaria' THEN 'Dano'
                     WHEN c.category = 'Funilaria' THEN 'Dano'
                     WHEN c.category = 'Multa' THEN 'Multa'
                     WHEN c.category = 'Excesso Km' THEN 'Excesso KM'
                     WHEN c.category = 'Diária Extra' THEN 'Diária Extra'
                     ELSE 'Dano'
                 END
        HAVING SUM(c.amount) > 0
    LOOP
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
    END LOOP;
    
    RETURN QUERY SELECT v_charges_count, v_total_amount;
END;
$$ LANGUAGE plpgsql;

-- Add a function to get detailed information about costs that can be converted to charges
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
    charge_date text
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
        c.category::text as charge_type,
        c.cost_date::text as charge_date
    FROM public.costs c
    LEFT JOIN public.customers cust ON c.customer_id = cust.id
    LEFT JOIN public.vehicles v ON c.vehicle_id = v.id
    WHERE c.tenant_id = p_tenant_id
        AND c.status IN ('Pendente', 'Autorizado', 'Pago')
    ORDER BY c.cost_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Success message
SELECT 'Customer charges generation function updated successfully!' as message; 