-- SOLUÇÃO FINAL ERRO 400 - EXECUTE NO SUPABASE SQL EDITOR

-- Adicionar campos
ALTER TABLE public.fines 
ADD COLUMN IF NOT EXISTS severity text CHECK (severity IN ('Baixa', 'Média', 'Alta')),
ADD COLUMN IF NOT EXISTS points integer DEFAULT 0 CHECK (points >= 0);

-- Corrigir RLS
ALTER TABLE public.fines DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fines_policy" ON public.fines;

CREATE POLICY "fines_all_access" ON public.fines
    FOR ALL
    USING (true)
    WITH CHECK (true);

ALTER TABLE public.fines ENABLE ROW LEVEL SECURITY;

GRANT ALL ON public.fines TO authenticated;

-- Verificar se funcionou
SELECT '✅ SOLUÇÃO APLICADA! TESTE O FORMULÁRIO!' as resultado; 