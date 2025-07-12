-- Drop existing triggers
DROP TRIGGER IF EXISTS employees_updated_at ON public.employees;
DROP TRIGGER IF EXISTS employees_unique_email ON public.employees;
DROP TRIGGER IF EXISTS employees_role_validation ON public.employees;
DROP TRIGGER IF EXISTS employees_removed_sync ON public.employees;

-- Drop existing functions
DROP FUNCTION IF EXISTS public.update_updated_at();
DROP FUNCTION IF EXISTS public.validate_unique_email();
DROP FUNCTION IF EXISTS public.validate_employee_role();
DROP FUNCTION IF EXISTS public.sync_removed_users();

-- Drop existing constraints
ALTER TABLE public.employees DROP CONSTRAINT IF EXISTS employees_role_check;

-- Add updated constraint
ALTER TABLE public.employees ADD CONSTRAINT employees_role_check 
CHECK (role IN ('Admin', 'Manager', 'Mechanic', 'Inspector', 'FineAdmin', 'Sales', 'User'));

-- Add constraint for roles_extra
ALTER TABLE public.employees DROP CONSTRAINT IF EXISTS roles_extra_valid;
ALTER TABLE public.employees ADD CONSTRAINT roles_extra_valid 
CHECK (roles_extra IS NULL OR (
  array_length(roles_extra, 1) IS NULL OR 
  array_length(roles_extra, 1) = 0 OR
  (array_length(roles_extra, 1) > 0 AND 
   (SELECT bool_and(role_item IN ('Admin', 'Manager', 'Mechanic', 'Inspector', 'FineAdmin', 'Sales', 'User'))
    FROM unnest(roles_extra) AS role_item))
));

-- Trigger para atualizar timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER employees_updated_at
  BEFORE UPDATE ON public.employees
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

-- Trigger para validar email único
CREATE OR REPLACE FUNCTION public.validate_unique_email()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.employees e
    WHERE LOWER(e.contact_info->>'email') = LOWER(NEW.contact_info->>'email')
    AND e.id != NEW.id
    AND e.active = true
  ) THEN
    RAISE EXCEPTION 'Email already exists';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER employees_unique_email
  BEFORE INSERT OR UPDATE ON public.employees
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_unique_email();

-- Trigger para validar role
CREATE OR REPLACE FUNCTION public.validate_employee_role()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.role NOT IN ('Admin', 'Manager', 'Mechanic', 'Inspector', 'FineAdmin', 'Sales', 'User') THEN
    RAISE EXCEPTION 'Invalid role';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER employees_role_validation
  BEFORE INSERT OR UPDATE ON public.employees
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_employee_role();

-- Trigger para sincronizar usuários removidos
CREATE OR REPLACE FUNCTION public.sync_removed_users()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.active = true AND NEW.active = false THEN
    INSERT INTO public.removed_users (id, email, removed_at, reason)
    VALUES (
      NEW.id,
      NEW.contact_info->>'email',
      NOW(),
      COALESCE(NEW.contact_info->>'updated_reason', 'User deactivated')
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER employees_removed_sync
  AFTER UPDATE ON public.employees
  FOR EACH ROW
  WHEN (OLD.active = true AND NEW.active = false)
  EXECUTE FUNCTION public.sync_removed_users(); 