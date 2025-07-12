import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import toast from 'react-hot-toast';

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
  status: 'pending' | 'approved' | 'rejected';
  approved_by_employee_id: string | null;
  approved_at: string | null;
  cost_id: string | null;
  created_at: string;
  updated_at: string;
  // Relacionamentos
  vehicles?: {
    plate: string;
    model: string;
    year: number;
  };
  contracts?: {
    id: string;
    contract_number: string;
    customers?: {
      id: string;
      name: string;
    };
  };
  costs?: {
    id: string;
    customer_name: string;
    status: string;
  };
}

export interface FuelRecordInsert {
  vehicle_id: string;
  contract_id?: string | null;
  guest_id?: string | null;
  driver_employee_id?: string | null;
  driver_name: string;
  fuel_amount: number;
  unit_price: number;
  total_cost: number;
  mileage?: number | null;
  fuel_station?: string | null;
  receipt_number?: string | null;
  receipt_photo_url?: string | null;
  dashboard_photo_url?: string | null;
  notes?: string | null;
  recorded_at?: string;
  status?: 'pending' | 'approved' | 'rejected';
}

export const useFuelRecords = () => {
  const [fuelRecords, setFuelRecords] = useState<FuelRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchFuelRecords = async () => {
    try {
      setLoading(true);
      
      // Try to use the detailed view first, fallback to direct query
      let { data, error } = await supabase
        .from('vw_fuel_records_detailed')
        .select('*')
        .order('recorded_at', { ascending: false });

      // If view doesn't exist, query directly
      if (error || !data) {
        const { data: directData, error: directError } = await supabase
          .from('fuel_records')
          .select(`
            *,
            vehicles (
              plate,
              model,
              year
            ),
            contracts (
              id,
              contract_number,
              customers (
                id,
                name
              )
            ),
            costs (
              id,
              customer_name,
              status
            )
          `)
          .order('recorded_at', { ascending: false });

        if (directError) throw directError;
        data = directData;
        error = null;
      }

      if (error) throw error;
      setFuelRecords(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao carregar registros de abastecimento');
    } finally {
      setLoading(false);
    }
  };

  const createFuelRecord = async (fuelData: FuelRecordInsert) => {
    try {
      console.log('Creating fuel record with data:', fuelData);
      
      const { data, error } = await supabase
        .from('fuel_records')
        .insert([{ 
          ...fuelData, 
          tenant_id: DEFAULT_TENANT_ID,
          recorded_at: fuelData.recorded_at || new Date().toISOString()
        }])
        .select(`
          *,
          vehicles (
            plate,
            model,
            year
          ),
          contracts (
            id,
            contract_number,
            customers (
              id,
              name
            )
          ),
          costs (
            id,
            customer_name,
            status
          )
        `)
        .single();

      if (error) {
        console.error('Error creating fuel record:', error);
        throw error;
      }

      console.log('Fuel record created successfully:', data);
      
      // Refresh the fuel records list
      await fetchFuelRecords();
      
      toast.success('Registro de abastecimento criado com sucesso!');
      return data;
    } catch (err) {
      console.error('Error in createFuelRecord:', err);
      
      // More detailed error handling
      if (err && typeof err === 'object' && 'message' in err) {
        const errorMessage = (err as { message: string }).message;
        if (errorMessage.includes('foreign key')) {
          toast.error('Erro: Veículo não encontrado.');
        } else if (errorMessage.includes('check constraint')) {
          toast.error('Erro: Dados inválidos. Verifique os valores inseridos.');
        } else if (errorMessage.includes('not null')) {
          toast.error('Erro: Campos obrigatórios não preenchidos.');
        } else {
          toast.error('Erro ao criar registro de abastecimento: ' + errorMessage);
        }
      } else {
        toast.error('Erro ao criar registro de abastecimento: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      }
      
      throw new Error(err instanceof Error ? err.message : 'Failed to create fuel record');
    }
  };

  const updateFuelRecord = async (id: string, updates: Partial<FuelRecordInsert>) => {
    try {
      const { data, error } = await supabase
        .from('fuel_records')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select(`
          *,
          vehicles (
            plate,
            model,
            year
          ),
          contracts (
            id,
            contract_number,
            customers (
              id,
              name
            )
          ),
          costs (
            id,
            customer_name,
            status
          )
        `)
        .single();

      if (error) throw error;
      await fetchFuelRecords();
      toast.success('Registro de abastecimento atualizado com sucesso!');
      return data;
    } catch (err) {
      toast.error('Erro ao atualizar registro de abastecimento: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to update fuel record');
    }
  };

  const deleteFuelRecord = async (id: string) => {
    try {
      const { error } = await supabase
        .from('fuel_records')
        .delete()
        .eq('id', id);

      if (error) throw error;
      await fetchFuelRecords();
      toast.success('Registro de abastecimento excluído com sucesso!');
    } catch (err) {
      toast.error('Erro ao excluir registro de abastecimento: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to delete fuel record');
    }
  };

  const approveFuelRecord = async (id: string, approvedBy: string) => {
    try {
      const { data, error } = await supabase
        .from('fuel_records')
        .update({ 
          status: 'approved',
          approved_by_employee_id: approvedBy,
          approved_at: new Date().toISOString()
        })
        .eq('id', id)
        .select(`
          *,
          vehicles (
            plate,
            model,
            year
          ),
          contracts (
            id,
            contract_number,
            customers (
              id,
              name
            )
          ),
          costs (
            id,
            customer_name,
            status
          )
        `)
        .single();

      if (error) throw error;
      await fetchFuelRecords();
      toast.success('Registro de abastecimento aprovado com sucesso!');
      return data;
    } catch (err) {
      toast.error('Erro ao aprovar registro de abastecimento: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to approve fuel record');
    }
  };

  const rejectFuelRecord = async (id: string, rejectedBy: string) => {
    try {
      const { data, error } = await supabase
        .from('fuel_records')
        .update({ 
          status: 'rejected',
          approved_by_employee_id: rejectedBy,
          approved_at: new Date().toISOString()
        })
        .eq('id', id)
        .select(`
          *,
          vehicles (
            plate,
            model,
            year
          ),
          contracts (
            id,
            contract_number,
            customers (
              id,
              name
            )
          ),
          costs (
            id,
            customer_name,
            status
          )
        `)
        .single();

      if (error) throw error;
      await fetchFuelRecords();
      toast.success('Registro de abastecimento rejeitado com sucesso!');
      return data;
    } catch (err) {
      toast.error('Erro ao rejeitar registro de abastecimento: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to reject fuel record');
    }
  };

  const getFuelRecordsByGuest = async (guestId: string) => {
    try {
      const { data, error } = await supabase
        .from('vw_fuel_records_detailed')
        .select('*')
        .eq('guest_id', guestId)
        .order('recorded_at', { ascending: false });

      if (error) throw error;
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao buscar registros do guest');
    }
  };

  const getFuelRecordsByVehicle = async (vehicleId: string) => {
    try {
      const { data, error } = await supabase
        .from('vw_fuel_records_detailed')
        .select('*')
        .eq('vehicle_id', vehicleId)
        .order('recorded_at', { ascending: false });

      if (error) throw error;
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao buscar registros do veículo');
    }
  };

  // Função para verificar se um registro de combustível tem custo associado
  const checkFuelRecordCost = async (fuelRecordId: string) => {
    try {
      const { data, error } = await supabase
        .from('costs')
        .select('*')
        .eq('source_reference_type', 'fuel_record')
        .eq('source_reference_id', fuelRecordId)
        .single();

      if (error && error.code !== 'PGRST116') throw error;
      return data;
    } catch (err) {
      console.error('Error checking fuel record cost:', err);
      return null;
    }
  };

  useEffect(() => {
    fetchFuelRecords();
  }, []);

  return {
    fuelRecords,
    loading,
    error,
    createFuelRecord,
    updateFuelRecord,
    deleteFuelRecord,
    approveFuelRecord,
    rejectFuelRecord,
    getFuelRecordsByGuest,
    getFuelRecordsByVehicle,
    checkFuelRecordCost,
    refetch: fetchFuelRecords
  };
}; 