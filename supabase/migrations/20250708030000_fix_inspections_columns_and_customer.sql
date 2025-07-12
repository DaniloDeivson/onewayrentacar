-- ============================================================================
-- CORREÇÃO DE COLUNAS NA TABELA INSPECTIONS E ADIÇÃO DE CUSTOMER_ID
-- ============================================================================
-- Esta migração garante que todas as colunas necessárias existam e adiciona customer_id baseado no usuário logado

-- ============================================================================
-- 1. GARANTIR QUE TODAS AS COLUNAS NECESSÁRIAS EXISTAM
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
-- 2. CRIAR ÍNDICES SE NÃO EXISTIREM
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_inspections_created_by_employee ON inspections(created_by_employee_id);
CREATE INDEX IF NOT EXISTS idx_inspections_customer ON inspections(customer_id);
CREATE INDEX IF NOT EXISTS idx_inspections_tenant ON inspections(tenant_id);

-- ============================================================================
-- 3. FUNÇÃO PARA DEFINIR CUSTOMER_ID BASEADO NO USUÁRIO LOGADO
-- ============================================================================

-- Função para obter o customer_id do usuário logado
CREATE OR REPLACE FUNCTION fn_get_user_customer_id()
RETURNS UUID AS $$
DECLARE
  v_customer_id UUID;
  v_user_email TEXT;
BEGIN
  -- Obter email do usuário logado
  SELECT email INTO v_user_email
  FROM auth.users
  WHERE id = auth.uid();
  
  -- Buscar customer_id baseado no email do usuário
  SELECT id INTO v_customer_id
  FROM customers
  WHERE email = v_user_email
    AND tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
    AND active = true
  LIMIT 1;
  
  RETURN v_customer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. FUNÇÃO PARA DEFINIR AUTOMATICAMENTE OS CAMPOS DE CRIAÇÃO
-- ============================================================================

-- Função para definir automaticamente created_by_employee_id, created_by_name e customer_id
CREATE OR REPLACE FUNCTION fn_set_inspection_creation_fields()
RETURNS TRIGGER AS $$
DECLARE
  v_employee_name TEXT;
  v_user_name TEXT;
  v_customer_id UUID;
BEGIN
  -- Definir tenant_id se não estiver definido
  IF NEW.tenant_id IS NULL THEN
    NEW.tenant_id := '00000000-0000-0000-0000-000000000001'::uuid;
  END IF;
  
  -- Tentar obter o nome do funcionário do usuário logado
  SELECT name INTO v_employee_name
  FROM employees
  WHERE auth_user_id = auth.uid()
    AND tenant_id = NEW.tenant_id
    AND active = true
  LIMIT 1;
  
  -- Definir created_by_name
  IF v_employee_name IS NOT NULL AND v_employee_name != '' THEN
    v_user_name := v_employee_name;
  ELSE
    -- Tentar obter nome do usuário do auth.users
    SELECT raw_user_meta_data->>'name' INTO v_user_name
    FROM auth.users
    WHERE id = auth.uid();
    
    -- Se ainda não tiver nome, usar fallback
    IF v_user_name IS NULL OR v_user_name = '' THEN
      v_user_name := 'Usuário do Sistema';
    END IF;
  END IF;
  
  -- Definir created_by_name se não estiver definido
  IF NEW.created_by_name IS NULL OR NEW.created_by_name = 'Sistema' OR NEW.created_by_name = '' THEN
    NEW.created_by_name := v_user_name;
  END IF;
  
  -- Definir created_by_employee_id se não estiver definido
  IF NEW.created_by_employee_id IS NULL THEN
    SELECT id INTO NEW.created_by_employee_id
    FROM employees
    WHERE auth_user_id = auth.uid()
      AND tenant_id = NEW.tenant_id
      AND active = true
    LIMIT 1;
  END IF;
  
  -- Definir customer_id baseado no usuário logado se não estiver definido
  IF NEW.customer_id IS NULL THEN
    v_customer_id := fn_get_user_customer_id();
    IF v_customer_id IS NOT NULL THEN
      NEW.customer_id := v_customer_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 5. CRIAR TRIGGER PARA DEFINIR CAMPOS AUTOMATICAMENTE
