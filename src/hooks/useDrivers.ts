import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import { Database } from '../types/database';

type Driver = Database['public']['Tables']['drivers']['Row'];
type DriverInsert = Database['public']['Tables']['drivers']['Insert'];
type DriverUpdate = Database['public']['Tables']['drivers']['Update'];

export const useDrivers = () => {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchDrivers = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('drivers')
        .select('*')
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('name', { ascending: true });

      if (error) throw error;
      setDrivers(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const createDriver = async (driverData: Omit<DriverInsert, 'tenant_id'>) => {
    try {
      const { data, error } = await supabase
        .from('drivers')
        .insert([{ ...driverData, tenant_id: DEFAULT_TENANT_ID }])
        .select()
        .single();

      if (error) throw error;
      setDrivers(prev => [...prev, data].sort((a, b) => a.name.localeCompare(b.name)));
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to create driver');
    }
  };

  const updateDriver = async (id: string, updates: DriverUpdate) => {
    try {
      const { data, error } = await supabase
        .from('drivers')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      setDrivers(prev => prev.map(d => d.id === id ? data : d));
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to update driver');
    }
  };

  const deleteDriver = async (id: string) => {
    try {
      // Check if driver has associated fines
      const { data: finesData, error: finesError } = await supabase
        .from('fines')
        .select('id')
        .eq('driver_id', id)
        .limit(1);
      
      if (finesError) throw finesError;
      
      // If driver has fines, we should handle this case
      if (finesData && finesData.length > 0) {
        // Option 1: Throw an error and prevent deletion
        // throw new Error('Este motorista possui multas associadas e não pode ser excluído');
        
        // Option 2: Set driver_id to null in associated fines
        const { error: updateError } = await supabase
          .from('fines')
          .update({ driver_id: null })
          .eq('driver_id', id);
        
        if (updateError) throw updateError;
      }
      
      // Now delete the driver
      const { error } = await supabase
        .from('drivers')
        .delete()
        .eq('id', id);

      if (error) throw error;
      setDrivers(prev => prev.filter(d => d.id !== id));
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to delete driver');
    }
  };

  useEffect(() => {
    fetchDrivers();
  }, []);

  return {
    drivers,
    loading,
    error,
    createDriver,
    updateDriver,
    deleteDriver,
    refetch: fetchDrivers
  };
};