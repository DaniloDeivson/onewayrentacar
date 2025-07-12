-- Opção 1: Resetar senha diretamente (requer service_role)
UPDATE auth.users
SET encrypted_password = crypt('nova_senha_aqui', gen_salt('bf'))
WHERE email = 'email@exemplo.com';

-- Opção 2: Criar um token de reset de senha (mais seguro)
INSERT INTO auth.mfa_factors 
  (user_id, friendly_name, factor_type, status, created_at, updated_at)
SELECT 
  id as user_id,
  'Password Reset',
  'totp' as factor_type,
  'verified' as status,
  now(),
  now()
FROM auth.users
WHERE email = 'email@exemplo.com'
AND NOT EXISTS (
  SELECT 1 FROM auth.mfa_factors 
  WHERE user_id = auth.users.id 
  AND factor_type = 'totp'
);

-- Opção 3: Forçar usuário a redefinir senha no próximo login
UPDATE auth.users
SET raw_app_meta_data = raw_app_meta_data || 
  '{"force_password_reset": true}'::jsonb
WHERE email = 'email@exemplo.com'; 