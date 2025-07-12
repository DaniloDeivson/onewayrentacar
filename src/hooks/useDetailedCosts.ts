import { useState, useEffect, useCallback } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import { useAuth } from './useAuth';
import toast from 'react-hot-toast';

// Tipo para os dados da view vw_costs_detailed
export type DetailedCost = {
  id: string;
  tenant_id: string;
  category: string;
  vehicle_id: string;
  vehicle_plate: string;
  vehicle_model: string;
  description: string;
  amount: number;
  cost_date: string;
  status: string;
  document_ref: string | null;
  observations: string | null;
  origin: string;
  source_reference_type: string | null;
  source_reference_id: string | null;
  department: string | null;
  customer_id: string | null;
  customer_name: string | null;
  contract_id: string | null;
  created_by_name: string;
  created_by_role: string;
  created_by_code: string | null;
  origin_description: string;
  is_amount_to_define: boolean;
  created_at: string;
  updated_at: string;
};

export function useDetailedCosts(vehicleId?: string) {
  const [costs, setCosts] = useState<DetailedCost[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { user } = useAuth();

  const fetchDetailedCosts = useCallback(async () => {
    try {
      setLoading(true);
      let costsData;
      let costsError;

      // Se for motorista, usar a função que busca apenas custos associados
      if (user?.role === 'Driver') {
        const result = await supabase.rpc('get_driver_costs', {
          p_driver_id: user.id
        });
        costsData = result.data;
        costsError = result.error;
      } else {
        // Para outros papéis, usar a view detalhada
        const query = supabase
          .from('vw_costs_detailed')
          .select('*')
          .eq('tenant_id', DEFAULT_TENANT_ID)
          .order('created_at', { ascending: false });

        if (vehicleId) {
          query.eq('vehicle_id', vehicleId);
        }

        const result = await query;
        costsData = result.data;
        costsError = result.error;
      }

      if (costsError) throw costsError;
      setCosts(costsData || []);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Erro ao carregar custos detalhados';
      setError(message);
      toast.error(message);
    } finally {
      setLoading(false);
    }
  }, [user?.role, vehicleId]);

  // Filtrar custos por categoria
  const getCostsByCategory = (category: string) => {
    return costs.filter(cost => cost.category === category);
  };

  // Filtrar custos por origem
  const getCostsByOrigin = (origin: string) => {
    return costs.filter(cost => cost.origin === origin);
  };

  // Filtrar custos por status
  const getCostsByStatus = (status: string) => {
    return costs.filter(cost => cost.status === status);
  };

  // Buscar custos com valor a definir
  const getCostsToDefine = () => {
    return costs.filter(cost => cost.is_amount_to_define);
  };

  // Buscar custos por funcionário
  const getCostsByEmployee = (employeeName: string) => {
    return costs.filter(cost => 
      cost.created_by_name.toLowerCase().includes(employeeName.toLowerCase())
    );
  };

  // Buscar custos por veículo
  const getCostsByVehicle = (plate: string) => {
    return costs.filter(cost => 
      cost.vehicle_plate.toLowerCase().includes(plate.toLowerCase())
    );
  };

  // Estatísticas dos custos
  const getCostStatistics = () => {
    const total = costs.length;
    const totalAmount = costs.reduce((sum, cost) => sum + cost.amount, 0);
    const pending = costs.filter(cost => cost.status === 'Pendente').length;
    const paid = costs.filter(cost => cost.status === 'Pago').length;
    const toDefine = costs.filter(cost => cost.is_amount_to_define).length;

    const byCategory = costs.reduce((acc, cost) => {
      acc[cost.category] = (acc[cost.category] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    const byOrigin = costs.reduce((acc, cost) => {
      acc[cost.origin_description] = (acc[cost.origin_description] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    return {
      total,
      totalAmount,
      pending,
      paid,
      toDefine,
      byCategory,
      byOrigin
    };
  };

  useEffect(() => {
    fetchDetailedCosts();
    const channel = supabase.channel('realtime:costs_detailed')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'costs',
        },
        () => {
          fetchDetailedCosts();
        }
      )
      .subscribe();
    return () => {
      channel.unsubscribe();
    };
  }, [fetchDetailedCosts]);

  return {
    costs,
    loading,
    error,
    fetchDetailedCosts,
    getCostsByCategory,
    getCostsByOrigin,
    getCostsByStatus,
    getCostsToDefine,
    getCostsByEmployee,
    getCostsByVehicle,
    getCostStatistics,
    refetch: fetchDetailedCosts
  };
} 