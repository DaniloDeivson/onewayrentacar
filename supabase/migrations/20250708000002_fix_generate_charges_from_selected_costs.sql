-- Fix the generate charges from selected costs function
-- This migration fixes the issue where 0 charges are generated

-- Drop and recreate the function with better error handling and logging
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
    v_cost_count integer := 0;
BEGIN
    -- Log the input parameters for debugging
    RAISE NOTICE 'Generating charges for tenant_id: %, cost_ids: %', p_tenant_id, p_cost_ids;
    
    -- Count how many costs we're processing
    SELECT COUNT(*) INTO v_cost_count
    FROM public.costs c
    WHERE c.id = ANY(p_cost_ids)
        AND c.tenant_id = p_tenant_id
        AND c.customer_id IS NOT NULL;
    
    RAISE NOTICE 'Found % costs to process', v_cost_count;
    
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
                WHEN c.category = 'Combustível' THEN 'Combustível'
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
        RAISE NOTICE 'Processing cost_id: %, customer_id: %, contract_id: %, amount: %', 
            v_cost_record.id, v_cost_record.customer_id, v_cost_record.contract_id, v_cost_record.amount;
        
        -- Check if charge already exists for this cost
        IF NOT EXISTS (
            SELECT 1 FROM public.customer_charges cc 
            WHERE cc.source_cost_ids && ARRAY[v_cost_record.id]
                AND cc.tenant_id = p_tenant_id
        ) THEN
            RAISE NOTICE 'Creating new charge for cost_id: %', v_cost_record.id;
            
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
                COALESCE(v_cost_record.description, 'Cobrança gerada a partir de custo'),
                v_cost_record.amount,
                'Pendente',
                v_cost_record.cost_date,
                v_cost_record.cost_date + INTERVAL '30 days',
                ARRAY[v_cost_record.id],
                'Automatic'
            );
            
            v_charges_count := v_charges_count + 1;
            v_total_amount := v_total_amount + v_cost_record.amount;
            
            RAISE NOTICE 'Charge created successfully. Total charges: %, Total amount: %', v_charges_count, v_total_amount;
        ELSE
            RAISE NOTICE 'Charge already exists for cost_id: %, skipping', v_cost_record.id;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Final result: % charges generated, total amount: %', v_charges_count, v_total_amount;
    
    RETURN QUERY SELECT v_charges_count, v_total_amount;
END;
$$ LANGUAGE plpgsql;

-- Success message
SELECT 'Generate charges from selected costs function fixed successfully!' as message; 