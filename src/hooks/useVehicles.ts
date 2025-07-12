import { useState, useEffect, useRef } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import { Database } from '../types/database';
import toast from 'react-hot-toast';
import { useAuth } from './useAuth';

type Vehicle = Database['public']['Tables']['vehicles']['Row'];
type VehicleInsert = Database['public']['Tables']['vehicles']['Insert'];
type VehicleUpdate = Database['public']['Tables']['vehicles']['Update'];

interface VehicleWithMileage extends Omit<Vehicle, 'mileage'> {
  mileage: number;
  total_mileage: number;
  initial_mileage: number;
  current_fuel_level?: number;
}

export const useVehicles = () => {
  const [vehicles, setVehicles] = useState<VehicleWithMileage[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { user } = useAuth();

  const debounceTimeout = useRef<NodeJS.Timeout | null>(null);

  // Verificar se é driver para usar lógica específica
  const isDriver = user?.role === 'Driver';

  // Função para calcular a quilometragem total de um veículo
  const calculateTotalMileage = async (vehicleId: string): Promise<number> => {
    try {
      // Usar a função SQL que considera veículo, inspeções e ordens de serviço
      const { data, error } = await supabase
        .rpc('fn_calculate_vehicle_total_mileage', { p_vehicle_id: vehicleId });

      if (error) throw error;

      return data || 0;
    } catch (err) {
      console.error('Erro ao calcular quilometragem total:', err);
      // Fallback para o cálculo manual se a função SQL falhar
      try {
        const { data: vehicleData } = await supabase
          .from('vehicles')
          .select('mileage')
          .eq('id', vehicleId)
          .single();

        return vehicleData?.mileage || 0;
      } catch {
        return 0;
      }
    }
  };

  function isValidDate(date: string) {
    const d = new Date(date);
    return d instanceof Date && !isNaN(d.getTime()) && d.getFullYear() >= 2023;
  }

  function isValidDateString(dateStr: string) {
    // Aceita apenas datas no formato yyyy-mm-dd
    if (!dateStr || typeof dateStr !== 'string') return false;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) return false;
    const date = new Date(dateStr);
    return (
      date instanceof Date &&
      !isNaN(date.getTime()) &&
      date.getFullYear() >= 2023
    );
  }

  // Função específica para buscar veículos do driver
  const fetchDriverVehicles = async () => {
    if (!user?.id) return [];

    try {
      // Buscar veículos associados ao driver
      const { data: driverVehicleAssociations, error: associationError } = await supabase
        .from('driver_vehicles')
        .select('vehicle_id')
        .eq('driver_id', user.id)
        .eq('active', true);

      if (associationError) throw associationError;

      if (!driverVehicleAssociations || driverVehicleAssociations.length === 0) {
        return [];
      }

      const vehicleIds = driverVehicleAssociations.map(assoc => assoc.vehicle_id);

      // Buscar dados completos dos veículos
      const { data: vehicles, error: vehiclesError } = await supabase
        .from('vehicles')
        .select('*')
        .in('id', vehicleIds)
        .order('created_at', { ascending: false });

      if (vehiclesError) throw vehiclesError;

      return vehicles || [];
    } catch (error) {
      console.error('Erro ao buscar veículos do driver:', error);
      return [];
    }
  };

  const fetchVehicles = async (startDate?: string, endDate?: string) => {
    if (startDate && endDate) {
      if (!isValidDate(startDate) || !isValidDate(endDate) || new Date(startDate) >= new Date(endDate)) {
        toast.error('Datas inválidas. Verifique o período do contrato.');
        setVehicles([]);
        setLoading(false);
        return;
      }
    }
    try {
      setLoading(true);

      let vehiclesData;
      let vehiclesError;

      // Se for motorista, usar função específica para drivers
      if (isDriver) {
        vehiclesData = await fetchDriverVehicles();
        vehiclesError = null;
      } else {
        // Para outros papéis (admin, etc), mostrar todos os veículos do tenant
        // Incluir veículos 'Em Uso' e 'Manutenção' para visualização completa da frota
        const result = await supabase
          .from('vehicles')
          .select('*')
          .eq('tenant_id', DEFAULT_TENANT_ID)
          .in('status', ['Disponível', 'Em Uso', 'Manutenção', 'No Patio']) // Agora inclui veículos No Patio
          .order('created_at', { ascending: false });
        vehiclesData = result.data;
        vehiclesError = result.error;
      }

      if (vehiclesError) throw vehiclesError;

      // Calcular quilometragem total para cada veículo
      const vehiclesWithMileage = await Promise.all(
        (vehiclesData || []).map(async (vehicle: Vehicle) => {
          const totalMileage = await calculateTotalMileage(vehicle.id);
          return {
            ...vehicle,
            mileage: vehicle.mileage || 0,
            total_mileage: totalMileage,
            initial_mileage: Number(vehicle.initial_mileage) || 0,
            current_fuel_level: vehicle.current_fuel_level || 0
          } as VehicleWithMileage;
        })
      );

      setVehicles(vehiclesWithMileage);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Erro ao carregar veículos';
      setError(message);
      toast.error(message);
    } finally {
      setLoading(false);
    }
  };

  const fetchVehiclesDebounced = (startDate?: string, endDate?: string) => {
    if (debounceTimeout.current) clearTimeout(debounceTimeout.current);
    debounceTimeout.current = setTimeout(() => {
      if (startDate && endDate) {
        if (!isValidDateString(startDate) || !isValidDateString(endDate) || new Date(startDate) >= new Date(endDate)) {
          // Não mostrar erro se o campo está incompleto
          setVehicles([]);
          setLoading(false);
          return;
        }
        fetchVehicles(startDate, endDate);
      }
    }, 500);
  };

  const createVehicle = async (vehicleData: Omit<VehicleInsert, 'tenant_id'>) => {
    try {
      // Se vehicleData contém tenant_id, usar ele; senão usar DEFAULT_TENANT_ID
      const tenantId = ('tenant_id' in vehicleData ? vehicleData.tenant_id : null) || DEFAULT_TENANT_ID;
      
      const { data: existingVehicle, error: checkError } = await supabase
        .from('vehicles')
        .select('plate')
        .eq('plate', vehicleData.plate)
        .eq('tenant_id', tenantId)
        .limit(1);

      if (checkError) {
        throw checkError;
      }

      if (existingVehicle && existingVehicle.length > 0) {
        throw new Error(`A vehicle with plate ${vehicleData.plate} already exists.`);
      }

      const { data, error } = await supabase
        .from('vehicles')
        .insert([{ ...vehicleData, tenant_id: tenantId }])
        .select()
        .single();

      if (error) throw error;

      // Se for driver, associar automaticamente o veículo
      if (isDriver && user?.id) {
        await supabase
          .from('driver_vehicles')
          .insert([{
            driver_id: user.id,
            vehicle_id: data.id,
            active: true
          }]);
      }

      setVehicles(prev => [data, ...prev]);
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to create vehicle');
    }
  };

  const updateVehicle = async (id: string, updates: VehicleUpdate) => {
    try {
      // Limpar campos undefined/null para evitar problemas
      const cleanUpdates = Object.fromEntries(
        Object.entries(updates).filter(([, value]) => value !== undefined)
      );

      const { data, error } = await supabase
        .from('vehicles')
        .update({ ...cleanUpdates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single();

      if (error) {
        throw error;
      }

      // Calcular nova quilometragem total
      const totalMileage = await calculateTotalMileage(id);
      
      // Atualizar o estado local
      setVehicles(prev => prev.map(v => {
        if (v.id === id) {
          return {
            ...data,
            mileage: data.mileage || 0,
            total_mileage: totalMileage,
            initial_mileage: Number(data.initial_mileage) || 0
          } as VehicleWithMileage;
        }
        return v;
      }));

      return data;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Erro ao atualizar veículo';
      toast.error(`Erro ao atualizar veículo: ${message}`);
      throw new Error(message);
    }
  };

  const deleteVehicle = async (id: string) => {
    try {
      const { error } = await supabase
        .from('vehicles')
        .delete()
        .eq('id', id);

      if (error) throw error;

      setVehicles(prev => prev.filter(vehicle => vehicle.id !== id));
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Erro ao deletar veículo';
      toast.error(message);
      throw new Error(message);
    }
  };

  // Adicionar um método para atualizar a quilometragem total de um veículo específico
  const refreshVehicleMileage = async (vehicleId: string) => {
    try {
      const totalMileage = await calculateTotalMileage(vehicleId);
      setVehicles(prev => prev.map(v => {
        if (v.id === vehicleId) {
          return { ...v, total_mileage: totalMileage };
        }
        return v;
      }));
    } catch (err) {
      console.error('Erro ao atualizar quilometragem do veículo:', err);
    }
  };

  // Função para forçar refresh dos dados
  const refresh = async () => {
    await fetchVehicles();
  };

  useEffect(() => {
    fetchVehicles();

    // Listen for vehicle mileage updates from maintenance check-outs
    const handleMileageUpdate = (event: CustomEvent) => {
      const { vehicleId } = event.detail;
      if (vehicleId) {
        // Refetch vehicles data or just refresh the specific vehicle
        setTimeout(() => {
          fetchVehicles();
        }, 500); // Small delay to ensure database is updated
      }
    };

    window.addEventListener('vehicle-mileage-updated', handleMileageUpdate as EventListener);

    return () => {
      window.removeEventListener('vehicle-mileage-updated', handleMileageUpdate as EventListener);
    };
  }, [user, isDriver]); // Adicionar dependências

  return {
    vehicles,
    loading,
    error,
    fetchVehicles,
    fetchVehiclesDebounced,
    createVehicle,
    updateVehicle,
    deleteVehicle,
    refreshVehicleMileage,
    refresh,
    isDriver // Expor se é driver
  };
};