-- ============================================================================
-- ATUALIZAR CONSTRAINT DE ROLES PARA INCLUIR TODOS OS ROLES VÁLIDOS
-- ============================================================================
-- Esta migração atualiza a constraint de roles para incluir todos os roles válidos
-- incluindo FineAdmin e Driver que foram adicionados posteriormente

-- Remover constraint existente
ALTER TABLE public.employees DROP CONSTRAINT IF EXISTS employees_role_check;

-- Adicionar nova constraint com todos os roles válidos
ALTER TABLE public.employees ADD CONSTRAINT employees_role_check 
CHECK (role IN ('Admin', 'Manager', 'Mechanic', 'Inspector', 'FineAdmin', 'Sales', 'User', 'Driver'));

-- Remover constraint de roles_extra que causa problemas
ALTER TABLE public.employees DROP CONSTRAINT IF EXISTS roles_extra_valid;

-- Atualizar função de validação de role
CREATE OR REPLACE FUNCTION public.validate_employee_role()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.role NOT IN ('Admin', 'Manager', 'Mechanic', 'Inspector', 'FineAdmin', 'Sales', 'User', 'Driver') THEN
    RAISE EXCEPTION 'Invalid role: %. Valid roles are: Admin, Manager, Mechanic, Inspector, FineAdmin, Sales, User, Driver', NEW.role;
  END IF;
  RETURN NEW;
END;
$$;

-- Recriar trigger se necessário
DROP TRIGGER IF EXISTS employees_role_validation ON public.employees;
CREATE TRIGGER employees_role_validation
  BEFORE INSERT OR UPDATE ON public.employees
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_employee_role(); 