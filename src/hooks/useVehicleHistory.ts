import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

export interface VehicleHistoryEvent {
  id: string;
  vehicle_id: string;
  plate: string;
  model: string;
  event_type: 'cost' | 'maintenance' | 'inspection' | 'contract' | 'fuel' | 'accident' | 'status_change' | 'damage' | 'fine';
  event_date: string;
  description: string;
  amount: number | null;
  vehicle_status: string | null;
  mileage: number | null;
  notes: string | null;
  created_by: string | null;
  created_at: string;
}

export interface VehicleHistoryFilters {
  vehicle_id?: string;
  event_type?: string;
  start_date?: string;
  end_date?: string;
  min_amount?: number;
  max_amount?: number;
}

export const useVehicleHistory = () => {
  const [vehicleHistory, setVehicleHistory] = useState<VehicleHistoryEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchVehicleHistory = async (filters: VehicleHistoryFilters = {}) => {
    try {
      setLoading(true);
      let query = supabase
        .from('vw_vehicle_complete_history')
        .select('*');

      // Aplicar filtros
      if (filters.vehicle_id) {
        query = query.eq('vehicle_id', filters.vehicle_id);
      }
      if (filters.event_type) {
        query = query.eq('event_type', filters.event_type);
      }
      if (filters.start_date) {
        query = query.gte('event_date', filters.start_date);
      }
      if (filters.end_date) {
        query = query.lte('event_date', filters.end_date);
      }
      if (filters.min_amount) {
        query = query.gte('amount', filters.min_amount);
      }
      if (filters.max_amount) {
        query = query.lte('amount', filters.max_amount);
      }

      const { data, error } = await query.order('event_date', { ascending: false });

      if (error) throw error;
      setVehicleHistory(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao carregar histórico do veículo');
    } finally {
      setLoading(false);
    }
  };

  const getVehicleHistoryByVehicle = async (vehicleId: string) => {
    try {
      const { data, error } = await supabase
        .from('vw_vehicle_complete_history')
        .select('*')
        .eq('vehicle_id', vehicleId)
        .order('event_date', { ascending: false });

      if (error) throw error;
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao buscar histórico do veículo');
    }
  };

  const getVehicleHistoryStats = async (vehicleId: string) => {
    try {
      const { data, error } = await supabase
        .from('vw_vehicle_complete_history')
        .select('event_type, amount')
        .eq('vehicle_id', vehicleId)
        .not('amount', 'is', null);

      if (error) throw error;

      // Calcular estatísticas
      const stats = data.reduce((acc, event) => {
        const type = event.event_type;
        if (!acc[type]) {
          acc[type] = { total: 0, count: 0 };
        }
        acc[type].total += event.amount || 0;
        acc[type].count += 1;
        return acc;
      }, {} as Record<string, { total: number; count: number }>);

      return stats;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao calcular estatísticas do veículo');
    }
  };

  const getVehicleTimelineData = async (vehicleId: string) => {
    try {
      const { data, error } = await supabase
        .from('vw_vehicle_complete_history')
        .select('*')
        .eq('vehicle_id', vehicleId)
        .order('event_date', { ascending: true });

      if (error) throw error;

      // Agrupar por mês para timeline
      const timeline = data.reduce((acc, event) => {
        const monthKey = event.event_date.substring(0, 7); // YYYY-MM
        if (!acc[monthKey]) {
          acc[monthKey] = {
            month: monthKey,
            events: [],
            total_amount: 0,
            events_count: 0
          };
        }
        acc[monthKey].events.push(event);
        acc[monthKey].total_amount += event.amount || 0;
        acc[monthKey].events_count += 1;
        return acc;
      }, {} as Record<string, { month: string; events: VehicleHistoryEvent[]; total_amount: number; events_count: number }>);

      return Object.values(timeline);
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao gerar timeline do veículo');
    }
  };

  const getEventTypeSummary = async (vehicleId?: string) => {
    try {
      let query = supabase
        .from('vw_vehicle_complete_history')
        .select('event_type, amount');

      if (vehicleId) {
        query = query.eq('vehicle_id', vehicleId);
      }

      const { data, error } = await query;

      if (error) throw error;

      // Agrupar por tipo de evento
      const summary = data.reduce((acc, event) => {
        const type = event.event_type;
        if (!acc[type]) {
          acc[type] = { count: 0, total: 0 };
        }
        acc[type].count += 1;
        acc[type].total += event.amount || 0;
        return acc;
      }, {} as Record<string, { count: number; total: number }>);

      return summary;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao gerar resumo por tipo de evento');
    }
  };

  useEffect(() => {
    fetchVehicleHistory();
  }, []);

  return {
    vehicleHistory,
    loading,
    error,
    fetchVehicleHistory,
    getVehicleHistoryByVehicle,
    getVehicleHistoryStats,
    getVehicleTimelineData,
    getEventTypeSummary,
    refetch: fetchVehicleHistory
  };
}; 