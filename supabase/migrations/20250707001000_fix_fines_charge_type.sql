-- Fix fines charge type issue - multas should be "Multa" not "Dano"

-- 1. Update the constraint to allow "Multa" as a valid charge_type
ALTER TABLE public.customer_charges 
DROP CONSTRAINT IF EXISTS customer_charges_charge_type_check;

ALTER TABLE public.customer_charges 
ADD CONSTRAINT customer_charges_charge_type_check 
CHECK (charge_type IN ('Dano', 'Excesso KM', 'Combustível', 'Diária Extra', 'Multa'));

-- 2. Update existing customer_charges that were incorrectly set as "Dano" for fines
UPDATE public.customer_charges 
SET charge_type = 'Multa'
WHERE charge_type = 'Dano' 
  AND source_cost_ids IS NOT NULL 
  AND EXISTS (
    SELECT 1 FROM public.costs 
    WHERE id = ANY(source_cost_ids) 
      AND category = 'Multa'
  );

-- 3. Update the function to correctly map "Multa" category
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
                     WHEN c.category = 'Multa' THEN 'Multa'
                     WHEN c.category = 'Excesso Km' THEN 'Excesso KM'
                     WHEN c.category = 'Combustível' THEN 'Combustível'
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

-- 4. Create a function to regenerate customer charges for fines
CREATE OR REPLACE FUNCTION public.fn_regenerate_fines_charges(
    p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid
)
RETURNS TABLE (
    updated_count integer,
    total_amount numeric
) AS $$
DECLARE
    v_updated_count integer := 0;
    v_total_amount numeric := 0;
BEGIN
    -- Delete existing charges for fines
    DELETE FROM public.customer_charges 
    WHERE tenant_id = p_tenant_id 
        AND charge_type = 'Dano'
        AND source_cost_ids IS NOT NULL 
        AND EXISTS (
            SELECT 1 FROM public.costs 
            WHERE id = ANY(source_cost_ids) 
              AND category = 'Multa'
        );
    
    -- Regenerate charges for fines
    SELECT charges_generated, total_amount 
    INTO v_updated_count, v_total_amount
    FROM public.fn_generate_customer_charges(p_tenant_id);
    
    RETURN QUERY SELECT v_updated_count, v_total_amount;
END;
$$ LANGUAGE plpgsql;

-- 5. Success message
SELECT 'Fines charge type fix applied successfully!' as message; 