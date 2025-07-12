-- MIGRATION: Garantir que sempre salva o nome do usuário da sessão no campo created_by_name da tabela costs

-- 1. Certifique-se que a função fn_set_created_by_name existe (já criada em outra migration)
-- 2. Crie o trigger para a tabela costs

DROP TRIGGER IF EXISTS tr_set_cost_created_by ON costs;
CREATE TRIGGER tr_set_cost_created_by
  BEFORE INSERT ON costs
  FOR EACH ROW
  EXECUTE FUNCTION fn_set_created_by_name(); 