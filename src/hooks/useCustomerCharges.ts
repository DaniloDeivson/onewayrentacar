import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import { Database } from '../types/database';

type CustomerCharge = Database['public']['Tables']['customer_charges']['Row'] & {
  customers?: { name: string };
  contracts?: { 
    vehicles?: { plate: string; model: string }; 
  };
  vehicles?: { plate: string; model: string };
};

type CustomerChargeInsert = Database['public']['Tables']['customer_charges']['Insert'];
type CustomerChargeUpdate = Database['public']['Tables']['customer_charges']['Update'];

interface ChargeStatistics {
  total_charges: number;
  pending_charges: number;
  paid_charges: number;
  total_amount: number;
  pending_amount: number;
  paid_amount: number;
}

export const useCustomerCharges = () => {
  const [charges, setCharges] = useState<CustomerCharge[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchCharges = async () => {
    try {
      setLoading(true);
      setError(null);
      
      // Simplified query to avoid JOIN issues
      const { data, error } = await supabase
        .from('customer_charges')
        .select('*')
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('created_at', { ascending: false });

      if (error) {
              // Check if it's a table not found error
      if (error.code === 'PGRST106' || error.message.includes('relation "customer_charges" does not exist')) {
        setCharges([]);
        setError('Database migration needed. Please execute the customer charges SQL migration.');
        return;
      }
        throw error;
      }

      // Fetch related data separately to avoid JOIN issues
      const chargesWithRelatedData = await Promise.all(
        (data || []).map(async (charge) => {
          const [customerData, contractData, vehicleData] = await Promise.all([
            supabase
              .from('customers')
              .select('name')
              .eq('id', charge.customer_id)
              .single(),
            charge.contract_id ? 
              supabase
                .from('contracts')
                .select('*')
                .eq('id', charge.contract_id)
                .single() :
              Promise.resolve({ data: null, error: null }),
            charge.vehicle_id ?
              supabase
                .from('vehicles')
                .select('plate, model')
                .eq('id', charge.vehicle_id)
                .single() :
              Promise.resolve({ data: null, error: null })
          ]);

          return {
            ...charge,
            customers: customerData.data ? { name: customerData.data.name } : null,
            contracts: contractData.data ? { 
              vehicles: vehicleData.data ? { 
                plate: vehicleData.data.plate, 
                model: vehicleData.data.model 
              } : null 
            } : null,
            vehicles: vehicleData.data ? { 
              plate: vehicleData.data.plate, 
              model: vehicleData.data.model 
            } : null
          };
        })
      );
      
      setCharges(chargesWithRelatedData);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
      console.error('Error fetching customer charges:', err);
    } finally {
      setLoading(false);
    }
  };

  const createCharge = async (chargeData: Omit<CustomerChargeInsert, 'tenant_id'>) => {
    try {
      const { data, error } = await supabase
        .from('customer_charges')
        .insert([{ ...chargeData, tenant_id: (chargeData as any).tenant_id || DEFAULT_TENANT_ID }])
        .select('*');

      if (error) throw error;
      
      // Refresh the list
      await fetchCharges();
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to create charge');
    }
  };

  const updateCharge = async (id: string, updates: CustomerChargeUpdate) => {
    try {
      const { data, error } = await supabase
        .from('customer_charges')
        .update(updates)
        .eq('id', id)
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .select()
        .single();

      if (error) throw error;
      
      // Refresh the list
      await fetchCharges();
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to update charge');
    }
  };

  const deleteCharge = async (id: string) => {
    try {
      const { error } = await supabase
        .from('customer_charges')
        .delete()
        .eq('id', id)
        .eq('tenant_id', DEFAULT_TENANT_ID);

      if (error) throw error;
      
      setCharges(prev => prev.filter(c => c.id !== id));
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to delete charge');
    }
  };

  const generateChargesFromCosts = async (contractId?: string) => {
    try {
      const { data, error } = await supabase
        .rpc('fn_generate_customer_charges', {
          p_tenant_id: DEFAULT_TENANT_ID,
          p_contract_id: contractId || null
        });

      if (error) throw error;
      
      // Refresh the list after generation
      await fetchCharges();
      
      return data?.[0] || { charges_generated: 0, total_amount: 0 };
    } catch (err) {
      console.error('Error generating charges from costs:', err);
      throw new Error(err instanceof Error ? err.message : 'Failed to generate charges from costs');
    }
  };

  const getChargeStatistics = async (): Promise<ChargeStatistics> => {
    try {
      const { data, error } = await supabase
        .rpc('fn_customer_charges_statistics', { p_tenant_id: DEFAULT_TENANT_ID });

      if (error) throw error;
      
      return data?.[0] || {
        total_charges: 0,
        pending_charges: 0,
        paid_charges: 0,
        total_amount: 0,
        pending_amount: 0,
        paid_amount: 0
      };
    } catch (err) {
      console.error('Error fetching charge statistics:', err);
      return {
        total_charges: 0,
        pending_charges: 0,
        paid_charges: 0,
        total_amount: 0,
        pending_amount: 0,
        paid_amount: 0
      };
    }
  };

  const markAsPaid = async (id: string) => {
    return updateCharge(id, { 
      status: 'Pago',
      updated_at: new Date().toISOString()
    });
  };

  const markAsAuthorized = async (id: string) => {
    return updateCharge(id, { 
      status: 'Autorizado',
      updated_at: new Date().toISOString()
    });
  };

  const markAsDisputed = async (id: string) => {
    return updateCharge(id, { 
      status: 'Contestado',
      updated_at: new Date().toISOString()
    });
  };

  // Função para verificar quais custos podem ser convertidos em cobranças
  const getChargeableCosts = async () => {
    try {
      const { data, error } = await supabase
        .rpc('fn_get_chargeable_costs', { p_tenant_id: DEFAULT_TENANT_ID });

      if (error) throw error;
      
      return data || [];
    } catch (err) {
      console.error('Error fetching chargeable costs:', err);
      throw new Error(err instanceof Error ? err.message : 'Failed to fetch chargeable costs');
    }
  };

  // Função para gerar cobranças a partir de custos selecionados
  const generateChargesFromSelectedCosts = async (costIds: string[]) => {
    try {
      const { data, error } = await supabase
        .rpc('fn_generate_charges_from_selected_costs', { 
          p_tenant_id: DEFAULT_TENANT_ID,
          p_cost_ids: costIds
        });

      if (error) throw error;
      
      // Refresh the list after generation
      await fetchCharges();
      
      return data?.[0] || { charges_generated: 0, total_amount: 0 };
    } catch (err) {
      console.error('Error generating charges from selected costs:', err);
      throw new Error(err instanceof Error ? err.message : 'Failed to generate charges from selected costs');
    }
  };

  useEffect(() => {
    fetchCharges();
  }, []);

  return {
    charges,
    loading,
    error,
    createCharge,
    updateCharge,
    deleteCharge,
    generateChargesFromCosts,
    generateChargesFromSelectedCosts,
    getChargeStatistics,
    getChargeableCosts,
    markAsPaid,
    markAsAuthorized,
    markAsDisputed,
    refetch: fetchCharges
  };
}; 