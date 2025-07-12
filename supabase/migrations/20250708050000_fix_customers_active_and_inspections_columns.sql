-- ============================================================================
-- CORREÇÃO DE COLUNAS FALTANTES
-- ============================================================================
-- Esta migração adiciona colunas faltantes nas tabelas customers e inspections

-- ============================================================================
-- 1. ADICIONAR COLUNA ACTIVE NA TABELA CUSTOMERS
-- ============================================================================

-- Adicionar coluna active se não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'customers' AND column_name = 'active'
  ) THEN
    ALTER TABLE customers ADD COLUMN active BOOLEAN DEFAULT true;
    RAISE NOTICE 'Coluna active adicionada à tabela customers';
  ELSE
    RAISE NOTICE 'Coluna active já existe na tabela customers';
  END IF;
END $$;

-- Atualizar registros existentes para ter active = true
UPDATE customers SET active = true WHERE active IS NULL;

-- ============================================================================
-- 2. GARANTIR QUE TODAS AS COLUNAS NECESSÁRIAS EXISTAM NA TABELA INSPECTIONS
-- ============================================================================

-- Adicionar created_by_employee_id se não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'created_by_employee_id'
  ) THEN
    ALTER TABLE inspections ADD COLUMN created_by_employee_id UUID REFERENCES employees(id) ON DELETE SET NULL;
    RAISE NOTICE 'Coluna created_by_employee_id adicionada à tabela inspections';
  ELSE
    RAISE NOTICE 'Coluna created_by_employee_id já existe na tabela inspections';
  END IF;
END $$;

-- Adicionar created_by_name se não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'created_by_name'
  ) THEN
    ALTER TABLE inspections ADD COLUMN created_by_name TEXT;
    RAISE NOTICE 'Coluna created_by_name adicionada à tabela inspections';
  ELSE
    RAISE NOTICE 'Coluna created_by_name já existe na tabela inspections';
  END IF;
END $$;

-- Adicionar customer_id se não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'customer_id'
  ) THEN
    ALTER TABLE inspections ADD COLUMN customer_id UUID REFERENCES customers(id) ON DELETE SET NULL;
    RAISE NOTICE 'Coluna customer_id adicionada à tabela inspections';
  ELSE
    RAISE NOTICE 'Coluna customer_id já existe na tabela inspections';
  END IF;
END $$;

-- Adicionar tenant_id se não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inspections' AND column_name = 'tenant_id'
  ) THEN
    ALTER TABLE inspections ADD COLUMN tenant_id UUID DEFAULT '00000000-0000-0000-0000-000000000001'::uuid;
    RAISE NOTICE 'Coluna tenant_id adicionada à tabela inspections';
  ELSE
    RAISE NOTICE 'Coluna tenant_id já existe na tabela inspections';
  END IF;
END $$;

-- ============================================================================
-- 3. CRIAR ÍNDICES SE NÃO EXISTIREM
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_inspections_created_by_employee ON inspections(created_by_employee_id);
CREATE INDEX IF NOT EXISTS idx_inspections_customer ON inspections(customer_id);
CREATE INDEX IF NOT EXISTS idx_inspections_tenant ON inspections(tenant_id);
CREATE INDEX IF NOT EXISTS idx_customers_active ON customers(active);

-- ============================================================================
-- 4. ATUALIZAR REGISTROS EXISTENTES
-- ============================================================================

-- Atualizar registros existentes sem tenant_id
UPDATE inspections 
SET tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
WHERE tenant_id IS NULL;

-- Atualizar registros existentes sem created_by_name
UPDATE inspections 
SET created_by_name = 'Sistema'
WHERE created_by_name IS NULL OR created_by_name = '';

-- ============================================================================
-- 5. VERIFICAÇÃO FINAL
-- ============================================================================

-- Mostrar estrutura final das tabelas
DO $$
DECLARE
  v_inspections_columns INTEGER;
  v_customers_columns INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_inspections_columns
  FROM information_schema.columns
  WHERE table_name = 'inspections';
  
  SELECT COUNT(*) INTO v_customers_columns
  FROM information_schema.columns
  WHERE table_name = 'customers';
  
  RAISE NOTICE '=== ESTRUTURA FINAL ===';
  RAISE NOTICE 'Tabela inspections: % colunas', v_inspections_columns;
  RAISE NOTICE 'Tabela customers: % colunas', v_customers_columns;
  RAISE NOTICE 'Colunas principais inspections:';
  RAISE NOTICE '- created_by_employee_id: %', 
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'inspections' AND column_name = 'created_by_employee_id') 
         THEN 'EXISTE' ELSE 'NÃO EXISTE' END;
  RAISE NOTICE '- created_by_name: %', 
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'inspections' AND column_name = 'created_by_name') 
         THEN 'EXISTE' ELSE 'NÃO EXISTE' END;
  RAISE NOTICE '- customer_id: %', 
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'inspections' AND column_name = 'customer_id') 
         THEN 'EXISTE' ELSE 'NÃO EXISTE' END;
  RAISE NOTICE '- tenant_id: %', 
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'inspections' AND column_name = 'tenant_id') 
         THEN 'EXISTE' ELSE 'NÃO EXISTE' END;
  RAISE NOTICE 'Colunas principais customers:';
  RAISE NOTICE '- active: %', 
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'customers' AND column_name = 'active') 
         THEN 'EXISTE' ELSE 'NÃO EXISTE' END;
  RAISE NOTICE '========================';
END $$; 