-- 🔧 SOLUÇÃO ALTERNATIVA - DESABILITAR RLS TEMPORARIAMENTE
-- Execute este SQL no Supabase SQL Editor

-- 1. Verificar estado atual do RLS
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename = 'fines';

-- 2. Desabilitar RLS temporariamente para teste
ALTER TABLE public.fines DISABLE ROW LEVEL SECURITY;

-- 3. Verificar se o problema era RLS
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename = 'fines';

-- 4. Teste de inserção simples
INSERT INTO public.fines (
    vehicle_id,
    employee_id,
    infraction_type,
    amount,
    infraction_date,
    due_date,
    status,
    severity,
    points,
    tenant_id
) VALUES (
    '5d9d3ca2-883f-4929-bef3-9c0dbbbc11aa',
    '69baaaaa-9142-4c48-915b-a6b396107fa2',
    'Teste RLS OFF',
    100.00,
    '2025-07-03',
    '2025-08-02',
    'Pendente',
    'Média',
    3,
    'default'
);

-- 5. Verificar se a inserção funcionou
SELECT 
    id,
    infraction_type,
    amount,
    severity,
    points
FROM public.fines 
WHERE infraction_type = 'Teste RLS OFF';

-- 6. Limpar teste
DELETE FROM public.fines WHERE infraction_type = 'Teste RLS OFF';

-- 7. Reabilitar RLS
ALTER TABLE public.fines ENABLE ROW LEVEL SECURITY;

-- 8. Verificar se RLS foi reabilitado
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename = 'fines';

-- 9. Se funcionou com RLS desabilitado, o problema é nas políticas RLS
-- Vamos criar uma política mais permissiva
CREATE POLICY IF NOT EXISTS "fines_insert_policy" ON public.fines
    FOR INSERT WITH CHECK (true);

CREATE POLICY IF NOT EXISTS "fines_select_policy" ON public.fines
    FOR SELECT USING (true);

-- 10. Verificar políticas criadas
SELECT 
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE tablename = 'fines'; 