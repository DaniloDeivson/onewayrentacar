import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import { Database } from '../types/database';

type Mechanic = Database['public']['Tables']['mechanics']['Row'];
type MechanicInsert = Database['public']['Tables']['mechanics']['Insert'];
type MechanicUpdate = Database['public']['Tables']['mechanics']['Update'];

export const useMechanics = () => {
  const [mechanics, setMechanics] = useState<Mechanic[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchMechanics = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('mechanics')
        .select('*')
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('name', { ascending: true });

      if (error) throw error;
      setMechanics(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const createMechanic = async (data: Omit<MechanicInsert, 'tenant_id'>) => {
    try {
      const { data: newMechanic, error } = await supabase
        .from('mechanics')
        .insert([{ ...data, tenant_id: DEFAULT_TENANT_ID }])
        .select()
        .single();

      if (error) throw error;
      setMechanics(prev => [...prev, newMechanic].sort((a, b) => a.name.localeCompare(b.name)));
      return newMechanic;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to create mechanic');
    }
  };

  const updateMechanic = async (id: string, updates: MechanicUpdate) => {
    try {
      const { data, error } = await supabase
        .from('mechanics')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      setMechanics(prev => prev.map(m => m.id === id ? data : m));
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to update mechanic');
    }
  };

  const deleteMechanic = async (id: string) => {
    try {
      const { error } = await supabase
        .from('mechanics')
        .delete()
        .eq('id', id);

      if (error) throw error;
      setMechanics(prev => prev.filter(m => m.id !== id));
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to delete mechanic');
    }
  };

  useEffect(() => {
    fetchMechanics();
  }, []);

  return {
    mechanics,
    loading,
    error,
    createMechanic,
    updateMechanic,
    deleteMechanic,
    refetch: fetchMechanics
  };
};