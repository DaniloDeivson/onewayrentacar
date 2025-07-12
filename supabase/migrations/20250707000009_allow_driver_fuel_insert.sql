DROP POLICY IF EXISTS "Drivers can insert fuel records for their vehicles" ON fuel_records;

-- Permitir que motoristas insiram registros de abastecimento para veículos vinculados
CREATE POLICY "Drivers can insert fuel records for their vehicles"
  ON fuel_records
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM driver_vehicles dv
      WHERE dv.driver_id = auth.uid()::uuid
        AND dv.vehicle_id = fuel_records.vehicle_id
        AND dv.active = true
    )
    AND tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  );

-- Opcional: permitir UPDATE/DELETE se necessário
-- Replicar lógica acima para UPDATE/DELETE se motoristas puderem editar/excluir seus abastecimentos 