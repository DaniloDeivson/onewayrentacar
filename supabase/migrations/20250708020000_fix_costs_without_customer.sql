-- ============================================================================
-- CORREÇÃO DE CUSTOS SEM CLIENTE ATRIBUÍDO
-- ============================================================================
-- Esta migração identifica e corrige custos sem customer_id antes de tornar o campo obrigatório

-- ============================================================================
-- 1. ANÁLISE DOS CUSTOS SEM CLIENTE
-- ============================================================================

-- Criar tabela temporária para análise
CREATE TEMP TABLE costs_analysis AS
SELECT 
    id,
    description,
    origin,
    category,
    amount,
    cost_date,
    created_at,
    CASE 
        WHEN origin = 'Patio' THEN 'Danos de inspeção - precisa de cliente'
        WHEN origin = 'Compras' THEN 'Compra de peças - pode ser geral'
        WHEN origin = 'Manutencao' THEN 'Manutenção - precisa de cliente'
        WHEN origin = 'Usuario' THEN 'Custo manual - precisa de cliente'
        WHEN origin = 'Sistema' THEN 'Multa - precisa de cliente'
        ELSE 'Origem desconhecida'
    END as action_needed
FROM costs 
WHERE customer_id IS NULL;

-- ============================================================================
-- 2. RELATÓRIO DE CUSTOS SEM CLIENTE
-- ============================================================================

-- Mostrar quantos custos existem por origem sem cliente
DO $$
DECLARE
    v_patio_count INTEGER;
    v_compras_count INTEGER;
    v_manutencao_count INTEGER;
    v_usuario_count INTEGER;
    v_sistema_count INTEGER;
    v_total_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_patio_count FROM costs WHERE customer_id IS NULL AND origin = 'Patio';
    SELECT COUNT(*) INTO v_compras_count FROM costs WHERE customer_id IS NULL AND origin = 'Compras';
    SELECT COUNT(*) INTO v_manutencao_count FROM costs WHERE customer_id IS NULL AND origin = 'Manutencao';
    SELECT COUNT(*) INTO v_usuario_count FROM costs WHERE customer_id IS NULL AND origin = 'Usuario';
    SELECT COUNT(*) INTO v_sistema_count FROM costs WHERE customer_id IS NULL AND origin = 'Sistema';
    SELECT COUNT(*) INTO v_total_count FROM costs WHERE customer_id IS NULL;
    
    RAISE NOTICE '=== RELATÓRIO DE CUSTOS SEM CLIENTE ===';
    RAISE NOTICE 'Total de custos sem cliente: %', v_total_count;
    RAISE NOTICE 'Patio (Danos): %', v_patio_count;
    RAISE NOTICE 'Compras: %', v_compras_count;
    RAISE NOTICE 'Manutencao: %', v_manutencao_count;
    RAISE NOTICE 'Usuario: %', v_usuario_count;
    RAISE NOTICE 'Sistema (Multas): %', v_sistema_count;
    RAISE NOTICE '========================================';
END $$;

-- ============================================================================
-- 3. ESTRATÉGIA DE CORREÇÃO
-- ============================================================================

-- OPÇÃO 1: DELETAR CUSTOS DE COMPRAS (geralmente não têm cliente específico)
-- Descomente a linha abaixo se quiser remover custos de compras sem cliente
-- DELETE FROM costs WHERE customer_id IS NULL AND origin = 'Compras';

-- OPÇÃO 2: ATRIBUIR CLIENTE PADRÃO PARA CUSTOS DE MANUTENÇÃO
-- Descomente e ajuste o UUID abaixo se quiser atribuir um cliente padrão
-- UPDATE costs SET customer_id = '00000000-0000-0000-0000-000000000000' WHERE customer_id IS NULL AND origin = 'Manutencao';

-- OPÇÃO 3: ATRIBUIR CLIENTE PADRÃO PARA TODOS OS CUSTOS SEM CLIENTE
-- Descomente e ajuste o UUID abaixo se quiser atribuir um cliente padrão para todos
-- UPDATE costs SET customer_id = '00000000-0000-0000-0000-000000000000' WHERE customer_id IS NULL;

-- ============================================================================
-- 4. VERIFICAÇÃO FINAL
-- ============================================================================

-- Verificar se ainda existem custos sem cliente
DO $$
DECLARE
    v_remaining_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_remaining_count FROM costs WHERE customer_id IS NULL;
    
    IF v_remaining_count > 0 THEN
        RAISE NOTICE 'ATENÇÃO: Ainda existem % custos sem cliente!', v_remaining_count;
        RAISE NOTICE 'Execute uma das opções acima antes de tornar customer_id obrigatório.';
    ELSE
        RAISE NOTICE 'SUCESSO: Todos os custos agora têm cliente atribuído!';
        RAISE NOTICE 'Pode prosseguir para tornar customer_id obrigatório.';
    END IF;
END $$;

-- ============================================================================
-- 5. TORNAR CUSTOMER_ID OBRIGATÓRIO (APENAS SE NÃO HOUVER CUSTOS SEM CLIENTE)
-- ============================================================================

-- Descomente a linha abaixo APENAS após corrigir todos os custos sem cliente
-- ALTER TABLE costs ALTER COLUMN customer_id SET NOT NULL;

-- ============================================================================
-- 6. LIMPEZA
-- ============================================================================

DROP TABLE IF EXISTS costs_analysis; 