import { useState } from 'react';
import { supabase } from '../lib/supabase';
import toast from 'react-hot-toast';

export function useApproveFuelRecord() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Aprovar abastecimento
  const approve = async (id: string, adminId?: string, adminName?: string) => {
    setLoading(true);
    setError(null);
    
    try {
      // 1. Buscar o registro de abastecimento completo
      const { data: fuelRecord, error: fetchError } = await supabase
        .from('fuel_records')
        .select(`
          *,
          vehicles (
            id,
            plate,
            model,
            mileage
          )
        `)
        .eq('id', id)
        .single();

      if (fetchError) {
        throw new Error(`Erro ao buscar registro: ${fetchError.message}`);
      }

      if (!fuelRecord) {
        throw new Error('Registro de abastecimento não encontrado');
      }

      // 2. Atualizar o status do registro de abastecimento
      const { error: updateError } = await supabase
        .from('fuel_records')
        .update({ 
          status: 'Aprovado',
          approved_by_employee_id: adminId,
          approved_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .eq('id', id);

      if (updateError) {
        throw new Error(`Erro ao atualizar registro: ${updateError.message}`);
      }

      // 3. Atualizar a quilometragem do veículo (se fornecida)
      if (fuelRecord.mileage && fuelRecord.vehicle_id) {
        const currentMileage = fuelRecord.vehicles?.mileage || 0;
        if (fuelRecord.mileage > currentMileage) {
          const { error: vehicleError } = await supabase
            .from('vehicles')
            .update({ 
              mileage: fuelRecord.mileage,
              updated_at: new Date().toISOString()
            })
            .eq('id', fuelRecord.vehicle_id);

          if (vehicleError) {
            console.warn('Erro ao atualizar quilometragem do veículo:', vehicleError);
            // Não falha a operação por isso
          }
        }
      }

      // 4. Criar ou atualizar custo relacionado
      if (fuelRecord.cost_id) {
        // Se já existe um custo, apenas atualizar o status
        const { error: costUpdateError } = await supabase
          .from('costs')
          .update({ 
            status: 'Autorizado',
            updated_at: new Date().toISOString()
          })
          .eq('id', fuelRecord.cost_id);

        if (costUpdateError) {
          console.warn('Erro ao atualizar custo existente:', costUpdateError);
        }
      } else {
        // Criar novo custo
        const costData = {
          category: 'Combustível',
          description: `Abastecimento - ${fuelRecord.vehicles?.plate || 'Veículo'} - ${fuelRecord.fuel_station || 'Posto não informado'}`,
          amount: fuelRecord.total_cost,
          cost_date: fuelRecord.recorded_at,
          status: 'Autorizado' as const,
          vehicle_id: fuelRecord.vehicle_id,
          origin: 'Abastecimento' as const,
          created_by_employee_id: adminId,
          created_by_name: adminName || 'Administrador',
          customer_id: fuelRecord.driver_employee_id, // Motorista como cliente
          customer_name: fuelRecord.driver_name,
          contract_id: fuelRecord.contract_id,
          source_reference_id: fuelRecord.id,
          source_reference_type: 'fuel_record' as const,
          observations: `Registro de abastecimento aprovado. Quilometragem: ${fuelRecord.mileage || 0} km. ${fuelRecord.notes ? `Observações: ${fuelRecord.notes}` : ''}`,
          tenant_id: fuelRecord.tenant_id,
          is_real_cost: true,
          source_type: 'fuel' as const,
          source_id: fuelRecord.id
        };

        const { data: newCost, error: costError } = await supabase
          .from('costs')
          .insert([costData])
          .select('id')
          .single();

        if (costError) {
          console.warn('Erro ao criar custo:', costError);
          // Não falha a operação principal
        } else if (newCost) {
          // Vincular o custo ao registro de abastecimento
          await supabase
            .from('fuel_records')
            .update({ cost_id: newCost.id })
            .eq('id', id);
        }
      }

      setLoading(false);
      toast.success('Abastecimento aprovado com sucesso!');
      return true;

    } catch (error) {
      console.error('Erro ao aprovar abastecimento:', error);
      const message = error instanceof Error ? error.message : 'Erro desconhecido';
      setError(message);
      toast.error(`Erro ao aprovar: ${message}`);
      setLoading(false);
      return false;
    }
  };

  // Rejeitar abastecimento
  const reject = async (id: string, adminId?: string) => {
    setLoading(true);
    setError(null);
    
    try {
      // 1. Buscar o registro de abastecimento
      const { data: fuelRecord, error: fetchError } = await supabase
        .from('fuel_records')
        .select('cost_id')
        .eq('id', id)
        .single();

      if (fetchError) {
        throw new Error(`Erro ao buscar registro: ${fetchError.message}`);
      }

      // 2. Atualizar o status do registro de abastecimento
      const { error: updateError } = await supabase
        .from('fuel_records')
        .update({ 
          status: 'Pendente',
          approved_by_employee_id: adminId,
          approved_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .eq('id', id);

      if (updateError) {
        throw new Error(`Erro ao atualizar registro: ${updateError.message}`);
      }

      // 3. Atualizar o status do custo relacionado, se existir
      if (fuelRecord?.cost_id) {
        const { error: costError } = await supabase
          .from('costs')
          .update({ 
            status: 'Pendente',
            updated_at: new Date().toISOString()
          })
          .eq('id', fuelRecord.cost_id);

        if (costError) {
          console.warn('Erro ao atualizar custo:', costError);
        }
      }

      setLoading(false);
      toast.success('Abastecimento rejeitado.');
      return true;

    } catch (error) {
      console.error('Erro ao rejeitar abastecimento:', error);
      const message = error instanceof Error ? error.message : 'Erro desconhecido';
      setError(message);
      toast.error(`Erro ao rejeitar: ${message}`);
      setLoading(false);
      return false;
    }
  };

  return { approve, reject, loading, error };
} 