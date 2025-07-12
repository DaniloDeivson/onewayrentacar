import React, { useState, useEffect } from 'react';
import { Button } from '../../components/UI/Button';
import { Card, CardHeader, CardContent } from '../../components/UI/Card';
import { Badge } from '../../components/UI/Badge';
import { useRecurringCosts } from '../../hooks/useRecurringCosts';
import { useVehicles } from '../../hooks/useVehicles';
import { useCustomers } from '../../hooks/useCustomers';
import { useContracts } from '../../hooks/useContracts';
import { Calendar, DollarSign, Car, User, Loader2, Edit, Trash2, RefreshCw } from 'lucide-react';
import toast from 'react-hot-toast';

interface RecurringCostsFormProps {
  onClose?: () => void;
  editingCost?: any;
  onSave?: (data: any) => Promise<void>;
}

export const RecurringCostsForm: React.FC<RecurringCostsFormProps> = ({ onClose, editingCost, onSave }) => {
  const {
    recurringCosts,
    loading,
    generateRecurringCosts,
    getRecurringCostsStats
  } = useRecurringCosts();

  const { vehicles } = useVehicles();
  const { customers } = useCustomers();
  const { contracts } = useContracts();

  const [isFormOpen, setIsFormOpen] = useState(false);
  const [formData, setFormData] = useState({
    category: '',
    description: '',
    amount: 0,
    cost_date: new Date().toISOString().split('T')[0],
    status: 'Pendente' as 'Pendente' | 'Autorizado' | 'Pago',
    vehicle_id: '',
    customer_id: '',
    contract_id: '',
    recurrence_type: 'monthly' as 'monthly' | 'weekly' | 'yearly',
    recurrence_day: 1
  });

  const stats = getRecurringCostsStats();

  // Inicializar formulário quando editingCost mudar
  useEffect(() => {
    if (editingCost) {
      setFormData({
        category: editingCost.category,
        description: editingCost.description,
        amount: editingCost.amount,
        cost_date: editingCost.cost_date,
        status: editingCost.status,
        vehicle_id: editingCost.vehicle_id || '',
        customer_id: editingCost.customer_id || '',
        contract_id: editingCost.contract_id || '',
        recurrence_type: editingCost.recurrence_type,
        recurrence_day: editingCost.recurrence_day
      });
      setIsFormOpen(true);
    }
  }, [editingCost]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      if (onSave) {
        await onSave(formData);
      }
      
      resetForm();
      setIsFormOpen(false);
    } catch (error) {
      toast.error('Erro ao salvar custo recorrente');
    }
  };

  const handleEdit = (cost: any) => {
    setFormData({
      category: cost.category,
      description: cost.description,
      amount: cost.amount,
      cost_date: cost.cost_date,
      status: cost.status,
      vehicle_id: cost.vehicle_id || '',
      customer_id: cost.customer_id || '',
      contract_id: cost.contract_id || '',
      recurrence_type: cost.recurrence_type,
      recurrence_day: cost.recurrence_day
    });
    setIsFormOpen(true);
  };

  const handleDelete = async (id: string) => {
    if (confirm('Tem certeza que deseja excluir este custo recorrente?')) {
      try {
        await deleteRecurringCost(id);
        toast.success('Custo recorrente excluído com sucesso!');
      } catch (error) {
        toast.error('Erro ao excluir custo recorrente');
      }
    }
  };

  const handleGenerateRecurring = async () => {
    try {
      const result = await generateRecurringCosts();
      toast.success(`${result} custos recorrentes gerados automaticamente!`);
    } catch (error) {
      toast.error('Erro ao gerar custos recorrentes');
    }
  };

  const resetForm = () => {
    setFormData({
      category: '',
      description: '',
      amount: 0,
      cost_date: new Date().toISOString().split('T')[0],
      status: 'Pendente',
      vehicle_id: '',
      customer_id: '',
      contract_id: '',
      recurrence_type: 'monthly',
      recurrence_day: 1
    });
  };

  const getStatusBadge = (status: string) => {
    const variants = {
      'Pendente': 'warning',
      'Autorizado': 'info',
      'Pago': 'success'
    } as const;

    return <Badge variant={variants[status as keyof typeof variants] || 'secondary'}>{status}</Badge>;
  };

  const getRecurrenceTypeLabel = (type: string) => {
    const labels = {
      'monthly': 'Mensal',
      'weekly': 'Semanal',
      'yearly': 'Anual'
    };
    return labels[type as keyof typeof labels] || type;
  };

  return (
    <div className="space-y-6">
      {/* Header com estatísticas */}
      <Card>
        <CardHeader className="p-4 lg:p-6">
          <div className="flex justify-between items-center">
            <h3 className="text-lg font-semibold text-secondary-900">
              Custos Recorrentes
            </h3>
            <div className="flex space-x-2">
              <Button
                onClick={handleGenerateRecurring}
                variant="secondary"
                size="sm"
                disabled={loading}
              >
                <RefreshCw className="h-4 w-4 mr-2" />
                Gerar Automático
              </Button>
            </div>
          </div>
        </CardHeader>
        <CardContent className="p-4 lg:p-6">
          <div className="grid grid-cols-2 lg:grid-cols-5 gap-4 mb-6">
            <div className="text-center">
              <p className="text-2xl font-bold text-primary-600">{stats.total}</p>
              <p className="text-sm text-secondary-600">Total</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold text-info-600">{stats.active}</p>
              <p className="text-sm text-secondary-600">Ativos</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold text-warning-600">{stats.overdue}</p>
              <p className="text-sm text-secondary-600">Vencidos</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold text-secondary-600">{stats.upcoming}</p>
              <p className="text-sm text-secondary-600">Próximos</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold text-success-600">
                R$ {stats.totalAmount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
              </p>
              <p className="text-sm text-secondary-600">Valor Total</p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Lista de custos recorrentes */}
      <Card>
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-secondary-50">
                <tr>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Descrição</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Categoria</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Valor</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Recorrência</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Próximo Vencimento</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Status</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-secondary-200">
                {recurringCosts
                  .sort((a, b) => new Date(a.next_due_date).getTime() - new Date(b.next_due_date).getTime())
                  .map((cost) => (
                  <tr key={cost.id} className="hover:bg-secondary-50">
                    <td className="py-4 px-6 text-sm font-medium text-secondary-900">
                      {cost.description}
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      {cost.category}
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      <div className="flex items-center">
                        <DollarSign className="h-4 w-4 mr-1 text-secondary-400" />
                        <span className="font-medium">
                          R$ {cost.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                        </span>
                      </div>
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      {getRecurrenceTypeLabel(cost.recurrence_type)}
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      <div className="flex items-center">
                        <Calendar className="h-4 w-4 mr-1 text-secondary-400" />
                        <span>{new Date(cost.next_due_date).toLocaleDateString('pt-BR')}</span>
                      </div>
                    </td>
                    <td className="py-4 px-6">
                      {getStatusBadge(cost.status)}
                    </td>
                    <td className="py-4 px-6">
                      <div className="flex items-center space-x-2">
                        <button 
                          onClick={() => handleEdit(cost)}
                          className="p-1 text-secondary-400 hover:text-secondary-600"
                        >
                          <Edit className="h-4 w-4" />
                        </button>
                        <button 
                          onClick={() => handleDelete(cost.id)}
                          className="p-1 text-secondary-400 hover:text-error-600"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {recurringCosts.length === 0 && (
            <div className="text-center py-8">
              <DollarSign className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
              <p className="text-secondary-600">Nenhum custo recorrente encontrado</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Modal de formulário */}
      {(isFormOpen || onSave) && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            <h3 className="text-lg font-semibold text-secondary-900 mb-4">
              {editingCost ? 'Editar Custo Recorrente' : 'Novo Custo Recorrente'}
            </h3>
            
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Categoria *
                  </label>
                  <select
                    name="category"
                    value={formData.category}
                    onChange={(e) => setFormData(prev => ({ ...prev, category: e.target.value }))}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    required
                  >
                    <option value="">Selecione uma categoria</option>
                    <option value="Seguro">Seguro</option>
                    <option value="Aluguel de Veículo">Aluguel de Veículo</option>
                    <option value="Manutenção">Manutenção</option>
                    <option value="Avulsa">Avulsa</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Valor (R$) *
                  </label>
                  <div className="relative">
                    <DollarSign className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
                    <input
                      type="number"
                      name="amount"
                      value={formData.amount}
                      onChange={(e) => setFormData(prev => ({ ...prev, amount: Number(e.target.value) }))}
                      className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                      step="0.01"
                      min="0"
                      required
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Data de Início *
                  </label>
                  <div className="relative">
                    <Calendar className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
                    <input
                      type="date"
                      name="cost_date"
                      value={formData.cost_date}
                      onChange={(e) => setFormData(prev => ({ ...prev, cost_date: e.target.value }))}
                      className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                      required
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Status
                  </label>
                  <select
                    name="status"
                    value={formData.status}
                    onChange={(e) => setFormData(prev => ({ ...prev, status: e.target.value as any }))}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  >
                    <option value="Pendente">Pendente</option>
                    <option value="Autorizado">Autorizado</option>
                    <option value="Pago">Pago</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Veículo
                  </label>
                  <div className="relative">
                    <Car className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
                    <select
                      name="vehicle_id"
                      value={formData.vehicle_id}
                      onChange={(e) => setFormData(prev => ({ ...prev, vehicle_id: e.target.value }))}
                      className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                    >
                      <option value="">Selecione um veículo</option>
                      {vehicles.map(vehicle => (
                        <option key={vehicle.id} value={vehicle.id}>
                          {vehicle.plate} - {vehicle.model}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Cliente
                  </label>
                  <div className="relative">
                    <User className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
                    <select
                      name="customer_id"
                      value={formData.customer_id}
                      onChange={(e) => setFormData(prev => ({ ...prev, customer_id: e.target.value }))}
                      className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                    >
                      <option value="">Selecione um cliente</option>
                      {customers.map(customer => (
                        <option key={customer.id} value={customer.id}>
                          {customer.name}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-2">
                  Descrição *
                </label>
                <textarea
                  name="description"
                  value={formData.description}
                  onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  rows={3}
                  required
                />
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Tipo de Recorrência *
                  </label>
                  <select
                    name="recurrence_type"
                    value={formData.recurrence_type}
                    onChange={(e) => setFormData(prev => ({ ...prev, recurrence_type: e.target.value as any }))}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    required
                  >
                    <option value="monthly">Mensal</option>
                    <option value="weekly">Semanal</option>
                    <option value="yearly">Anual</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Dia da Recorrência
                  </label>
                  <input
                    type="number"
                    name="recurrence_day"
                    value={formData.recurrence_day}
                    onChange={(e) => setFormData(prev => ({ ...prev, recurrence_day: Number(e.target.value) }))}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    min="1"
                    max="31"
                  />
                </div>
              </div>

              <div className="flex justify-end space-x-3 pt-4">
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => {
                    if (onClose) {
                      onClose();
                    } else {
                    setIsFormOpen(false);
                    resetForm();
                    }
                  }}
                >
                  Cancelar
                </Button>
                <Button
                  type="submit"
                  disabled={loading}
                >
                  {loading ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : null}
                  {editingCost ? 'Atualizar' : 'Criar'}
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}; 