-- 🔧 MIGRAÇÃO CORRIGIDA - SISTEMA DE COBRANÇAS
-- Execute este SQL no Supabase SQL Editor

-- 1. Criar tabela customer_charges (seguro para executar múltiplas vezes)
CREATE TABLE IF NOT EXISTS public.customer_charges (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
    customer_id uuid NOT NULL,
    contract_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
    charge_type text NOT NULL CHECK (charge_type IN ('Dano', 'Excesso KM', 'Combustível', 'Diária Extra')),
    description text,
    amount numeric(10,2) NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'Pendente' CHECK (status IN ('Pendente', 'Pago', 'Autorizado', 'Contestado')),
    charge_date date DEFAULT CURRENT_DATE,
    due_date date NOT NULL,
    source_cost_ids uuid[],
    generated_from text DEFAULT 'Manual' CHECK (generated_from IN ('Manual', 'Automatic')),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- 2. Criar índices (evita erros se já existirem)
CREATE INDEX IF NOT EXISTS idx_customer_charges_tenant_id ON public.customer_charges(tenant_id);
CREATE INDEX IF NOT EXISTS idx_customer_charges_customer_id ON public.customer_charges(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_charges_contract_id ON public.customer_charges(contract_id);
CREATE INDEX IF NOT EXISTS idx_customer_charges_status ON public.customer_charges(status);
CREATE INDEX IF NOT EXISTS idx_customer_charges_charge_type ON public.customer_charges(charge_type);

-- 3. Criar função para trigger (substitui se já existir)
CREATE OR REPLACE FUNCTION public.update_customer_charges_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Remover trigger existente e criar novo (evita erro de conflito)
DROP TRIGGER IF EXISTS customer_charges_updated_at ON public.customer_charges;
CREATE TRIGGER customer_charges_updated_at
    BEFORE UPDATE ON public.customer_charges
    FOR EACH ROW
    EXECUTE FUNCTION public.update_customer_charges_updated_at();

-- 5. Habilitar RLS
ALTER TABLE public.customer_charges ENABLE ROW LEVEL SECURITY;

-- 6. Remover políticas existentes e criar novas
DROP POLICY IF EXISTS "Enable read access for all users" ON public.customer_charges;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.customer_charges;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.customer_charges;

CREATE POLICY "Enable read access for all users" ON public.customer_charges
    FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users" ON public.customer_charges
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Enable update for authenticated users" ON public.customer_charges
    FOR UPDATE USING (auth.uid() IS NOT NULL);

-- 7. Função para gerar cobranças automáticas
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
            AND c.status IN ('Autorizado', 'Pago')
            AND c.category IN ('Avaria', 'Excesso Km', 'Combustível', 'Diária Extra')
            AND c.customer_id IS NOT NULL
            AND c.contract_id IS NOT NULL
            AND (p_contract_id IS NULL OR c.contract_id = p_contract_id)
        GROUP BY c.customer_id, c.contract_id, c.vehicle_id, 
                 CASE 
                     WHEN c.category = 'Avaria' THEN 'Dano'
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

-- 8. Função para estatísticas
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

-- 9. Verificações finais
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'customer_charges' 
            AND table_schema = 'public'
        ) THEN '✅ Tabela customer_charges criada com sucesso!'
        ELSE '❌ Erro: Tabela customer_charges não foi criada'
    END as status_tabela;

SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'fn_generate_customer_charges' 
            AND routine_schema = 'public'
        ) THEN '✅ Função fn_generate_customer_charges criada com sucesso!'
        ELSE '❌ Erro: Função fn_generate_customer_charges não foi criada'
    END as status_funcao;

SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.triggers 
            WHERE trigger_name = 'customer_charges_updated_at'
        ) THEN '✅ Trigger customer_charges_updated_at criado com sucesso!'
        ELSE '❌ Erro: Trigger customer_charges_updated_at não foi criado'
    END as status_trigger;

-- Mensagem final
SELECT '🎉 MIGRAÇÃO CONCLUÍDA COM SUCESSO! O sistema de cobranças está pronto para uso.' as mensagem_final; 