-- Criar função para gerar custos recorrentes automaticamente
CREATE OR REPLACE FUNCTION fn_generate_recurring_costs()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    recurring_cost RECORD;
    new_cost_id UUID;
    next_date DATE;
    generated_count INTEGER := 0;
BEGIN
    -- Buscar todos os custos recorrentes que precisam ser gerados
    FOR recurring_cost IN 
        SELECT 
            c.*,
            CASE 
                WHEN c.recurrence_type = 'monthly' THEN
                    COALESCE(c.next_due_date, c.cost_date) + INTERVAL '1 month'
                WHEN c.recurrence_type = 'weekly' THEN
                    COALESCE(c.next_due_date, c.cost_date) + INTERVAL '1 week'
                WHEN c.recurrence_type = 'yearly' THEN
                    COALESCE(c.next_due_date, c.cost_date) + INTERVAL '1 year'
                ELSE
                    COALESCE(c.next_due_date, c.cost_date) + INTERVAL '1 month'
            END as calculated_next_date
        FROM costs c
        WHERE c.is_recurring = true
        AND c.parent_recurring_cost_id IS NULL
        AND (
            c.next_due_date IS NULL 
            OR c.next_due_date <= CURRENT_DATE
        )
    LOOP
        -- Calcular a próxima data de vencimento
        next_date := recurring_cost.calculated_next_date::DATE;
        
        -- Verificar se já existe um custo para esta data
        IF NOT EXISTS (
            SELECT 1 FROM costs 
            WHERE parent_recurring_cost_id = recurring_cost.id
            AND cost_date = next_date
        ) THEN
            -- Inserir novo custo recorrente
            INSERT INTO costs (
                tenant_id,
                category,
                vehicle_id,
                description,
                amount,
                cost_date,
                status,
                document_ref,
                observations,
                origin,
                created_by_employee_id,
                source_reference_id,
                source_reference_type,
                department,
                customer_id,
                customer_name,
                contract_id,
                supplier_id,
                supplier_name,
                created_by_name,
                is_recurring,
                recurrence_type,
                recurrence_day,
                next_due_date,
                parent_recurring_cost_id,
                auto_generated,
                guest_id
            ) VALUES (
                recurring_cost.tenant_id,
                recurring_cost.category,
                recurring_cost.vehicle_id,
                recurring_cost.description,
                recurring_cost.amount,
                next_date,
                'Pendente',
                recurring_cost.document_ref,
                recurring_cost.observations,
                'Automático',
                recurring_cost.created_by_employee_id,
                recurring_cost.source_reference_id,
                recurring_cost.source_reference_type,
                recurring_cost.department,
                recurring_cost.customer_id,
                recurring_cost.customer_name,
                recurring_cost.contract_id,
                recurring_cost.supplier_id,
                recurring_cost.supplier_name,
                recurring_cost.created_by_name,
                false, -- Não é o custo pai
                recurring_cost.recurrence_type,
                recurring_cost.recurrence_day,
                next_date + CASE 
                    WHEN recurring_cost.recurrence_type = 'monthly' THEN INTERVAL '1 month'
                    WHEN recurring_cost.recurrence_type = 'weekly' THEN INTERVAL '1 week'
                    WHEN recurring_cost.recurrence_type = 'yearly' THEN INTERVAL '1 year'
                    ELSE INTERVAL '1 month'
                END,
                recurring_cost.id,
                true,
                recurring_cost.guest_id
            ) RETURNING id INTO new_cost_id;
            
            -- Atualizar a próxima data de vencimento do custo pai
            UPDATE costs 
            SET next_due_date = next_date + CASE 
                WHEN recurring_cost.recurrence_type = 'monthly' THEN INTERVAL '1 month'
                WHEN recurring_cost.recurrence_type = 'weekly' THEN INTERVAL '1 week'
                WHEN recurring_cost.recurrence_type = 'yearly' THEN INTERVAL '1 year'
                ELSE INTERVAL '1 month'
            END
            WHERE id = recurring_cost.id;
            
            generated_count := generated_count + 1;
        END IF;
    END LOOP;
    
    RETURN generated_count;
END;
$$;

-- Criar função para buscar estatísticas de custos recorrentes
CREATE OR REPLACE FUNCTION fn_get_recurring_costs_stats()
RETURNS TABLE(
    total_recurring INTEGER,
    total_monthly_value NUMERIC,
    upcoming_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_recurring,
        COALESCE(SUM(amount), 0) as total_monthly_value,
        COUNT(*) FILTER (WHERE next_due_date <= CURRENT_DATE + INTERVAL '30 days')::INTEGER as upcoming_count
    FROM costs 
    WHERE is_recurring = true 
    AND parent_recurring_cost_id IS NULL;
END;
$$; 