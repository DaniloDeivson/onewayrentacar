-- ============================================================================
-- CORREÇÃO DA FOREIGN KEY CONSTRAINT DA TABELA FINES
-- ============================================================================
-- Esta migração corrige o problema onde driver_id em fines referencia
-- a tabela drivers ao invés de employees

-- 1. Remover a constraint problemática
ALTER TABLE fines DROP CONSTRAINT IF EXISTS fines_driver_id_fkey;

-- 2. Adicionar a constraint correta referenciando employees
ALTER TABLE fines ADD CONSTRAINT fines_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES employees(id) ON DELETE SET NULL;

-- 3. Verificar se a coluna driver_id existe e tem o tipo correto
DO $$
BEGIN
  -- Verificar se a coluna existe
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fines' AND column_name = 'driver_id'
  ) THEN
    -- Adicionar a coluna se não existir
    ALTER TABLE fines ADD COLUMN driver_id UUID;
  END IF;
  
  -- Verificar se o tipo está correto
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fines' 
    AND column_name = 'driver_id' 
    AND data_type != 'uuid'
  ) THEN
    -- Alterar o tipo se necessário
    ALTER TABLE fines ALTER COLUMN driver_id TYPE UUID USING driver_id::uuid;
  END IF;
END $$;

-- 4. Criar índice para performance
CREATE INDEX IF NOT EXISTS idx_fines_driver_id ON fines(driver_id);

-- 5. Verificar se existem dados inconsistentes e limpar
-- Remover referências a drivers que não existem em employees
DELETE FROM fines 
WHERE driver_id IS NOT NULL 
  AND driver_id NOT IN (SELECT id FROM employees);

-- 6. Log da correção
DO $$
BEGIN
  RAISE NOTICE 'Foreign key constraint fines_driver_id_fkey corrigida para referenciar employees';
  RAISE NOTICE 'Índice idx_fines_driver_id criado/verificado';
END $$; 