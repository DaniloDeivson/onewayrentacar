import { useState, useEffect, useCallback } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import { Database } from '../types/database';
import { useAuth } from './useAuth';
import toast from 'react-hot-toast';

export type Cost = Database['public']['Tables']['costs']['Row'] & {
  vehicles?: { plate: string; model: string };
  created_by_name?: string;
  created_by_role?: string;
  created_by_code?: string;
  origin_description?: string;
  is_amount_to_define?: boolean;
  contracts?: { id: string; contract_number: string };
  customers?: { id: string; name: string };
  employees?: { id: string; name: string; role: string };
  // Campos para custos reais (multas, danos, combustível)
  is_real_cost?: boolean;
  source_type?: 'fine' | 'damage' | 'fuel';
  source_id?: string;
  // Campos opcionais para compatibilidade
  document_ref?: string | null;
  observations?: string | null;
  created_by_employee_id?: string | null;
  source_reference_id?: string | null;
  source_reference_type?: string | null;
  department?: string | null;
  customer_id?: string | null;
  customer_name?: string | null;
  contract_id?: string | null;
  vehicle_plate?: string;
  vehicle_model?: string;
  category: string;
};
type CostInsert = Database['public']['Tables']['costs']['Insert'];
type CostUpdate = Database['public']['Tables']['costs']['Update'];

