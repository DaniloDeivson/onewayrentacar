-- ============================================================================
-- ADICIONAR CLIENTE PEDRO PARDAL E CORRIGIR CUSTOS SEM CLIENTE
-- ============================================================================
-- Esta migração cria o cliente Pedro Pardal e associa todos os custos sem cliente a ele

-- ============================================================================
-- 1. CRIAR CLIENTE PEDRO PARDAL SE NÃO EXISTIR
-- ============================================================================

DO $$
DECLARE
  v_pedro_customer_id uuid;
BEGIN
  -- Verificar se o cliente Pedro Pardal já existe
  SELECT id INTO v_pedro_customer_id
  FROM customers
  WHERE email = 'pedropardal04@gmail.com'
    AND tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
    AND active = true
  LIMIT 1;
  
  -- Se não existir, criar o cliente
  IF v_pedro_customer_id IS NULL THEN
    INSERT INTO customers (
      id,
      tenant_id,
      name,
      document,
      email,
      phone,
      address,
      active,
      created_at,
      updated_at
    ) VALUES (
      gen_random_uuid(),
      '00000000-0000-0000-0000-000000000001'::uuid,
      'Pedro Pardal',
      '415.757.448-64',
      'pedropardal04@gmail.com',
      '11975333355',
      'Rua Sampaio Viana, 601\n141',
      true,
      now(),
      now()
    )
    RETURNING id INTO v_pedro_customer_id;
    
    RAISE NOTICE 'Cliente Pedro Pardal criado com ID: %', v_pedro_customer_id;
  ELSE
    RAISE NOTICE 'Cliente Pedro Pardal já existe com ID: %', v_pedro_customer_id;
  END IF;
  
  -- ============================================================================
  -- 2. ASSOCIAR TODOS OS CUSTOS SEM CLIENTE AO PEDRO PARDAL
  -- ============================================================================
  
  -- Atualizar custos que não têm customer_id mas têm customer_name
  UPDATE costs 
  SET 
    customer_id = v_pedro_customer_id,
    customer_name = 'Pedro Pardal',
    updated_at = now()
  WHERE tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
    AND customer_id IS NULL
    AND customer_name IS NOT NULL
    AND customer_name != '';
  
  -- Atualizar custos que não têm customer_id nem customer_name
  UPDATE costs 
  SET 
    customer_id = v_pedro_customer_id,
    customer_name = 'Pedro Pardal',
    updated_at = now()
  WHERE tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
    AND customer_id IS NULL
    AND (customer_name IS NULL OR customer_name = '');
  
  RAISE NOTICE 'Custos atualizados com sucesso';
  
END $$;

-- ============================================================================
-- 3. VERIFICAR RESULTADOS
-- ============================================================================

-- Contar quantos custos foram associados ao Pedro Pardal
SELECT 
  'Custos associados ao Pedro Pardal' as descricao,
  COUNT(*) as quantidade
FROM costs 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  AND customer_name = 'Pedro Pardal'

UNION ALL

-- Contar custos que ainda não têm cliente
SELECT 
  'Custos sem cliente' as descricao,
  COUNT(*) as quantidade
FROM costs 
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  AND customer_id IS NULL;

-- ============================================================================
-- 4. MENSAGEM DE SUCESSO
-- ============================================================================

SELECT 'Cliente Pedro Pardal criado e custos associados com sucesso!' as message; 