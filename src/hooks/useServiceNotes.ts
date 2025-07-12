import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import { Database } from '../types/database';
import toast from 'react-hot-toast';
import { PartCartItem } from './useServiceOrderParts';

type ServiceNote = Database['public']['Tables']['service_notes']['Row'] & {
  vehicles?: { plate: string };
  employees?: { name: string; role: string };
};
type ServiceNoteInsert = Database['public']['Tables']['service_notes']['Insert'];
type ServiceNoteUpdate = Database['public']['Tables']['service_notes']['Update'];

export const useServiceNotes = () => {
  const [serviceNotes, setServiceNotes] = useState<ServiceNote[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchServiceNotes = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('service_notes')
        .select(`
          *,
          vehicles (
            plate
          ),
          employees (
            name,
            role
          )
        `)
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('start_date', { ascending: false });

      if (error) throw error;
      setServiceNotes(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
      toast.error('Erro ao carregar ordens de serviço');
    } finally {
      setLoading(false);
    }
  };

  const createServiceNote = async (serviceNoteData: Omit<ServiceNoteInsert, 'tenant_id'>) => {
    try {
      const { data, error } = await supabase
        .from('service_notes')
        .insert([{ ...serviceNoteData, tenant_id: DEFAULT_TENANT_ID }])
        .select(`
          *,
          vehicles (
            plate
          ),
          employees (
            name,
            role
          )
        `)
        .single();

      if (error) throw error;
      setServiceNotes(prev => [data, ...prev]);
      toast.success('Ordem de serviço criada com sucesso!');
      return data;
    } catch (err) {
      toast.error('Erro ao criar ordem de serviço: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to create service note');
    }
  };

  const updateServiceNote = async (id: string, updates: ServiceNoteUpdate) => {
    try {
      console.log('Updating service note:', { id, updates });
      
      // Remove any undefined or null values that might cause issues
      const cleanUpdates = Object.fromEntries(
        Object.entries(updates).filter(([, value]) => value !== undefined && value !== null)
      );
      
      console.log('Clean updates:', cleanUpdates);
      
      const { data, error } = await supabase
        .from('service_notes')
        .update({ ...cleanUpdates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select(`
          *,
          vehicles (
            plate
          ),
          employees (
            name,
            role
          )
        `)
        .single();

      if (error) {
        console.error('Supabase error:', error);
        throw error;
      }
      
      console.log('Update successful:', data);
      setServiceNotes(prev => prev.map(sn => sn.id === id ? data : sn));
      toast.success('Ordem de serviço atualizada com sucesso!');
      return data;
    } catch (err) {
      console.error('Update service note error:', err);
      const errorMessage = err instanceof Error ? err.message : 'Erro desconhecido';
      toast.error('Erro ao atualizar ordem de serviço: ' + errorMessage);
      throw new Error('Failed to update service note: ' + errorMessage);
    }
  };

  const deleteServiceNote = async (id: string) => {
    try {
      // First check if there are any active check-ins for this service note
      const { data: activeCheckins, error: checkError } = await supabase
        .from('maintenance_checkins')
        .select('id')
        .eq('service_note_id', id)
        .is('checkout_at', null)
        .limit(1);
      
      if (checkError) throw checkError;
      
      if (activeCheckins && activeCheckins.length > 0) {
        throw new Error('Não é possível excluir uma ordem de serviço com check-in ativo. Faça o check-out primeiro.');
      }
      
      // Step 1: Delete service_order_parts first (this will trigger stock reversal)
      const { error: partsError } = await supabase
        .from('service_order_parts')
        .delete()
        .eq('service_note_id', id);
      
      if (partsError) {
        console.error('Error deleting service order parts:', partsError);
        throw partsError;
      }
      
      // Step 2: Delete maintenance_checkins
      const { error: checkinsError } = await supabase
        .from('maintenance_checkins')
        .delete()
        .eq('service_note_id', id);
      
      if (checkinsError) {
        console.error('Error deleting maintenance checkins:', checkinsError);
        throw checkinsError;
      }
      
      // Step 3: Update stock_movements to remove service_note_id reference
      const { error: stockError } = await supabase
        .from('stock_movements')
        .update({ service_note_id: null })
        .eq('service_note_id', id);
      
      if (stockError) {
        console.error('Error updating stock movements:', stockError);
        throw stockError;
      }
      
      // Step 4: Update costs to remove service_note reference
      const { error: costsError } = await supabase
        .from('costs')
        .update({ 
          source_reference_id: null, 
          source_reference_type: 'manual' 
        })
        .eq('source_reference_id', id)
        .eq('source_reference_type', 'service_note');
      
      if (costsError) {
        console.error('Error updating costs:', costsError);
        throw costsError;
      }
      
      // Step 5: Finally delete the service note
      const { error } = await supabase
        .from('service_notes')
        .delete()
        .eq('id', id);

      if (error) {
        console.error('Error deleting service note:', error);
        throw error;
      }
      
      setServiceNotes(prev => prev.filter(sn => sn.id !== id));
      toast.success('Ordem de serviço excluída com sucesso!');
    } catch (err) {
      console.error('Delete service note error:', err);
      toast.error('Erro ao excluir ordem de serviço: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to delete service note');
    }
  };

  useEffect(() => {
    fetchServiceNotes();
  }, []);

  return {
    serviceNotes,
    loading,
    error,
    createServiceNote,
    updateServiceNote,
    deleteServiceNote,
    refetch: fetchServiceNotes
  };
};

// Função utilitária pura para criar ordem de serviço + peças
export async function createServiceNoteWithParts(
  createServiceNoteFn: (data: Omit<ServiceNoteInsert, 'tenant_id'>) => Promise<ServiceNote>,
  addPartsToServiceOrderFn: (serviceNoteId: string, parts: PartCartItem[]) => Promise<unknown>,
  serviceNoteData: Omit<ServiceNoteInsert, 'tenant_id'>,
  parts: PartCartItem[]
): Promise<ServiceNote> {
  console.log('createServiceNoteWithParts called with:', { serviceNoteData, parts });
  
  const serviceNote = await createServiceNoteFn(serviceNoteData);
  console.log('Service note created:', serviceNote);
  
  if (serviceNote && serviceNote.id && parts && parts.length > 0) {
    console.log('Adding parts to service note:', parts);
    await addPartsToServiceOrderFn(serviceNote.id, parts);
    console.log('Parts added successfully');
  } else {
    console.log('No parts to add or service note not created properly');
  }
  
  return serviceNote;
}

// Função utilitária pura para atualizar ordem de serviço + peças
export async function updateServiceNoteWithParts(
  updateServiceNoteFn: (id: string, updates: ServiceNoteUpdate) => Promise<ServiceNote>,
  addPartsToServiceOrderFn: (serviceNoteId: string, parts: PartCartItem[]) => Promise<unknown>,
  removeAllPartsFromServiceOrderFn: (serviceNoteId: string) => Promise<void>,
  id: string,
  updates: ServiceNoteUpdate,
  parts: PartCartItem[]
): Promise<ServiceNote> {
  const serviceNote = await updateServiceNoteFn(id, updates);
  if (serviceNote && serviceNote.id) {
    await removeAllPartsFromServiceOrderFn(serviceNote.id);
    if (parts && parts.length > 0) {
      await addPartsToServiceOrderFn(serviceNote.id, parts);
    }
  }
  return serviceNote;
}