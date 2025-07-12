import React, { useState } from 'react';
import { X, Calendar, DollarSign, Repeat, MapPin } from 'lucide-react';
import { Button } from '../UI/Button';
import { useRecurringCosts } from '../../hooks/useRecurringCosts';
import { useVehicles } from '../../hooks/useVehicles';

interface RecurringCostInsert {
  id?: string;
  category: string;
  description: string;
  amount: number;
      is_recurring: true;
  recurrence_type: 'monthly' | 'weekly' | 'yearly';
  recurrence_day: number;
  next_due_date: string;
  department: string;
      vehicle_id: string | undefined;
  status: 'Pendente' | 'Autorizado' | 'Pago';
  origin: 'Usuario' | 'Patio' | 'Manutencao' | 'Sistema' | 'Compras';
  cost_date: string;
}

interface RecurringCostsFormProps {
  isOpen: boolean;
  onClose: () => void;
  editingCost?: RecurringCostInsert;
}

export const RecurringCostsForm: React.FC<RecurringCostsFormProps> = ({
  isOpen,
  onClose,
  editingCost
}) => {
  const { createRecurringCost, updateRecurringCost } = useRecurringCosts();
  const { vehicles } = useVehicles();
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState<RecurringCostInsert>({
    id: editingCost?.id,
    category: editingCost?.category || 'Aluguel de Veículo',
    description: editingCost?.description || '',
    amount: editingCost?.amount || 0,
    is_recurring: true as const,
    recurrence_type: editingCost?.recurrence_type || 'monthly',
    recurrence_day: editingCost?.recurrence_day || 1,
    next_due_date: editingCost?.next_due_date || '',
    department: editingCost?.department || 'Cobrança',
    vehicle_id: editingCost?.vehicle_id || undefined,
    status: editingCost?.status || 'Pendente',
    origin: editingCost?.origin || 'Usuario',
    cost_date: editingCost?.cost_date || new Date().toISOString().split('T')[0]
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      if (editingCost && editingCost.id) {
        await updateRecurringCost(editingCost.id, formData);
      } else {
        await createRecurringCost(formData);
      }
      onClose();
    } catch (error) {
      console.error('Erro ao salvar custo recorrente:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = (field: keyof RecurringCostInsert, value: string | number | boolean | null) => {
    setFormData(prev => ({
      ...prev,
      [field]: value
    }));
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-2xl mx-4 max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center p-6 border-b">
          <h2 className="text-xl font-semibold text-gray-800">
            {editingCost ? 'Editar Custo Recorrente' : 'Novo Custo Recorrente'}
          </h2>
          <Button
            variant="secondary"
            size="sm"
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
          >
            <X size={20} />
          </Button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Categoria
              </label>
              <select
                value={formData.category}
                onChange={(e) => handleInputChange('category', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                required
              >
                <option value="Aluguel de Veículo">Aluguel de Veículo</option>
                <option value="Combustível">Combustível</option>
                <option value="Seguro">Seguro</option>
                <option value="Manutenção">Manutenção</option>
                <option value="Avulsa">Avulsa</option>
                <option value="Multa">Multa</option>
                <option value="Funilaria">Funilaria</option>
                <option value="Compra">Compra</option>
                <option value="Excesso Km">Excesso Km</option>
                <option value="Diária Extra">Diária Extra</option>
                <option value="Avaria">Avaria</option>
                <option value="Peças">Peças</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Veículo (Opcional)
              </label>
              <select
                value={formData.vehicle_id || ''}
                onChange={(e) => handleInputChange('vehicle_id', e.target.value || null)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="">Selecione um veículo</option>
                {vehicles.map(vehicle => (
                  <option key={vehicle.id} value={vehicle.id}>
                    {vehicle.plate} - {vehicle.model}
                  </option>
                ))}
              </select>
            </div>

            <div className="md:col-span-2">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Descrição
              </label>
              <input
                type="text"
                value={formData.description}
                onChange={(e) => handleInputChange('description', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="Descrição do custo recorrente"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <DollarSign className="inline w-4 h-4 mr-1" />
                Valor
              </label>
              <input
                type="number"
                step="0.01"
                min="0"
                value={formData.amount}
                onChange={(e) => handleInputChange('amount', parseFloat(e.target.value))}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <Repeat className="inline w-4 h-4 mr-1" />
                Tipo de Recorrência
              </label>
              <select
                value={formData.recurrence_type || 'monthly'}
                onChange={(e) => handleInputChange('recurrence_type', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                required
              >
                <option value="monthly">Mensal</option>
                <option value="weekly">Semanal</option>
                <option value="yearly">Anual</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Dia de Vencimento
              </label>
              <input
                type="number"
                min="1"
                max="31"
                value={formData.recurrence_day || 1}
                onChange={(e) => handleInputChange('recurrence_day', parseInt(e.target.value))}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <Calendar className="inline w-4 h-4 mr-1" />
                Próximo Vencimento
              </label>
              <input
                type="date"
                value={formData.next_due_date || ''}
                onChange={(e) => handleInputChange('next_due_date', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <MapPin className="inline w-4 h-4 mr-1" />
                Departamento
              </label>
              <select
                value={formData.department || 'Cobrança'}
                onChange={(e) => handleInputChange('department', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="Cobrança">Cobrança</option>
                <option value="Manutenção">Manutenção</option>
                <option value="Administração">Administração</option>
                <option value="Operação">Operação</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Status
              </label>
              <select
                value={formData.status || 'Pendente'}
                onChange={(e) => handleInputChange('status', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="Pendente">Pendente</option>
                <option value="Pago">Pago</option>
                <option value="Autorizado">Autorizado</option>
              </select>
            </div>
          </div>

          <div className="flex justify-end space-x-3 pt-6 border-t">
            <Button
              type="button"
              variant="secondary"
              onClick={onClose}
              disabled={loading}
            >
              Cancelar
            </Button>
            <Button
              type="submit"
              disabled={loading}
              className="bg-blue-600 hover:bg-blue-700"
            >
              {loading ? 'Salvando...' : editingCost ? 'Atualizar' : 'Criar'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}; 