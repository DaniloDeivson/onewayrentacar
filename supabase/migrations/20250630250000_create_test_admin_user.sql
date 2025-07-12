-- MIGRAÇÃO: CRIAR USUÁRIO ADMIN DE TESTE
-- Data: 2025-06-30 25:00:00
-- Descrição: Criar usuário admin para testes das correções implementadas

-- Criar usuário admin de teste
DO $$
DECLARE
  v_user_id uuid;
  v_tenant_id uuid := '00000000-0000-0000-0000-000000000001';
  v_admin_permissions jsonb := '{
    "dashboard": true,
    "costs": true,
    "fleet": true,
    "contracts": true,
    "fines": true,
    "statistics": true,
    "employees": true,
    "admin": true,
    "suppliers": true,
    "purchases": true,
    "inventory": true,
    "maintenance": true,
    "inspections": true,
    "finance": true
  }';
BEGIN
  -- Verificar se usuário já existe
  SELECT id INTO v_user_id
  FROM employees
  WHERE contact_info->>'email' = 'admin@test.com';
  
  IF v_user_id IS NULL THEN
    -- Criar novo usuário admin de teste
    INSERT INTO employees (
      tenant_id,
      name,
      role,
      employee_code,
      contact_info,
      active,
      permissions,
      created_at,
      updated_at
    ) VALUES (
      v_tenant_id,
      'Admin Teste',
      'Admin',
      'TEST001',
      jsonb_build_object(
        'email', 'admin@test.com',
        'phone', '(11) 99999-0000'
      ),
      true,
      v_admin_permissions,
      now(),
      now()
    );
    
    RAISE NOTICE 'Usuário admin de teste criado: admin@test.com';
  ELSE
    -- Atualizar usuário existente
    UPDATE employees
    SET 
      role = 'Admin',
      permissions = v_admin_permissions,
      active = true,
      updated_at = now()
    WHERE id = v_user_id;
    
    RAISE NOTICE 'Usuário admin de teste atualizado: admin@test.com';
  END IF;
END $$;

-- Comentário de documentação
COMMENT ON TABLE employees IS 'Tabela de funcionários/usuários do sistema. Para login use o Supabase Auth.'; 