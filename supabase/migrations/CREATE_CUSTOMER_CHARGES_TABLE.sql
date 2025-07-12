-- 🏗️ CRIAR TABELA DE COBRANÇAS DE CLIENTES
-- Execute este SQL no Supabase SQL Editor

-- 1. Criar tabela customer_charges
CREATE TABLE IF NOT EXISTS public.customer_charges (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id uuid NOT NULL REFERENCES public.tenants(id),
    customer_id uuid NOT NULL REFERENCES public.customers(id),
    contract_id uuid NOT NULL REFERENCES public.contracts(id),
    vehicle_id uuid NOT NULL REFERENCES public.vehicles(id),
    charge_type text NOT NULL CHECK (charge_type IN ('Dano', 'Excesso KM', 'Combustível', 'Diária Extra')),
    description text,
    amount numeric(10,2) NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'Pendente' CHECK (status IN ('Pendente', 'Pago', 'Autorizado', 'Contestado')),
    charge_date date DEFAULT CURRENT_DATE,
    due_date date NOT NULL,
    source_cost_ids uuid[], -- Array de IDs dos custos que geraram esta cobrança
    generated_from text DEFAULT 'Manual' CHECK (generated_from IN ('Manual', 'Automatic')),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- 2. Criar índices para performance
CREATE INDEX IF NOT EXISTS idx_customer_charges_tenant_id ON public.customer_charges(tenant_id);
CREATE INDEX IF NOT EXISTS idx_customer_charges_customer_id ON public.customer_charges(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_charges_contract_id ON public.customer_charges(contract_id);
CREATE INDEX IF NOT EXISTS idx_customer_charges_status ON public.customer_charges(status);
CREATE INDEX IF NOT EXISTS idx_customer_charges_charge_type ON public.customer_charges(charge_type);

-- 3. Trigger para updated_at
CREATE OR REPLACE FUNCTION public.update_customer_charges_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER customer_charges_updated_at
    BEFORE UPDATE ON public.customer_charges
    FOR EACH ROW
    EXECUTE FUNCTION public.update_customer_charges_updated_at();

-- 4. RLS (Row Level Security)
ALTER TABLE public.customer_charges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customer charges are viewable by same tenant" ON public.customer_charges
    FOR SELECT USING (tenant_id = auth.jwt() ->> 'tenant_id'::text);

CREATE POLICY "Customer charges are insertable by same tenant" ON public.customer_charges
    FOR INSERT WITH CHECK (tenant_id = auth.jwt() ->> 'tenant_id'::text);

CREATE POLICY "Customer charges are updatable by same tenant" ON public.customer_charges
    FOR UPDATE USING (tenant_id = auth.jwt() ->> 'tenant_id'::text);

-- 5. Função para gerar cobranças automaticamente baseada nos custos
CREATE OR REPLACE FUNCTION public.fn_generate_customer_charges(
    p_tenant_id uuid DEFAULT NULL,
    p_contract_id uuid DEFAULT NULL
)
RETURNS TABLE (
    charges_generated integer,
    total_amount numeric
) AS $$
DECLARE
    v_tenant_id uuid;
    v_charges_count integer := 0;
    v_total_amount numeric := 0;
    v_charge_record record;
BEGIN
    -- Use o tenant_id fornecido ou o padrão
    v_tenant_id := COALESCE(p_tenant_id, '00000000-0000-0000-0000-000000000001'::uuid);
    
    -- Gerar cobranças baseadas nos custos agrupados por contrato
    FOR v_charge_record IN
        SELECT 
            c.contract_id,
            c.customer_id,
            c.vehicle_id,
            CASE 
                WHEN c.category = 'Avaria' THEN 'Dano'
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
        INNER JOIN public.contracts ct ON c.contract_id = ct.id
        WHERE c.tenant_id = v_tenant_id
            AND c.status IN ('Autorizado', 'Pago')
            AND c.contract_id IS NOT NULL
            AND c.customer_id IS NOT NULL
            AND c.category IN ('Avaria', 'Excesso Km', 'Combustível', 'Diária Extra')
            AND (p_contract_id IS NULL OR c.contract_id = p_contract_id)
            -- Não gerar cobrança se já existe uma para estes custos
            AND NOT EXISTS (
                SELECT 1 FROM public.customer_charges cc 
                WHERE cc.contract_id = c.contract_id 
                    AND cc.charge_type = CASE 
                        WHEN c.category = 'Avaria' THEN 'Dano'
                        WHEN c.category = 'Excesso Km' THEN 'Excesso KM'
                        WHEN c.category = 'Combustível' THEN 'Combustível'
                        WHEN c.category = 'Diária Extra' THEN 'Diária Extra'
                        ELSE 'Dano'
                    END
                    AND cc.source_cost_ids && ARRAY[c.id]
            )
        GROUP BY c.contract_id, c.customer_id, c.vehicle_id, 
                 CASE 
                     WHEN c.category = 'Avaria' THEN 'Dano'
                     WHEN c.category = 'Excesso Km' THEN 'Excesso KM'
                     WHEN c.category = 'Combustível' THEN 'Combustível'
                     WHEN c.category = 'Diária Extra' THEN 'Diária Extra'
                     ELSE 'Dano'
                 END
        HAVING SUM(c.amount) > 0
    LOOP
        -- Inserir cobrança para o grupo de custos
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
            v_tenant_id,
            v_charge_record.customer_id,
            v_charge_record.contract_id,
            v_charge_record.vehicle_id,
            v_charge_record.charge_type,
            COALESCE(v_charge_record.combined_description, 'Cobrança gerada automaticamente'),
            v_charge_record.total_amount,
            'Pendente',
            v_charge_record.latest_cost_date,
            v_charge_record.latest_cost_date + INTERVAL '30 days', -- Vencimento em 30 dias
            v_charge_record.cost_ids,
            'Automatic'
        );
        
        v_charges_count := v_charges_count + 1;
        v_total_amount := v_total_amount + v_charge_record.total_amount;
    END LOOP;
    
    RETURN QUERY SELECT v_charges_count, v_total_amount;
END;
$$ LANGUAGE plpgsql;

-- 6. Função para obter estatísticas de cobrança
CREATE OR REPLACE FUNCTION public.fn_customer_charges_statistics(
    p_tenant_id uuid DEFAULT NULL
)
RETURNS TABLE (
    total_charges integer,
    pending_charges integer,
    paid_charges integer,
    total_amount numeric,
    pending_amount numeric,
    paid_amount numeric
) AS $$
DECLARE
    v_tenant_id uuid;
BEGIN
    v_tenant_id := COALESCE(p_tenant_id, '00000000-0000-0000-0000-000000000001'::uuid);
    
    RETURN QUERY
    SELECT 
        COUNT(*)::integer as total_charges,
        COUNT(*) FILTER (WHERE status = 'Pendente')::integer as pending_charges,
        COUNT(*) FILTER (WHERE status = 'Pago')::integer as paid_charges,
        COALESCE(SUM(amount), 0) as total_amount,
        COALESCE(SUM(amount) FILTER (WHERE status = 'Pendente'), 0) as pending_amount,
        COALESCE(SUM(amount) FILTER (WHERE status = 'Pago'), 0) as paid_amount
    FROM public.customer_charges
    WHERE tenant_id = v_tenant_id;
END;
$$ LANGUAGE plpgsql;

-- 7. Comentário de documentação
COMMENT ON TABLE public.customer_charges IS 'Tabela de cobranças de clientes geradas automaticamente baseada nos custos dos contratos';

-- 8. Gerar cobranças iniciais (opcional - descomente se quiser gerar automaticamente)
/*
SELECT * FROM public.fn_generate_customer_charges('00000000-0000-0000-0000-000000000001'::uuid);
*/

-- 9. Verificar se a tabela foi criada
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'customer_charges' AND table_schema = 'public'
ORDER BY ordinal_position; 