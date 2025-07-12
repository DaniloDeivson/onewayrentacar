import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';

export interface Supplier {
  id: string;
  tenant_id: string;
  name: string;
  document: string | null;
  contact_info: {
    email?: string | null;
    phone?: string | null;
    address?: string | null;
    contact_person?: string | null;
  };
  created_at: string;
  updated_at: string;
}

export interface SupplierInsert {
  name: string;
  document?: string | null;
  contact_info: {
    email?: string | null;
    phone?: string | null;
    address?: string | null;
    contact_person?: string | null;
  };
}

export interface SupplierUpdate {
  name?: string;
  document?: string | null;
  contact_info?: {
    email?: string | null;
    phone?: string | null;
    address?: string | null;
    contact_person?: string | null;
  };
}

export const useSuppliers = () => {
  const [suppliers, setSuppliers] = useState<Supplier[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchSuppliers = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('suppliers')
        .select('*')
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('name', { ascending: true });

      if (error) throw error;
      setSuppliers(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const createSupplier = async (supplierData: SupplierInsert) => {
    try {
      const { data, error } = await supabase
        .from('suppliers')
        .insert([{ ...supplierData, tenant_id: DEFAULT_TENANT_ID }])
        .select()
        .single();

      if (error) throw error;
      setSuppliers(prev => [...prev, data].sort((a, b) => a.name.localeCompare(b.name)));
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to create supplier');
    }
  };

  const updateSupplier = async (id: string, updates: SupplierUpdate) => {
    try {
      const { data, error } = await supabase
        .from('suppliers')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      setSuppliers(prev => prev.map(s => s.id === id ? data : s));
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to update supplier');
    }
  };

  const deleteSupplier = async (id: string) => {
    try {
      const { error } = await supabase
        .from('suppliers')
        .delete()
        .eq('id', id);

      if (error) throw error;
      setSuppliers(prev => prev.filter(s => s.id !== id));
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to delete supplier');
    }
  };

  useEffect(() => {
    fetchSuppliers();
  }, []);

  return {
    suppliers,
    loading,
    error,
    createSupplier,
    updateSupplier,
    deleteSupplier,
    refetch: fetchSuppliers
  };
};