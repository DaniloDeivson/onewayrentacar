-- Adicionar política para permitir exclusão de funcionários
DROP POLICY IF EXISTS "Allow delete employees" ON public.employees;
CREATE POLICY "Allow delete employees" ON public.employees FOR DELETE 
TO authenticated 
USING (
  auth.uid() IN (
    SELECT id FROM public.employees 
    WHERE tenant_id = employees.tenant_id 
    AND (role = 'Admin' OR role = 'Manager')
    AND active = true
  )
);

-- Melhorar a função de veículos disponíveis para permitir troca em contratos ativos
CREATE OR REPLACE FUNCTION public.fn_available_vehicles(
  p_start_date date,
  p_end_date date,
  p_tenant_id uuid,
  p_exclude_contract_id uuid DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  plate text,
  model text,
  year integer,
  type text,
  status text
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.id,
    v.plate,
    v.model,
    v.year,
    v.type,
    v.status
  FROM public.vehicles v
  WHERE v.tenant_id = p_tenant_id
    AND v.active = true
    AND v.status IN ('Disponível', 'Em Contrato')
    AND NOT EXISTS (
      SELECT 1 
      FROM public.contracts c
      WHERE c.vehicle_id = v.id
        AND c.tenant_id = p_tenant_id
        AND c.status = 'Ativo'
        AND (
          (c.start_date <= p_end_date AND c.end_date >= p_start_date)
        )
        AND (p_exclude_contract_id IS NULL OR c.id != p_exclude_contract_id)
    )
    AND NOT EXISTS (
      SELECT 1 
      FROM public.maintenance_checkins mc
      WHERE mc.vehicle_id = v.id
        AND mc.tenant_id = p_tenant_id
        AND mc.status = 'Em Manutenção'
        AND (
          (mc.checkin_date <= p_end_date AND (mc.checkout_date IS NULL OR mc.checkout_date >= p_start_date))
        )
    );
END;
$$;

-- Adicionar função para carrinho de veículos (futura implementação)
CREATE OR REPLACE FUNCTION public.fn_vehicle_cart_availability(
  p_vehicle_ids uuid[],
  p_start_date date,
  p_end_date date,
  p_tenant_id uuid,
  p_exclude_contract_id uuid DEFAULT NULL
)
RETURNS TABLE (
  vehicle_id uuid,
  plate text,
  model text,
  year integer,
  is_available boolean,
  conflict_reason text
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id uuid;
BEGIN
  FOREACH v_id IN ARRAY p_vehicle_ids
  LOOP
    RETURN QUERY
    SELECT 
      v.id,
      v.plate,
      v.model,
      v.year,
      CASE 
        WHEN NOT EXISTS (
          SELECT 1 
          FROM public.contracts c
          WHERE c.vehicle_id = v.id
            AND c.tenant_id = p_tenant_id
            AND c.status = 'Ativo'
            AND (c.start_date <= p_end_date AND c.end_date >= p_start_date)
            AND (p_exclude_contract_id IS NULL OR c.id != p_exclude_contract_id)
        ) AND NOT EXISTS (
          SELECT 1 
          FROM public.maintenance_checkins mc
          WHERE mc.vehicle_id = v.id
            AND mc.tenant_id = p_tenant_id
            AND mc.status = 'Em Manutenção'
            AND (mc.checkin_date <= p_end_date AND (mc.checkout_date IS NULL OR mc.checkout_date >= p_start_date))
        ) THEN true
        ELSE false
      END as is_available,
      CASE 
        WHEN EXISTS (
          SELECT 1 
          FROM public.contracts c
          WHERE c.vehicle_id = v.id
            AND c.tenant_id = p_tenant_id
            AND c.status = 'Ativo'
            AND (c.start_date <= p_end_date AND c.end_date >= p_start_date)
            AND (p_exclude_contract_id IS NULL OR c.id != p_exclude_contract_id)
        ) THEN 'Em contrato ativo'
        WHEN EXISTS (
          SELECT 1 
          FROM public.maintenance_checkins mc
          WHERE mc.vehicle_id = v.id
            AND mc.tenant_id = p_tenant_id
            AND mc.status = 'Em Manutenção'
            AND (mc.checkin_date <= p_end_date AND (mc.checkout_date IS NULL OR mc.checkout_date >= p_start_date))
        ) THEN 'Em manutenção'
        ELSE 'Disponível'
      END as conflict_reason
    FROM public.vehicles v
    WHERE v.id = v_id
      AND v.tenant_id = p_tenant_id
      AND v.active = true;
  END LOOP;
END;
$$;
