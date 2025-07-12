-- Primeiro, vamos identificar emails que não têm nenhum registro ativo
WITH inactive_emails AS (
    SELECT DISTINCT LOWER(contact_info->>'email') as email
    FROM employees
    GROUP BY LOWER(contact_info->>'email')
    HAVING COUNT(*) FILTER (WHERE active = true) = 0
)
-- Para cada email inativo, reativar o registro mais recente que não está marcado como orphaned
UPDATE employees e
SET 
    active = true,
    contact_info = jsonb_set(
        jsonb_set(
            contact_info,
            '{status}',
            'null'::jsonb
        ),
        '{updated_reason}',
        '"Registro reativado após correção de duplicatas"'::jsonb
    )
WHERE id IN (
    SELECT e2.id
    FROM employees e2
    JOIN inactive_emails ie ON LOWER(e2.contact_info->>'email') = ie.email
    WHERE e2.contact_info->>'status' != 'orphaned'
    AND NOT EXISTS (
        SELECT 1 
        FROM employees e3
        WHERE LOWER(e3.contact_info->>'email') = ie.email
        AND e3.active = true
    )
    ORDER BY e2.created_at DESC
);

-- Verificar se ainda existem duplicatas ativas
DO $$
DECLARE
    duplicate_count integer;
BEGIN
    SELECT COUNT(*)
    INTO duplicate_count
    FROM (
        SELECT LOWER(contact_info->>'email') as email
        FROM employees
        WHERE active = true
        GROUP BY LOWER(contact_info->>'email')
        HAVING COUNT(*) > 1
    ) duplicates;

    IF duplicate_count > 0 THEN
        RAISE EXCEPTION 'Ainda existem % emails com múltiplos registros ativos', duplicate_count;
    END IF;
END $$; 