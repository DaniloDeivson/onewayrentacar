-- 🧪 TESTE MANUAL DE INSERÇÃO - IDENTIFICAR CAUSA DO ERRO 400
-- Execute este SQL no Supabase SQL Editor

-- 1. Teste básico - apenas campos obrigatórios
INSERT INTO public.fines (
    vehicle_id,
    employee_id,
    infraction_type,
    amount,
    infraction_date,
    due_date,
    status,
    tenant_id
) VALUES (
    '5d9d3ca2-883f-4929-bef3-9c0dbbbc11aa',
    '69baaaaa-9142-4c48-915b-a6b396107fa2',
    'Teste básico',
    100.00,
    '2025-07-03',
    '2025-08-02',
    'Pendente',
    'default'
);

-- 2. Se o teste básico funcionar, teste com severity e points
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
    'Teste com severity e points',
    150.00,
    '2025-07-03',
    '2025-08-02',
    'Pendente',
    'Média',
    3,
    'default'
);

-- 3. Verificar se as inserções funcionaram
SELECT 
    id,
    vehicle_id,
    employee_id,
    infraction_type,
    amount,
    severity,
    points,
    created_at
FROM public.fines 
WHERE infraction_type LIKE 'Teste%'
ORDER BY created_at DESC;

-- 4. Limpar dados de teste
DELETE FROM public.fines WHERE infraction_type LIKE 'Teste%'; 