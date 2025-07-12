-- ============================================================================
-- CORREÇÃO DOS PROBLEMAS DE COBRANÇA E MANUTENÇÃO
-- ============================================================================
-- Esta migração corrige:
-- 1. Problema do contract_id NOT NULL em customer_charges
-- 2. Problema do carrinho de peças não funcionando
-- 3. Atualizar responsáveis "Sistema" para Pedro Pardal

-- ============================================================================
-- 1. CORRIGIR CONSTRAINT DO CONTRACT_ID EM CUSTOMER_CHARGES
-- ============================================================================

-- Tornar contract_id opcional (nullable) na tabela customer_charges
ALTER TABLE public.customer_charges 
ALTER COLUMN contract_id DROP NOT NULL;

-- ============================================================================
-- 2. ATUALIZAR RESPONSÁVEIS "SISTEMA" PARA PEDRO PARDAL
-- ============================================================================

-- Primeiro, garantir que o cliente Pedro Pardal existe
DO $$
DECLARE
  v_pedro_customer_id uuid;
BEGIN
  -- Verificar se o cliente Pedro Pardal já existe
  SELECT id INTO v_pedro_customer_id
  FROM customers
  WHERE email = 'pedropardal04@gmail.com'
    AND tenant_id = '00000000-0000-0000-0000-000000000001'::uuid;
  
  -- Se não existe, criar
  IF v_pedro_customer_id IS NULL THEN
    INSERT INTO customers (
      id,
      tenant_id,
      name,
      email,
      phone,
      document,
      address,
      city,
      state,
      postal_code,
      country,
      active,
      created_at,
      updated_at
    ) VALUES (
      gen_random_uuid(),
      '00000000-0000-0000-0000-000000000001'::uuid,
      'Pedro Pardal',
      'pedropardal04@gmail.com',
      '(11) 99999-9999',
      '123.456.789-00',
      'Rua das Aves, 123',
      'São Paulo',
      'SP',
      '01234-567',
      'Brasil',
      true,
      now(),
      now()
    ) RETURNING id INTO v_pedro_customer_id;
  END IF;
  
  -- Atualizar todos os custos com responsável "Sistema" para Pedro Pardal
  UPDATE costs 
  SET created_by_name = 'Pedro Pardal',
      customer_id = v_pedro_customer_id
  WHERE created_by_name = 'Sistema'
    AND tenant_id = '00000000-0000-0000-0000-000000000001'::uuid;
    
  RAISE NOTICE 'Atualizados % custos com responsável "Sistema" para Pedro Pardal', FOUND;
END $$;

-- ============================================================================
-- 3. CORRIGIR FUNÇÃO DE GERAÇÃO DE COBRANÇAS
-- ============================================================================

-- Atualizar a função para lidar com contract_id NULL
CREATE OR REPLACE FUNCTION public.fn_generate_charges_from_selected_costs(
    p_tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
    p_cost_ids uuid[] DEFAULT '{}'::uuid[]
)
RETURNS TABLE (
    charges_generated integer,
    total_amount numeric
) AS $$
DECLARE
    v_charges_count integer := 0;
    v_total_amount numeric := 0;
    v_cost_record record;
