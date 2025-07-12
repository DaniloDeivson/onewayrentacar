import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { Database } from '../types/database';
import { useCache } from '../context/CacheContext';

type Customer = Database['public']['Tables']['customers']['Row'];

export function useCustomers() {
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { get, set, has } = useCache();

  const fetchCustomers = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);

      const { data, error } = await supabase
        .from('customers')
        .select('*')
        .order('name', { ascending: true });

      if (error) throw error;
      setCustomers(data);
    } catch (err) {
      console.error('Erro ao buscar clientes:', err);
      setError(err instanceof Error ? err.message : 'Erro ao buscar clientes');
    } finally {
      setLoading(false);
    }
  }, []);

  const createCustomer = useCallback(async (customerData: Partial<Customer>) => {
    try {
      const { data, error } = await supabase
        .from('customers')
        .insert([customerData])
        .select()
        .single();

      if (error) throw error;

      // Buscar lista real do banco após insert
      await fetchCustomers();
      return data;
    } catch (err) {
      console.error('Erro ao criar cliente:', err);
      throw err;
    }
  }, [fetchCustomers]);

  const updateCustomer = useCallback(async (id: string, updates: Partial<Customer>) => {
    try {
      const { data, error } = await supabase
        .from('customers')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;

      // Buscar lista real do banco após update
      await fetchCustomers();
      return data;
    } catch (err) {
      console.error('Erro ao atualizar cliente:', err);
      throw err;
    }
  }, [fetchCustomers]);

  const deleteCustomer = useCallback(async (id: string, email?: string) => {
    try {
      // 1. Deletar employee relacionado, se existir
      if (email) {
        const { error: empError } = await supabase
          .from('employees')
          .delete()
          .filter('contact_info->>email', 'eq', email);
        if (empError) throw empError;
      }
      // 2. Deletar cliente
      const { error } = await supabase
        .from('customers')
        .delete()
        .eq('id', id);

      if (error) throw error;

      // Após deletar, buscar lista real do banco para garantir consistência
      await fetchCustomers();
    } catch (err) {
      console.error('Erro ao deletar cliente:', err);
      throw err;
    }
  }, []);

  useEffect(() => {
    fetchCustomers();
  }, [fetchCustomers]);

  return {
    customers,
    loading,
    error,
    refetch: fetchCustomers,
    createCustomer,
    updateCustomer,
    deleteCustomer
  };
}