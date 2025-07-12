import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import toast from 'react-hot-toast';

type MaintenanceCheckin = {
  id: string;
  tenant_id: string;
  service_note_id: string;
  mechanic_id: string;
  checkin_at: string;
  checkout_at: string | null;
  notes: string | null;
  signature_url: string | null;
  created_at: string;
  updated_at: string | null;
  // From view
  service_description?: string;
  maintenance_type?: string;
  priority?: string;
  service_status?: string;
  mechanic_name?: string;
  mechanic_code?: string;
  vehicle_id?: string;
  vehicle_plate?: string;
  vehicle_model?: string;
  vehicle_status?: string;
  is_active?: boolean;
  duration?: string;
  is_overdue?: boolean;
};

type MaintenanceCheckinInsert = {
  service_note_id: string;
  mechanic_id: string;
  notes?: string;
  signature_url?: string;
};

type MaintenanceCheckinUpdate = {
  checkout_at?: string;
  notes?: string;
  signature_url?: string;
  updated_at?: string;
};

interface MaintenanceCheckinStatistics {
  total_checkins: number;
  active_checkins: number;
  completed_checkins: number;
  vehicles_in_maintenance: number;
  avg_maintenance_duration: string;
  most_active_mechanic: string;
  longest_maintenance_duration: string;
}

