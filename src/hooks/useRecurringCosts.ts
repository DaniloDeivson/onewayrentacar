import { useState, useCallback, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { Database } from '../types/database';

type RecurringCost = Database['public']['Tables']['costs']['Row'] & {
  is_recurring: true;
  recurrence_type: 'monthly' | 'weekly' | 'yearly';
  recurrence_day: number;
  next_due_date: string;
  parent_recurring_cost_id: string | null;
  auto_generated: boolean;
  guest_id: string | null;
};

interface CreateRecurringCostData {
  tenant_id?: string;
  category: string;
  description: string;
  amount: number;
  cost_date: string;
  status?: 'Pendente' | 'Autorizado' | 'Pago';
  vehicle_id?: string;
  customer_id?: string;
  customer_name?: string;
  contract_id?: string;
  guest_id?: string;
  is_recurring: true;
  recurrence_type: 'monthly' | 'weekly' | 'yearly';
  recurrence_day: number;
  auto_generated?: boolean;
  parent_recurring_cost_id?: string | null;
}

interface UpdateRecurringCostData {
  category?: string;
  description?: string;
  amount?: number;
  cost_date?: string;
  status?: 'Pendente' | 'Autorizado' | 'Pago';
  vehicle_id?: string;
  customer_id?: string;
  customer_name?: string;
  contract_id?: string;
  guest_id?: string;
  recurrence_type?: 'monthly' | 'weekly' | 'yearly';
  recurrence_day?: number;
  next_due_date?: string;
  auto_generated?: boolean;
  parent_recurring_cost_id?: string | null;
}

export function useRecurringCosts() {
  const [recurringCosts, setRecurringCosts] = useState<RecurringCost[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const TENANT_ID = '00000000-0000-0000-0000-000000000001';

  // Buscar custos recorrentes
  const fetchRecurringCosts = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);

      // Buscar todas as instâncias de custos recorrentes (pais e filhos)
      const { data, error } = await supabase
        .from('costs')
        .select('*')
        .eq('tenant_id', TENANT_ID)
        .eq('is_recurring', true)
        .order('next_due_date', { ascending: true });

      if (error) {
        console.error('❌ Erro na consulta:', error);
        throw error;
      }

      setRecurringCosts(data as RecurringCost[]);
    } catch (err) {
      console.error('❌ Erro ao buscar custos recorrentes:', err);
      setError(err instanceof Error ? err.message : 'Erro ao buscar custos recorrentes');
    } finally {
      setLoading(false);
    }
  }, []);

  // Subscription em tempo real para custos recorrentes
  useEffect(() => {
    fetchRecurringCosts();
    const channel = supabase.channel('realtime:costs_recurring')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'costs',
          filter: 'is_recurring=eq.true',
        },
        () => {
          fetchRecurringCosts();
        }
      )
      .subscribe();
    return () => {
      channel.unsubscribe();
    };
  }, [fetchRecurringCosts]);

  // Criar custo recorrente
  const createRecurringCost = useCallback(async (costData: CreateRecurringCostData) => {
    try {
      setLoading(true);
      setError(null);

      // Calcular próxima data de vencimento
      const costDate = new Date(costData.cost_date);
      const nextDueDate = new Date(costDate);
      
      switch (costData.recurrence_type) {
        case 'monthly':
          nextDueDate.setMonth(nextDueDate.getMonth() + 1);
          break;
        case 'weekly':
          nextDueDate.setDate(nextDueDate.getDate() + 7);
          break;
        case 'yearly':
          nextDueDate.setFullYear(nextDueDate.getFullYear() + 1);
          break;
      }

      const costToInsert = {
        ...costData,
        tenant_id: costData.tenant_id || TENANT_ID,
        status: costData.status || 'Pendente',
        auto_generated: costData.auto_generated || false,
        origin: 'Usuario',
        next_due_date: nextDueDate.toISOString().split('T')[0],
        is_recurring: true,
        parent_recurring_cost_id: costData.parent_recurring_cost_id === '' ? null : costData.parent_recurring_cost_id ?? null,
        vehicle_id: costData.vehicle_id === '' ? null : costData.vehicle_id,
        customer_id: costData.customer_id === '' ? null : costData.customer_id,
        contract_id: costData.contract_id === '' ? null : costData.contract_id,
        guest_id: costData.guest_id === '' ? null : costData.guest_id,
      };

      const { data, error } = await supabase
        .from('costs')
        .insert([costToInsert])
        .select()
        .single();

      if (error) throw error;

      setRecurringCosts(prev => [data as RecurringCost, ...prev]);
      return data;
    } catch (err) {
      console.error('Erro ao criar custo recorrente:', err);
      setError(err instanceof Error ? err.message : 'Erro ao criar custo recorrente');
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  // Atualizar custo recorrente
  const updateRecurringCost = useCallback(async (id: string, updates: UpdateRecurringCostData) => {
    try {
      setLoading(true);
      setError(null);

      // Se a data de vencimento foi alterada, recalcular próxima data
      let nextDueDate = updates.next_due_date;
      if (updates.cost_date && updates.recurrence_type) {
        const costDate = new Date(updates.cost_date);
        const newNextDueDate = new Date(costDate);
        
        switch (updates.recurrence_type) {
          case 'monthly':
            newNextDueDate.setMonth(newNextDueDate.getMonth() + 1);
            break;
          case 'weekly':
            newNextDueDate.setDate(newNextDueDate.getDate() + 7);
            break;
          case 'yearly':
            newNextDueDate.setFullYear(newNextDueDate.getFullYear() + 1);
            break;
        }
        nextDueDate = newNextDueDate.toISOString().split('T')[0];
      }

      const costToUpdate = {
        ...updates,
        ...(nextDueDate && { next_due_date: nextDueDate }),
        vehicle_id: updates.vehicle_id === '' ? null : updates.vehicle_id,
        customer_id: updates.customer_id === '' ? null : updates.customer_id,
        contract_id: updates.contract_id === '' ? null : updates.contract_id,
        guest_id: updates.guest_id === '' ? null : updates.guest_id,
        parent_recurring_cost_id: updates.parent_recurring_cost_id === '' ? null : updates.parent_recurring_cost_id,
      };

      const { data, error } = await supabase
        .from('costs')
        .update(costToUpdate)
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;

      setRecurringCosts(prev => 
        prev.map(cost => cost.id === id ? data as RecurringCost : cost)
      );
      return data;
    } catch (err) {
      console.error('Erro ao atualizar custo recorrente:', err);
      setError(err instanceof Error ? err.message : 'Erro ao atualizar custo recorrente');
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  // Deletar custo recorrente
  const deleteRecurringCost = useCallback(async (id: string) => {
    try {
      setLoading(true);
      setError(null);

      const { error } = await supabase
        .from('costs')
        .delete()
        .eq('id', id);

      if (error) throw error;

      setRecurringCosts(prev => prev.filter(cost => cost.id !== id));
    } catch (err) {
      console.error('Erro ao deletar custo recorrente:', err);
      setError(err instanceof Error ? err.message : 'Erro ao deletar custo recorrente');
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  // Marcar custo recorrente como pago
  const markAsPaid = useCallback(async (id: string) => {
    try {
      setLoading(true);
      setError(null);

      const { data, error } = await supabase
        .from('costs')
        .update({ status: 'Pago' })
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;

      setRecurringCosts(prev => 
        prev.map(cost => cost.id === id ? data as RecurringCost : cost)
      );
      return data;
    } catch (err) {
      console.error('Erro ao marcar custo recorrente como pago:', err);
      setError(err instanceof Error ? err.message : 'Erro ao marcar como pago');
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  // Gerar custos recorrentes automaticamente
  const generateRecurringCosts = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);

      const { data, error } = await supabase
        .rpc('fn_generate_recurring_costs');

      if (error) throw error;

      // Recarregar lista após gerar novos custos
      await fetchRecurringCosts();
      
      return data;
    } catch (err) {
      console.error('Erro ao gerar custos recorrentes:', err);
      setError(err instanceof Error ? err.message : 'Erro ao gerar custos recorrentes');
      throw err;
    } finally {
      setLoading(false);
    }
  }, [fetchRecurringCosts]);

  // Buscar custos recorrentes por categoria
  const getRecurringCostsByCategory = useCallback((category: string) => {
    return recurringCosts.filter(cost => cost.category === category);
  }, [recurringCosts]);

  // Buscar custos recorrentes por veículo
  const getRecurringCostsByVehicle = useCallback((vehicleId: string) => {
    return recurringCosts.filter(cost => cost.vehicle_id === vehicleId);
  }, [recurringCosts]);

  // Buscar custos recorrentes vencidos
  const getOverdueRecurringCosts = useCallback(() => {
    const today = new Date().toISOString().split('T')[0];
    return recurringCosts.filter(cost => cost.next_due_date < today);
  }, [recurringCosts]);

  // Buscar custos recorrentes próximos do vencimento (próximos 7 dias)
  const getUpcomingRecurringCosts = useCallback(() => {
    const today = new Date();
    const nextWeek = new Date(today);
    nextWeek.setDate(today.getDate() + 7);
    
    const todayStr = today.toISOString().split('T')[0];
    const nextWeekStr = nextWeek.toISOString().split('T')[0];
    
    return recurringCosts.filter(cost => 
      cost.next_due_date >= todayStr && cost.next_due_date <= nextWeekStr
    );
  }, [recurringCosts]);

  // Estatísticas de custos recorrentes
  const getRecurringCostsStats = useCallback(() => {
    const total = recurringCosts.length;
    const active = recurringCosts.filter(cost => cost.status === 'Pendente' || cost.status === 'Autorizado').length;
    const overdue = getOverdueRecurringCosts().length;
    const upcoming = getUpcomingRecurringCosts().length;
    const totalAmount = recurringCosts.reduce((sum, cost) => sum + cost.amount, 0);
    
    return {
      total,
      active,
      overdue,
      upcoming,
      totalAmount
    };
  }, [recurringCosts, getOverdueRecurringCosts, getUpcomingRecurringCosts]);

  return {
    recurringCosts,
    loading,
    error,
    refetch: fetchRecurringCosts,
    createRecurringCost,
    updateRecurringCost,
    deleteRecurringCost,
    markAsPaid,
    generateRecurringCosts,
    getRecurringCostsByCategory,
    getRecurringCostsByVehicle,
    getOverdueRecurringCosts,
    getUpcomingRecurringCosts,
    getRecurringCostsStats
  };
} 