-- Desabilitar RLS temporariamente para configuração inicial
ALTER TABLE employees DISABLE ROW LEVEL SECURITY;

-- Criar uma função para verificar se o usuário é admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM employees
    WHERE id = auth.uid()::uuid
    AND role = 'Admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Habilitar RLS
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

-- Política para SELECT: usuários podem ver funcionários do mesmo tenant_id
CREATE POLICY "employees_select_policy" ON employees
FOR SELECT USING (
  tenant_id = (
    SELECT tenant_id FROM employees 
    WHERE id = auth.uid()::uuid 
    LIMIT 1
  )
);

-- Política para INSERT: apenas admins podem criar funcionários
CREATE POLICY "employees_insert_policy" ON employees
FOR INSERT WITH CHECK (
  is_admin() AND
  tenant_id = (
    SELECT tenant_id FROM employees 
    WHERE id = auth.uid()::uuid 
    LIMIT 1
  )
);

-- Política para UPDATE: admins podem atualizar qualquer funcionário do mesmo tenant
CREATE POLICY "employees_update_admin_policy" ON employees
FOR UPDATE USING (
  is_admin() AND
  tenant_id = (
    SELECT tenant_id FROM employees 
    WHERE id = auth.uid()::uuid 
    LIMIT 1
  )
);

-- Política para UPDATE: usuários podem atualizar seus próprios dados
CREATE POLICY "employees_update_self_policy" ON employees
FOR UPDATE USING (
  auth.uid()::uuid = id
);

-- Política para DELETE: apenas admins podem deletar
CREATE POLICY "employees_delete_policy" ON employees
FOR DELETE USING (
  is_admin() AND
  tenant_id = (
    SELECT tenant_id FROM employees 
    WHERE id = auth.uid()::uuid 
    LIMIT 1
  )
);

-- Função para obter o tenant_id do usuário atual
CREATE OR REPLACE FUNCTION public.get_current_tenant_id()
RETURNS uuid AS $$
BEGIN
  RETURN (
    SELECT tenant_id FROM employees 
    WHERE id = auth.uid()::uuid 
    LIMIT 1
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para garantir que novos registros usem o tenant_id correto
CREATE OR REPLACE FUNCTION public.set_tenant_id()
RETURNS trigger AS $$
DECLARE
  current_tenant_id uuid;
BEGIN
  -- Obter o tenant_id do usuário atual
  SELECT tenant_id INTO current_tenant_id
  FROM employees
  WHERE id = auth.uid()::uuid;

  -- Se o tenant_id não foi fornecido, usar o do usuário atual
  IF NEW.tenant_id IS NULL THEN
    NEW.tenant_id := current_tenant_id;
  END IF;

  -- Verificar se o tenant_id é válido para o usuário atual
  IF NEW.tenant_id != current_tenant_id THEN
    RAISE EXCEPTION 'Não é permitido criar registros em outro tenant_id';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Aplicar o trigger
CREATE TRIGGER ensure_tenant_id_employees
  BEFORE INSERT OR UPDATE ON employees
  FOR EACH ROW
  EXECUTE FUNCTION set_tenant_id();

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_employees_tenant_id ON employees(tenant_id);
CREATE INDEX IF NOT EXISTS idx_employees_role ON employees(role);
CREATE INDEX IF NOT EXISTS idx_employees_email ON employees USING gin ((contact_info->'email'));

-- Criar um usuário admin inicial se não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM employees 
    WHERE role = 'Admin' 
    AND tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  ) THEN
    INSERT INTO employees (
      id,
      name,
      role,
      contact_info,
      tenant_id,
      active
    ) VALUES (
      '00000000-0000-0000-0000-000000000002'::uuid,
      'Admin Inicial',
      'Admin',
      jsonb_build_object(
        'email', 'admin@oneway.com',
        'phone', ''
      ),
      '00000000-0000-0000-0000-000000000001'::uuid,
      true
    );
  END IF;
END;
$$;

-- Função para verificar se o usuário tem uma role específica
CREATE OR REPLACE FUNCTION public.has_role(required_role text)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM employees AS e
    WHERE e.id = auth.uid()::uuid
    AND (
      e.role = required_role 
      OR required_role = ANY(e.roles_extra)
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para verificar se o usuário pertence ao mesmo tenant
CREATE OR REPLACE FUNCTION public.same_tenant(check_tenant_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM employees AS e
    WHERE e.id = auth.uid()::uuid
    AND e.tenant_id = check_tenant_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para logging de alterações
CREATE TABLE IF NOT EXISTS audit_log (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  table_name text NOT NULL,
  record_id uuid NOT NULL,
  operation text NOT NULL,
  old_data jsonb,
  new_data jsonb,
  changed_by uuid NOT NULL,
  changed_at timestamptz DEFAULT now(),
  tenant_id uuid NOT NULL
);

-- Habilitar RLS para audit_log
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Política para audit_log
CREATE POLICY "Admins podem ver logs do seu tenant" ON audit_log
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM employees AS e
    WHERE e.id = auth.uid()::uuid
    AND e.tenant_id = audit_log.tenant_id
    AND e.role = 'Admin'
  )
);

-- Função para registrar alterações no audit_log
CREATE OR REPLACE FUNCTION public.log_changes()
RETURNS trigger AS $$
DECLARE
  current_tenant_id uuid;
BEGIN
  -- Obter o tenant_id do usuário atual
  SELECT tenant_id INTO current_tenant_id
  FROM employees
  WHERE id = auth.uid()::uuid;

  INSERT INTO audit_log (
    table_name,
    record_id,
    operation,
    old_data,
    new_data,
    changed_by,
    tenant_id
  ) VALUES (
    TG_TABLE_NAME,
    CASE
      WHEN TG_OP = 'DELETE' THEN (OLD).id
      ELSE (NEW).id
    END,
    TG_OP,
    CASE 
      WHEN TG_OP = 'UPDATE' OR TG_OP = 'DELETE' 
      THEN to_jsonb(OLD)
      ELSE NULL 
    END,
    CASE 
      WHEN TG_OP = 'INSERT' OR TG_OP = 'UPDATE' 
      THEN to_jsonb(NEW)
      ELSE NULL 
    END,
    auth.uid()::uuid,
    current_tenant_id
  );
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Aplicar trigger de auditoria na tabela employees
CREATE TRIGGER audit_employees_changes
  AFTER INSERT OR UPDATE OR DELETE ON employees
  FOR EACH ROW
  EXECUTE FUNCTION log_changes();

-- Índices para audit_log
CREATE INDEX IF NOT EXISTS idx_audit_log_tenant_id ON audit_log(tenant_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_table_name ON audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_log_record_id ON audit_log(record_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_changed_at ON audit_log(changed_at);

-- Comentários para documentação das funções
COMMENT ON FUNCTION public.has_role IS 'Verifica se o usuário atual tem uma determinada role';
COMMENT ON FUNCTION public.same_tenant IS 'Verifica se o usuário atual pertence ao mesmo tenant_id';
COMMENT ON FUNCTION public.get_current_tenant_id IS 'Retorna o tenant_id do usuário atual';
COMMENT ON FUNCTION public.set_tenant_id IS 'Garante que novos registros usem o tenant_id correto';
COMMENT ON FUNCTION public.can_access_record IS 'Verifica se um registro pode ser acessado pelo usuário atual';
COMMENT ON FUNCTION public.has_permission IS 'Verifica se o usuário tem uma permissão específica';
COMMENT ON FUNCTION public.log_changes IS 'Registra alterações no audit_log'; 