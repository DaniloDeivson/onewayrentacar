import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { Database } from '../types/database';
import { useAuth } from './useAuth';

type DriverVehicle = Database['public']['Tables']['driver_vehicles']['Row'];
type Vehicle = Database['public']['Tables']['vehicles']['Row'];

interface AssignedVehicle {
  vehicle_id: string;
  plate: string;
  model: string;
  year: number;
  type: string;
  status: string;
  contract_id: string | null;
  contract_number: string | null;
  assignment_date: string;
}

export function useDriverVehicles() {
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [driverVehicles, setDriverVehicles] = useState<DriverVehicle[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { user } = useAuth();

  const fetchDriverVehicles = useCallback(async () => {
    if (!user?.id) return;

    try {
      setLoading(true);
      setError(null);

      // Usar a nova função para buscar veículos atribuídos ao motorista
      const { data: assignedVehicles, error: driverError } = await supabase
        .rpc('fn_get_driver_assigned_vehicles', {
          p_driver_id: user.id
        });

      if (driverError) throw driverError;

      // Converter para o formato esperado
      const vehiclesData = (assignedVehicles as AssignedVehicle[])?.map((av: AssignedVehicle) => ({
        id: av.vehicle_id,
        plate: av.plate,
        model: av.model,
        year: av.year,
        type: av.type as 'Furgão' | 'Van',
        status: av.status as 'Disponível' | 'Em Uso' | 'Manutenção' | 'Inativo',
        // Adicionar outros campos necessários com valores padrão
        tenant_id: '',
        color: null,
        fuel: null,
        category: '',
        chassis: null,
        renavam: null,
        cargo_capacity: null,
        location: null,
        acquisition_date: null,
        acquisition_value: null,
        mileage: null,
        initial_mileage: null,
        tank_capacity: null,
        maintenance_status: 'Available' as const,
        created_at: '',
        updated_at: ''
      })) || [];

      setVehicles(vehiclesData);

      // Criar driver_vehicles records para compatibilidade
      const driverVehiclesData = (assignedVehicles as AssignedVehicle[])?.map((av: AssignedVehicle) => ({
        id: '', // Será gerado pelo banco
        driver_id: user.id,
        vehicle_id: av.vehicle_id,
        contract_id: av.contract_id,
        active: true,
        assigned_at: av.assignment_date,
        removed_at: null
      })) || [];

      setDriverVehicles(driverVehiclesData);
    } catch (err) {
      console.error('Erro ao buscar veículos do motorista:', err);
      setError(err instanceof Error ? err.message : 'Erro ao buscar veículos');
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  // CREATE - Adicionar veículo ao motorista
  const addDriverVehicle = useCallback(async (vehicleId: string) => {
    if (!user?.id) return;

    try {
      setError(null);

      const { data, error } = await supabase
        .from('driver_vehicles')
        .insert({
          driver_id: user.id,
          vehicle_id: vehicleId,
          active: true,
          assigned_at: new Date().toISOString()
        })
        .select()
        .single();

      if (error) throw error;

      // Atualizar a lista local
      setDriverVehicles(prev => [...prev, data]);
      
      // Recarregar veículos para incluir o novo
      await fetchDriverVehicles();

      return data;
    } catch (err) {
      console.error('Erro ao adicionar veículo ao motorista:', err);
      setError(err instanceof Error ? err.message : 'Erro ao adicionar veículo');
      throw err;
    }
  }, [user?.id, fetchDriverVehicles]);

  // UPDATE - Atualizar atribuição de veículo
  const updateDriverVehicle = useCallback(async (driverVehicleId: string, updates: Partial<DriverVehicle>) => {
    try {
      setError(null);

      const { data, error } = await supabase
        .from('driver_vehicles')
        .update(updates)
        .eq('id', driverVehicleId)
        .select()
        .single();

      if (error) throw error;

      // Atualizar a lista local
      setDriverVehicles(prev => 
        prev.map(dv => dv.id === driverVehicleId ? data : dv)
      );

      // Se o veículo foi desativado, recarregar a lista
      if (updates.active === false) {
        await fetchDriverVehicles();
      }

      return data;
    } catch (err) {
      console.error('Erro ao atualizar atribuição de veículo:', err);
      setError(err instanceof Error ? err.message : 'Erro ao atualizar atribuição');
      throw err;
    }
  }, [fetchDriverVehicles]);

  // DELETE - Remover veículo do motorista (soft delete)
  const removeDriverVehicle = useCallback(async (driverVehicleId: string) => {
    try {
      setError(null);

      const { error } = await supabase
        .from('driver_vehicles')
        .update({ active: false, removed_at: new Date().toISOString() })
        .eq('id', driverVehicleId);

      if (error) throw error;

      // Atualizar a lista local
      setDriverVehicles(prev => 
        prev.filter(dv => dv.id !== driverVehicleId)
      );

      // Recarregar veículos
      await fetchDriverVehicles();

      return true;
    } catch (err) {
      console.error('Erro ao remover veículo do motorista:', err);
      setError(err instanceof Error ? err.message : 'Erro ao remover veículo');
      throw err;
    }
  }, [fetchDriverVehicles]);

  // HARD DELETE - Remover permanentemente (use com cuidado)
  const deleteDriverVehicle = useCallback(async (driverVehicleId: string) => {
    try {
      setError(null);

      const { error } = await supabase
        .from('driver_vehicles')
        .delete()
        .eq('id', driverVehicleId);

      if (error) throw error;

      // Atualizar a lista local
      setDriverVehicles(prev => 
        prev.filter(dv => dv.id !== driverVehicleId)
      );

      // Recarregar veículos
      await fetchDriverVehicles();

      return true;
    } catch (err) {
      console.error('Erro ao deletar atribuição de veículo:', err);
      setError(err instanceof Error ? err.message : 'Erro ao deletar atribuição');
      throw err;
    }
  }, [fetchDriverVehicles]);

  useEffect(() => {
    fetchDriverVehicles();
  }, [fetchDriverVehicles]);

  return {
    vehicles,
    driverVehicles,
    loading,
    error,
    refetch: fetchDriverVehicles,
    addDriverVehicle,
    updateDriverVehicle,
    removeDriverVehicle,
    deleteDriverVehicle
  };
} 