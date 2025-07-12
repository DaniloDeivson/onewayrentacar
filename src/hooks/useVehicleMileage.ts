import { useCallback } from 'react';
import { supabase } from '../lib/supabase';
import toast from 'react-hot-toast';

export const useVehicleMileage = () => {
  // Função para atualizar a quilometragem do veículo
  const updateVehicleMileage = useCallback(async (vehicleId: string, newMileage: number) => {
    try {
      // Primeiro, buscar a quilometragem atual do veículo
      const { data: vehicleData, error: fetchError } = await supabase
        .from('vehicles')
        .select('mileage, initial_mileage')
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
        
        console.log(`✅ Quilometragem do veículo ${vehicleId} atualizada para ${newMileage.toLocaleString('pt-BR')} km`);
        return true;
      } else {
        console.log(`ℹ️ Quilometragem não atualizada - valor atual: ${vehicleData?.mileage?.toLocaleString('pt-BR')} km, novo valor: ${newMileage.toLocaleString('pt-BR')} km`);
        return false;
      }
    } catch (err) {
      console.error('❌ Erro ao atualizar quilometragem do veículo:', err);
      toast.error('Erro ao atualizar quilometragem do veículo');
      return false;
    }
  }, []);

  // Função para calcular a quilometragem total de um veículo
  const calculateTotalMileage = useCallback(async (vehicleId: string): Promise<number> => {
    try {
      const { data, error } = await supabase
        .rpc('fn_calculate_vehicle_total_mileage', { p_vehicle_id: vehicleId });

      if (error) throw error;
      return data || 0;
    } catch (err) {
      console.error('Erro ao calcular quilometragem total:', err);
      // Fallback para o cálculo manual
      try {
        const { data: vehicleData } = await supabase
          .from('vehicles')
          .select('mileage')
          .eq('id', vehicleId)
          .single();

        return vehicleData?.mileage || 0;
      } catch {
        return 0;
      }
    }
  }, []);

  // Função para obter a quilometragem atual de um veículo
  const getCurrentMileage = useCallback(async (vehicleId: string): Promise<number> => {
    try {
      const { data, error } = await supabase
        .from('vehicles')
        .select('total_mileage, mileage')
        .eq('id', vehicleId)
        .single();

      if (error) throw error;
      
      // Retorna a quilometragem total calculada ou a quilometragem básica
      return data?.total_mileage || data?.mileage || 0;
    } catch (err) {
      console.error('Erro ao obter quilometragem atual:', err);
      return 0;
    }
  }, []);

  return {
    updateVehicleMileage,
    calculateTotalMileage,
    getCurrentMileage
  };
}; 