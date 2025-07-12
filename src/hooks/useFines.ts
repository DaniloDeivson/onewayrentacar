import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import { Database } from '../types/database';
import { useAuth } from './useAuth';
import toast from 'react-hot-toast';

type Fine = Database['public']['Tables']['fines']['Row'] & {
  vehicles?: { plate: string; model: string; year: number };
  drivers?: { name: string; cpf: string | null };
  employees?: { name: string; role: string };
  contract_id?: string;
  customer_id?: string;
  customer_name?: string;
  contracts?: { id: string; contract_number: string };
  customers?: { id: string; name: string };
};

type FineInsert = Database['public']['Tables']['fines']['Insert'];
type FineUpdate = Database['public']['Tables']['fines']['Update'];

interface FineStatistics {
  total_fines: number;
  pending_fines: number;
  paid_fines: number;
  contested_fines: number;
  total_amount: number;
  pending_amount: number;
  notified_count: number;
  not_notified_count: number;
  avg_fine_amount: number;
  most_common_infraction: string;
  most_fined_vehicle: string;
}

export const useFines = () => {
  const [fines, setFines] = useState<Fine[]>([]);
  const [statistics, setStatistics] = useState<FineStatistics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { user } = useAuth();

  const fetchFines = async () => {
    try {
      setLoading(true);
      let data;
      let error;

      // Se for motorista, usar a função específica para drivers
      if (user?.role === 'Driver') {
        const result = await supabase.rpc('get_driver_fines', {
          p_driver_id: user.id
        });
        data = result.data;
        error = result.error;
      } else {
        // Para outros papéis, usar a lógica existente
        // Try to use the detailed view first, fallback to direct query
        ({ data, error } = await supabase
          .from('vw_fines_detailed')
          .select('*')
          .eq('tenant_id', DEFAULT_TENANT_ID)
          .order('created_at', { ascending: false }));

        // If view doesn't exist, query directly
        if (error || !data) {
          const { data: directData, error: directError } = await supabase
            .from('fines')
            .select(`
              *,
              vehicles (
                plate,
                model,
                year
              ),
              drivers (
                name,
                cpf
              ),
              employees (
                name,
                role
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
            .order('created_at', { ascending: false });

          if (directError) throw directError;
          data = directData;
        }
      }

      if (error) throw error;

      // Associate fines with contracts based on date
      const enhancedFines = await associateFinesWithContracts(data || []);
      setFines(enhancedFines);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
      toast.error('Erro ao carregar multas');
    } finally {
      setLoading(false);
    }
  };

  // Function to associate fines with contracts based on date
  const associateFinesWithContracts = async (finesData: Fine[]) => {
    try {
      // Get all active contracts
      const { data: contracts, error } = await supabase
        .from('contracts')
        .select(`
          id,
          customer_id,
          vehicle_id,
          start_date,
          end_date,
          customers (
            id,
            name
          )
        `)
        .eq('tenant_id', DEFAULT_TENANT_ID);

      if (error) throw error;

      // Associate each fine with a contract if dates match
      return finesData.map(fine => {
        const matchingContract = contracts?.find(contract => 
          contract.vehicle_id === fine.vehicle_id &&
          new Date(fine.infraction_date) >= new Date(contract.start_date) &&
          new Date(fine.infraction_date) <= new Date(contract.end_date)
        );

        if (matchingContract) {
          return {
            ...fine,
            contract_id: matchingContract.id,
            customer_id: matchingContract.customer_id,
            customer_name: matchingContract.customers?.name
          };
        }
        return fine;
      });
    } catch (err) {
      console.error('Error associating fines with contracts:', err);
      return finesData;
    }
  };

  const fetchStatistics = async () => {
    try {
      const { data, error } = await supabase
        .rpc('fn_fines_statistics', { p_tenant_id: DEFAULT_TENANT_ID });

      if (error) throw error;
      if (data && data.length > 0) {
        setStatistics(data[0]);
      }
    } catch (err) {
      console.error('Error fetching fines statistics:', err);
    }
  };

  // Test function to verify basic insert capability
  const testBasicInsert = async () => {
    try {
      console.log('Testing basic insert...');
      const testData = {
        vehicle_id: 'test-vehicle-id',
        employee_id: 'test-employee-id',
        infraction_type: 'Teste',
        amount: 100.00,
        infraction_date: '2024-01-01',
        due_date: '2024-01-31',
        status: 'Pendente' as const,
        tenant_id: DEFAULT_TENANT_ID
      };
      
      const { data, error } = await supabase
        .from('fines')
        .insert([testData])
        .select('*')
        .single();
        
      if (error) {
        console.error('Test insert failed:', error);
        return { success: false, error };
      }
      
      console.log('Test insert successful:', data);
      
      // Clean up test data
      await supabase.from('fines').delete().eq('id', data.id);
      
      return { success: true, data };
    } catch (err) {
      console.error('Test insert exception:', err);
      return { success: false, error: err };
    }
  };

  const createFine = async (fineData: Omit<FineInsert, 'tenant_id'>) => {
    try {
      // Validate required fields before sending to Supabase
      const requiredFields = ['vehicle_id', 'employee_id', 'infraction_type', 'amount', 'infraction_date', 'due_date'];
      const missingFields = requiredFields.filter(field => !fineData[field as keyof typeof fineData]);
      if (missingFields.length > 0) {
        const errorMsg = `Missing required fields: ${missingFields.join(', ')}`;
        throw new Error(errorMsg);
      }
      // Validate data types
      if (typeof fineData.amount !== 'number' || fineData.amount <= 0) {
        throw new Error('Amount must be a positive number');
      }
      if (fineData.points !== undefined && fineData.points !== null && (typeof fineData.points !== 'number' || fineData.points < 0)) {
        throw new Error('Points must be a non-negative number');
      }
      // Tratar fine_number vazio como null para evitar conflito desnecessário
      const fineToInsert = {
        ...fineData,
        fine_number: fineData.fine_number && fineData.fine_number !== '' ? fineData.fine_number : null,
        tenant_id: DEFAULT_TENANT_ID
      };
      // First, try to insert without complex select to isolate the issue
      const { data: insertedData, error: insertError } = await supabase
        .from('fines')
        .insert([fineToInsert])
        .select('*')
        .single();
      if (insertError) {
        // Checagem extra para erro de chave duplicada
        if (insertError.message && insertError.message.includes('duplicate key')) {
          throw new Error('Já existe uma multa com esse número. Escolha outro número ou deixe em branco.');
        }
        throw insertError;
      }
      
      // Now try to get the full data with relationships
      const { data: fullData, error: selectError } = await supabase
        .from('fines')
        .select(`
          *,
          vehicles (
            plate,
            model,
            year
          ),
          drivers (
            name,
            cpf
          ),
          employees (
            name,
            role
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
        .eq('id', insertedData.id)
        .single();

      if (selectError) {
        console.error('Select error:', selectError);
        // Even if select fails, we still have the inserted data
        setFines(prev => [insertedData, ...prev]);
        await fetchStatistics();
        toast.success('Multa registrada com sucesso!');
        return insertedData;
      }
      
      // Associate with contract if applicable
      const enhancedFine = await associateFinesWithContracts([fullData]);
      setFines(prev => [enhancedFine[0], ...prev]);
      await fetchStatistics();
      toast.success('Multa registrada com sucesso!');
      return enhancedFine[0];
    } catch (err) {
      // More detailed error handling
      if (err && typeof err === 'object' && 'message' in err) {
        const errorMessage = (err as any).message;
        if (errorMessage.includes('foreign key')) {
          toast.error('Erro: Veículo, funcionário ou motorista não encontrado.');
        } else if (errorMessage.includes('check constraint')) {
          toast.error('Erro: Dados inválidos. Verifique os valores inseridos.');
        } else if (errorMessage.includes('not null')) {
          toast.error('Erro: Campos obrigatórios não preenchidos.');
        } else {
          toast.error('Erro ao criar multa: ' + errorMessage);
        }
      } else {
        toast.error('Erro ao criar multa: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      }
      
      throw new Error(err instanceof Error ? err.message : 'Failed to create fine');
    }
  };

  const updateFine = async (id: string, updates: FineUpdate) => {
    try {
      console.log('Updating fine with id:', id);
      console.log('Update data:', updates);
      
      // Validate that we have an ID
      if (!id || id === '') {
        throw new Error('ID da multa é obrigatório para atualização');
      }
      
      // First, try to update without complex select to isolate the issue
      const { data: updatedData, error: updateError } = await supabase
        .from('fines')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .eq('tenant_id', DEFAULT_TENANT_ID) // Add tenant_id check for security
        .select('*')
        .single();

      if (updateError) {
        console.error('Update error:', updateError);
        console.error('Update error details:', {
          message: updateError.message,
          details: updateError.details,
          hint: updateError.hint,
          code: updateError.code
        });
        throw updateError;
      }
      
      console.log('Fine updated successfully:', updatedData);
      
      // Now try to get the full data with relationships
      const { data: fullData, error: selectError } = await supabase
        .from('fines')
        .select(`
          *,
          vehicles (
            plate,
            model,
            year
          ),
          drivers (
            name,
            cpf
          ),
          employees (
            name,
            role
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
        .eq('id', id)
        .single();

      if (selectError) {
        console.error('Select error after update:', selectError);
        // Even if select fails, we still have the updated data
        setFines(prev => prev.map(f => f.id === id ? updatedData : f));
        await fetchStatistics();
        toast.success('Multa atualizada com sucesso!');
        return updatedData;
      }
      
      // Associate with contract if applicable
      const enhancedFine = await associateFinesWithContracts([fullData]);
      setFines(prev => prev.map(f => f.id === id ? enhancedFine[0] : f));
      await fetchStatistics();
      toast.success('Multa atualizada com sucesso!');
      return enhancedFine[0];
    } catch (err) {
      console.error('Full update error details:', err);
      
      // More detailed error handling
      if (err && typeof err === 'object' && 'message' in err) {
        const errorMessage = (err as any).message;
        if (errorMessage.includes('foreign key')) {
          toast.error('Erro: Veículo, funcionário ou motorista não encontrado.');
        } else if (errorMessage.includes('check constraint')) {
          toast.error('Erro: Dados inválidos. Verifique os valores inseridos.');
        } else if (errorMessage.includes('not null')) {
          toast.error('Erro: Campos obrigatórios não preenchidos.');
        } else if (errorMessage.includes('No rows')) {
          toast.error('Erro: Multa não encontrada ou sem permissão para editar.');
        } else {
          toast.error('Erro ao atualizar multa: ' + errorMessage);
        }
      } else {
        toast.error('Erro ao atualizar multa: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      }
      
      throw new Error(err instanceof Error ? err.message : 'Failed to update fine');
    }
  };

  const deleteFine = async (id: string) => {
    try {
      console.log('Deleting fine with id:', id);
      
      // Validate that we have an ID
      if (!id || id === '') {
        throw new Error('ID da multa é obrigatório para exclusão');
      }
      
      // First check if the fine exists and belongs to this tenant
      const { data: existingFine, error: checkError } = await supabase
        .from('fines')
        .select('id, tenant_id')
        .eq('id', id)
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .single();
        
      if (checkError) {
        console.error('Error checking fine existence:', checkError);
        if (checkError.code === 'PGRST116') {
          throw new Error('Multa não encontrada ou sem permissão para excluir.');
        }
        throw checkError;
      }
      
      if (!existingFine) {
        throw new Error('Multa não encontrada ou sem permissão para excluir.');
      }
      
      console.log('Fine exists, proceeding with deletion:', existingFine);
      
      const { error: deleteError } = await supabase
        .from('fines')
        .delete()
        .eq('id', id)
        .eq('tenant_id', DEFAULT_TENANT_ID); // Add tenant_id check for security

      if (deleteError) {
        console.error('Delete error:', deleteError);
        console.error('Delete error details:', {
          message: deleteError.message,
          details: deleteError.details,
          hint: deleteError.hint,
          code: deleteError.code
        });
        throw deleteError;
      }
      
      console.log('Fine deleted successfully');
      setFines(prev => prev.filter(f => f.id !== id));
      await fetchStatistics();
      toast.success('Multa excluída com sucesso!');
    } catch (err) {
      console.error('Full delete error details:', err);
      
      // More detailed error handling
      if (err && typeof err === 'object' && 'message' in err) {
        const errorMessage = (err as any).message;
        if (errorMessage.includes('foreign key')) {
          toast.error('Erro: Não é possível excluir multa que possui dependências.');
        } else if (errorMessage.includes('permission')) {
          toast.error('Erro: Sem permissão para excluir esta multa.');
        } else {
          toast.error('Erro ao excluir multa: ' + errorMessage);
        }
      } else {
        toast.error('Erro ao excluir multa: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      }
      
      throw new Error(err instanceof Error ? err.message : 'Failed to delete fine');
    }
  };

  const markAsNotified = async (id: string) => {
    return updateFine(id, { notified: true });
  };

  const markAsNotNotified = async (id: string) => {
    return updateFine(id, { notified: false });
  };

  // Get fines for a specific contract
  const getFinesByContract = async (contractId: string) => {
    try {
      const { data, error } = await supabase
        .from('fines')
        .select(`
          *,
          vehicles (
            plate,
            model,
            year
          ),
          drivers (
            name,
            cpf
          ),
          employees (
            name,
            role
          )
        `)
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .eq('contract_id', contractId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return data || [];
    } catch (err) {
      console.error('Error fetching fines by contract:', err);
      return [];
    }
  };

  // Get fines for a specific vehicle
  const getFinesByVehicle = async (vehicleId: string) => {
    try {
      const { data, error } = await supabase
        .from('fines')
        .select(`
          *,
          drivers (
            name,
            cpf
          ),
          employees (
            name,
            role
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
        .eq('vehicle_id', vehicleId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return data || [];
    } catch (err) {
      console.error('Error fetching fines by vehicle:', err);
      return [];
    }
  };

  useEffect(() => {
    fetchFines();
    fetchStatistics();
  }, []);

  return {
    fines,
    statistics,
    loading,
    error,
    createFine,
    updateFine,
    deleteFine,
    markAsNotified,
    markAsNotNotified,
    getFinesByContract,
    getFinesByVehicle,
    refetch: fetchFines
  };
};