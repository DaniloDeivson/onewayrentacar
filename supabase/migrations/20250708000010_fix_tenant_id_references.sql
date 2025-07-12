-- Fix tenant_id references in tables that don't have this field
-- This migration corrects triggers, functions, and policies that incorrectly reference tenant_id

-- 1. Fix inspection_items trigger that incorrectly references tenant_id
-- The table inspection_items does NOT have tenant_id field, so we need to fix the trigger

-- Drop the problematic trigger first
DROP TRIGGER IF EXISTS trg_inspection_items_auto_service_order ON inspection_items;

-- Recreate the function to NOT reference NEW.tenant_id
CREATE OR REPLACE FUNCTION fn_auto_create_damage_service_order()
RETURNS TRIGGER AS $$
DECLARE
  v_inspection_record RECORD;
  v_service_note_id uuid;
  v_maintenance_type_id uuid;
BEGIN
  -- Só cria OS para CheckOut com danos que requerem reparo
  IF NEW.requires_repair = false THEN
    RETURN NEW;
  END IF;

  -- Busca informações da inspeção (incluindo tenant_id da tabela inspections)
  SELECT i.*, v.plate, v.model
  INTO v_inspection_record
  FROM inspections i
  JOIN vehicles v ON v.id = i.vehicle_id
  WHERE i.id = NEW.inspection_id;

  -- Só processa CheckOut (danos novos)
  IF v_inspection_record.inspection_type != 'CheckOut' THEN
    RETURN NEW;
  END IF;

  -- Busca ou cria tipo de manutenção "Funilaria"
  SELECT id INTO v_maintenance_type_id
  FROM maintenance_types
  WHERE tenant_id = v_inspection_record.tenant_id
    AND name = 'Funilaria'
  LIMIT 1;

  -- Se não existe, cria o tipo de manutenção
  IF v_maintenance_type_id IS NULL THEN
    INSERT INTO maintenance_types (tenant_id, name)
    VALUES (v_inspection_record.tenant_id, 'Funilaria')
    RETURNING id INTO v_maintenance_type_id;
  END IF;

  -- Cria ordem de serviço automaticamente
  INSERT INTO service_notes (
    tenant_id,
    vehicle_id,
    maintenance_type,
    start_date,
    mechanic,
    priority,
    description,
    observations,
    status,
    created_at
  )
  VALUES (
    v_inspection_record.tenant_id,
    v_inspection_record.vehicle_id,
    'Funilaria',
    CURRENT_DATE,
    'A definir', -- Será atribuído posteriormente
    CASE 
      WHEN NEW.severity = 'Alta' THEN 'Alta'
      WHEN NEW.severity = 'Média' THEN 'Média'
      ELSE 'Baixa'
    END,
    CONCAT('Reparo de dano detectado em inspeção - ', NEW.location, ': ', NEW.damage_type),
    CONCAT('Dano detectado em ', v_inspection_record.inspected_at::date, ' por ', v_inspection_record.inspected_by, '. Descrição: ', NEW.description),
    'Aberta',
    now()
  )
  RETURNING id INTO v_service_note_id;

  -- Cria custo estimado se fornecido
  IF NEW.cost_estimate IS NOT NULL AND NEW.cost_estimate > 0 THEN
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
      created_at
    )
    VALUES (
      v_inspection_record.tenant_id,
      'Funilaria',
      v_inspection_record.vehicle_id,
      CONCAT('Estimativa de reparo - ', NEW.location, ' (', NEW.damage_type, ')'),
      NEW.cost_estimate,
      CURRENT_DATE,
      'Pendente',
      CONCAT('INSP-', NEW.inspection_id, '-OS-', v_service_note_id),
      CONCAT('Custo estimado baseado em inspeção. Severidade: ', NEW.severity),
      now()
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
CREATE TRIGGER trg_inspection_items_auto_service_order
  AFTER INSERT ON inspection_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_create_damage_service_order();

-- 2. Fix any other triggers that might reference tenant_id incorrectly
-- Check for triggers on inspection_items that might be problematic
DO $$
DECLARE
  trigger_record RECORD;
BEGIN
  FOR trigger_record IN 
    SELECT trigger_name 
    FROM information_schema.triggers 
    WHERE event_object_table = 'inspection_items'
  LOOP
    -- Log the trigger for debugging
    RAISE NOTICE 'Found trigger on inspection_items: %', trigger_record.trigger_name;
  END LOOP;
END $$;

-- 3. Ensure RLS policies are correct for inspection_items
-- Drop and recreate policies to ensure they don't reference tenant_id directly
DROP POLICY IF EXISTS "Allow all operations for default tenant on inspection_items" ON inspection_items;
CREATE POLICY "Allow all operations for default tenant on inspection_items"
  ON inspection_items
  FOR ALL
  TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM inspections i
    WHERE i.id = inspection_items.inspection_id
      AND i.tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM inspections i
    WHERE i.id = inspection_items.inspection_id
      AND i.tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  ));

DROP POLICY IF EXISTS "Users can manage their tenant inspection items" ON inspection_items;
CREATE POLICY "Users can manage their tenant inspection items"
  ON inspection_items
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM inspections i
    WHERE i.id = inspection_items.inspection_id
      AND i.tenant_id IN (
        SELECT tenants.id
        FROM tenants
        WHERE auth.uid() IS NOT NULL
      )
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM inspections i
    WHERE i.id = inspection_items.inspection_id
      AND i.tenant_id IN (
        SELECT tenants.id
        FROM tenants
        WHERE auth.uid() IS NOT NULL
      )
  ));

-- 4. Add a comment to prevent future issues
COMMENT ON TABLE inspection_items IS 'Table for inspection items. IMPORTANT: This table does NOT have tenant_id field. Always join with inspections table to check tenant_id.'; 