export const useMaintenanceCheckins = () => {
  const [checkins, setCheckins] = useState<MaintenanceCheckin[]>([]);
  const [statistics, setStatistics] = useState<MaintenanceCheckinStatistics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchCheckins = async () => {
    try {
      setLoading(true);
      
      // Try to use the detailed view first
      let { data, error } = await supabase
        .from('vw_maintenance_checkins_detailed')
        .select('*')
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('checkin_at', { ascending: false });

      // If view doesn't exist, query directly
      if (error || !data) {
        const { data: directData, error: directError } = await supabase
          .from('maintenance_checkins')
          .select(`
            *,
            service_notes (
              description,
              maintenance_type,
              priority,
              status,
              vehicle_id,
              vehicles (
                plate,
                model,
                maintenance_status
              )
            ),
            employees (
              name,
              employee_code
            )
          `)
          .eq('tenant_id', DEFAULT_TENANT_ID)
          .order('checkin_at', { ascending: false });

        if (directError) throw directError;
        
        // Transform data to match view structure
        data = directData?.map(checkin => ({
          ...checkin,
          service_description: checkin.service_notes?.description,
          maintenance_type: checkin.service_notes?.maintenance_type,
          priority: checkin.service_notes?.priority,
          service_status: checkin.service_notes?.status,
          mechanic_name: checkin.employees?.name,
          mechanic_code: checkin.employees?.employee_code,
          vehicle_id: checkin.service_notes?.vehicle_id,
          vehicle_plate: checkin.service_notes?.vehicles?.plate,
          vehicle_model: checkin.service_notes?.vehicles?.model,
          vehicle_status: checkin.service_notes?.vehicles?.maintenance_status,
          is_active: !checkin.checkout_at,
          duration: checkin.checkout_at 
            ? new Date(checkin.checkout_at).getTime() - new Date(checkin.checkin_at).getTime()
            : Date.now() - new Date(checkin.checkin_at).getTime(),
          is_overdue: !checkin.checkout_at && 
            new Date(checkin.checkin_at).getTime() < Date.now() - (24 * 60 * 60 * 1000)
        })) || [];
      }

      setCheckins(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
      toast.error('Erro ao carregar check-ins de manutenção');
    } finally {
      setLoading(false);
    }
  };

  const fetchStatistics = async () => {
    try {
      const { data, error } = await supabase
        .rpc('fn_maintenance_checkins_statistics', { p_tenant_id: DEFAULT_TENANT_ID });

      if (error) throw error;
      if (data && data.length > 0) {
        setStatistics(data[0]);
      }
    } catch (err) {
      console.error('Error fetching maintenance checkins statistics:', err);
    }
  };

  const createCheckin = async (checkinData: MaintenanceCheckinInsert) => {
    try {
      const { data, error } = await supabase
        .from('maintenance_checkins')
        .insert([{ ...checkinData, tenant_id: DEFAULT_TENANT_ID }])
        .select()
        .single();

      if (error) throw error;
      await fetchCheckins(); // Refresh to get updated view data
      await fetchStatistics();
      
      // Update service note status to "Em Andamento"
      await supabase
        .from('service_notes')
        .update({ status: 'Em Andamento', updated_at: new Date().toISOString() })
        .eq('id', checkinData.service_note_id);
      
      return data;
    } catch (err) {
      toast.error('Erro ao realizar check-in: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to create check-in');
    }
  };

  const updateCheckin = async (id: string, updates: MaintenanceCheckinUpdate) => {
    try {
      // Ensure updated_at is included in the update
      const updateData = {
        ...updates,
        updated_at: new Date().toISOString()
      };

      const { data, error } = await supabase
        .from('maintenance_checkins')
        .update(updateData)
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      await fetchCheckins(); // Refresh to get updated view data
      await fetchStatistics();
      return data;
    } catch (err) {
      toast.error('Erro ao atualizar check-in: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to update check-in');
    }
  };

  const deleteCheckin = async (id: string) => {
    try {
      const { error } = await supabase
        .from('maintenance_checkins')
        .delete()
        .eq('id', id);

      if (error) throw error;
      setCheckins(prev => prev.filter(c => c.id !== id));
      await fetchStatistics();
      toast.success('Check-in excluído com sucesso!');
    } catch (err) {
      toast.error('Erro ao excluir check-in: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to delete check-in');
    }
  };

  const checkOut = async (id: string, notes?: string, signatureUrl?: string) => {
    try {
      // Get the service note ID and vehicle info before checking out
      const checkin = checkins.find(c => c.id === id);
      if (!checkin) throw new Error('Check-in não encontrado');
      
      const serviceNoteId = checkin.service_note_id;
      
      // Get service note details to check if it has mileage
      const { data: serviceNote } = await supabase
        .from('service_notes')
        .select('mileage, vehicle_id, vehicles(plate)')
        .eq('id', serviceNoteId)
        .single();
      
      // Perform the check-out
      const result = await updateCheckin(id, {
        checkout_at: new Date().toISOString(),
        notes,
        signature_url: signatureUrl
      });
      
      // Update service note status to "Concluída"
      await supabase
        .from('service_notes')
        .update({ 
          status: 'Concluída', 
          end_date: new Date().toISOString().split('T')[0],
          updated_at: new Date().toISOString() 
        })
        .eq('id', serviceNoteId);
      
      // Show notification about mileage update if applicable
      if (serviceNote?.mileage && serviceNote.mileage > 0) {
        toast.success(
          `Check-out realizado com sucesso! Quilometragem do veículo ${(serviceNote.vehicles as any)?.plate} atualizada para ${serviceNote.mileage.toLocaleString('pt-BR')} km.`,
          { duration: 5000 }
        );
        
        // Trigger a refetch of vehicles data to update the fleet page
        setTimeout(() => {
          window.dispatchEvent(new CustomEvent('vehicle-mileage-updated', { 
            detail: { vehicleId: serviceNote.vehicle_id } 
          }));
        }, 1000); // Aguarda 1 segundo para o trigger SQL executar
      } else {
        toast.success('Check-out realizado com sucesso!');
      }
      
      return result;
    } catch (err) {
      toast.error('Erro ao realizar check-out: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to check out');
    }
  };

  const uploadSignature = async (signatureBlob: Blob): Promise<string> => {
    try {
      const fileName = `signature-${Date.now()}.png`;
      const filePath = `maintenance-signatures/${fileName}`;

      const { error: uploadError } = await supabase.storage
        .from('signatures')
        .upload(filePath, signatureBlob);

      if (uploadError) throw uploadError;

      const { data } = supabase.storage
        .from('signatures')
        .getPublicUrl(filePath);

      return data.publicUrl;
    } catch (err) {
      toast.error('Erro ao enviar assinatura: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to upload signature');
    }
  };

  const getActiveCheckinForServiceNote = (serviceNoteId: string) => {
    return checkins.find(checkin => 
      checkin.service_note_id === serviceNoteId && checkin.is_active
    );
  };

  const getCheckinsForServiceNote = (serviceNoteId: string) => {
    return checkins.filter(checkin => checkin.service_note_id === serviceNoteId);
  };

  useEffect(() => {
    fetchCheckins();
    fetchStatistics();
  }, []);

  return {
    checkins,
    statistics,
    loading,
    error,
    createCheckin,
    updateCheckin,
    deleteCheckin,
    checkOut,
    uploadSignature,
    getActiveCheckinForServiceNote,
    getCheckinsForServiceNote,
    refetch: fetchCheckins,
    refetchStatistics: fetchStatistics
  };
};