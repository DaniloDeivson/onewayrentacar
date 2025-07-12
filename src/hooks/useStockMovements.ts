import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import { Database } from '../types/database';
import toast from 'react-hot-toast';

type StockMovement = Database['public']['Tables']['stock_movements']['Row'] & {
  parts?: { name: string; sku: string };
  service_notes?: { description: string };
};
type StockMovementInsert = Database['public']['Tables']['stock_movements']['Insert'];

export const useStockMovements = () => {
  const [stockMovements, setStockMovements] = useState<StockMovement[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchStockMovements = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('stock_movements')
        .select(`
          *,
          parts (
            name,
            sku
          ),
          service_notes (
            description
          )
        `)
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('movement_date', { ascending: false });

      if (error) throw error;
      setStockMovements(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
      toast.error('Erro ao carregar movimentações de estoque');
    } finally {
      setLoading(false);
    }
  };

  const createStockMovement = async (movementData: Omit<StockMovementInsert, 'tenant_id'>) => {
    try {
      // First, check if we have enough stock for outgoing movements
      if (movementData.type === 'Saída') {
        const { data: partData, error: partError } = await supabase
          .from('parts')
          .select('quantity')
          .eq('id', movementData.part_id)
          .single();
        
        if (partError) throw partError;
        
        if (partData.quantity < movementData.quantity) {
          throw new Error(`Estoque insuficiente. Disponível: ${partData.quantity}, Solicitado: ${movementData.quantity}`);
        }
      }
      
      // Create the stock movement
      const { data, error } = await supabase
        .from('stock_movements')
        .insert([{ ...movementData, tenant_id: DEFAULT_TENANT_ID }])
        .select(`
          *,
          parts (
            name,
            sku
          ),
          service_notes (
            description
          )
        `)
        .single();

      if (error) throw error;
      
      // Update the part quantity using the RPC function
      const updateQuantity = movementData.type === 'Entrada' 
        ? movementData.quantity 
        : -movementData.quantity;
      
      const { error: updateError } = await supabase.rpc('increment_part_quantity', {
        p_part_id: movementData.part_id,
        p_quantity: updateQuantity
      });
      
      if (updateError) throw updateError;
      
      // Fetch the updated part to confirm the quantity change
      const { data: updatedPart, error: fetchError } = await supabase
        .from('parts')
        .select('quantity')
        .eq('id', movementData.part_id)
        .single();
        
      if (fetchError) throw fetchError;
      
      setStockMovements(prev => [data, ...prev]);
      toast.success(`Movimentação de ${movementData.type.toLowerCase()} registrada com sucesso!`);
      return data;
    } catch (err) {
      toast.error('Erro ao registrar movimentação: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to create stock movement');
    }
  };

  useEffect(() => {
    fetchStockMovements();
  }, []);

  return {
    stockMovements,
    loading,
    error,
    createStockMovement,
    refetch: fetchStockMovements
  };
};