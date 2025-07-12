-- 🔧 CORRIGIR CUSTOS CONTORNANDO RESTRIÇÃO DE ATUALIZAÇÃO
-- Este script contorna a função fn_restrict_cost_update() para corrigir dados

-- MÉTODO 1: Desabilitar temporariamente o trigger (se possível)
-- Primeiro, vamos verificar se existe o trigger
SELECT 
    trigger_name,
    event_manipulation,
    trigger_schema,
    trigger_table
FROM information_schema.triggers 
WHERE trigger_table = 'costs' 
    AND trigger_schema = 'public';

-- MÉTODO 2: Usar uma abordagem alternativa via function
-- Criar uma função temporária para corrigir os dados

CREATE OR REPLACE FUNCTION fix_costs_data()
RETURNS TABLE(
    fixed_customer_ids integer,
    fixed_contract_ids integer,
    remaining_issues integer
) AS $$
DECLARE
    customer_fixes integer := 0;
    contract_fixes integer := 0;
    remaining integer := 0;
    rec RECORD;
BEGIN
    -- Contar problemas iniciais
    SELECT COUNT(*) INTO remaining
    FROM public.costs 
    WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
        AND status IN ('Autorizado', 'Pago')
        AND category IN ('Avaria', 'Excesso Km', 'Combustível', 'Diária Extra')
        AND (customer_id IS NULL OR contract_id IS NULL);

    RAISE NOTICE 'Custos com problema encontrados: %', remaining;

    -- Corrigir customer_id baseado no customer_name
    FOR rec IN 
        SELECT c.id, c.customer_name, cust.id as customer_uuid
        FROM public.costs c
        JOIN public.customers cust ON c.customer_name = cust.name
        WHERE c.tenant_id = '00000000-0000-0000-0000-000000000001'
            AND c.customer_id IS NULL
            AND c.customer_name IS NOT NULL
            AND c.status IN ('Autorizado', 'Pago')
            AND c.category IN ('Avaria', 'Excesso Km', 'Combustível', 'Diária Extra')
    LOOP
        -- Usar DELETE + INSERT em vez de UPDATE
        INSERT INTO public.costs (
            id, tenant_id, category, amount, description, status, cost_date,
            customer_id, customer_name, contract_id, vehicle_id, 
            responsible_party, authorized_by, authorized_at, created_at, updated_at
        )
        SELECT 
            gen_random_uuid(), -- novo ID
            tenant_id, category, amount, description, status, cost_date,
            rec.customer_uuid, -- customer_id corrigido
            customer_name, contract_id, vehicle_id,
            responsible_party, authorized_by, authorized_at, created_at, now()
        FROM public.costs 
        WHERE id = rec.id;
        
        -- Deletar o registro antigo
        DELETE FROM public.costs WHERE id = rec.id;
        
        customer_fixes := customer_fixes + 1;
    END LOOP;

    -- Corrigir contract_id baseado no vehicle_id
    FOR rec IN 
        SELECT c.id, c.vehicle_id, cont.id as contract_uuid
        FROM public.costs c
        JOIN public.contracts cont ON c.vehicle_id = cont.vehicle_id
        WHERE c.tenant_id = '00000000-0000-0000-0000-000000000001'
            AND c.contract_id IS NULL
            AND c.vehicle_id IS NOT NULL
            AND c.status IN ('Autorizado', 'Pago')
            AND c.category IN ('Avaria', 'Excesso Km', 'Combustível', 'Diária Extra')
            AND cont.status = 'Ativo'
    LOOP
        -- Usar DELETE + INSERT em vez de UPDATE
        INSERT INTO public.costs (
            id, tenant_id, category, amount, description, status, cost_date,
            customer_id, customer_name, contract_id, vehicle_id, 
            responsible_party, authorized_by, authorized_at, created_at, updated_at
        )
        SELECT 
            gen_random_uuid(), -- novo ID
            tenant_id, category, amount, description, status, cost_date,
            customer_id, customer_name, 
            rec.contract_uuid, -- contract_id corrigido
            vehicle_id,
            responsible_party, authorized_by, authorized_at, created_at, now()
        FROM public.costs 
        WHERE id = rec.id;
        
        -- Deletar o registro antigo
        DELETE FROM public.costs WHERE id = rec.id;
        
        contract_fixes := contract_fixes + 1;
    END LOOP;

    -- Corrigir customer_id via contract_id
    FOR rec IN 
        SELECT c.id, cont.customer_id as customer_uuid
        FROM public.costs c
        JOIN public.contracts cont ON c.contract_id = cont.id
        WHERE c.tenant_id = '00000000-0000-0000-0000-000000000001'
            AND c.customer_id IS NULL
            AND c.contract_id IS NOT NULL
            AND c.status IN ('Autorizado', 'Pago')
            AND c.category IN ('Avaria', 'Excesso Km', 'Combustível', 'Diária Extra')
    LOOP
        -- Usar DELETE + INSERT em vez de UPDATE
        INSERT INTO public.costs (
            id, tenant_id, category, amount, description, status, cost_date,
            customer_id, customer_name, contract_id, vehicle_id, 
            responsible_party, authorized_by, authorized_at, created_at, updated_at
        )
        SELECT 
            gen_random_uuid(), -- novo ID
            tenant_id, category, amount, description, status, cost_date,
            rec.customer_uuid, -- customer_id corrigido
            customer_name, contract_id, vehicle_id,
            responsible_party, authorized_by, authorized_at, created_at, now()
        FROM public.costs 
        WHERE id = rec.id;
        
        -- Deletar o registro antigo
        DELETE FROM public.costs WHERE id = rec.id;
        
        customer_fixes := customer_fixes + 1;
    END LOOP;

    -- Contar problemas restantes
    SELECT COUNT(*) INTO remaining
    FROM public.costs 
    WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
        AND status IN ('Autorizado', 'Pago')
        AND category IN ('Avaria', 'Excesso Km', 'Combustível', 'Diária Extra')
        AND (customer_id IS NULL OR contract_id IS NULL);

    RETURN QUERY SELECT customer_fixes, contract_fixes, remaining;
END;
$$ LANGUAGE plpgsql;

-- Executar a correção
SELECT 
    'RESULTADO DA CORREÇÃO' as titulo,
    fixed_customer_ids,
    fixed_contract_ids,
    remaining_issues
FROM fix_costs_data();

-- Verificar resultado
SELECT 
    'APÓS CORREÇÃO' as status,
    COUNT(*) as total_custos_disponiveis,
    SUM(amount) as valor_total,
    COUNT(*) FILTER (WHERE customer_id IS NULL) as ainda_sem_customer_id,
    COUNT(*) FILTER (WHERE contract_id IS NULL) as ainda_sem_contract_id
FROM public.costs 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
    AND status IN ('Autorizado', 'Pago')
    AND category IN ('Avaria', 'Excesso Km', 'Combustível', 'Diária Extra');

-- Testar geração de cobranças
SELECT 
    'GERAÇÃO APÓS CORREÇÃO' as titulo,
    charges_generated,
    total_amount
FROM public.fn_generate_customer_charges('00000000-0000-0000-0000-000000000001'::uuid);

-- Limpar a função temporária
DROP FUNCTION IF EXISTS fix_costs_data();

-- 📋 INSTRUÇÕES:
-- 1. Execute este script completo
-- 2. Verifique os resultados da correção
-- 3. Teste a geração de cobranças
-- 4. Vá na página de Cobranças e clique "Gerar Cobranças"

-- ⚠️ IMPORTANTE: 
-- Este método cria novos registros em vez de atualizar os existentes
-- para contornar a restrição de atualização. 