import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { useAuth } from '../hooks/useAuth';
import { supabase } from '../lib/supabase';
import { Database } from '../types/database';

type Vehicle = Database['public']['Tables']['vehicles']['Row'];
type Cost = Database['public']['Tables']['costs']['Row'];
type Fine = Database['public']['Tables']['fines']['Row'];
type Inspection = Database['public']['Tables']['inspections']['Row'];

// Interfaces para os dados de entrada
interface VehicleData {
  name: string;
  model: string;
  year: number;
  license_plate: string;
  color: string;
  status: string;
  tenant_id: string;
}

interface CostData {
  vehicle_id: string;
  description: string;
  amount: number;
  date: string;
  category: string;
  tenant_id: string;
}

interface FineData {
  vehicle_id: string;
  description: string;
  amount: number;
  date: string;
  status: string;
  tenant_id: string;
}

interface InspectionData {
  vehicle_id: string;
  inspection_date: string;
  status: string;
  notes?: string;
  tenant_id: string;
}

interface DriverContextType {
  // Estado
  driverVehicles: Vehicle[];
  driverCosts: Cost[];
  driverFines: Fine[];
  driverInspections: Inspection[];
  loading: boolean;
  
  // Ações
  refreshDriverData: () => Promise<void>;
  addDriverVehicle: (vehicleData: VehicleData) => Promise<void>;
  addDriverCost: (costData: CostData) => Promise<void>;
  addDriverFine: (fineData: FineData) => Promise<void>;
  addDriverInspection: (inspectionData: InspectionData) => Promise<void>;
}

const DriverContext = createContext<DriverContextType | undefined>(undefined);

export const useDriverContext = () => {
  const context = useContext(DriverContext);
  if (!context) {
    throw new Error('useDriverContext must be used within a DriverProvider');
  }
  return context;
};

interface DriverProviderProps {
  children: React.ReactNode;
}

