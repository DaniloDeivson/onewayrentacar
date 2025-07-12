-- Migration: Adicionar campo 'location' à tabela inspections
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS location text NULL; 