export const useCosts = (vehicleId?: string) => {
  const [costs, setCosts] = useState<Cost[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { user } = useAuth();

  const fetchCosts = useCallback(async () => {
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
        // Para outros papéis, buscar todos os custos com relações (ou filtrar por veículo se especificado)
        const query = supabase
          .from('costs')
          .select(`
            *,
            vehicles (
              plate,
              model
            ),
            customers (
              id,
              name
            ),
            contracts (
              id,
              contract_number,
              customers (
                id,
                name
              )
            ),
            employees!costs_created_by_employee_id_fkey (
              id,
              name,
              role
            )
          `)
          .eq('tenant_id', DEFAULT_TENANT_ID)
          .or('is_recurring.is.null,is_recurring.eq.false') // Excluir custos recorrentes
          .order('created_at', { ascending: false });

        if (vehicleId) {
          query.eq('vehicle_id', vehicleId);
        }

        const result = await query;
        costsData = result.data;
        costsError = result.error;
      }

      if (costsError) throw costsError;
      setCosts(
        (costsData || []).filter(
          (cost: Cost) => !(cost.category === 'Salário' && cost.is_recurring)
        )
      );
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Erro ao carregar custos';
      setError(message);
      toast.error(message);
    } finally {
      setLoading(false);
    }
  }, [user, vehicleId]);

  const createCost = async (costData: CostInsert) => {
    try {
      // Garantir que o campo created_by_name seja sempre preenchido
      const costWithUser = {
        ...costData,
        tenant_id: costData.tenant_id || DEFAULT_TENANT_ID,
        created_by_name: costData.created_by_name || user?.name || 'Usuário do Sistema',
        created_by_employee_id: costData.created_by_employee_id || user?.id || null
      };
      
      // Corrigir/forçar o valor de source_reference_type se vier de OS/peças
      const fixedCostData = { ...costWithUser };
      if (
        fixedCostData.source_reference_id &&
        fixedCostData.source_reference_type &&
        typeof fixedCostData.source_reference_type !== 'string'
      ) {
        // Se vier enum/objeto, força para string permitida
        fixedCostData.source_reference_type = 'service_note';
      }
      // Se vier valor inválido, zera
      if (
        fixedCostData.source_reference_type &&
        !['service_note', 'manual', 'finance', 'inspection', 'recurring'].includes(fixedCostData.source_reference_type)
      ) {
        fixedCostData.source_reference_type = 'service_note';
      }

      // Garantir que campos obrigatórios estejam presentes
      if (!fixedCostData.category) {
        fixedCostData.category = 'Combustível';
      }
      if (!fixedCostData.status) {
        fixedCostData.status = 'Pendente';
      }
      if (!fixedCostData.origin) {
        fixedCostData.origin = 'Sistema';
      }
      
      // Garantir que custos criados por este hook sejam sempre avulsos (não recorrentes)
      fixedCostData.is_recurring = false;

      const { data, error } = await supabase
        .from('costs')
        .insert([fixedCostData])
        .select(`
          *,
          vehicles (
            plate,
            model
          ),
          customers (
            id,
            name
          ),
          contracts (
            id,
            contract_number
          ),
          employees!costs_created_by_employee_id_fkey (
            id,
            name,
            role
          )
        `)
        .single();

      if (error) {
        console.error('Erro do Supabase ao criar custo:', error);
        alert('Erro ao criar custo: ' + (error.message || JSON.stringify(error)));
        throw error;
      }
      setCosts(prev => [data, ...prev]);
      return data;
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Erro ao criar custo';
      console.error('Erro inesperado ao criar custo:', error);
      alert('Erro inesperado ao criar custo: ' + message);
      throw new Error(message);
    }
  };

  const updateCost = async (id: string, updates: CostUpdate) => {
    try {
      const { data, error } = await supabase
        .from('costs')
        .update(updates)
        .eq('id', id)
        .select(`
          *,
          vehicles (
            plate,
            model
          ),
          customers (
            id,
            name
          ),
          contracts (
            id,
            contract_number
          ),
          employees!costs_created_by_employee_id_fkey (
            id,
            name,
            role
          )
        `)
        .single();

      if (error) throw error;
      setCosts(prev => prev.map(cost => cost.id === id ? data : cost));
      return data;
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Erro ao atualizar custo';
      toast.error(message);
      throw new Error(message);
    }
  };

  const deleteCost = async (id: string) => {
    try {
      const { error } = await supabase
        .from('costs')
        .delete()
        .eq('id', id);

      if (error) throw error;
      setCosts(prev => prev.filter(cost => cost.id !== id));
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Erro ao deletar custo';
      toast.error(message);
      throw new Error(message);
    }
  };

  const getCostStatistics = async () => {
    try {
      const { data, error } = await supabase
        .rpc('fn_cost_statistics_by_origin', { p_tenant_id: DEFAULT_TENANT_ID });

      if (error) throw error;
      return data?.[0] || null;
    } catch {
      return null;
    }
  };

  const debugAutomaticCosts = async () => {
    try {
      const { data, error } = await supabase
        .rpc('fn_debug_automatic_costs', { p_tenant_id: DEFAULT_TENANT_ID });

      if (error) throw error;
      return data || [];
    } catch {
      return [];
    }
  };

  const reprocessInspectionCosts = async () => {
    try {
      const { data, error } = await supabase
        .rpc('fn_reprocess_inspection_costs', { p_tenant_id: DEFAULT_TENANT_ID });

      if (error) throw error;
      
      await fetchCosts(); // Refresh after reprocessing
      return data;
    } catch {
      throw new Error('Failed to reprocess costs');
    }
  };

  const authorizePurchase = async (id: string) => {
    return updateCost(id, { 
      status: 'Autorizado',
      updated_at: new Date().toISOString()
    });
  };

  // Get costs for billing (with contract and customer info)
  const getBillingCosts = async () => {
    try {
      // Try to use the new billing view first
      let data, error;
      ({ data, error } = await supabase
        .from('vw_billing_detailed')
        .select('*')
        .order('created_at', { ascending: false }));

      // Fallback to direct query if view doesn't exist
      if (error || !data) {
        const { data: directData, error: directError } = await supabase
          .from('costs')
          .select(`
            *,
            vehicles (
              plate,
              model
            ),
            contracts (
              id,
              contract_number
            ),
            customers (
              id,
              name
            )
          `)
          .eq('tenant_id', DEFAULT_TENANT_ID)
          .in('status', ['Autorizado', 'Pago'])
          .neq('origin', 'Manual')
          .order('created_at', { ascending: false });

        if (directError) throw directError;
        data = directData;
      }

      return data || [];
    } catch {
      return [];
    }
  };

  // Generate billing costs automatically
  const generateBillingCosts = async (contractId?: string) => {
    try {
      const { data, error } = await supabase
        .rpc('fn_generate_billing_costs', {
          p_contract_id: contractId || null,
          p_tenant_id: DEFAULT_TENANT_ID
        });

      if (error) throw error;
      
      // Refresh costs after generation
      await fetchCosts();
      
      return data?.[0] || { generated_count: 0, total_amount: 0 };
    } catch {
      throw new Error('Failed to generate billing costs');
    }
  };

  // Get billing statistics
  const getBillingStatistics = async () => {
    try {
      const { data, error } = await supabase
        .rpc('fn_billing_statistics', { p_tenant_id: DEFAULT_TENANT_ID });

      if (error) throw error;
      return data?.[0] || null;
    } catch {
      return null;
    }
  };

  // Mark cost as paid
  const markAsPaid = async (id: string) => {
    const { data, error } = await supabase
      .from('costs')
      .update({ status: 'Pago' })
      .eq('id', id)
      .select('*')
      .maybeSingle();

    if (error) throw error;
    if (!data) throw new Error('Custo não encontrado para marcar como pago.');
    setCosts(prev => prev.map(cost => cost.id === id ? data : cost));
    return data;
  };

  // Função para buscar multas, batidas e combustível do banco de dados
  const fetchRealCosts = async () => {
    try {
      setLoading(true);
      
      // Buscar multas
      const { data: fines, error: finesError } = await supabase
        .from('fines')
        .select(`
          *,
          vehicles (
            plate,
            model
          ),
          contracts (
            id,
            contract_number,
            customers (
              id,
              name
            )
          )
        `)
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('created_at', { ascending: false });

      if (finesError) throw finesError;

      // Buscar danos de inspeções
      const { data: damages, error: damagesError } = await supabase
        .from('inspection_damages')
        .select(`
          *,
          inspections (
            vehicles (
              plate,
              model
            ),
            contracts (
              id,
              contract_number,
              customers (
                id,
                name
              )
            )
          )
        `)
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('created_at', { ascending: false });

      if (damagesError) throw damagesError;

      // Buscar combustível de manutenções
      const { data: fuelCosts, error: fuelError } = await supabase
        .from('maintenance_checkins')
        .select(`
          *,
          vehicles (
            plate,
            model
          ),
          contracts (
            id,
            contract_number,
            customers (
              id,
              name
            )
          )
        `)
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .not('fuel_cost', 'is', null)
        .order('created_at', { ascending: false });

      if (fuelError) throw fuelError;

      // Converter multas para formato de custos
      const finesAsCosts = fines?.map(fine => ({
        id: `fine_${fine.id}`,
        category: 'Multa' as const,
        vehicle_id: fine.vehicle_id,
        description: `Multa: ${fine.description || 'Infração de trânsito'}`,
        amount: fine.amount || 0,
        cost_date: fine.fine_date || fine.created_at,
        status: fine.paid ? 'Pago' as const : 'Pendente' as const,
        origin: 'Multas' as const,
        created_at: fine.created_at,
        updated_at: fine.updated_at,
        tenant_id: fine.tenant_id,
        vehicles: fine.vehicles,
        contracts: fine.contracts,
        customers: fine.contracts?.customers,
        customer_name: fine.contracts?.customers?.name,
        vehicle_plate: fine.vehicles?.plate,
        vehicle_model: fine.vehicles?.model,
        created_by_name: 'Multas',
        created_by_role: 'Multas',
        origin_description: 'Multas',
        is_amount_to_define: (fine.amount || 0) === 0 && !fine.paid,
        is_real_cost: true,
        source_type: 'fine' as const,
        source_id: fine.id
      })) || [];

      // Converter danos para formato de custos
      const damagesAsCosts = damages?.map(damage => ({
        id: `damage_${damage.id}`,
        category: 'Funilaria' as const,
        vehicle_id: damage.inspections?.vehicles?.id,
        description: `Dano: ${damage.description || 'Avaria identificada'}`,
        amount: damage.estimated_cost || 0,
        cost_date: damage.created_at,
        status: damage.repaired ? 'Pago' as const : (damage.estimated_cost && damage.estimated_cost > 0 ? 'Autorizado' as const : 'Pendente' as const),
        origin: 'Danos' as const,
        created_at: damage.created_at,
        updated_at: damage.updated_at,
        tenant_id: damage.tenant_id,
        vehicles: damage.inspections?.vehicles,
        contracts: damage.inspections?.contracts,
        customers: damage.inspections?.contracts?.customers,
        customer_name: damage.inspections?.contracts?.customers?.name,
        vehicle_plate: damage.inspections?.vehicles?.plate,
        vehicle_model: damage.inspections?.vehicles?.model,
        created_by_name: 'Danos',
        created_by_role: 'Danos',
        origin_description: 'Danos',
        is_amount_to_define: (damage.estimated_cost || 0) === 0 && !damage.repaired,
        is_real_cost: true,
        source_type: 'damage' as const,
        source_id: damage.id
      })) || [];

      // Converter combustível para formato de custos
      const fuelAsCosts = fuelCosts?.map(fuel => ({
        id: `fuel_${fuel.id}`,
        category: 'Combustível' as const,
        vehicle_id: fuel.vehicle_id,
        description: `Combustível: ${fuel.fuel_type || 'Gasolina'} - ${fuel.fuel_liters || 0}L`,
        amount: fuel.fuel_cost || 0,
        cost_date: fuel.checkin_date || fuel.created_at,
        status: fuel.fuel_paid ? 'Pago' as const : 'Pendente' as const,
        origin: 'Abastecimento' as const,
        created_at: fuel.created_at,
        updated_at: fuel.updated_at,
        tenant_id: fuel.tenant_id,
        vehicles: fuel.vehicles,
        contracts: fuel.contracts,
        customers: fuel.contracts?.customers,
        customer_name: fuel.contracts?.customers?.name,
        vehicle_plate: fuel.vehicles?.plate,
        vehicle_model: fuel.vehicles?.model,
        created_by_name: 'Abastecimento',
        created_by_role: 'Abastecimento',
        origin_description: 'Abastecimento',
        is_amount_to_define: (fuel.fuel_cost || 0) === 0 && !fuel.fuel_paid,
        is_real_cost: true,
        source_type: 'fuel' as const,
        source_id: fuel.id
      })) || [];

      // Combinar custos normais com custos reais
      const allCosts = [
        ...costs,
        ...finesAsCosts,
        ...damagesAsCosts,
        ...fuelAsCosts
      ].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()) as Cost[];

      setCosts(allCosts);
    } catch (error) {
      setError(error instanceof Error ? error.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  // Função para atualizar orçamento de custos "à definir"
  const updateCostEstimate = async (id: string, amount: number, observations?: string) => {
    try {
      const cost = costs.find(c => c.id === id);
      if (!cost) throw new Error('Custo não encontrado');

      // Se for um custo real (multa, dano, combustível), atualizar na tabela original
      if (cost.is_real_cost) {
        switch (cost.source_type) {
          case 'fine': {
            const { error: fineError } = await supabase
              .from('fines')
              .update({ 
                amount: amount,
                observations: observations,
                updated_at: new Date().toISOString()
              })
              .eq('id', cost.source_id);
            if (fineError) throw fineError;
            break;
          }

          case 'damage': {
            const { error: damageError } = await supabase
              .from('inspection_damages')
              .update({ 
                estimated_cost: amount,
                observations: observations,
                updated_at: new Date().toISOString()
              })
              .eq('id', cost.source_id);
            if (damageError) throw damageError;
            break;
          }

          case 'fuel': {
            const { error: fuelError } = await supabase
              .from('service_notes')
              .update({ 
                fuel_cost: amount,
                observations: observations,
                updated_at: new Date().toISOString()
              })
              .eq('id', cost.source_id);
            if (fuelError) throw fuelError;
            break;
          }
        }
        
        // Para custos reais, não precisamos atualizar a tabela costs pois são virtuais
        // O status será recalculado automaticamente na próxima busca
      } else {
        // Se for um custo normal, atualizar na tabela costs
        const { error } = await supabase
          .from('costs')
          .update({ 
            amount: amount,
            observations: observations,
            updated_at: new Date().toISOString()
          })
          .eq('id', id);
        if (error) throw error;
      }

      // Recarregar os custos reais para atualizar o status
      await fetchRealCosts();
      
      // Log para debug
      console.log('Orçamento atualizado:', { id, amount, observations });
      console.log('Recarregando custos para atualizar status...');
    } catch (error) {
      throw new Error(error instanceof Error ? error.message : 'Failed to update cost estimate');
    }
  };

  // Função para buscar peças associadas a um custo
  const getCostParts = async (costId: string) => {
    try {
      const cost = costs.find(c => c.id === costId);
      if (!cost) return [];

      // Se o custo tem source_reference_id e source_reference_type, buscar peças
      if (cost.source_reference_id && cost.source_reference_type === 'service_note') {
        const { data, error } = await supabase
          .from('service_order_parts')
          .select(`
            *,
            parts (
              sku,
              name,
              quantity
            )
          `)
          .eq('service_note_id', cost.source_reference_id)
          .order('created_at', { ascending: false });

        if (error) throw error;
        return data || [];
      }

      return [];
    } catch (error) {
      console.error('Error fetching cost parts:', error);
      return [];
    }
  };

  useEffect(() => {
    fetchCosts();
    const channel = supabase.channel('realtime:costs_all')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'costs',
        },
        () => {
          fetchCosts();
        }
      )
      .subscribe();
    return () => {
      channel.unsubscribe();
    };
  }, [fetchCosts]);

  return {
    costs,
    loading,
    error,
    createCost,
    updateCost,
    deleteCost,
    updateCostEstimate,
    fetchRealCosts,
    getCostStatistics,
    debugAutomaticCosts,
    reprocessInspectionCosts,
    authorizePurchase,
    getBillingCosts,
    generateBillingCosts,
    getBillingStatistics,
    markAsPaid,
    getCostParts,
    refetch: fetchCosts
  };
};