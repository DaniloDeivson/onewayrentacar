-- Drop existing functions
DROP FUNCTION IF EXISTS public.mark_duplicate_users();
DROP FUNCTION IF EXISTS public.cleanup_removed_users();
DROP FUNCTION IF EXISTS public.sync_auth_users();

-- Função para marcar usuários duplicados
CREATE OR REPLACE FUNCTION public.mark_duplicate_users()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Atualizar status de emails duplicados
  WITH duplicates AS (
    SELECT 
      e.id,
      e.contact_info->>'email' as email,
      e.created_at,
      ROW_NUMBER() OVER (
        PARTITION BY LOWER(e.contact_info->>'email')
        ORDER BY e.created_at DESC
      ) as rn
    FROM public.employees e
    WHERE e.active = true
  )
  UPDATE public.employees e
  SET 
    contact_info = jsonb_set(
      jsonb_set(
        e.contact_info,
        '{status}',
        '"orphaned_duplicate"'::jsonb
      ),
      '{updated_reason}',
      '"Duplicate email found"'::jsonb
    ),
    active = false,
    updated_at = NOW()
  WHERE EXISTS (
    SELECT 1
    FROM duplicates d
    WHERE d.id = e.id
    AND d.rn > 1
  );
END;
$$;

-- Função para limpar usuários removidos
CREATE OR REPLACE FUNCTION public.cleanup_removed_users()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Inserir usuários removidos na tabela de histórico
  INSERT INTO public.removed_users (id, email, removed_at, reason)
  SELECT 
    e.id,
    e.contact_info->>'email',
    NOW(),
    COALESCE(e.contact_info->>'updated_reason', 'User deactivated')
  FROM public.employees e
  WHERE e.active = false
  AND e.contact_info->>'status' IN ('orphaned', 'orphaned_duplicate')
  AND NOT EXISTS (
    SELECT 1 
    FROM public.removed_users ru 
    WHERE ru.id = e.id
  );
END;
$$;

-- Função para sincronizar usuários auth com employees
CREATE OR REPLACE FUNCTION public.sync_auth_users()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Marcar usuários órfãos (existem em auth mas não em employees)
  UPDATE public.employees e
  SET 
    contact_info = jsonb_set(
      jsonb_set(
        e.contact_info,
        '{status}',
        '"orphaned"'::jsonb
      ),
      '{updated_reason}',
      '"User not found in auth.users"'::jsonb
    ),
    active = false,
    updated_at = NOW()
  WHERE NOT EXISTS (
    SELECT 1
    FROM auth.users au
    WHERE au.id::text = e.id
  )
  AND e.active = true;

  -- Marcar usuários inativos no auth
  UPDATE public.employees e
  SET 
    contact_info = jsonb_set(
      jsonb_set(
        e.contact_info,
        '{status}',
        '"orphaned"'::jsonb
      ),
      '{updated_reason}',
      '"User inactive in auth.users"'::jsonb
    ),
    active = false,
    updated_at = NOW()
  WHERE EXISTS (
    SELECT 1
    FROM auth.users au
    WHERE au.id::text = e.id
    AND NOT au.confirmed_at IS NOT NULL
  )
  AND e.active = true;
END;
$$; 