-- 🔍 VERIFICAR CUSTOS PARA COBRANÇAS (APENAS LEITURA)
-- Execute este SQL no Supabase SQL Editor - SÓ CONSULTAS, SEM ALTERAÇÕES

-- 1. Verificar se a tabela customer_charges existe
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'customer_charges' 
            AND table_schema = 'public'
        ) THEN '✅ Tabela customer_charges existe'
        ELSE '❌ Tabela customer_charges NÃO existe - execute a migração'
    END as status_tabela;

-- 2. Verificar quantas cobranças existem
SELECT 
    COUNT(*) as total_cobrancas,
    COUNT(*) FILTER (WHERE status = 'Pendente') as pendentes,
    COUNT(*) FILTER (WHERE status = 'Pago') as pagas,
    SUM(amount) as valor_total
FROM public.customer_charges
WHERE tenant_id = '00000000-0000-0000-0000-000000000001';

-- 3. Verificar se há custos que poderiam gerar cobranças
SELECT 
    'CUSTOS DISPONÍVEIS PARA COBRANÇAS' as titulo,
    COUNT(*) as total_custos,
    SUM(amount) as valor_total,
    COUNT(*) FILTER (WHERE status = 'Autorizado') as autorizados,
    COUNT(*) FILTER (WHERE status = 'Pago') as pagos
FROM public.costs 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
    AND status IN ('Autorizado', 'Pago')
    AND category IN ('Avaria', 'Excesso Km', 'Combustível', 'Diária Extra');

-- 4. Verificar custos COM todos os dados necessários
SELECT 
    'CUSTOS PRONTOS PARA COBRANÇA' as status,
    COUNT(*) as total_custos_prontos,
    SUM(amount) as valor_total_pronto
FROM public.costs 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
    AND status IN ('Autorizado', 'Pago')
    AND category IN ('Avaria', 'Excesso Km', 'Combustível', 'Diária Extra')
    AND customer_id IS NOT NULL
    AND contract_id IS NOT NULL;

-- 5. Verificar custos SEM dados obrigatórios (problema)
SELECT 
    'CUSTOS COM PROBLEMA' as problema,
    COUNT(*) as total_custos_problema,
    COUNT(*) FILTER (WHERE customer_id IS NULL) as sem_customer_id,
    COUNT(*) FILTER (WHERE contract_id IS NULL) as sem_contract_id,
    COUNT(*) FILTER (WHERE customer_id IS NULL AND contract_id IS NULL) as sem_ambos
FROM public.costs 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
    AND status IN ('Autorizado', 'Pago')
    AND category IN ('Avaria', 'Excesso Km', 'Combustível', 'Diária Extra')
    AND (customer_id IS NULL OR contract_id IS NULL);

-- 6. Listar os 10 primeiros custos com problema
SELECT 
    'DETALHES DOS CUSTOS COM PROBLEMA' as titulo,
    c.id,
    c.category,
    c.amount,
    c.description,
    c.customer_name,
    c.customer_id,
    c.contract_id,
    c.vehicle_id,
    c.status,
    c.cost_date
FROM public.costs c
WHERE c.tenant_id = '00000000-0000-0000-0000-000000000001'
    AND c.status IN ('Autorizado', 'Pago')
    AND c.category IN ('Avaria', 'Excesso Km', 'Combustível', 'Diária Extra')
    AND (c.customer_id IS NULL OR c.contract_id IS NULL)
ORDER BY c.cost_date DESC
LIMIT 10;

-- 7. Verificar se há customers disponíveis para fazer o match
SELECT 
    'CUSTOMERS DISPONÍVEIS' as info,
    COUNT(*) as total_customers
FROM public.customers 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001';

-- 8. Verificar se há contracts disponíveis para fazer o match
SELECT 
    'CONTRACTS DISPONÍVEIS' as info,
    COUNT(*) as total_contracts,
    COUNT(*) FILTER (WHERE status = 'Ativo') as contracts_ativos
FROM public.contracts 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001';

-- 9. Tentar gerar cobranças (teste)
SELECT 
    'TESTE DE GERAÇÃO DE COBRANÇAS' as titulo,
    charges_generated,
    total_amount
FROM public.fn_generate_customer_charges('00000000-0000-0000-0000-000000000001'::uuid);

-- 10. Verificar cobranças após possível geração
SELECT 
    'COBRANÇAS EXISTENTES' as titulo,
    cc.id,
    cc.charge_type,
    cc.amount,
    cc.status,
    cc.generated_from,
    cc.due_date,
    cc.created_at,
    cust.name as customer_name,
    v.plate as vehicle_plate
FROM public.customer_charges cc
LEFT JOIN public.customers cust ON cc.customer_id = cust.id
LEFT JOIN public.vehicles v ON cc.vehicle_id = v.id
WHERE cc.tenant_id = '00000000-0000-0000-0000-000000000001'
ORDER BY cc.created_at DESC
LIMIT 20;

-- 11. Estatísticas finais
SELECT 
    'ESTATÍSTICAS FINAIS' as titulo,
    public.fn_customer_charges_statistics('00000000-0000-0000-0000-000000000001'::uuid) as stats;

-- 📋 INTERPRETAÇÃO DOS RESULTADOS:
-- 
-- ✅ SE TUDO ESTIVER OK:
-- - Tabela customer_charges existe
-- - Há custos prontos para cobrança
-- - Geração retorna charges_generated > 0
-- - Cobranças aparecem na lista
-- 
-- ❌ SE HOUVER PROBLEMAS:
-- - Tabela não existe → Execute a migração
-- - Custos com problema → Execute correção manual
-- - Geração retorna 0 → Verificar se já existem cobranças
-- - Lista vazia → Verificar função de geração 