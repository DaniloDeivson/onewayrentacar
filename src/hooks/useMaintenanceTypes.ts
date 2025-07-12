import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import { Database } from '../types/database';

type MaintenanceType = Database['public']['Tables']['maintenance_types']['Row'];
type MaintenanceTypeInsert = Database['public']['Tables']['maintenance_types']['Insert'];

export const useMaintenanceTypes = () => {
  const [maintenanceTypes, setMaintenanceTypes] = useState<MaintenanceType[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchMaintenanceTypes = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('maintenance_types')
        .select('*')
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('name', { ascending: true });

      if (error) throw error;
      setMaintenanceTypes(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const createMaintenanceType = async (data: Omit<MaintenanceTypeInsert, 'tenant_id'>) => {
    try {
      const { data: newType, error } = await supabase
        .from('maintenance_types')
        .insert([{ ...data, tenant_id: DEFAULT_TENANT_ID }])
        .select()
        .single();

      if (error) throw error;
      setMaintenanceTypes(prev => [...prev, newType].sort((a, b) => a.name.localeCompare(b.name)));
      return newType;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to create maintenance type');
    }
  };

  useEffect(() => {
    fetchMaintenanceTypes();
  }, []);

  return {
    maintenanceTypes,
    loading,
    error,
    createMaintenanceType,
    refetch: fetchMaintenanceTypes
  };
};