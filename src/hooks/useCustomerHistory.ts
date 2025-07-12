import { useState, useEffect, useCallback } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import { Database } from '../types/database';

type Contract = Database['public']['Tables']['contracts']['Row'] & {
  vehicles?: { plate: string; model: string; type: string };
  contract_number?: string;
};

type Cost = Database['public']['Tables']['costs']['Row'] & {
  vehicles?: { plate: string; model: string };
};

type Fine = Database['public']['Tables']['fines']['Row'] & {
  vehicles?: { plate: string; model: string };
};

export interface CustomerHistory {
  contracts: Contract[];
  costs: Cost[];
  fines: Fine[];
  totalCosts: number;
  totalFines: number;
  activeContracts: number;
  totalContracts: number;
}

export function useCustomerHistory(customerId?: string) {
  const [history, setHistory] = useState<CustomerHistory>({
    contracts: [],
    costs: [],
    fines: [],
    totalCosts: 0,
    totalFines: 0,
    activeContracts: 0,
    totalContracts: 0
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchCustomerHistory = useCallback(async () => {
    if (!customerId) {
      setHistory({
        contracts: [],
        costs: [],
        fines: [],
        totalCosts: 0,
        totalFines: 0,
        activeContracts: 0,
        totalContracts: 0
      });
      return;
    }

    try {
      setLoading(true);
      setError(null);

      // Buscar contratos do cliente
      const { data: contracts, error: contractsError } = await supabase
        .from('contracts')
        .select(`
          *,
          vehicles:vehicle_id (
            plate,
            model,
            type
          )
        `)
        .eq('customer_id', customerId)
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('created_at', { ascending: false });

      if (contractsError) throw contractsError;

      // Buscar custos do cliente
      const { data: costs, error: costsError } = await supabase
        .from('costs')
        .select(`
          *,
          vehicles:vehicle_id (
            plate,
            model
          )
        `)
        .eq('customer_id', customerId)
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('cost_date', { ascending: false });

      if (costsError) throw costsError;

      // Buscar multas do cliente
      const { data: fines, error: finesError } = await supabase
        .from('fines')
        .select(`
          *,
          vehicles:vehicle_id (
            plate,
            model
          )
        `)
        .eq('customer_id', customerId)
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('infraction_date', { ascending: false });

      if (finesError) throw finesError;

      // Calcular estatísticas
      const totalCosts = costs?.reduce((sum, cost) => sum + (cost.amount || 0), 0) || 0;
      const totalFines = fines?.reduce((sum, fine) => sum + (fine.amount || 0), 0) || 0;
      const activeContracts = contracts?.filter(c => c.status === 'Ativo').length || 0;
      const totalContracts = contracts?.length || 0;

      setHistory({
        contracts: contracts || [],
        costs: costs || [],
        fines: fines || [],
        totalCosts,
        totalFines,
        activeContracts,
        totalContracts
      });

    } catch (err) {
      console.error('Erro ao buscar histórico do cliente:', err);
      setError(err instanceof Error ? err.message : 'Erro ao buscar histórico do cliente');
    } finally {
      setLoading(false);
    }
  }, [customerId]);

  useEffect(() => {
    fetchCustomerHistory();
  }, [fetchCustomerHistory]);

  return {
    history,
    loading,
    error,
    refetch: fetchCustomerHistory
  };
} 