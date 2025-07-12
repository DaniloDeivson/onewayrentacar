import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { Database } from '../types/database';
import { useCache } from '../context/CacheContext';
import toast from 'react-hot-toast';

// Tipos robustos
export type Contract = Database['public']['Tables']['contracts']['Row'];
export type ContractInsert = Database['public']['Tables']['contracts']['Insert'];
export type ContractUpdate = Database['public']['Tables']['contracts']['Update'];

interface ContractStatistics {
  total: number;
  active: number;
  expired: number;
  totalRevenue: number;
  averageDailyRate: number;
  monthlyRevenue: number;
}

export function useContracts() {
  const [contracts, setContracts] = useState<Contract[]>([]);
  const [statistics, setStatistics] = useState<ContractStatistics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { get, set, has } = useCache();

  // Busca contratos apenas do tenant correto e status válidos
  const fetchContracts = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      // Buscar apenas contratos do tenant correto
      const { data, error } = await supabase
        .from('contracts')
        .select(`*, customers:customer_id(*), vehicles:vehicle_id(*), contract_vehicles(*, vehicles:vehicle_id(*))`)
        .eq('tenant_id', TENANT_ID)
        .order('created_at', { ascending: false });
      if (error) throw error;
      setContracts(data || []);
    } catch (err: unknown) {
      setError((err as Error).message || 'Erro ao buscar contratos');
      toast.error((err as Error).message || 'Erro ao buscar contratos');
    } finally {
      setLoading(false);
    }
  }, []);

  const fetchStatistics = useCallback(async (forceRefresh = false) => {
    try {
      const cacheKey = 'contracts_statistics';
      if (!forceRefresh && has(cacheKey)) {
        const cachedData = get<ContractStatistics>(cacheKey);
        if (cachedData) {
          setStatistics(cachedData);
          return;
        }
      }

      const { data, error } = await supabase
        .from('contracts')
        .select('*');

      if (error) throw error;

      const total = data.length;
      const now = new Date();
      const active = data.filter(c => new Date(c.end_date) > now && c.status === 'Ativo').length;
      const expired = data.filter(c => new Date(c.end_date) <= now).length;
      
      // Calcular receita total baseada em contratos ativos e finalizados
      const totalRevenue = data.reduce((sum, c) => {
        if (c.status === 'Ativo' || c.status === 'Finalizado') {
          const start = new Date(c.start_date);
          const end = new Date(c.end_date);
          const days = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;
          return sum + (c.daily_rate * days);
        }
        return sum;
      }, 0);
      
      // Calcular receita mensal (média dos últimos 30 dias)
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      
      const monthlyRevenue = data.reduce((sum, c) => {
        if (c.status === 'Ativo' && new Date(c.start_date) >= thirtyDaysAgo) {
          const start = new Date(c.start_date);
          const end = new Date(c.end_date);
          const days = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;
          return sum + (c.daily_rate * days);
        }
        return sum;
      }, 0);
      
      const averageDailyRate = data.length > 0 ? data.reduce((sum, c) => sum + c.daily_rate, 0) / data.length : 0;

      const stats = { 
        total, 
        active, 
        expired, 
        totalRevenue, 
        averageDailyRate,
        monthlyRevenue 
      };
      set(cacheKey, stats, 5 * 60 * 1000);
      setStatistics(stats);
    } catch (err: unknown) {
      setError((err as Error).message || 'Erro ao buscar estatísticas');
    }
  }, [get, set, has]);

  const TENANT_ID = '00000000-0000-0000-0000-000000000001';

  const createContract = useCallback(async (contract: ContractInsert) => {
    setLoading(true);
    setError(null);
    try {
      // Garante que o tenant_id está presente
      const contractWithTenant = {
        ...contract,
        tenant_id: contract.tenant_id || TENANT_ID
      };
      // Primeiro, faz o insert e retorna apenas as colunas diretas
      const { data: inserted, error } = await supabase
        .from('contracts')
        .insert([contractWithTenant])
        .select('*')
        .single();
      if (error) throw error;
      // Depois, busca o contrato completo com relacionamentos
      const { data: full, error: fetchError } = await supabase
        .from('contracts')
        .select(`*, customers:customer_id(*), vehicles:vehicle_id(*), contract_vehicles(*, vehicles:vehicle_id(*))`)
        .eq('id', inserted.id)
        .single();
      if (fetchError) throw fetchError;
      setContracts(prev => [full, ...prev]);
      toast.success('Contrato criado com sucesso!');
      if (!contract.uses_multiple_vehicles && contract.vehicle_id) {
        await supabase.from('vehicles').update({ status: 'Em Uso' }).eq('id', contract.vehicle_id);
      }
      return full;
    } catch (err: unknown) {
      setError((err as Error).message || 'Erro ao criar contrato');
      toast.error((err as Error).message || 'Erro ao criar contrato');
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const updateContract = useCallback(async (id: string, updates: ContractUpdate) => {
    setLoading(true);
    setError(null);
    try {
      const { data: oldContract, error: fetchError } = await supabase
        .from('contracts')
        .select('id, vehicle_id, uses_multiple_vehicles, status')
        .eq('id', id)
        .single();
      if (fetchError || !oldContract) throw fetchError || new Error('Contrato não encontrado');
      
      // Verificar se há mudança de veículo
      const vehicleChanged = updates.vehicle_id && updates.vehicle_id !== oldContract.vehicle_id;
      
      // Atualiza e retorna apenas colunas diretas
      const { error } = await supabase
        .from('contracts')
        .update(updates)
        .eq('id', id)
        .select('*')
        .single();
      if (error) throw error;
      
      // Busca o contrato completo com relacionamentos
      const { data: full, error: fetchFullError } = await supabase
        .from('contracts')
        .select(`*, customers:customer_id(*), vehicles:vehicle_id(*), contract_vehicles(*, vehicles:vehicle_id(*))`)
        .eq('id', id)
        .single();
      if (fetchFullError) throw fetchFullError;
      
      setContracts(prev => prev.map(c => c.id === id ? full : c));
      toast.success('Contrato atualizado com sucesso!');
      
      // Se houve mudança de veículo e o contrato está ativo, atualize explicitamente os status
      if (vehicleChanged && updates.status === 'Ativo') {
        // Libera o veículo anterior
        if (oldContract.vehicle_id) {
          await supabase.from('vehicles').update({ status: 'Disponível' }).eq('id', oldContract.vehicle_id);
        }
        // Marca o novo veículo como em uso
        if (updates.vehicle_id) {
          await supabase.from('vehicles').update({ status: 'Em Uso' }).eq('id', updates.vehicle_id);
        }
      }
      
      // Atualizar status do veículo baseado no novo status do contrato (apenas se não houve mudança de veículo)
      if (updates.status && updates.status !== oldContract.status && !vehicleChanged) {
        if (oldContract.uses_multiple_vehicles) {
          // Para múltiplos veículos, buscar em contract_vehicles
          const { data: contractVehicles } = await supabase
            .from('contract_vehicles')
            .select('vehicle_id')
            .eq('contract_id', id);
          
          if (contractVehicles && contractVehicles.length > 0) {
            const vehicleIds = contractVehicles.map((cv: any) => cv.vehicle_id);
            const newVehicleStatus = updates.status === 'Ativo' ? 'Em Uso' : 'Disponível';
            await supabase.from('vehicles').update({ status: newVehicleStatus }).in('id', vehicleIds);
          }
        } else if (oldContract.vehicle_id) {
          // Para veículo único
          const newVehicleStatus = updates.status === 'Ativo' ? 'Em Uso' : 'Disponível';
          await supabase.from('vehicles').update({ status: newVehicleStatus }).eq('id', oldContract.vehicle_id);
        }
      }
      
      // Após atualizar o contrato, se o status mudou para Finalizado, gerar custos automáticos
      if (updates.status === 'Finalizado' && oldContract.status !== 'Finalizado') {
        // Buscar o contrato completo atualizado
        const { data: contractFull, error: contractError } = await supabase
          .from('contracts')
          .select('*')
          .eq('id', id)
          .single();
        if (!contractError && contractFull) {
          if (contractFull.uses_multiple_vehicles) {
            // Buscar todos os veículos do contrato
            const { data: contractVehicles } = await supabase
              .from('contract_vehicles')
              .select('vehicle_id')
              .eq('contract_id', contractFull.id);
            if (contractVehicles && contractVehicles.length > 0) {
              for (const cv of contractVehicles) {
                // Buscar última inspeção/check-out do veículo para obter km final e combustível
                const { data: lastInspection } = await supabase
                  .from('inspections')
                  .select('mileage, fuel_level')
                  .eq('vehicle_id', cv.vehicle_id)
                  .eq('contract_id', contractFull.id)
                  .order('inspected_at', { ascending: false })
                  .limit(1)
                  .single();
                // Buscar km inicial do veículo no início do contrato
                const { data: vehicle } = await supabase
                  .from('vehicles')
                  .select('initial_mileage')
                  .eq('id', cv.vehicle_id)
                  .single();
                // Excesso de km
                if (contractFull.km_limit && contractFull.price_per_excess_km && lastInspection?.mileage != null && vehicle?.initial_mileage != null) {
                  const kmRodado = lastInspection.mileage - vehicle.initial_mileage;
                  const excesso = kmRodado - contractFull.km_limit;
                  if (excesso > 0) {
                    const valorExcesso = excesso * contractFull.price_per_excess_km;
                    await supabase.from('costs').insert([{
                      tenant_id: contractFull.tenant_id,
                      contract_id: contractFull.id,
                      customer_id: contractFull.customer_id,
                      vehicle_id: cv.vehicle_id,
                      amount: valorExcesso,
                      category: 'Excesso Km',
                      description: `Cobrança por excesso de km no contrato (veículo ${cv.vehicle_id})`,
                      cost_date: new Date().toISOString().split('T')[0],
                      status: 'Pendente',
                      origin: 'Sistema',
                      created_by_name: 'Sistema',
                    }]);
                  }
                }
                // Combustível (exemplo: se fuel_level < 1, cobrar combustível faltante)
                if (contractFull.price_per_liter && lastInspection?.fuel_level != null && lastInspection.fuel_level < 1) {
                  const litrosFaltantes = (1 - lastInspection.fuel_level) * 50; // Exemplo: 50 litros tanque cheio
                  if (litrosFaltantes > 0) {
                    const valorCombustivel = litrosFaltantes * contractFull.price_per_liter;
                    await supabase.from('costs').insert([{
                      tenant_id: contractFull.tenant_id,
                      contract_id: contractFull.id,
                      customer_id: contractFull.customer_id,
                      vehicle_id: cv.vehicle_id,
                      amount: valorCombustivel,
                      category: 'Combustível',
                      description: `Cobrança de combustível no contrato (veículo ${cv.vehicle_id})`,
                      cost_date: new Date().toISOString().split('T')[0],
                      status: 'Pendente',
                      origin: 'Sistema',
                      created_by_name: 'Sistema',
                    }]);
                  }
                }
              }
            }
          } else {
            // Lógica para contrato de veículo único (já existente)
            const { data: lastInspection } = await supabase
              .from('inspections')
              .select('mileage, fuel_level')
              .eq('vehicle_id', contractFull.vehicle_id)
              .eq('contract_id', contractFull.id)
              .order('inspected_at', { ascending: false })
              .limit(1)
              .single();
            const { data: vehicle } = await supabase
              .from('vehicles')
              .select('initial_mileage')
              .eq('id', contractFull.vehicle_id)
              .single();
            if (contractFull.km_limit && contractFull.price_per_excess_km && lastInspection?.mileage != null && vehicle?.initial_mileage != null) {
              const kmRodado = lastInspection.mileage - vehicle.initial_mileage;
              const excesso = kmRodado - contractFull.km_limit;
              if (excesso > 0) {
                const valorExcesso = excesso * contractFull.price_per_excess_km;
                await supabase.from('costs').insert([{
                  tenant_id: contractFull.tenant_id,
                  contract_id: contractFull.id,
                  customer_id: contractFull.customer_id,
                  vehicle_id: contractFull.vehicle_id,
                  amount: valorExcesso,
                  category: 'Excesso Km',
                  description: `Cobrança por excesso de km no contrato`,
                  cost_date: new Date().toISOString().split('T')[0],
                  status: 'Pendente',
                  origin: 'Sistema',
                  created_by_name: 'Sistema',
                }]);
              }
            }
            if (contractFull.price_per_liter && lastInspection?.fuel_level != null && lastInspection.fuel_level < 1) {
              const litrosFaltantes = (1 - lastInspection.fuel_level) * 50;
              if (litrosFaltantes > 0) {
                const valorCombustivel = litrosFaltantes * contractFull.price_per_liter;
                await supabase.from('costs').insert([{
                  tenant_id: contractFull.tenant_id,
                  contract_id: contractFull.id,
                  customer_id: contractFull.customer_id,
                  vehicle_id: contractFull.vehicle_id,
                  amount: valorCombustivel,
                  category: 'Combustível',
                  description: `Cobrança de combustível no contrato`,
                  cost_date: new Date().toISOString().split('T')[0],
                  status: 'Pendente',
                  origin: 'Sistema',
                  created_by_name: 'Sistema',
                }]);
              }
            }
          }
        }
      }
      
      return full;
    } catch (err: unknown) {
      setError((err as Error).message || 'Erro ao atualizar contrato');
      toast.error((err as Error).message || 'Erro ao atualizar contrato');
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const deleteContract = useCallback(async (id: string) => {
    setLoading(true);
    setError(null);
    try {
      const { data: contract, error: fetchError } = await supabase
        .from('contracts')
        .select('id, vehicle_id, uses_multiple_vehicles, status')
        .eq('id', id)
        .single();
      if (fetchError || !contract) throw fetchError || new Error('Contrato não encontrado');

      const { error: deleteError } = await supabase
        .from('contracts')
        .delete()
        .eq('id', id);
      if (deleteError) throw deleteError;

      // Sempre atualizar status do veículo para 'Disponível' ao deletar contrato
      if (contract.uses_multiple_vehicles) {
        const { data: contractVehicles } = await supabase
          .from('contract_vehicles')
          .select('vehicle_id')
          .eq('contract_id', id);
        if (contractVehicles) {
          const vehicleIds = contractVehicles.map((cv: { vehicle_id: string }) => cv.vehicle_id);
          await supabase.from('vehicles').update({ status: 'Disponível' }).in('id', vehicleIds);
        }
      } else if (contract.vehicle_id) {
        await supabase.from('vehicles').update({ status: 'Disponível' }).eq('id', contract.vehicle_id);
      }

      // Refetch contratos do backend para garantir atualização da listagem
      await fetchContracts();
      toast.success('Contrato removido com sucesso!');
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Erro ao remover contrato';
      setError(errorMsg);
      toast.error(errorMsg);
      throw err;
    } finally {
      setLoading(false);
    }
  }, [fetchContracts]);

  const finalizeExpiredContracts = useCallback(async () => {
    try {
      const now = new Date().toISOString();
      const { error } = await supabase
        .from('contracts')
        .update({ status: 'finalized', updated_at: now })
        .lt('end_date', now)
        .eq('status', 'active');

      if (error) throw error;
      await fetchContracts();
    } catch (err) {
      console.error('Erro ao finalizar contratos:', err);
    }
  }, [fetchContracts]);

  const updateContractPaymentStatus = useCallback(async (id: string, paymentStatus: string) => {
    try {
      const { error } = await supabase
        .from('contracts')
        .update({ payment_status: paymentStatus })
        .eq('id', id);

      if (error) throw error;
      await fetchContracts();
    } catch (err) {
      console.error('Erro ao atualizar status de pagamento:', err);
    }
  }, [fetchContracts]);

  const calculateContractTotal = (contract: Contract) => {
    if (!contract.daily_rate || !contract.start_date || !contract.end_date) return 0;
    
    const start = new Date(contract.start_date);
    const end = new Date(contract.end_date);
    const days = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
    
    return contract.daily_rate * days;
  };

  const calculateContractPaid = (contract: Contract) => {
    return typeof (contract as any).paid_amount === 'number' ? (contract as any).paid_amount : 0;
  };

  const getAvailableVehicles = async (startDate: string, endDate: string, excludeContractId?: string) => {
    try {
      // Validate dates
      if (!startDate || !endDate) {
        throw new Error('Datas de início e fim são obrigatórias');
      }

      const start = new Date(startDate);
      const end = new Date(endDate);
      
      if (start >= end) {
        throw new Error('Data de início deve ser anterior à data de fim');
      }

      // Get available vehicles using the simpler database function
      const { data, error } = await supabase
        .rpc('fn_available_vehicles', {
          p_start_date: startDate,
          p_end_date: endDate,
          p_tenant_id: '00000000-0000-0000-0000-000000000001',
          p_exclude_contract_id: excludeContractId || null
        });

      if (error) {
        console.error('Database error in getAvailableVehicles:', error);
        throw error;
      }

      return data || [];
    } catch (err: unknown) {
      console.error('Error getting available vehicles:', err);
      throw err;
    }
  };

  const checkContractConflicts = async (vehicleIds: string | string[], startDate: string, endDate: string, excludeContractId?: string) => {
    try {
      // Convert single ID to array for consistency
      const ids = Array.isArray(vehicleIds) ? vehicleIds : [vehicleIds];
      
      // Filter out empty IDs
      const validIds = ids.filter(id => id && id.trim() !== '');
      
      if (validIds.length === 0) {
        return {
          has_conflict: false,
          conflicts: [],
          conflicting_vehicles: [],
          conflict_details: []
        };
      }
      
      // Build query with detailed information
      let query = supabase
        .from('contracts')
        .select(`
          id, 
          vehicle_id, 
          start_date, 
          end_date, 
          status,
          contract_number,
          customer_id,
          customers(name, document)
        `)
        .in('vehicle_id', validIds)
        .eq('status', 'Ativo');
      
      // Only add neq filter if excludeContractId is provided and valid
      if (excludeContractId && excludeContractId.trim() !== '') {
        query = query.neq('id', excludeContractId);
      }
      
      // Add date conflict filter
      const { data, error } = await query
        .or(`start_date.lte.${endDate},end_date.gte.${startDate}`);

      if (error) throw error;

      // Format conflict details for better user experience
      const conflictDetails = data.map(contract => {
        const customer = Array.isArray(contract.customers) ? contract.customers[0] : contract.customers;
        return {
          contract_id: contract.id,
          contract_number: contract.contract_number || 'N/A',
          customer_name: customer?.name || 'Cliente não identificado',
          customer_document: customer?.document || 'N/A',
          vehicle_id: contract.vehicle_id,
          start_date: contract.start_date,
          end_date: contract.end_date,
          conflict_message: `Contrato ${contract.contract_number || 'N/A'} - ${customer?.name || 'Cliente não identificado'} (${contract.start_date} a ${contract.end_date})`
        };
      });

      // Return object with detailed conflict information
      return {
        has_conflict: data.length > 0,
        conflicts: data,
        conflicting_vehicles: data.map(c => c.vehicle_id),
        conflict_details: conflictDetails
      };
    } catch (err) {
      console.error('Error checking contract conflicts:', err);
      throw err;
    }
  };

  useEffect(() => {
    fetchContracts();
    fetchStatistics();
  }, [fetchContracts, fetchStatistics]);

  /**
   * Retorna veículos atualmente "Em Uso" (associados a contratos ativos no período atual)
   * Considera contratos com múltiplos veículos (contract_vehicles) e tenant_id
   */
  const getInUseVehicles = async () => {
    try {
      const now = new Date().toISOString();
      // Buscar contratos ativos do tenant, no período atual
      const { data: contracts, error } = await supabase
        .from('contracts')
        .select('id, vehicle_id, uses_multiple_vehicles, start_date, end_date, status')
        .eq('tenant_id', TENANT_ID)
        .eq('status', 'Ativo')
        .lte('start_date', now)
        .gte('end_date', now);
      if (error) throw error;

      // IDs de veículos em uso
      let vehicleIds: string[] = [];
      // Contratos com múltiplos veículos
      const multiContracts = contracts.filter(c => c.uses_multiple_vehicles);
      if (multiContracts.length > 0) {
        const contractIds = multiContracts.map(c => c.id);
        const { data: contractVehicles, error: cvError } = await supabase
          .from('contract_vehicles')
          .select('vehicle_id, contract_id')
          .in('contract_id', contractIds);
        if (cvError) throw cvError;
        vehicleIds = [
          ...vehicleIds,
          ...contractVehicles.map((cv: any) => cv.vehicle_id)
        ];
      }
      // Contratos com veículo único
      const singleVehicleIds = contracts
        .filter(c => !c.uses_multiple_vehicles && c.vehicle_id)
        .map(c => c.vehicle_id);
      vehicleIds = [
        ...vehicleIds,
        ...singleVehicleIds
      ];
      // Remover duplicados
      vehicleIds = Array.from(new Set(vehicleIds));
      if (vehicleIds.length === 0) return [];
      // Buscar dados dos veículos
      const { data: vehicles, error: vError } = await supabase
        .from('vehicles')
        .select('*')
        .in('id', vehicleIds);
      if (vError) throw vError;
      return vehicles || [];
    } catch (err: unknown) {
      setError((err as Error).message || 'Erro ao buscar veículos em uso');
      throw err;
    }
  };

  return {
    contracts,
    statistics,
    loading,
    error,
    refetch: fetchContracts,
    refetchStatistics: fetchStatistics,
    createContract,
    updateContract,
    deleteContract,
    finalizeExpiredContracts,
    updateContractPaymentStatus,
    calculateContractTotal,
    calculateContractPaid,
    getAvailableVehicles,
    checkContractConflicts,
    getInUseVehicles
  };
}