-- ============================================================================

-- Remover trigger existente se houver
DROP TRIGGER IF EXISTS tr_set_inspection_creation_fields ON inspections;

-- Criar novo trigger
CREATE TRIGGER tr_set_inspection_creation_fields
  BEFORE INSERT ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_set_inspection_creation_fields();

-- ============================================================================
-- 6. ATUALIZAR REGISTROS EXISTENTES
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
-- 7. CORRIGIR VALIDAÇÃO DE QUILOMETRAGEM
-- ============================================================================

-- Atualizar a função de validação de quilometragem para ser mais flexível
CREATE OR REPLACE FUNCTION fn_validate_inspection_mileage()
RETURNS TRIGGER AS $$
DECLARE
  v_current_vehicle_mileage NUMERIC;
  v_original_inspection_mileage NUMERIC;
  v_mileage_difference NUMERIC;
  v_allowed_tolerance NUMERIC := 0.10; -- 10% de tolerância
BEGIN
  -- Se não há quilometragem na inspeção, permitir
  IF NEW.mileage IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Obter quilometragem atual do veículo
  SELECT mileage INTO v_current_vehicle_mileage
  FROM vehicles
  WHERE id = NEW.vehicle_id;
  
  -- Se não conseguiu obter a quilometragem do veículo, permitir
  IF v_current_vehicle_mileage IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Se é uma atualização, verificar a quilometragem original
  IF TG_OP = 'UPDATE' THEN
    SELECT mileage INTO v_original_inspection_mileage
    FROM inspections
    WHERE id = NEW.id;
    
    -- Se a quilometragem original é menor que a atual do veículo, permitir correção
    IF v_original_inspection_mileage < v_current_vehicle_mileage THEN
      RETURN NEW;
    END IF;
  END IF;
  
  -- Calcular diferença percentual
  v_mileage_difference := ABS(NEW.mileage - v_current_vehicle_mileage) / v_current_vehicle_mileage;
  
  -- Permitir se a diferença está dentro da tolerância (10%)
  IF v_mileage_difference <= v_allowed_tolerance THEN
    RETURN NEW;
  END IF;
  
  -- Se a nova quilometragem é significativamente menor, verificar se é uma correção válida
  IF NEW.mileage < v_current_vehicle_mileage THEN
    -- Permitir correções que não sejam muito drásticas (máximo 20% menor)
    IF v_mileage_difference <= 0.20 THEN
      RAISE NOTICE 'Correção de quilometragem permitida: % km -> % km (diferença: %%)', 
                   v_current_vehicle_mileage, NEW.mileage, ROUND(v_mileage_difference * 100, 2);
      RETURN NEW;
    ELSE
      RAISE EXCEPTION 'A quilometragem não pode ser muito menor que a quilometragem atual do veículo. Quilometragem atual: % km, Valor informado: % km. Diferença máxima permitida: 20%%', 
                      v_current_vehicle_mileage, NEW.mileage;
    END IF;
  END IF;
  
  -- Se chegou até aqui, a quilometragem é maior, então permitir
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Verificar se a função foi atualizada
DO $$
BEGIN
  RAISE NOTICE 'Função fn_validate_inspection_mileage atualizada com sucesso!';
  RAISE NOTICE 'Agora permite correções de quilometragem dentro de margem razoável (20%%)';
END $$;

-- ============================================================================
-- 8. VERIFICAÇÃO FINAL
-- ============================================================================

-- Mostrar estrutura final da tabela
DO $$
DECLARE
  v_column_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_column_count
  FROM information_schema.columns
  WHERE table_name = 'inspections';
  
  RAISE NOTICE '=== ESTRUTURA FINAL DA TABELA INSPECTIONS ===';
  RAISE NOTICE 'Total de colunas: %', v_column_count;
  RAISE NOTICE 'Colunas principais:';
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
  RAISE NOTICE '===============================================';
  RAISE NOTICE 'Validação de quilometragem atualizada para permitir correções!';
END $$; 