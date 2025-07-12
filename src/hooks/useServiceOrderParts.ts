import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';

export interface ServiceOrderPart {
  id: string;
  service_note_id: string;
  part_id: string;
  quantity_used: number;
  unit_cost_at_time: number;
  total_cost: number;
  created_at: string;
  parts?: {
    sku: string;
    name: string;
    quantity: number;
  };
}

export interface PartCartItem {
  part_id: string;
  sku: string;
  name: string;
  available_quantity: number;
  quantity_to_use: number;
  unit_cost: number;
  total_cost: number;
}

export const useServiceOrderParts = (serviceNoteId?: string) => {
  const [serviceOrderParts, setServiceOrderParts] = useState<ServiceOrderPart[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchServiceOrderParts = async (noteId: string) => {
    try {
      setLoading(true);
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
        .eq('service_note_id', noteId)
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setServiceOrderParts(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const addPartsToServiceOrder = async (serviceNoteId: string, parts: PartCartItem[]) => {
    try {
      console.log('Adding parts to service order:', { serviceNoteId, parts });

      if (!parts || parts.length === 0) {
        console.log('No parts to add, skipping');
        return [];
      }

      // Validar dados antes de inserir
      const validParts = parts.filter(part => {
        if (!part.part_id) {
          console.error('Part missing part_id:', part);
          return false;
        }
        if (!part.quantity_to_use || part.quantity_to_use <= 0) {
          console.error('Part has invalid quantity:', part);
          return false;
        }
        return true;
      });

      if (validParts.length === 0) {
        console.log('No valid parts to insert');
        return [];
      }

      // Buscar peças existentes para comparar
      const { data: existingParts, error: fetchError } = await supabase
        .from('service_order_parts')
        .select('*')
        .eq('service_note_id', serviceNoteId)
        .eq('tenant_id', DEFAULT_TENANT_ID);

      if (fetchError) {
        console.error('Error fetching existing parts:', fetchError);
        throw fetchError;
      }

      // Verificar se as peças são realmente diferentes
      const existingPartsMap = new Map(
        existingParts?.map(p => [p.part_id, p]) || []
      );

      const partsToInsert = validParts.filter(newPart => {
        const existing = existingPartsMap.get(newPart.part_id);
        if (!existing) return true; // Nova peça
        if (existing.quantity_used !== newPart.quantity_to_use) return true; // Quantidade diferente
        if (Math.abs(existing.unit_cost_at_time - newPart.unit_cost) > 0.01) return true; // Custo diferente
        return false; // Mesma peça, mesma quantidade, mesmo custo
      });

      const partsToUpdate = validParts.filter(newPart => {
        const existing = existingPartsMap.get(newPart.part_id);
        return existing && (
          existing.quantity_used !== newPart.quantity_to_use ||
          Math.abs(existing.unit_cost_at_time - newPart.unit_cost) > 0.01
        );
      });

      const partsToDelete = existingParts?.filter(existing => 
        !validParts.some(newPart => newPart.part_id === existing.part_id)
      ) || [];

      console.log('Parts analysis:', {
        toInsert: partsToInsert.length,
        toUpdate: partsToUpdate.length,
        toDelete: partsToDelete.length,
        unchanged: validParts.length - partsToInsert.length - partsToUpdate.length
      });

      // Se não há mudanças, retornar as peças existentes
      if (partsToInsert.length === 0 && partsToUpdate.length === 0 && partsToDelete.length === 0) {
        console.log('No changes detected, returning existing parts');
        if (serviceNoteId) {
          await fetchServiceOrderParts(serviceNoteId);
        }
        return existingParts || [];
      }

      // Deletar peças que não estão mais na lista
      if (partsToDelete.length > 0) {
        const { error: deleteError } = await supabase
          .from('service_order_parts')
          .delete()
          .in('id', partsToDelete.map(p => p.id));

        if (deleteError) {
          console.error('Error deleting removed parts:', deleteError);
          throw deleteError;
        }
        console.log('Removed parts deleted:', partsToDelete.length);
      }

      // Atualizar peças existentes
      for (const part of partsToUpdate) {
        const existing = existingPartsMap.get(part.part_id);
        if (existing) {
          const { error: updateError } = await supabase
            .from('service_order_parts')
            .update({
              quantity_used: part.quantity_to_use,
              unit_cost_at_time: Math.max(part.unit_cost || 0, 0.01),
              updated_at: new Date().toISOString()
            })
            .eq('id', existing.id);

          if (updateError) {
            console.error('Error updating part:', existing.id, updateError);
            throw updateError;
          }
        }
      }

      // Inserir novas peças
      let insertedParts: ServiceOrderPart[] = [];
      if (partsToInsert.length > 0) {
        const partsToInsertData = partsToInsert.map(part => ({
          tenant_id: DEFAULT_TENANT_ID,
          service_note_id: serviceNoteId,
          part_id: part.part_id,
          quantity_used: part.quantity_to_use,
          unit_cost_at_time: Math.max(part.unit_cost || 0, 0.01)
        }));

        console.log('Inserting new parts:', partsToInsertData);

        try {
          const { data, error } = await supabase
            .from('service_order_parts')
            .insert(partsToInsertData)
            .select(`
              *,
              parts (
                sku,
                name,
                quantity
              )
            `);

          if (error) {
            console.error('Error inserting parts in batch:', error);
            throw error;
          }

          insertedParts = data || [];
          console.log('New parts inserted successfully:', insertedParts.length);
        } catch (batchError) {
          console.error('Batch insert failed, trying individual inserts:', batchError);
          
          // Fallback: inserir peças uma por vez
          for (const partData of partsToInsertData) {
            try {
              const { data, error } = await supabase
                .from('service_order_parts')
                .insert([partData])
                .select(`
                  *,
                  parts (
                    sku,
                    name,
                    quantity
                  )
                `)
                .single();

              if (error) {
                console.error('Error inserting part:', partData, error);
                continue;
              }

              if (data) {
                insertedParts.push(data);
              }
            } catch (partError) {
              console.error('Error inserting individual part:', partData, partError);
            }
          }
        }
      }

      // Atualizar a lista local
      if (serviceNoteId) {
        await fetchServiceOrderParts(serviceNoteId);
      }

      console.log('Parts operation completed successfully');
      return insertedParts;
    } catch (err) {
      console.error('Error in addPartsToServiceOrder:', err);
      throw new Error(err instanceof Error ? err.message : 'Failed to add parts to service order');
    }
  };

  const removePartFromServiceOrder = async (serviceOrderPartId: string) => {
    try {
      const { error } = await supabase
        .from('service_order_parts')
        .delete()
        .eq('id', serviceOrderPartId);

      if (error) throw error;
      
      setServiceOrderParts(prev => prev.filter(p => p.id !== serviceOrderPartId));
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to remove part from service order');
    }
  };

  useEffect(() => {
    if (serviceNoteId) {
      fetchServiceOrderParts(serviceNoteId);
    }
  }, [serviceNoteId]);

  return {
    serviceOrderParts,
    loading,
    error,
    addPartsToServiceOrder,
    removePartFromServiceOrder,
    refetch: serviceNoteId ? () => fetchServiceOrderParts(serviceNoteId) : undefined
  };
};