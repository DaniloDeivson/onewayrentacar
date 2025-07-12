import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';

export interface Guest {
  id: string;
  tenant_id: string;
  auth_user_id: string | null;
  name: string;
  email: string;
  phone: string | null;
  document: string | null;
  address: string | null;
  status: 'active' | 'inactive' | 'blocked';
  created_at: string;
  updated_at: string;
}

export interface GuestInsert {
  name: string;
  email: string;
  phone?: string | null;
  document?: string | null;
  address?: string | null;
  status?: 'active' | 'inactive' | 'blocked';
  auth_user_id?: string | null;
}

export const useGuests = () => {
  const [guests, setGuests] = useState<Guest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchGuests = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('guest_users')
        .select('*')
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setGuests(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao carregar guests');
    } finally {
      setLoading(false);
    }
  };

  const createGuest = async (guestData: GuestInsert) => {
    try {
      const { data, error } = await supabase
        .from('guest_users')
        .insert([{ 
          ...guestData, 
          tenant_id: DEFAULT_TENANT_ID,
          status: guestData.status || 'active'
        }])
        .select()
        .single();

      if (error) throw error;
      await fetchGuests();
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao criar guest');
    }
  };

  const updateGuest = async (id: string, updates: Partial<GuestInsert>) => {
    try {
      const { data, error } = await supabase
        .from('guest_users')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      await fetchGuests();
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao atualizar guest');
    }
  };

  const deleteGuest = async (id: string) => {
    try {
      const { error } = await supabase
        .from('guest_users')
        .delete()
        .eq('id', id);

      if (error) throw error;
      await fetchGuests();
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao excluir guest');
    }
  };

  const getGuestById = async (id: string) => {
    try {
      const { data, error } = await supabase
        .from('guest_users')
        .select('*')
        .eq('id', id)
        .single();

      if (error) throw error;
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao buscar guest');
    }
  };

  const getGuestContracts = async (guestId: string) => {
    try {
      const { data, error } = await supabase
        .from('contracts')
        .select(`
          *,
          vehicles (id, plate, model, brand),
          customers (name, email, phone)
        `)
        .eq('guest_id', guestId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao buscar contratos do guest');
    }
  };

  useEffect(() => {
    fetchGuests();
  }, []);

  return {
    guests,
    loading,
    error,
    createGuest,
    updateGuest,
    deleteGuest,
    getGuestById,
    getGuestContracts,
    refetch: fetchGuests
  };
}; 