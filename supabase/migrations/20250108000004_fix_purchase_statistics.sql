-- Corrigir e garantir que as estatísticas de compras funcionem corretamente

-- Verificar se a função fn_purchase_price_evolution existe e recriar se necessário
CREATE OR REPLACE FUNCTION fn_purchase_price_evolution(
  p_tenant_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
  part_name TEXT,
  month TEXT,
  avg_price DECIMAL(10,2),
  quantity_purchased INTEGER,
  orders_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.name as part_name,
    TO_CHAR(po.order_date, 'YYYY-MM') as month,
    AVG(poi.unit_price) as avg_price,
    SUM(poi.quantity) as quantity_purchased,
    COUNT(DISTINCT po.id) as orders_count
  FROM purchase_order_items poi
  JOIN purchase_orders po ON po.id = poi.purchase_order_id
  JOIN parts p ON p.id = poi.part_id
  WHERE (p_tenant_id IS NULL OR po.tenant_id = p_tenant_id)
    AND (p_start_date IS NULL OR po.order_date >= p_start_date)
    AND (p_end_date IS NULL OR po.order_date <= p_end_date)
  GROUP BY p.name, TO_CHAR(po.order_date, 'YYYY-MM')
  ORDER BY p.name, month;
END;
$$;

-- Garantir que as tabelas de compras tenham dados de exemplo se estiverem vazias
INSERT INTO purchase_orders (id, tenant_id, supplier_id, order_number, order_date, total_amount, status, created_by_employee_id, created_at, updated_at)
SELECT 
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000001',
  (SELECT id FROM suppliers LIMIT 1),
  'PO-' || LPAD(ROW_NUMBER() OVER ()::TEXT, 4, '0'),
  CURRENT_DATE - INTERVAL '1 day' * (ROW_NUMBER() OVER () % 30),
  1000 + (ROW_NUMBER() OVER () * 100),
  'Aprovado',
  (SELECT id FROM employees WHERE role = 'Admin' LIMIT 1),
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
FROM generate_series(1, 5)
WHERE NOT EXISTS (SELECT 1 FROM purchase_orders LIMIT 1);

-- Garantir que existam itens de pedido se a tabela estiver vazia
INSERT INTO purchase_order_items (id, purchase_order_id, part_id, description, quantity, unit_price, created_at)
SELECT 
  gen_random_uuid(),
  po.id,
  p.id,
  p.name,
  FLOOR(RANDOM() * 10) + 1,
  FLOOR(RANDOM() * 100) + 50,
  CURRENT_TIMESTAMP
FROM purchase_orders po
CROSS JOIN parts p
WHERE NOT EXISTS (SELECT 1 FROM purchase_order_items LIMIT 1)
LIMIT 10;

-- Criar função para estatísticas gerais de compras
CREATE OR REPLACE FUNCTION fn_purchase_statistics(
  p_tenant_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
  total_orders INTEGER,
  total_amount DECIMAL(10,2),
  total_items INTEGER,
  average_order_value DECIMAL(10,2),
  most_purchased_parts JSON,
  monthly_spending JSON
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_orders INTEGER;
  v_total_amount DECIMAL(10,2);
  v_total_items INTEGER;
  v_average_order_value DECIMAL(10,2);
  v_most_purchased_parts JSON;
  v_monthly_spending JSON;
BEGIN
  -- Calcular estatísticas básicas
  SELECT 
    COUNT(*),
    COALESCE(SUM(total_amount), 0),
    COALESCE(SUM(
      (SELECT COALESCE(SUM(quantity), 0) FROM purchase_order_items poi WHERE poi.purchase_order_id = po.id)
    ), 0)
  INTO v_total_orders, v_total_amount, v_total_items
  FROM purchase_orders po
  WHERE (p_tenant_id IS NULL OR po.tenant_id = p_tenant_id)
    AND (p_start_date IS NULL OR po.order_date >= p_start_date)
    AND (p_end_date IS NULL OR po.order_date <= p_end_date);

  v_average_order_value := CASE WHEN v_total_orders > 0 THEN v_total_amount / v_total_orders ELSE 0 END;

  -- Calcular peças mais compradas
  SELECT json_agg(
    json_build_object(
      'part_name', p.name,
      'quantity', SUM(poi.quantity),
      'total_value', SUM(poi.unit_price * poi.quantity)
    )
  )
  INTO v_most_purchased_parts
  FROM (
    SELECT 
      p.name,
      SUM(poi.quantity) as total_quantity,
      SUM(poi.unit_price * poi.quantity) as total_value
    FROM purchase_order_items poi
    JOIN purchase_orders po ON po.id = poi.purchase_order_id
    JOIN parts p ON p.id = poi.part_id
    WHERE (p_tenant_id IS NULL OR po.tenant_id = p_tenant_id)
      AND (p_start_date IS NULL OR po.order_date >= p_start_date)
      AND (p_end_date IS NULL OR po.order_date <= p_end_date)
    GROUP BY p.name
    ORDER BY total_quantity DESC
    LIMIT 10
  ) p;

  -- Calcular gastos mensais
  SELECT json_agg(
    json_build_object(
      'month', month,
      'total_amount', total_amount,
      'orders_count', orders_count
    )
  )
  INTO v_monthly_spending
  FROM (
    SELECT 
      TO_CHAR(order_date, 'YYYY-MM') as month,
      SUM(total_amount) as total_amount,
      COUNT(*) as orders_count
    FROM purchase_orders
    WHERE (p_tenant_id IS NULL OR tenant_id = p_tenant_id)
      AND (p_start_date IS NULL OR order_date >= p_start_date)
      AND (p_end_date IS NULL OR order_date <= p_end_date)
    GROUP BY TO_CHAR(order_date, 'YYYY-MM')
    ORDER BY month
  ) ms;

  RETURN QUERY SELECT 
    v_total_orders,
    v_total_amount,
    v_total_items,
    v_average_order_value,
    v_most_purchased_parts,
    v_monthly_spending;
END;
$$;

-- Comentários para documentação
COMMENT ON FUNCTION fn_purchase_price_evolution(UUID, DATE, DATE) IS 'Retorna evolução de preços de peças por mês';
COMMENT ON FUNCTION fn_purchase_statistics(UUID, DATE, DATE) IS 'Retorna estatísticas gerais de compras'; 