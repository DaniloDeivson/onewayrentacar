DROP POLICY IF EXISTS "Drivers can insert pending fuel records" ON fuel_records;
CREATE POLICY "Drivers can insert pending fuel records"
  ON fuel_records
  FOR INSERT
  TO authenticated
  WITH CHECK (
    status = 'Pendente'
    AND EXISTS (
      SELECT 1 FROM driver_vehicles dv
      WHERE dv.driver_id = auth.uid()::uuid
        AND dv.vehicle_id = fuel_records.vehicle_id
        AND dv.active = true
    )
    AND tenant_id = '00000000-0000-0000-0000-000000000001'::uuid
  ); 