-- Migration: Criação da tabela removed_users para bloquear re-cadastro de usuários excluídos
CREATE TABLE IF NOT EXISTS public.removed_users (
  id uuid PRIMARY KEY,
  email text NOT NULL,
  removed_at timestamp with time zone DEFAULT now()
);

-- Índice para busca rápida por email
CREATE INDEX IF NOT EXISTS removed_users_email_idx ON public.removed_users(email); 