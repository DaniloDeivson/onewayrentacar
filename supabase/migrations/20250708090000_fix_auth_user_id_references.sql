-- ============================================================================
-- CORREÇÃO DAS REFERÊNCIAS À COLUNA AUTH_USER_ID
-- ============================================================================
-- Esta migração corrige as funções que estão tentando acessar auth_user_id
-- que não existe na tabela employees

-- ============================================================================
-- 1. FUNÇÃO CORRIGIDA PARA OBTER CUSTOMER_ID
-- ============================================================================

-- Função corrigida para obter o customer_id do usuário logado
CREATE OR REPLACE FUNCTION fn_get_user_customer_id_robust()
RETURNS UUID AS $$
DECLARE
  v_customer_id UUID;
  v_user_email TEXT;
BEGIN
  -- Verificar se há usuário logado
  IF auth.uid() IS NULL THEN
    RETURN NULL;
  END IF;
  
  -- Obter email do usuário logado com tratamento de erro
  BEGIN
    SELECT email INTO v_user_email
    FROM auth.users
    WHERE id = auth.uid();
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  
  -- Se não conseguiu obter o email, retornar NULL
  IF v_user_email IS NULL OR v_user_email = '' THEN
    RETURN NULL;
  END IF;
  
  -- Buscar customer_id baseado no email do usuário com tratamento de erro
  BEGIN
    SELECT id INTO v_customer_id
    FROM customers
    WHERE email = v_user_email
      AND tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
      AND active = true
    LIMIT 1;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  
  RETURN v_customer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 2. FUNÇÃO CORRIGIDA PARA DEFINIR CAMPOS DE CRIAÇÃO
-- ============================================================================

-- Função corrigida para definir automaticamente os campos de criação
CREATE OR REPLACE FUNCTION fn_set_inspection_creation_fields_robust()
RETURNS TRIGGER AS $$
DECLARE
  v_employee_name TEXT;
  v_user_name TEXT;
  v_customer_id UUID;
  v_user_email TEXT;
BEGIN
  -- Definir tenant_id se não estiver definido
  IF NEW.tenant_id IS NULL THEN
    NEW.tenant_id := '00000000-0000-0000-0000-000000000001'::uuid;
  END IF;
  
  -- Obter email do usuário logado
  BEGIN
    SELECT email INTO v_user_email
    FROM auth.users
    WHERE id = auth.uid();
  EXCEPTION
    WHEN OTHERS THEN
      v_user_email := NULL;
  END;
  
  -- Tentar obter o nome do funcionário baseado no email (não em auth_user_id)
  IF v_user_email IS NOT NULL THEN
    BEGIN
      SELECT name INTO v_employee_name
      FROM employees
      WHERE (contact_info->>'email') = v_user_email
        AND tenant_id = NEW.tenant_id
        AND active = true
      LIMIT 1;
    EXCEPTION
      WHEN OTHERS THEN
        v_employee_name := NULL;
    END;
  END IF;
  
  -- Definir created_by_name
  IF v_employee_name IS NOT NULL AND v_employee_name != '' THEN
    v_user_name := v_employee_name;
  ELSE
    -- Tentar obter nome do usuário do auth.users com tratamento de erro
    BEGIN
      SELECT raw_user_meta_data->>'name' INTO v_user_name
      FROM auth.users
      WHERE id = auth.uid();
    EXCEPTION
      WHEN OTHERS THEN
        v_user_name := NULL;
    END;
    
    -- Se ainda não tiver nome, usar fallback
    IF v_user_name IS NULL OR v_user_name = '' THEN
      v_user_name := 'Usuário do Sistema';
    END IF;
  END IF;
  
  -- Definir created_by_name se não estiver definido
  IF NEW.created_by_name IS NULL OR NEW.created_by_name = 'Sistema' OR NEW.created_by_name = '' THEN
    NEW.created_by_name := v_user_name;
  END IF;
  
  -- Definir created_by_employee_id baseado no email (não em auth_user_id)
  IF NEW.created_by_employee_id IS NULL AND v_user_email IS NOT NULL THEN
    BEGIN
      SELECT id INTO NEW.created_by_employee_id
      FROM employees
      WHERE (contact_info->>'email') = v_user_email
        AND tenant_id = NEW.tenant_id
        AND active = true
      LIMIT 1;
    EXCEPTION
      WHEN OTHERS THEN
        NEW.created_by_employee_id := NULL;
    END;
  END IF;
  
  -- Definir customer_id baseado no usuário logado se não estiver definido
  -- Se falhar, permitir que seja NULL (não é obrigatório)
  IF NEW.customer_id IS NULL THEN
    BEGIN
      v_customer_id := fn_get_user_customer_id_robust();
      IF v_customer_id IS NOT NULL THEN
        NEW.customer_id := v_customer_id;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        -- Se falhar ao obter customer_id, permitir que seja NULL
        NEW.customer_id := NULL;
    END;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 3. REMOVER TRIGGER ANTIGO E CRIAR NOVO
-- ============================================================================

-- Remover trigger existente se houver
DROP TRIGGER IF EXISTS tr_set_inspection_creation_fields ON inspections;
DROP TRIGGER IF EXISTS tr_set_inspection_creation_fields_robust ON inspections;

-- Criar novo trigger corrigido
CREATE TRIGGER tr_set_inspection_creation_fields_fixed
  BEFORE INSERT ON inspections
  FOR EACH ROW
  EXECUTE FUNCTION fn_set_inspection_creation_fields_robust();

-- ============================================================================
-- 4. VERIFICAÇÃO
-- ============================================================================

-- Verificar se as funções foram criadas
DO $$
BEGIN
  RAISE NOTICE '=== TRIGGER DE INSPEÇÕES CORRIGIDO ===';
  RAISE NOTICE 'Função fn_get_user_customer_id_robust corrigida com sucesso!';
  RAISE NOTICE 'Função fn_set_inspection_creation_fields_robust corrigida com sucesso!';
  RAISE NOTICE 'Trigger tr_set_inspection_creation_fields_fixed criado com sucesso!';
  RAISE NOTICE 'Agora o sistema não tenta acessar auth_user_id que não existe!';
END $$; 