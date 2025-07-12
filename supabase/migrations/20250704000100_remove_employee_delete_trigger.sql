-- Migration: Remover trigger e função que impedem exclusão real de usuários na tabela employees

DROP TRIGGER IF EXISTS trg_prevent_employee_delete ON employees;
DROP FUNCTION IF EXISTS fn_handle_employee_delete; 