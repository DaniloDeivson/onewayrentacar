import { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';

export interface FuelRecord {
  id: string;
  tenant_id: string;
  vehicle_id: string;
  contract_id: string | null;
  guest_id: string | null;
  driver_employee_id: string | null;
  driver_name: string;
  fuel_amount: number;
  unit_price: number;
  total_cost: number;
  mileage: number | null;
  fuel_station: string | null;
  receipt_number: string | null;
  receipt_photo_url: string | null;
  dashboard_photo_url: string | null;
  notes: string | null;
  recorded_at: string;
  status: 'Pendente' | 'Aprovado' | 'Rejeitado' | 'pending' | 'approved' | 'rejected';
  approved_by_employee_id: string | null;
  approved_at: string | null;
  cost_id: string | null;
  created_at: string;
  updated_at: string;
  vehicles?: {
    plate: string;
    model: string;
    year: number;
  };
}

export function useAllFuelRecords() {
  const [records, setRecords] = useState<FuelRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchRecords = useCallback(async () => {
    setLoading(true);
    setError(null);
    console.log('useAllFuelRecords: Fetching all fuel records');
    
    try {
      const { data, error } = await supabase
        .from('fuel_records')
        .select(`
          *,
          vehicles (
            plate,
            model,
            year
          )
        `)
        .order('recorded_at', { ascending: false });
        
      if (error) {
        console.error('useAllFuelRecords: Error fetching records:', error);
        setError(error.message);
        setRecords([]);
      } else {
        console.log('useAllFuelRecords: Records fetched:', data?.length || 0);
        setRecords(data || []);
      }
    } catch (err) {
      console.error('useAllFuelRecords: Unexpected error:', err);
      setError('Erro inesperado ao buscar registros');
      setRecords([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchRecords();
  }, [fetchRecords]);

  return { records, loading, error, refetch: fetchRecords };
} 