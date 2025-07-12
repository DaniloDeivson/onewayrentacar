import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import { Database } from '../types/database';
import { useAuth } from './useAuth';
import toast from 'react-hot-toast';

type Inspection = Database['public']['Tables']['inspections']['Row'] & {
  vehicles?: { plate: string; model: string; year: number };
  inspection_items?: InspectionItem[];
  employees?: { name: string; role: string };
  contracts?: { id: string; contract_number: string };
  customers?: { id: string; name: string };
};

type InspectionItem = Database['public']['Tables']['inspection_items']['Row'];

type InspectionInsert = Database['public']['Tables']['inspections']['Insert'];
type InspectionItemInsert = Database['public']['Tables']['inspection_items']['Insert'];

// type Vehicle = Database['public']['Tables']['vehicles']['Row'];

interface InspectionStatistics {
  total_inspections: number;
  checkin_count: number;
  checkout_count: number;
  total_damages: number;
  high_severity_damages: number;
  total_estimated_costs: number;
  vehicles_in_maintenance: number;
  average_damages_per_checkout: number;
}

export const useInspections = (vehicleId?: string) => {
  const [inspections, setInspections] = useState<Inspection[]>([]);
  const [statistics, setStatistics] = useState<InspectionStatistics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { user } = useAuth();

  // Função auxiliar para atualizar a quilometragem do veículo
  const updateVehicleMileage = async (vehicleId: string, newMileage: number) => {
    try {
      // Primeiro, buscar a quilometragem atual do veículo
      const { data: vehicleData, error: fetchError } = await supabase
        .from('vehicles')
        .select('mileage')
        .eq('id', vehicleId)
        .single();

      if (fetchError) throw fetchError;

      // Só atualiza se a nova quilometragem for maior que a atual
      if (vehicleData && (!vehicleData.mileage || newMileage > vehicleData.mileage)) {
        const { error: updateError } = await supabase
          .from('vehicles')
          .update({ 
            mileage: newMileage,
            updated_at: new Date().toISOString()
          })
          .eq('id', vehicleId);

        if (updateError) throw updateError;
      }
    } catch (err) {
      console.error('Erro ao atualizar quilometragem do veículo:', err);
      throw err;
    }
  };

  const fetchInspections = async () => {
    try {
      setLoading(true);
      let inspectionsData;
      let inspectionsError;

      // Se for motorista, usar a função que busca apenas inspeções associadas
      if (user?.role === 'Driver') {
        const result = await supabase.rpc('get_driver_inspections', {
          p_driver_id: user.id
        });
        inspectionsData = result.data;
        inspectionsError = result.error;
      } else {
        // Para outros papéis, buscar todas as inspeções com relações (ou filtrar por veículo se especificado)
        const query = supabase
          .from('inspections')
          .select(`
            *,
            vehicles (
              plate,
              model,
              year,
              type
            ),
            employees!inspections_employee_id_fkey (
              name,
              role
            ),
            contracts (
              id,
              contract_number,
              name
            ),
            customers (
              id,
              name
            ),
            inspection_items (
              id,
              location,
              description,
              damage_type,
              severity,
              photo_url,
              requires_repair
            )
          `)
          .order('created_at', { ascending: false });

        if (vehicleId) {
          query.eq('vehicle_id', vehicleId);
        }

        const result = await query;
        inspectionsData = result.data;
        inspectionsError = result.error;
      }

      if (inspectionsError) throw inspectionsError;
      setInspections(inspectionsData || []);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Erro ao carregar inspeções';
      setError(message);
      toast.error(message);
    } finally {
      setLoading(false);
    }
  };

  const fetchStatistics = async () => {
    try {
      const { data, error } = await supabase
        .rpc('fn_inspection_statistics', { 
          p_tenant_id: DEFAULT_TENANT_ID,
          p_start_date: null,
          p_end_date: null
        });

      if (error) throw error;
      if (data && data.length > 0) {
        setStatistics(data[0]);
      }
    } catch {
      // Error handling for statistics
    }
  };

  const createInspection = async (inspectionData: InspectionInsert) => {
    try {
      // Garantir que tenant_id seja incluído
      const dataWithTenant = {
        ...inspectionData,
        tenant_id: user?.tenant_id || DEFAULT_TENANT_ID
      };

      const { data, error } = await supabase
        .from('inspections')
        .insert([dataWithTenant])
        .select(`
          *,
          vehicles (
            plate,
            model,
            year,
            type
          ),
          employees!inspections_employee_id_fkey (
            name,
            role
          ),
          contracts (
            id,
            contract_number
          ),
          customers (
            id,
            name
          ),
          inspection_items (
            id,
            location,
            description,
            damage_type,
            severity,
            photo_url,
            requires_repair
          )
        `)
        .single();

      if (error) throw error;
      
      // Atualizar a quilometragem do veículo se houver quilometragem na inspeção
      if (data && data.mileage && data.vehicle_id) {
        try {
          await updateVehicleMileage(data.vehicle_id, data.mileage);
          console.log(`Quilometragem do veículo ${data.vehicle_id} atualizada para ${data.mileage} km`);
        } catch (mileageError) {
          console.error('Erro ao atualizar quilometragem do veículo:', mileageError);
          // Não falhar a criação da inspeção se a atualização da quilometragem falhar
        }
      }
      
      setInspections(prev => [data, ...prev]);
      return data;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Erro ao criar inspeção';
      toast.error(message);
      throw new Error(message);
    }
  };

  const updateInspection = async (id: string, updates: Partial<Inspection>) => {
    try {
      const { data, error } = await supabase
        .from('inspections')
        .update(updates)
        .eq('id', id)
        .select(`
          *,
          vehicles (
            plate,
            model,
            year,
            type
          ),
          employees!inspections_employee_id_fkey (
            name,
            role
          ),
          contracts (
            id,
            contract_number
          ),
          customers (
            id,
            name
          ),
          inspection_items (
            id,
            location,
            description,
            damage_type,
            severity,
            photo_url,
            requires_repair
          )
        `)
        .single();

      if (error) throw error;
      
      // Atualizar a quilometragem do veículo se houver quilometragem na atualização
      if (data && data.mileage && data.vehicle_id) {
        try {
          await updateVehicleMileage(data.vehicle_id, data.mileage);
          console.log(`Quilometragem do veículo ${data.vehicle_id} atualizada para ${data.mileage} km`);
        } catch (mileageError) {
          console.error('Erro ao atualizar quilometragem do veículo:', mileageError);
          // Não falhar a atualização da inspeção se a atualização da quilometragem falhar
        }
      }
      
      setInspections(prev => prev.map(inspection => inspection.id === id ? data : inspection));
      return data;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Erro ao atualizar inspeção';
      toast.error(message);
      throw new Error(message);
    }
  };

  const deleteInspection = async (id: string) => {
    try {
      const { error } = await supabase
        .from('inspections')
        .delete()
        .eq('id', id);

      if (error) throw error;
      setInspections(prev => prev.filter(inspection => inspection.id !== id));
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Erro ao deletar inspeção';
      toast.error(message);
      throw new Error(message);
    }
  };

  const addInspectionItem = async (inspectionId: string, itemData: Omit<InspectionItemInsert, 'inspection_id'>) => {
    try {
      console.log('addInspectionItem chamado:', { inspectionId, itemData });
      
      // Validar campos obrigatórios
      if (!itemData.location || itemData.location.trim() === '') {
        throw new Error('Localização é obrigatória');
      }
      if (!itemData.description || itemData.description.trim() === '') {
        throw new Error('Descrição é obrigatória');
      }
      if (!itemData.damage_type || !['Arranhão', 'Amassado', 'Quebrado', 'Desgaste', 'Outro'].includes(itemData.damage_type)) {
        throw new Error('Tipo de dano é obrigatório e deve ser válido');
      }
      
      // Validar que a inspeção existe
      const { data: inspectionExists, error: checkError } = await supabase
        .from('inspections')
        .select('id')
        .eq('id', inspectionId)
        .single();
        
      if (checkError || !inspectionExists) {
        throw new Error('Inspeção não encontrada');
      }
      
      // Garantir valores padrão para campos opcionais
      const insertData = { 
        inspection_id: inspectionId,
        location: itemData.location.trim(),
        description: itemData.description.trim(),
        damage_type: itemData.damage_type,
        severity: itemData.severity || 'Baixa',
        requires_repair: itemData.requires_repair !== undefined ? itemData.requires_repair : true,
        photo_url: itemData.photo_url || null
      };
      
      console.log('Dados para inserção:', insertData);
      
      const { data, error } = await supabase
        .from('inspection_items')
        .insert([insertData])
        .select()
        .single();

      if (error) {
        console.error('Erro na inserção:', error);
        if (error.code === '23505') {
          throw new Error('Item de inspeção duplicado');
        } else if (error.code === '23503') {
          throw new Error('Inspeção não encontrada');
        } else if (error.code === '23514') {
          throw new Error('Dados inválidos para o item de inspeção');
        } else {
          throw new Error(`Erro de banco de dados: ${error.message}`);
        }
      }
      
      console.log('Item inserido com sucesso:', data);
      
      // Update local state
      setInspections(prev => prev.map(inspection => {
        if (inspection.id === inspectionId) {
          return {
            ...inspection,
            inspection_items: [...(inspection.inspection_items || []), data]
          };
        }
        return inspection;
      }));
      
      await fetchStatistics();
      return data;
    } catch (err) {
      console.error('Erro completo em addInspectionItem:', err);
      const errorMessage = err instanceof Error ? err.message : 'Erro desconhecido';
      toast.error('Erro ao adicionar item de inspeção: ' + errorMessage);
      throw new Error(errorMessage);
    }
  };

  const removeInspectionItem = async (itemId: string) => {
    try {
      const { error } = await supabase
        .from('inspection_items')
        .delete()
        .eq('id', itemId);

      if (error) throw error;
      
      // Update local state
      setInspections(prev => prev.map(inspection => ({
        ...inspection,
        inspection_items: inspection.inspection_items?.filter(item => item.id !== itemId) || []
      })));
      
      await fetchStatistics();
    } catch (err) {
      toast.error('Erro ao remover item de inspeção: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to remove inspection item');
    }
  };

  const uploadPhoto = async (file: File): Promise<string> => {
    try {
      if (!file) throw new Error('Nenhum arquivo selecionado');
      if (!file.type.startsWith('image/')) throw new Error('Arquivo não é uma imagem');
      if (file.size === 0) throw new Error('Arquivo vazio');
      
      // Validar tamanho máximo (10MB)
      const maxSize = 10 * 1024 * 1024;
      if (file.size > maxSize) throw new Error('Arquivo muito grande. Máximo 10MB');
      
      // Validar tipos de arquivo permitidos
      const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];
      if (!allowedTypes.includes(file.type)) {
        throw new Error('Tipo de arquivo não permitido. Use JPEG, PNG, WebP ou GIF');
      }
      
      const ext = file.name.split('.').pop()?.toLowerCase() || 'jpg';
      const timestamp = Date.now();
      const fileName = `dashboard-${timestamp}.${ext}`;
      const filePath = `inspection-photos/${fileName}`;
      
      console.log('Iniciando upload:', { fileName, filePath, size: file.size, type: file.type });
      
      const { data, error } = await supabase.storage
        .from('photos')
        .upload(filePath, file, { 
          cacheControl: '3600', 
          upsert: false,
          contentType: file.type // Forçar o content type correto
        });
        
      if (error) {
        console.error('Erro no upload:', error);
        throw new Error(error.message);
      }
      
      console.log('Upload bem-sucedido:', data);
      
      const { data: { publicUrl } } = supabase.storage
        .from('photos')
        .getPublicUrl(filePath);
        
      if (!publicUrl) throw new Error('Erro ao gerar URL pública da imagem');
      
      console.log('URL pública gerada:', publicUrl);
      return publicUrl;
    } catch (err) {
      console.error('Erro completo no upload:', err);
      throw new Error(err instanceof Error ? err.message : 'Falha no upload da foto');
    }
  };

  const uploadSignature = async (signatureBlob: Blob): Promise<string> => {
    try {
      const fileName = `signature-${Date.now()}.png`;
      const filePath = `signatures/${fileName}`;

      const { error: uploadError } = await supabase.storage
        .from('signatures')
        .upload(filePath, signatureBlob);

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('signatures')
        .getPublicUrl(filePath);

      return publicUrl;
    } catch (err) {
      toast.error('Erro ao fazer upload da assinatura: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to upload signature');
    }
  };

  const processDamageNotifications = async () => {
    try {
      const { data, error } = await supabase
        .rpc('fn_process_damage_notifications', { p_tenant_id: DEFAULT_TENANT_ID });

      if (error) throw error;
      
      toast.success(`Processadas ${data || 0} notificações de danos`);
      return data;
    } catch (err) {
      toast.error('Erro ao processar notificações: ' + (err instanceof Error ? err.message : 'Erro desconhecido'));
      throw new Error(err instanceof Error ? err.message : 'Failed to process notifications');
    }
  };

  useEffect(() => {
    fetchInspections();
    fetchStatistics();
  }, [vehicleId]);

  return {
    inspections,
    statistics,
    loading,
    error,
    createInspection,
    updateInspection,
    deleteInspection,
    addInspectionItem,
    removeInspectionItem,
    uploadPhoto,
    uploadSignature,
    processDamageNotifications,
    refetch: fetchInspections
  };
};

// Nova função para buscar inspetores
export async function getInspectors() {
  const { data, error } = await supabase
    .from('employees')
    .select('*')
    .eq('active', true)
    .contains('permissions', { inspections: true });
  if (error) throw error;
  return data;
}