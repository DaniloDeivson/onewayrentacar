-- Adicionar campos de recorrência na tabela costs
ALTER TABLE costs 
ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS recurrence_type TEXT CHECK (recurrence_type IN ('monthly', 'weekly', 'yearly')),
ADD COLUMN IF NOT EXISTS recurrence_day INTEGER CHECK (recurrence_day >= 1 AND recurrence_day <= 31),
ADD COLUMN IF NOT EXISTS next_due_date DATE,
ADD COLUMN IF NOT EXISTS parent_recurring_cost_id UUID REFERENCES costs(id),
ADD COLUMN IF NOT EXISTS auto_generated BOOLEAN DEFAULT FALSE;

-- Criar índices para melhorar performance
CREATE INDEX IF NOT EXISTS idx_costs_is_recurring ON costs(is_recurring);
CREATE INDEX IF NOT EXISTS idx_costs_next_due_date ON costs(next_due_date);
CREATE INDEX IF NOT EXISTS idx_costs_parent_recurring_cost_id ON costs(parent_recurring_cost_id);

-- Função para gerar custos recorrentes automaticamente
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
            COALESCE(c.next_due_date, c.cost_date) as base_date
        FROM costs c
        WHERE c.is_recurring = TRUE 
        AND c.parent_recurring_cost_id IS NULL
        AND (
            c.next_due_date IS NULL 
            OR c.next_due_date <= CURRENT_DATE
        )
    LOOP
        -- Calcular próxima data baseada no tipo de recorrência
        next_date := recurring_cost.base_date;
        
        WHILE next_date <= CURRENT_DATE LOOP
            CASE recurring_cost.recurrence_type
                WHEN 'monthly' THEN
                    next_date := next_date + INTERVAL '1 month';
                WHEN 'weekly' THEN
                    next_date := next_date + INTERVAL '1 week';
                WHEN 'yearly' THEN
                    next_date := next_date + INTERVAL '1 year';
                ELSE
                    EXIT;
            END CASE;
        END LOOP;
        
        -- Criar novo custo recorrente
        INSERT INTO costs (
            tenant_id,
            category,
            description,
            amount,
            cost_date,
            status,
            vehicle_id,
            customer_id,
            customer_name,
            contract_id,
            guest_id,
            is_recurring,
            recurrence_type,
            recurrence_day,
            next_due_date,
            parent_recurring_cost_id,
            auto_generated,
            origin,
            created_by_employee_id,
            created_by_name
        ) VALUES (
            recurring_cost.tenant_id,
            recurring_cost.category,
            recurring_cost.description,
            recurring_cost.amount,
            CURRENT_DATE,
            'Pendente',
            recurring_cost.vehicle_id,
            recurring_cost.customer_id,
            recurring_cost.customer_name,
            recurring_cost.contract_id,
            recurring_cost.guest_id,
            TRUE,
            recurring_cost.recurrence_type,
            recurring_cost.recurrence_day,
            next_date,
            recurring_cost.id,
            TRUE,
            'Recorrente',
            recurring_cost.created_by_employee_id,
            recurring_cost.created_by_name
        ) RETURNING id INTO new_cost_id;
        
        -- Atualizar próxima data de vencimento do custo pai
        UPDATE costs 
        SET next_due_date = next_date
        WHERE id = recurring_cost.id;
        
        generated_count := generated_count + 1;
    END LOOP;
    
    RETURN generated_count;
END;
$$;

-- Trigger para atualizar next_due_date quando um custo recorrente é criado
CREATE OR REPLACE FUNCTION fn_update_recurring_cost_next_due_date()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Se é um custo recorrente e não tem próxima data definida
    IF NEW.is_recurring = TRUE AND NEW.next_due_date IS NULL THEN
        -- Calcular próxima data baseada na data atual e tipo de recorrência
        CASE NEW.recurrence_type
            WHEN 'monthly' THEN
                NEW.next_due_date := NEW.cost_date + INTERVAL '1 month';
            WHEN 'weekly' THEN
                NEW.next_due_date := NEW.cost_date + INTERVAL '1 week';
            WHEN 'yearly' THEN
                NEW.next_due_date := NEW.cost_date + INTERVAL '1 year';
        END CASE;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Aplicar trigger
DROP TRIGGER IF EXISTS trigger_update_recurring_cost_next_due_date ON costs;
CREATE TRIGGER trigger_update_recurring_cost_next_due_date
    BEFORE INSERT OR UPDATE ON costs
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_recurring_cost_next_due_date();

-- Função para buscar custos recorrentes com estatísticas
CREATE OR REPLACE FUNCTION fn_get_recurring_costs_stats(tenant_id_param UUID DEFAULT NULL)
RETURNS TABLE (
    total_count INTEGER,
    active_count INTEGER,
    overdue_count INTEGER,
    upcoming_count INTEGER,
    total_amount DECIMAL(10,2)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_count,
        COUNT(*) FILTER (WHERE status IN ('Pendente', 'Autorizado'))::INTEGER as active_count,
        COUNT(*) FILTER (WHERE next_due_date < CURRENT_DATE)::INTEGER as overdue_count,
        COUNT(*) FILTER (WHERE next_due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days')::INTEGER as upcoming_count,
        COALESCE(SUM(amount), 0) as total_amount
    FROM costs 
    WHERE is_recurring = TRUE 
    AND parent_recurring_cost_id IS NULL
    AND (tenant_id_param IS NULL OR tenant_id = tenant_id_param);
END;
$$;

-- Comentários para documentação
COMMENT ON COLUMN costs.is_recurring IS 'Indica se o custo é recorrente';
COMMENT ON COLUMN costs.recurrence_type IS 'Tipo de recorrência: monthly, weekly, yearly';
COMMENT ON COLUMN costs.recurrence_day IS 'Dia da recorrência (1-31)';
COMMENT ON COLUMN costs.next_due_date IS 'Próxima data de vencimento do custo recorrente';
COMMENT ON COLUMN costs.parent_recurring_cost_id IS 'ID do custo pai para custos gerados automaticamente';
COMMENT ON COLUMN costs.auto_generated IS 'Indica se o custo foi gerado automaticamente pelo sistema';

COMMENT ON FUNCTION fn_generate_recurring_costs() IS 'Gera custos recorrentes automaticamente baseado na configuração';
COMMENT ON FUNCTION fn_get_recurring_costs_stats(UUID) IS 'Retorna estatísticas dos custos recorrentes'; 