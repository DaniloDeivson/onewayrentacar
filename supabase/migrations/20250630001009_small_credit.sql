/*
  # Fix Parts Used in Accounts Payable

  1. Changes
    - Update fn_sync_costs_to_accounts_payable function to exclude parts used in maintenance
    - Add condition to filter out costs from maintenance parts
    - Ensure only relevant costs are synced to accounts payable
    - Remove any existing accounts payable entries for parts used in maintenance

  2. Cleanup
    - Remove any existing accounts payable entries for parts used in maintenance
    - Refresh materialized view after changes
*/

-- Update the function to exclude parts used in maintenance
CREATE OR REPLACE FUNCTION fn_sync_costs_to_accounts_payable(p_tenant_id uuid)
RETURNS integer AS $$
DECLARE
  v_cost costs%ROWTYPE;
  v_count integer := 0;
BEGIN
  -- For each cost that's not already in accounts_payable and is not a part used in maintenance
  FOR v_cost IN 
    SELECT * FROM costs 
    WHERE tenant_id = p_tenant_id
      AND NOT EXISTS (
        SELECT 1 FROM accounts_payable WHERE cost_id = costs.id
      )
      -- Exclude parts used in maintenance (from service_order_parts)
      AND NOT (
        origin = 'Manutencao' 
        AND source_reference_type = 'service_note'
        AND description LIKE 'Peça utilizada:%'
      )
  LOOP
    -- Create accounts payable entry
    INSERT INTO accounts_payable (
      tenant_id,
      description,
      amount,
      due_date,
      category,
      status,
      cost_id,
      notes
    ) VALUES (
      p_tenant_id,
      v_cost.description,
      v_cost.amount,
      v_cost.cost_date + interval '15 days', -- Due date is 15 days after cost date
      CASE 
        WHEN v_cost.category = 'Multa' THEN 'Multa'
        WHEN v_cost.category = 'Funilaria' THEN 'Manutenção'
        WHEN v_cost.category = 'Seguro' THEN 'Seguro'
        WHEN v_cost.category = 'Avulsa' THEN 'Despesa Geral'
        WHEN v_cost.category = 'Compra' THEN 'Compra'
        ELSE 'Outros'
      END,
      v_cost.status,
      v_cost.id,
      'Sincronizado automaticamente do módulo de custos'
    );
    
    v_count := v_count + 1;
  END LOOP;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Remove any existing accounts payable entries for parts used in maintenance
DELETE FROM accounts_payable
WHERE cost_id IN (
  SELECT id FROM costs
  WHERE origin = 'Manutencao' 
    AND source_reference_type = 'service_note'
    AND description LIKE 'Peça utilizada:%'
);

-- Refresh the materialized view
REFRESH MATERIALIZED VIEW mv_accounts_payable_summary;

-- Log the cleanup
DO $$
DECLARE
  v_removed_count integer;
BEGIN
  GET DIAGNOSTICS v_removed_count = ROW_COUNT;
  RAISE NOTICE 'Removed % accounts payable entries for parts used in maintenance', v_removed_count;
END $$;