export const DriverProvider: React.FC<DriverProviderProps> = ({ children }) => {
  const { user, loading: authLoading } = useAuth();
  const [driverVehicles, setDriverVehicles] = useState<Vehicle[]>([]);
  const [driverCosts, setDriverCosts] = useState<Cost[]>([]);
  const [driverFines, setDriverFines] = useState<Fine[]>([]);
  const [driverInspections, setDriverInspections] = useState<Inspection[]>([]);
  const [loading, setLoading] = useState(true);

  // Verificar se o usuário é um driver ou guest
  const isDriver = user?.role === 'Driver' || user?.role === 'Guest';

  // Função para buscar veículos do driver
  const fetchDriverVehicles = async () => {
    if (!user?.id || !isDriver) return [];

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

  // Função para buscar custos dos veículos do driver
  const fetchDriverCosts = async (vehicleIds: string[]) => {
    if (!user?.id || !isDriver || vehicleIds.length === 0) return [];

    try {
      const { data, error } = await supabase
        .from('costs')
        .select('*')
        .in('vehicle_id', vehicleIds)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Erro ao buscar custos do driver:', error);
      return [];
    }
  };

  // Função para buscar multas dos veículos do driver
  const fetchDriverFines = async (vehicleIds: string[]) => {
    if (!user?.id || !isDriver || vehicleIds.length === 0) return [];

    try {
      const { data, error } = await supabase
        .from('fines')
        .select('*')
        .in('vehicle_id', vehicleIds)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Erro ao buscar multas do driver:', error);
      return [];
    }
  };

  // Função para buscar inspeções dos veículos do driver
  const fetchDriverInspections = async (vehicleIds: string[]) => {
    if (!user?.id || !isDriver || vehicleIds.length === 0) return [];

    try {
      const { data, error } = await supabase
        .from('inspections')
        .select('*')
        .in('vehicle_id', vehicleIds)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Erro ao buscar inspeções do driver:', error);
      return [];
    }
  };

  // Função principal para atualizar todos os dados
  const refreshDriverData = useCallback(async () => {
    if (!user?.id || !isDriver) {
      setDriverVehicles([]);
      setDriverCosts([]);
      setDriverFines([]);
      setDriverInspections([]);
      setLoading(false);
      return;
    }

    setLoading(true);
    try {
      // 1. Buscar veículos
      const vehicles = await fetchDriverVehicles();
      setDriverVehicles(vehicles);

      // 2. Se há veículos, buscar dados relacionados
      if (vehicles.length > 0) {
        const vehicleIds = vehicles.map(v => v.id);
        
        const [costs, fines, inspections] = await Promise.all([
          fetchDriverCosts(vehicleIds),
          fetchDriverFines(vehicleIds),
          fetchDriverInspections(vehicleIds)
        ]);

        setDriverCosts(costs);
        setDriverFines(fines);
        setDriverInspections(inspections);
      } else {
        setDriverCosts([]);
        setDriverFines([]);
        setDriverInspections([]);
      }
    } catch (error) {
      console.error('Erro ao atualizar dados do driver:', error);
    } finally {
      setLoading(false);
    }
  }, [user?.id, isDriver]);

  // useEffect deve vir antes de qualquer early return
  useEffect(() => {
    if (user?.id && isDriver) {
      refreshDriverData();
    }
  }, [user?.id, isDriver, refreshDriverData]);

  // Se ainda está carregando ou não é um driver, mostrar loading
  if (authLoading || !user || !isDriver) {
    return <div className="flex items-center justify-center min-h-screen">Carregando...</div>;
  }

  // Funções para adicionar novos dados
  const addDriverVehicle = async (vehicleData: VehicleData) => {
    if (!user?.id || !isDriver) throw new Error('Usuário não é um driver');

    try {
      // 1. Criar o veículo
      const { data: vehicle, error: vehicleError } = await supabase
        .from('vehicles')
        .insert([{ ...vehicleData, tenant_id: user.tenant_id }])
        .select()
        .single();

      if (vehicleError) throw vehicleError;

      // 2. Associar o veículo ao driver
      const { error: associationError } = await supabase
        .from('driver_vehicles')
        .insert([{
          driver_id: user.id,
          vehicle_id: vehicle.id,
          active: true
        }]);

      if (associationError) throw associationError;

      // 3. Atualizar estado local
      setDriverVehicles(prev => [vehicle, ...prev]);
    } catch (error) {
      console.error('Erro ao adicionar veículo:', error);
      throw error;
    }
  };

  const addDriverCost = async (costData: CostData) => {
    if (!user?.id || !isDriver) throw new Error('Usuário não é um driver');

    try {
      const { data, error } = await supabase
        .from('costs')
        .insert([{ ...costData, tenant_id: user.tenant_id }])
        .select()
        .single();

      if (error) throw error;

      setDriverCosts(prev => [data, ...prev]);
    } catch (error) {
      console.error('Erro ao adicionar custo:', error);
      throw error;
    }
  };

  const addDriverFine = async (fineData: FineData) => {
    if (!user?.id || !isDriver) throw new Error('Usuário não é um driver');

    try {
      const { data, error } = await supabase
        .from('fines')
        .insert([{ ...fineData, tenant_id: user.tenant_id, employee_id: user.id }])
        .select()
        .single();

      if (error) throw error;

      setDriverFines(prev => [data, ...prev]);
    } catch (error) {
      console.error('Erro ao adicionar multa:', error);
      throw error;
    }
  };

  const addDriverInspection = async (inspectionData: InspectionData) => {
    if (!user?.id || !isDriver) throw new Error('Usuário não é um driver');

    try {
      const { data, error } = await supabase
        .from('inspections')
        .insert([{ ...inspectionData, tenant_id: user.tenant_id, employee_id: user.id }])
        .select()
        .single();

      if (error) throw error;

      setDriverInspections(prev => [data, ...prev]);
    } catch (error) {
      console.error('Erro ao adicionar inspeção:', error);
      throw error;
    }
  };

  const value: DriverContextType = {
    driverVehicles,
    driverCosts,
    driverFines,
    driverInspections,
    loading,
    refreshDriverData,
    addDriverVehicle,
    addDriverCost,
    addDriverFine,
    addDriverInspection
  };

  return (
    <DriverContext.Provider value={value}>
      {children}
    </DriverContext.Provider>
  );
}; 