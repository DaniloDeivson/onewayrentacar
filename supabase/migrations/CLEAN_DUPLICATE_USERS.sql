-- Desabilitar temporariamente o trigger de audit_log
DROP TRIGGER IF EXISTS audit_employees_changes ON employees;

-- Criar tabela temporária para armazenar os IDs dos registros a serem mantidos (mais antigos)
CREATE TEMP TABLE keep_records AS
SELECT DISTINCT ON ((e.contact_info->>'email')) 
  e.id,
  e.contact_info->>'email' as email,
  e.created_at
FROM employees e
WHERE e.active = true
  AND (e.contact_info->>'status' IS NULL OR e.contact_info->>'status' NOT IN ('orphaned', 'orphaned_duplicate'))
ORDER BY (e.contact_info->>'email'), e.created_at ASC;

-- Marcar todos os outros registros como duplicados
WITH duplicates AS (
  SELECT e.id
  FROM employees e
  WHERE e.active = true
    AND e.id NOT IN (SELECT id FROM keep_records)
    AND (e.contact_info->>'email') IN (
      SELECT email FROM keep_records
    )
)
UPDATE employees
SET 
  active = false,
  contact_info = jsonb_set(
    jsonb_set(
      contact_info, 
      '{status}',
      '"orphaned_duplicate"'::jsonb
    ),
    '{updated_reason}',
    '"Registro duplicado detectado e desativado automaticamente"'::jsonb
  ),
  permissions = '{}'::jsonb,
  updated_at = NOW()
WHERE id IN (SELECT id FROM duplicates);

-- Limpar registros órfãos (sem email ou com status inválido)
UPDATE employees
SET 
  active = false,
  contact_info = jsonb_set(
    jsonb_set(
      contact_info, 
      '{status}',
      '"orphaned"'::jsonb
    ),
    '{updated_reason}',
    '"Registro inválido detectado e desativado automaticamente"'::jsonb
  ),
  permissions = '{}'::jsonb,
  updated_at = NOW()
WHERE 
  (contact_info->>'email' IS NULL OR contact_info->>'email' = '')
  OR (contact_info->>'status' = 'orphaned')
  OR id NOT IN (SELECT id FROM auth.users);

-- Remover registros completamente vazios
DELETE FROM employees
WHERE 
  contact_info = '{}'::jsonb 
  AND permissions = '{}'::jsonb
  AND roles_extra IS NULL
  AND employee_code IS NULL;

-- Recriar o trigger de audit_log com tratamento para usuário nulo
CREATE OR REPLACE FUNCTION public.log_changes()
RETURNS trigger AS $$
DECLARE
  current_tenant_id uuid;
  current_user_id uuid;
BEGIN
  -- Tentar obter o usuário atual
  current_user_id := COALESCE(auth.uid()::uuid, '00000000-0000-0000-0000-000000000000'::uuid);
  
  -- Obter o tenant_id do registro
  IF TG_OP = 'DELETE' THEN
    current_tenant_id := OLD.tenant_id;
  ELSE
    current_tenant_id := NEW.tenant_id;
  END IF;

  -- Inserir no log de auditoria
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
      WHEN TG_OP = 'DELETE' THEN OLD.id
      ELSE NEW.id
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
    current_user_id,
    current_tenant_id
  );

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recriar o trigger
CREATE TRIGGER audit_employees_changes
  AFTER INSERT OR UPDATE OR DELETE ON employees
  FOR EACH ROW
  EXECUTE FUNCTION log_changes();

-- Criar índice para melhorar performance de buscas por email
CREATE INDEX IF NOT EXISTS idx_employees_email_active ON employees ((contact_info->>'email')) WHERE active = true;

-- Estatísticas dos resultados
SELECT 
  'Registros mantidos' as tipo,
  COUNT(*) as quantidade
FROM keep_records
UNION ALL
SELECT 
  'Registros desativados' as tipo,
  COUNT(*) as quantidade
FROM employees
WHERE active = false
  AND (contact_info->>'status' IN ('orphaned', 'orphaned_duplicate'));

-- Limpar tabela temporária
DROP TABLE keep_records; 