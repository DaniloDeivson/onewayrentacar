import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

export type VehicleStatus = 'Aguardando Checkin' | 'Aguardando Checkout' | 'Alteração sob Análise' | 'Normal';

export function useVehicleStatusForDriver(driverId: string, vehicleId: string) {
  const [status, setStatus] = useState<VehicleStatus>('Normal');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!driverId || !vehicleId) return;
    setLoading(true);
    (async () => {
      // Verifica se há abastecimento pendente
      const { data: fuelPending } = await supabase
        .from('fuel_records')
        .select('id')
        .eq('driver_id', driverId)
        .eq('vehicle_id', vehicleId)
        .eq('status', 'Pendente')
        .maybeSingle();
      if (fuelPending) {
        setStatus('Alteração sob Análise');
        setLoading(false);
        return;
      }
      // Verifica se está aguardando checkin/checkout (exemplo: pode ser por inspeção pendente)
      // Aqui você pode customizar conforme sua regra de negócio
      // Exemplo fictício:
      const { data: inspections } = await supabase
        .from('driver_inspections')
        .select('id, inspection_type, status')
        .eq('driver_employee_id', driverId)
        .eq('vehicle_id', vehicleId)
        .order('created_at', { ascending: false })
        .limit(1);
      if (inspections && inspections.length > 0) {
        const last = inspections[0];
        if (last.inspection_type === 'checkout' && last.status === 'pending') {
          setStatus('Aguardando Checkout');
          setLoading(false);
          return;
        }
        if (last.inspection_type === 'checkin' && last.status === 'pending') {
          setStatus('Aguardando Checkin');
          setLoading(false);
          return;
        }
      }
      setStatus('Normal');
      setLoading(false);
    })();
  }, [driverId, vehicleId]);

  return { status, loading };
} 