BEGIN
    -- Generate charges for each selected cost
    FOR v_cost_record IN
        SELECT 
            c.id,
            c.customer_id,
            c.contract_id,
            c.vehicle_id,
            CASE 
                WHEN c.category = 'Avaria' THEN 'Dano'
                WHEN c.category = 'Funilaria' THEN 'Dano'
                WHEN c.category = 'Multa' THEN 'Multa'
                WHEN c.category = 'Excesso Km' THEN 'Excesso KM'
                WHEN c.category = 'Diária Extra' THEN 'Diária Extra'
                ELSE 'Dano'
            END as charge_type,
            c.description,
            c.amount,
            c.cost_date
        FROM public.costs c
        WHERE c.id = ANY(p_cost_ids)
            AND c.tenant_id = p_tenant_id
            AND c.customer_id IS NOT NULL
    LOOP
        -- Check if charge already exists for this cost
        IF NOT EXISTS (
            SELECT 1 FROM public.customer_charges cc 
            WHERE cc.source_cost_ids && ARRAY[v_cost_record.id]
        ) THEN
            INSERT INTO public.customer_charges (
                tenant_id,
                customer_id,
                contract_id,
                vehicle_id,
                charge_type,
                description,
                amount,
                status,
                charge_date,
                due_date,
                source_cost_ids,
                generated_from
            ) VALUES (
                p_tenant_id,
                v_cost_record.customer_id,
                v_cost_record.contract_id, -- Pode ser NULL agora
                v_cost_record.vehicle_id,
                v_cost_record.charge_type,
                v_cost_record.description,
                v_cost_record.amount,
                'Pendente',
                v_cost_record.cost_date,
                v_cost_record.cost_date + INTERVAL '30 days',
                ARRAY[v_cost_record.id],
                'Manual'
            );
            
            v_charges_count := v_charges_count + 1;
            v_total_amount := v_total_amount + v_cost_record.amount;
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT v_charges_count, v_total_amount;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CORRIGIR PROBLEMA DO CARRINHO DE PEÇAS
-- ============================================================================

-- Verificar se a tabela service_order_parts tem a coluna total_cost
DO $$
BEGIN
  -- Adicionar coluna total_cost se não existir
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'service_order_parts' 
    AND column_name = 'total_cost'
  ) THEN
    ALTER TABLE service_order_parts 
    ADD COLUMN total_cost numeric(12,2) GENERATED ALWAYS AS (quantity_used * unit_cost_at_time) STORED;
  END IF;
END $$;

-- Corrigir a função de adicionar peças para incluir total_cost
CREATE OR REPLACE FUNCTION handle_service_order_parts()
RETURNS TRIGGER AS $$
DECLARE
  v_part_name TEXT;
  v_part_quantity INTEGER;
  v_vehicle_id UUID;
  v_service_note_id UUID;
BEGIN
  -- Get part information
  SELECT name, quantity INTO v_part_name, v_part_quantity
  FROM parts 
  WHERE id = NEW.part_id;

  -- Get service order vehicle information
  SELECT vehicle_id, id INTO v_vehicle_id, v_service_note_id
  FROM service_notes 
  WHERE id = NEW.service_note_id;

  -- Check if we have enough stock
  IF v_part_quantity < NEW.quantity_used THEN
    RAISE EXCEPTION 'Insufficient stock for part %. Available: %, Required: %', 
      v_part_name, v_part_quantity, NEW.quantity_used;
  END IF;

  -- Update parts quantity
  UPDATE parts 
  SET quantity = quantity - NEW.quantity_used,
      updated_at = now()
  WHERE id = NEW.part_id;

  -- Create stock movement record
  INSERT INTO stock_movements (
    tenant_id,
    part_id,
    service_note_id,
    type,
    quantity,
    movement_date,
    created_at
  ) VALUES (
    NEW.tenant_id,
    NEW.part_id,
    NEW.service_note_id,
    'Saída',
    NEW.quantity_used,
    CURRENT_DATE,
    now()
  );

  -- Create cost record with proper category and origin
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
    created_by_name,
    source_reference_id,
    source_reference_type,
    created_at
  ) VALUES (
    NEW.tenant_id,
    'Tipo de Manutenção', -- Categoria correta
    v_vehicle_id,
    CONCAT('Peça utilizada: ', v_part_name, ' (Qtde: ', NEW.quantity_used, ')'),
    NEW.total_cost,
    CURRENT_DATE,
    'Pendente',
    CONCAT('OS-', v_service_note_id),
    CONCAT('Lançamento automático via Ordem de Serviço'),
    'Manutenção', -- Origem correta
    'Pedro Pardal', -- Responsável
    v_service_note_id::text,
    'service_note',
    now()
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 5. MENSAGEM DE SUCESSO
-- ============================================================================

SELECT 'Problemas de cobrança e manutenção corrigidos com sucesso!' as message; 