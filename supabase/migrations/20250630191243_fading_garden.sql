-- Create a function to increment part quantity safely
CREATE OR REPLACE FUNCTION increment_part_quantity(p_part_id uuid, p_quantity integer)
RETURNS void AS $$
BEGIN
  UPDATE parts
  SET 
    quantity = quantity + p_quantity,
    updated_at = now()
  WHERE id = p_part_id;
END;
$$ LANGUAGE plpgsql;

-- Fix the stock movement trigger to properly update part quantities
CREATE OR REPLACE FUNCTION handle_service_order_parts()
RETURNS TRIGGER AS $$
DECLARE
  v_part_name TEXT;
  v_part_quantity INTEGER;
  v_vehicle_id UUID;
BEGIN
  -- Get part information
  SELECT name, quantity INTO v_part_name, v_part_quantity
  FROM parts 
  WHERE id = NEW.part_id;

  -- Get service order vehicle information
  SELECT vehicle_id INTO v_vehicle_id
  FROM service_notes 
  WHERE id = NEW.service_note_id;

  -- Check if we have enough stock
  IF v_part_quantity < NEW.quantity_used THEN
    RAISE EXCEPTION 'Insufficient stock for part %. Available: %, Required: %', 
      v_part_name, v_part_quantity, NEW.quantity_used;
  END IF;

  -- Update parts quantity
  PERFORM increment_part_quantity(NEW.part_id, -NEW.quantity_used);

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

  -- Create cost record
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
  ) VALUES (
    NEW.tenant_id,
    'Avulsa',
    v_vehicle_id,
    CONCAT('Peça utilizada: ', v_part_name, ' (Qtde: ', NEW.quantity_used, ')'),
    NEW.total_cost,
    CURRENT_DATE,
    'Pendente',
    CONCAT('OS-', NEW.service_note_id),
    CONCAT('Lançamento automático via Ordem de Serviço'),
    now()
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix the reverse function to properly return parts to stock
CREATE OR REPLACE FUNCTION reverse_service_order_parts()
RETURNS TRIGGER AS $$
BEGIN
  -- Return parts to stock
  PERFORM increment_part_quantity(OLD.part_id, OLD.quantity_used);

  -- Create reverse stock movement
  INSERT INTO stock_movements (
    tenant_id,
    part_id,
    service_note_id,
    type,
    quantity,
    movement_date,
    created_at
  ) VALUES (
    OLD.tenant_id,
    OLD.part_id,
    OLD.service_note_id,
    'Entrada',
    OLD.quantity_used,
    CURRENT_DATE,
    now()
  );

  -- Note: We don't automatically delete the cost record as it may need manual review
  -- But we could mark it as "Cancelled" or similar

  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix the maintenance check-in/check-out integration with vehicle status
CREATE OR REPLACE FUNCTION fn_sync_vehicle_maintenance_status()
RETURNS TRIGGER AS $$
DECLARE
  v_vehicle_id uuid;
  v_new_status text;
  v_maintenance_status text;
BEGIN
  -- Buscar o vehicle_id através da service_note
  SELECT sn.vehicle_id INTO v_vehicle_id
  FROM service_notes sn
  WHERE sn.id = COALESCE(NEW.service_note_id, OLD.service_note_id);

  IF v_vehicle_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Determinar novo status baseado na operação
  IF (TG_OP = 'INSERT') THEN
    -- Check-in: veículo vai para manutenção
    v_maintenance_status := 'In_Maintenance';
    v_new_status := 'Manutenção';
  ELSIF (TG_OP = 'UPDATE' AND NEW.checkout_at IS NOT NULL AND OLD.checkout_at IS NULL) THEN
    -- Check-out: veículo volta a ficar disponível
    v_maintenance_status := 'Available';
    v_new_status := 'Disponível';
  ELSIF (TG_OP = 'DELETE') THEN
    -- Se deletar check-in, verificar se há outros check-ins ativos
    IF EXISTS (
      SELECT 1 FROM maintenance_checkins mc
      JOIN service_notes sn ON sn.id = mc.service_note_id
      WHERE sn.vehicle_id = v_vehicle_id 
        AND mc.checkout_at IS NULL
        AND mc.id != OLD.id
    ) THEN
      v_maintenance_status := 'In_Maintenance';
      v_new_status := 'Manutenção';
    ELSE
      v_maintenance_status := 'Available';
      v_new_status := 'Disponível';
    END IF;
  ELSE
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Atualizar status do veículo
  UPDATE vehicles
  SET 
    maintenance_status = v_maintenance_status,
    status = v_new_status,
    updated_at = now()
  WHERE id = v_vehicle_id;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;