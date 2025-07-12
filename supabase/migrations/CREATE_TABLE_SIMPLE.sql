-- 🏗️ CRIAR TABELA DE COBRANÇAS DE CLIENTES - VERSÃO SIMPLES
-- Execute este SQL no Supabase SQL Editor

-- 1. Criar tabela customer_charges
CREATE TABLE IF NOT EXISTS public.customer_charges (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    contract_id uuid NOT NULL,
    vehicle_id uuid NOT NULL,
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

DROP TRIGGER IF EXISTS customer_charges_updated_at ON public.customer_charges;
CREATE TRIGGER customer_charges_updated_at
    BEFORE UPDATE ON public.customer_charges
    FOR EACH ROW
    EXECUTE FUNCTION public.update_customer_charges_updated_at();

-- 4. RLS (Row Level Security) - versão simplificada
ALTER TABLE public.customer_charges ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Customer charges policy" ON public.customer_charges;

-- Create a simple policy for now
CREATE POLICY "Customer charges policy" ON public.customer_charges
    FOR ALL USING (true);

-- 5. Comentário de documentação
COMMENT ON TABLE public.customer_charges IS 'Tabela de cobranças de clientes geradas automaticamente baseada nos custos dos contratos';

-- 6. Verificar se a tabela foi criada
SELECT 
    'Tabela customer_charges criada com sucesso!' as status,
    count(*) as total_columns
FROM information_schema.columns 
WHERE table_name = 'customer_charges' AND table_schema = 'public';

-- 7. Inserir dados de teste para verificar funcionamento
INSERT INTO public.customer_charges (
    tenant_id,
    customer_id,
    contract_id,
    vehicle_id,
    charge_type,
    description,
    amount,
    due_date
) VALUES (
    '00000000-0000-0000-0000-000000000001'::uuid,
    '00000000-0000-0000-0000-000000000001'::uuid,
    '00000000-0000-0000-0000-000000000001'::uuid,
    '00000000-0000-0000-0000-000000000001'::uuid,
    'Dano',
    'Teste de cobrança',
    100.00,
    CURRENT_DATE + INTERVAL '30 days'
) ON CONFLICT (id) DO NOTHING;

-- 8. Verificar se o registro foi inserido
SELECT 
    'Registro de teste inserido:' as info,
    id,
    charge_type,
    amount,
    status
FROM public.customer_charges
WHERE description = 'Teste de cobrança'
LIMIT 1; 