import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import { Database } from '../types/database';
import toast from 'react-hot-toast';

type Part = Database['public']['Tables']['parts']['Row'];
type PartInsert = Database['public']['Tables']['parts']['Insert'];
type PartUpdate = Database['public']['Tables']['parts']['Update'];

export const useParts = () => {
  const [parts, setParts] = useState<Part[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchParts = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('parts')
        .select('*')
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('name', { ascending: true });

      if (error) throw error;
      setParts(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
      toast.error('Erro ao carregar peças');
    } finally {
      setLoading(false);
    }
  };

  const createPart = async (partData: Omit<PartInsert, 'tenant_id'>) => {
    try {
      const { data, error } = await supabase
        .from('parts')
        .insert([{ ...partData, tenant_id: DEFAULT_TENANT_ID }])
        .select()
        .single();

      if (error) throw error;
      setParts(prev => [...prev, data].sort((a, b) => a.name.localeCompare(b.name)));
      toast.success('Peça criada com sucesso!');
      return data;
    } catch (err) {
      toast.error('Erro ao criar peça: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to create part');
    }
  };

  const updatePart = async (id: string, updates: PartUpdate) => {
    try {
      const { data, error } = await supabase
        .from('parts')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      setParts(prev => prev.map(p => p.id === id ? data : p));
      toast.success('Peça atualizada com sucesso!');
      return data;
    } catch (err) {
      toast.error('Erro ao atualizar peça: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to update part');
    }
  };

  const deletePart = async (id: string) => {
    try {
      // Use the safe deletion function instead of direct delete
      const { error } = await supabase.rpc('safe_delete_part', {
        p_part_id: id
      });

      if (error) throw error;
      setParts(prev => prev.filter(p => p.id !== id));
      toast.success('Peça excluída com sucesso!');
    } catch (err) {
      toast.error('Erro ao excluir peça: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to delete part');
    }
  };

  // Add stock movement
  const addStockMovement = async (partId: string, quantity: number, movementType: 'in' | 'out', reference?: string) => {
    try {
      const { data, error } = await supabase
        .from('stock_movements')
        .insert([{
          tenant_id: DEFAULT_TENANT_ID,
          part_id: partId,
          quantity: movementType === 'in' ? quantity : -quantity,
          movement_type: movementType,
          reference: reference || 'Manual',
          created_by_employee_id: null // Will be set by trigger
        }])
        .select()
        .single();

      if (error) throw error;
      
      // Refresh parts to get updated quantities
      await fetchParts();
      toast.success(`Movimentação de estoque registrada: ${movementType === 'in' ? '+' : '-'}${quantity} unidades`);
      return data;
    } catch (err) {
      toast.error('Erro ao registrar movimentação: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to add stock movement');
    }
  };

  // Get stock movements for a part
  const getStockMovements = async (partId: string) => {
    try {
      const { data, error } = await supabase
        .from('stock_movements')
        .select(`
          *,
          parts (
            name,
            sku
          )
        `)
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .eq('part_id', partId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return data || [];
    } catch (err) {
      console.error('Error fetching stock movements:', err);
      return [];
    }
  };

  // Get low stock parts
  const getLowStockParts = async () => {
    try {
      const { data, error } = await supabase
        .from('parts')
        .select('*')
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .lte('current_quantity', 'min_stock')
        .order('current_quantity', { ascending: true });

      if (error) throw error;
      return data || [];
    } catch (err) {
      console.error('Error fetching low stock parts:', err);
      return [];
    }
  };

  // Get out of stock parts
  const getOutOfStockParts = async () => {
    try {
      const { data, error } = await supabase
        .from('parts')
        .select('*')
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .eq('current_quantity', 0)
        .order('name', { ascending: true });

      if (error) throw error;
      return data || [];
    } catch (err) {
      console.error('Error fetching out of stock parts:', err);
      return [];
    }
  };

  useEffect(() => {
    fetchParts();
  }, []);

  return {
    parts,
    loading,
    error,
    createPart,
    updatePart,
    deletePart,
    addStockMovement,
    getStockMovements,
    getLowStockParts,
    getOutOfStockParts,
    refetch: fetchParts
  };
};