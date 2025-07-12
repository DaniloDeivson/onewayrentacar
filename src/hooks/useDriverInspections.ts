import { useState, useEffect, useCallback } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import { Database } from '../types/database';
import { useAuth } from './useAuth';

type Inspection = Database['public']['Tables']['inspections']['Row'];

export interface DriverInspection {
  id: string;
  tenant_id: string;
  vehicle_id: string;
  contract_id: string | null;
  guest_id: string | null;
  driver_employee_id: string | null;
  driver_name: string;
  inspection_type: 'checkout' | 'checkin';
  checklist: Record<string, boolean>;
  fuel_level: number | null;
  mileage: number | null;
  damage_photos: string[];
  signature_url: string | null;
  notes: string | null;
  status: 'pending' | 'completed' | 'approved';
  approved_by_employee_id: string | null;
  approved_at: string | null;
  created_at: string;
  updated_at: string;
  // Campos da view
  vehicle_plate?: string;
  vehicle_model?: string;
  guest_name?: string;
  driver_employee_name?: string;
  approved_by_name?: string;
}

export interface DriverInspectionInsert {
  vehicle_id: string;
  contract_id?: string | null;
  guest_id?: string | null;
  driver_employee_id?: string | null;
  driver_name: string;
  inspection_type: 'checkout' | 'checkin';
  checklist?: Record<string, boolean>;
  fuel_level?: number | null;
  mileage?: number | null;
  damage_photos?: string[];
  signature_url?: string | null;
  notes?: string | null;
  status?: 'pending' | 'completed' | 'approved';
}

interface CreateInspectionData {
  vehicle_id: string;
  inspection_type: string;
  items: {
    location: string;
    condition: string;
    notes?: string;
    images?: string[];
  }[];
  notes?: string;
  mileage: number;
}

export const useDriverInspections = () => {
  const [inspections, setInspections] = useState<DriverInspection[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { user } = useAuth();

  const fetchInspections = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('vw_driver_inspections_detailed')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setInspections(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao carregar inspeções');
    } finally {
      setLoading(false);
    }
  };

  const createInspection = useCallback(async (data: CreateInspectionData) => {
    if (!user?.id) return null;

    try {
      setLoading(true);
      setError(null);

      // Verificar se o motorista tem acesso ao veículo
      const { data: hasAccess, error: accessError } = await supabase
        .from('driver_vehicles')
        .select('id')
        .eq('driver_id', user.id)
        .eq('vehicle_id', data.vehicle_id)
        .eq('active', true)
        .single();

      if (accessError || !hasAccess) {
        throw new Error('Você não tem permissão para inspecionar este veículo');
      }

      // Criar a inspeção
      const { data: inspection, error: inspectionError } = await supabase
        .from('inspections')
        .insert([{
          vehicle_id: data.vehicle_id,
          inspector_id: user.id,
          inspection_type: data.inspection_type,
          items: data.items,
          notes: data.notes,
          mileage: data.mileage,
          status: 'completed',
          inspection_date: new Date().toISOString()
        }])
        .select()
        .single();

      if (inspectionError) throw inspectionError;

      return inspection;
    } catch (err) {
      console.error('Erro ao criar inspeção:', err);
      setError(err instanceof Error ? err.message : 'Erro ao criar inspeção');
      return null;
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  const updateInspection = async (id: string, updates: Partial<DriverInspectionInsert>) => {
    try {
      const { data, error } = await supabase
        .from('driver_inspections')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      await fetchInspections();
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao atualizar inspeção');
    }
  };

  const deleteInspection = async (id: string) => {
    try {
      const { error } = await supabase
        .from('driver_inspections')
        .delete()
        .eq('id', id);

      if (error) throw error;
      await fetchInspections();
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao excluir inspeção');
    }
  };

  const approveInspection = async (id: string, approvedBy: string) => {
    try {
      const { data, error } = await supabase
        .from('driver_inspections')
        .update({ 
          status: 'approved',
          approved_by_employee_id: approvedBy,
          approved_at: new Date().toISOString()
        })
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      await fetchInspections();
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao aprovar inspeção');
    }
  };

  const getInspectionsByGuest = async (guestId: string) => {
    try {
      const { data, error } = await supabase
        .from('vw_driver_inspections_detailed')
        .select('*')
        .eq('guest_id', guestId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao buscar inspeções do guest');
    }
  };

  const getInspectionsByVehicle = async (vehicleId: string) => {
    try {
      const { data, error } = await supabase
        .from('vw_driver_inspections_detailed')
        .select('*')
        .eq('vehicle_id', vehicleId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao buscar inspeções do veículo');
    }
  };

  const getInspectionsByContract = async (contractId: string) => {
    try {
      const { data, error } = await supabase
        .from('vw_driver_inspections_detailed')
        .select('*')
        .eq('contract_id', contractId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Erro ao buscar inspeções do contrato');
    }
  };

  useEffect(() => {
    fetchInspections();
  }, []);

  return {
    inspections,
    loading,
    error,
    createInspection,
    updateInspection,
    deleteInspection,
    approveInspection,
    getInspectionsByGuest,
    getInspectionsByVehicle,
    getInspectionsByContract,
    refetch: fetchInspections
  };
}; 