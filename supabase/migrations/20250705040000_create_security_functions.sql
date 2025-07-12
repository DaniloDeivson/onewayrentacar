-- Drop existing functions
DROP FUNCTION IF EXISTS public.validate_session();
DROP FUNCTION IF EXISTS public.has_permission(text);

-- Função para validar sessão
CREATE OR REPLACE FUNCTION public.validate_session()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _user_id uuid;
  _is_valid boolean;
BEGIN
  -- Obter ID do usuário atual
  _user_id := auth.uid();
  
  IF _user_id IS NULL THEN
    RETURN false;
  END IF;

  -- Verificar se o usuário existe e está ativo
  SELECT EXISTS (
    SELECT 1 
    FROM public.employees e
    WHERE e.id = _user_id::text
    AND e.active = true
  ) INTO _is_valid;

  RETURN _is_valid;
END;
$$;

-- Função para verificar permissões
CREATE OR REPLACE FUNCTION public.has_permission(required_permission text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _user_id uuid;
  _user_role text;
  _has_permission boolean;
BEGIN
  -- Obter ID do usuário atual
  _user_id := auth.uid();
  
  IF _user_id IS NULL THEN
    RETURN false;
  END IF;

  -- Verificar se o usuário existe e está ativo
  SELECT e.role
  FROM public.employees e
  WHERE e.id = _user_id::text
  AND e.active = true
  INTO _user_role;

  IF _user_role IS NULL THEN
    RETURN false;
  END IF;

  -- Admin tem todas as permissões
  IF _user_role = 'Admin' THEN
    RETURN true;
  END IF;

  -- Manager tem todas as permissões exceto admin
  IF _user_role = 'Manager' AND required_permission != 'admin' THEN
    RETURN true;
  END IF;

  -- Verificar permissões específicas por role
  CASE _user_role
    WHEN 'Mechanic' THEN
      _has_permission := required_permission IN ('maintenance', 'inventory');
    WHEN 'Inspector' THEN
      _has_permission := required_permission IN ('inspections', 'fleet');
    WHEN 'User' THEN
      _has_permission := required_permission IN ('dashboard');
    ELSE
      _has_permission := false;
  END CASE;

  RETURN _has_permission;
END;
$$; 