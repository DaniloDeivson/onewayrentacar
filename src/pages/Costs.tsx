/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable @typescript-eslint/no-unused-vars */
import React, { useState, useEffect } from 'react';
import { Card, CardHeader, CardContent } from '../components/UI/Card';
import { Button } from '../components/UI/Button';
import { Badge } from '../components/UI/Badge';
import { useCosts } from '../hooks/useCosts';
import { useVehicles } from '../hooks/useVehicles';
import { useEmployees } from '../hooks/useEmployees';
import { useAuth } from '../hooks/useAuth';
import { CostsList } from '../components/Costs/CostsList';
import { RecurringCostsForm } from '../components/Finance/RecurringCostsForm';
import { useRecurringCosts } from '../hooks/useRecurringCosts';
import { useRecurringContracts } from '../hooks/useRecurringContracts';
import { Plus, Search, Filter, Calendar, DollarSign, Loader2, AlertTriangle, ClipboardCheck, Edit2, RefreshCw, FileText, User, CheckCircle, Car, Repeat, Package, Info } from 'lucide-react';
import { Database } from '../types/database';
import { useCustomers } from '../hooks/useCustomers';
import { useContracts } from '../hooks/useContracts';
import { usePurchaseOrders } from '../hooks/usePurchaseOrders';
import { supabase } from '../lib/supabase';

type Cost = Database['public']['Tables']['costs']['Row'] & {
  vehicles?: { plate: string; model: string };
  created_by_name?: string;
  created_by_role?: string;
  created_by_code?: string;
  origin_description?: string;
  is_amount_to_define?: boolean;
  contracts?: { id: string; contract_number: string };
  customers?: { id: string; name: string };
  vehicle_plate?: string | undefined;
  vehicle_model?: string;
};

type CostInsert = Omit<Database['public']['Tables']['costs']['Insert'], 'tenant_id'>;
type Vehicle = Database['public']['Tables']['vehicles']['Row'];
type Employee = Database['public']['Tables']['employees']['Row'];
type Contract = Database['public']['Tables']['contracts']['Row'];

const ITEMS_PER_PAGE = 20;

const CostModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  cost?: Cost;
  vehicles: Vehicle[];
  employees: Employee[];
  onSave: (data: CostInsert) => Promise<void>;
  isReadOnly?: boolean;
}> = ({ isOpen, onClose, cost, vehicles, employees, onSave, isReadOnly = false }) => {
  const { customers } = useCustomers();
  const { contracts } = useContracts();
  const { user } = useAuth();
  const { getCostParts } = useCosts();
  const [costParts, setCostParts] = useState<any[]>([]);
  const [loadingParts, setLoadingParts] = useState(false);
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const [selectedCustomer, setSelectedCustomer] = useState<string>('');
  const [filteredContracts, setFilteredContracts] = useState<Contract[]>([]);
  const [formData, setFormData] = useState({
    category: cost?.category || 'Avulsa' as const,
    vehicle_id: cost?.vehicle_id || '',
    description: cost?.description || '',
    amount: cost?.amount || 0,
    cost_date: cost?.cost_date || new Date().toISOString().split('T')[0],
    status: cost?.status || 'Pendente' as const,
    document_ref: cost?.document_ref || '',
    observations: cost?.observations || '',
    origin: (cost?.origin as 'Usuario' | 'Patio' | 'Manutencao' | 'Sistema' | 'Compras') || 'Usuario',
    created_by_employee_id: cost?.created_by_employee_id || user?.id || '',
    created_by_name: cost?.created_by_name || user?.name || '',
    source_reference_type: cost?.source_reference_type || null,
    department: cost?.department || '',
    customer_id: cost?.customer_id || '',
    customer_name: cost?.customer_name || '',
    contract_id: cost?.contract_id || ''
  });
  const [loading, setLoading] = useState(false);

  // Reset form data when modal opens or when a different cost is provided
  useEffect(() => {
    if (!isOpen) return;

    setFormData({
      category: cost?.category || 'Avulsa',
      vehicle_id: cost?.vehicle_id || '',
      description: cost?.description || '',
      amount: cost?.amount || 0,
      cost_date: cost?.cost_date || new Date().toISOString().split('T')[0],
      status: cost?.status || 'Pendente',
      document_ref: cost?.document_ref || '',
      observations: cost?.observations || '',
      origin: (cost?.origin as 'Usuario' | 'Patio' | 'Manutencao' | 'Sistema' | 'Compras') || 'Usuario',
      created_by_employee_id: cost?.created_by_employee_id || user?.id || '',
      created_by_name: cost?.created_by_name || user?.name || '',
      source_reference_type: cost?.source_reference_type || null,
      department: cost?.department || '',
      customer_id: cost?.customer_id || '',
      customer_name: cost?.customer_name || '',
      contract_id: cost?.contract_id || ''
    });

    // Sync selected customer for contract filtering
    if (cost?.customer_id) {
      setSelectedCustomer(cost.customer_id);
      setFilteredContracts(contracts.filter(c => c.customer_id === cost.customer_id));
    } else {
      setSelectedCustomer('');
      setFilteredContracts([]);
    }

    // Carregar peças associadas ao custo se for visualização
    if (isReadOnly && cost?.id) {
      setLoadingParts(true);
      getCostParts(cost.id)
        .then(parts => setCostParts(parts))
        .catch(error => {
          console.error('Error loading cost parts:', error);
          setCostParts([]);
        })
        .finally(() => setLoadingParts(false));
    } else {
      setCostParts([]);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isOpen, cost?.id, isReadOnly]);

  if (!isOpen) return null;

  // Função para determinar a origem baseada na categoria
  const getOriginFromCategory = (category: string): string => {
    switch (category) {
      case 'Multa':
        return 'Multas';
      case 'Funilaria':
      case 'Avaria':
        return 'Patio';
      case 'Combustível':
        return 'Manutencao';
      case 'Compra':
      case 'Peças':
        return 'Compras';
      case 'Seguro':
      case 'Diária Extra':
      case 'Excesso Km':
      case 'Avulsa':
      default:
        return 'Usuario';
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      if (!formData.customer_id) {
        alert('Selecione um cliente para o custo!');
        setLoading(false);
        return;
      }
      // Determinar origem baseada na categoria se não for um custo existente
      const finalOrigin = cost?.id ? formData.origin : (getOriginFromCategory(formData.category) as 'Usuario' | 'Patio' | 'Manutencao' | 'Sistema' | 'Compras');
      
      const submitData: CostInsert = {
        ...formData,
        origin: finalOrigin,
        created_by_employee_id: user?.id || formData.created_by_employee_id || null,
        created_by_name: user?.name?.trim() || 'Usuário do Sistema',
        document_ref: formData.document_ref === '' ? null : formData.document_ref,
        observations: formData.observations === '' ? null : formData.observations,
        department: formData.department === '' ? null : formData.department,
        customer_id: formData.customer_id === '' ? null : formData.customer_id,
        customer_name: formData.customer_name === '' ? null : formData.customer_name,
        contract_id: formData.contract_id === '' ? null : formData.contract_id
      };
      await onSave(submitData);
      onClose();
    } catch (error) {
      console.error('Error saving cost:', error);
      alert('Erro ao salvar custo: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => {
      const newData = {
        ...prev,
        [name]: name === 'amount' ? Number(value) || 0 : value
      };
      
      // Se a categoria foi alterada e não é um custo existente, atualizar a origem automaticamente
      if (name === 'category' && !cost?.id) {
        newData.origin = getOriginFromCategory(value);
      }
      
      return newData;
    });
  };

  const handleCustomerChange = (customerId: string) => {
    setSelectedCustomer(customerId);
    setFormData(prev => ({
      ...prev,
      customer_id: customerId,
      customer_name: customers.find(c => c.id === customerId)?.name || ''
    }));
    setFilteredContracts(contracts.filter(c => c.customer_id === customerId));
  };

  const isAmountToDefine = cost && cost.amount === 0 && cost.status === 'Pendente';
  const isAutomaticCost = cost?.origin && cost.origin !== 'Manual';
  const isViewOnly = isReadOnly || (isAutomaticCost && !isAmountToDefine) || (cost?.id && !isAmountToDefine);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <h2 className="text-lg lg:text-xl font-semibold text-secondary-900">
            {cost ? (isViewOnly ? 'Visualizar Custo' : 'Editar Custo') : 'Novo Lançamento de Custo'}
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            ×
          </button>
        </div>

        {/* Alert for automatic costs */}
        {isAutomaticCost && (
          <div className="mb-4 lg:mb-6 p-4 bg-info-50 border border-info-200 rounded-lg">
            <div className="flex items-center">
              <AlertTriangle className="h-5 w-5 text-info-600 mr-2" />
              <div>
                <p className="text-info-800 font-medium text-sm">
                  Custo Gerado Automaticamente
                </p>
                <p className="text-info-700 text-xs mt-1">
                  Este custo foi criado automaticamente pelo sistema. Origem: {
                    cost.origin === 'Patio' && cost.description?.toLowerCase().includes('check-out') ? 'Controle de Pátio (Check-Out)' :
                      cost.origin === 'Patio' && cost.description?.toLowerCase().includes('check-in') ? 'Controle de Pátio (Check-In)' :
                        cost.origin === 'Patio' ? 'Controle de Pátio' :
                          cost.origin === 'Manutencao' ? 'Manutenção' :
                            cost.origin === 'Sistema' ? 'Sistema' :
                              cost.origin === 'Compras' ? 'Compras' :
                                cost.origin === 'Multas' ? 'Multas' :
                                cost.origin === 'Usuario' ? 'Usuário' :
                                  cost.origin
                  }
                </p>
              </div>
            </div>
          </div>
        )}

        {/* Alert for immutable costs */}
        {cost?.id && (
          <div className="mb-4 lg:mb-6 p-4 bg-warning-50 border border-warning-200 rounded-lg">
            <div className="flex items-center">
              <AlertTriangle className="h-5 w-5 text-warning-600 mr-2" />
              <div>
                <p className="text-warning-800 font-medium text-sm">
                  Lançamento Imutável
                </p>
                <p className="text-warning-700 text-xs mt-1">
                  Lançamentos de custos não podem ser alterados após criados. Apenas o status pode ser atualizado para "Pago" ou "Autorizado".
                </p>
              </div>
            </div>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          {isViewOnly ? (
            <div className="p-4 bg-green-50 border border-green-200 rounded-xl shadow-sm mb-4">
              <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4 mb-4">
                <div className="flex items-center gap-2">
                  <User className="h-5 w-5 text-green-700" />
                  <span className="font-semibold text-green-900 text-lg">{cost?.customer_name || '-'}</span>
                </div>
                <div className="flex items-center gap-2">
                  <DollarSign className="h-5 w-5 text-green-700" />
                  <span className="font-semibold text-green-900 text-lg">R$ {cost?.amount?.toLocaleString('pt-BR', { minimumFractionDigits: 2 }) || '-'}</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle className="h-5 w-5 text-green-700" />
                  <span className="font-semibold text-green-900 text-lg">{cost?.status || '-'}</span>
                </div>
              </div>
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-2">
                <div className="flex items-center gap-2">
                  <FileText className="h-4 w-4 text-secondary-500" />
                  <span className="text-secondary-800">Contrato:</span>
                  <span className="font-medium text-secondary-900">{cost?.contract_id || '-'}</span>
                </div>
                <div className="flex items-center gap-2">
                  <Car className="h-4 w-4 text-secondary-500" />
                  <span className="text-secondary-800">Veículo:</span>
                  <span className="font-medium text-secondary-900">{cost?.vehicles?.plate || cost?.vehicle_plate || '-'}</span>
                </div>
                <div className="flex items-center gap-2">
                  <ClipboardCheck className="h-4 w-4 text-secondary-500" />
                  <span className="text-secondary-800">Categoria:</span>
                  <span className="font-medium text-secondary-900">{cost?.category || '-'}</span>
                </div>
                <div className="flex items-center gap-2">
                  <Calendar className="h-4 w-4 text-secondary-500" />
                  <span className="text-secondary-800">Data:</span>
                  <span className="font-medium text-secondary-900">{cost?.cost_date ? new Date(cost.cost_date).toLocaleDateString('pt-BR') : '-'}</span>
                </div>
                <div className="flex items-center gap-2">
                  <User className="h-4 w-4 text-secondary-500" />
                  <span className="text-secondary-800">Responsável:</span>
                  <span className="font-medium text-secondary-900">{cost?.employees?.name || cost?.created_by_name || (cost?.origin === 'Sistema' ? 'Sistema' : '-')}</span>
                </div>
                <div className="flex items-center gap-2">
                  <FileText className="h-4 w-4 text-secondary-500" />
                  <span className="text-secondary-800">Origem:</span>
                  <span className="font-medium text-secondary-900">
                    {cost?.origin === 'Usuario' ? 'Usuário' : 
                     cost?.origin === 'Patio' ? 'Controle de Pátio' :
                     cost?.origin === 'Manutencao' ? 'Manutenção' :
                     cost?.origin === 'Sistema' ? 'Sistema' :
                     cost?.origin === 'Compras' ? 'Compras' :
                     cost?.origin === 'Multas' ? 'Multas' :
                     cost?.origin || '-'}
                  </span>
                </div>
              </div>
              <div className="mt-4">
                <label className="block text-xs text-secondary-600 mb-1">Observações</label>
                <div className="font-medium text-secondary-900 bg-secondary-50 rounded p-2 min-h-[32px]">{cost?.observations || '-'}</div>
              </div>

              {/* Seção de Peças */}
              {costParts.length > 0 && (
                <div className="mt-6">
                  <h3 className="text-sm font-semibold text-secondary-900 mb-3 flex items-center">
                    <Package className="h-4 w-4 mr-2" />
                    Peças Utilizadas
                  </h3>
                  <div className="bg-secondary-50 rounded-lg p-4">
                    <div className="overflow-x-auto">
                      <table className="w-full text-sm">
                        <thead>
                          <tr className="border-b border-secondary-200">
                            <th className="text-left py-2 px-2 font-medium text-secondary-700">SKU</th>
                            <th className="text-left py-2 px-2 font-medium text-secondary-700">Peça</th>
                            <th className="text-right py-2 px-2 font-medium text-secondary-700">Qtd</th>
                            <th className="text-right py-2 px-2 font-medium text-secondary-700">Custo Unit.</th>
                            <th className="text-right py-2 px-2 font-medium text-secondary-700">Total</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-secondary-200">
                          {costParts.map((part) => (
                            <tr key={part.id} className="hover:bg-secondary-100">
                              <td className="py-2 px-2 text-secondary-900 font-medium">
                                {part.parts?.sku || 'N/A'}
                              </td>
                              <td className="py-2 px-2 text-secondary-800">
                                {part.parts?.name || 'Peça não encontrada'}
                              </td>
                              <td className="py-2 px-2 text-right text-secondary-800">
                                {part.quantity_used}
                              </td>
                              <td className="py-2 px-2 text-right text-secondary-800">
                                R$ {part.unit_cost_at_time?.toLocaleString('pt-BR', { minimumFractionDigits: 2 }) || '0,00'}
                              </td>
                              <td className="py-2 px-2 text-right font-medium text-secondary-900">
                                R$ {part.total_cost?.toLocaleString('pt-BR', { minimumFractionDigits: 2 }) || '0,00'}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                        <tfoot className="border-t border-secondary-200">
                          <tr>
                            <td colSpan={4} className="py-2 px-2 text-right font-semibold text-secondary-900">
                              Total das Peças:
                            </td>
                            <td className="py-2 px-2 text-right font-bold text-primary-600">
                              R$ {costParts.reduce((sum, part) => sum + (part.total_cost || 0), 0).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                            </td>
                          </tr>
                        </tfoot>
                      </table>
                    </div>
                  </div>
                </div>
              )}

              {/* Loading state para peças */}
              {loadingParts && (
                <div className="mt-6">
                  <div className="flex items-center justify-center py-4">
                    <Loader2 className="h-5 w-5 animate-spin text-primary-600 mr-2" />
                    <span className="text-sm text-secondary-600">Carregando peças...</span>
                  </div>
                </div>
              )}

              {/* Informações adicionais baseadas no tipo de custo */}
              {cost?.is_real_cost && (
                <div className="mt-6">
                  <h3 className="text-sm font-semibold text-secondary-900 mb-3 flex items-center">
                    <Info className="h-4 w-4 mr-2" />
                    Informações Adicionais
                  </h3>
                  <div className="bg-info-50 border border-info-200 rounded-lg p-4">
                    {cost.source_type === 'fine' && (
                      <div className="space-y-2">
                        <p className="text-sm text-info-800">
                          <strong>Tipo:</strong> Multa de Trânsito
                        </p>
                        <p className="text-sm text-info-800">
                          <strong>Referência:</strong> {cost.source_id}
                        </p>
                      </div>
                    )}
                    {cost.source_type === 'damage' && (
                      <div className="space-y-2">
                        <p className="text-sm text-info-800">
                          <strong>Tipo:</strong> Dano/Avaria
                        </p>
                        <p className="text-sm text-info-800">
                          <strong>Referência:</strong> {cost.source_id}
                        </p>
                      </div>
                    )}
                    {cost.source_type === 'fuel' && (
                      <div className="space-y-2">
                        <p className="text-sm text-info-800">
                          <strong>Tipo:</strong> Abastecimento
                        </p>
                        <p className="text-sm text-info-800">
                          <strong>Referência:</strong> {cost.source_id}
                        </p>
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
          ) : (
            <>
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Categoria *
                  </label>
                  <select
                    name="category"
                    value={formData.category}
                    onChange={handleChange}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    required
                    disabled={!!isViewOnly}
                  >
                    <option value="Multa">Multa</option>
                    <option value="Funilaria">Funilaria</option>
                    <option value="Seguro">Seguro</option>
                    <option value="Avulsa">Avulsa</option>
                    <option value="Compra">Compra</option>
                    <option value="Excesso Km">Excesso Km</option>
                    <option value="Diária Extra">Diária Extra</option>
                    <option value="Combustível">Combustível</option>
                    <option value="Avaria">Avaria</option>
                    <option value="Peças">Peças</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Origem *
                  </label>
                  <select
                    name="origin"
                    value={formData.origin}
                    onChange={handleChange}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    required
                    disabled={!!isViewOnly || !cost?.id} // Desabilitar se não for edição de custo existente
                  >
                    <option value="Usuario">Usuário</option>
                    <option value="Patio">Controle de Pátio</option>
                    <option value="Manutencao">Manutenção</option>
                    <option value="Sistema">Sistema</option>
                    <option value="Compras">Compras</option>
                    <option value="Multas">Multas</option>
                  </select>
                  {!cost?.id && (
                    <p className="text-xs text-secondary-600 mt-1">
                      A origem será definida automaticamente baseada na categoria selecionada
                    </p>
                  )}
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-2">
                  Veículo *
                </label>
                <select
                  name="vehicle_id"
                  value={formData.vehicle_id}
                  onChange={handleChange}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  required
                  disabled={!!isViewOnly}
                >
                  <option value="">Selecione um veículo</option>
                  {vehicles.filter(v => v.status !== 'Inativo').map(vehicle => (
                    <option key={vehicle.id} value={vehicle.id}>
                      {vehicle.plate} - {vehicle.model}
                    </option>
                  ))}
                </select>
              </div>

              {/* Department field */}
              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-2">
                  Departamento
                </label>
                <select
                  name="department"
                  value={formData.department || ''}
                  onChange={handleChange}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  disabled={!!isViewOnly}
                >
                  <option value="">Selecione um departamento (opcional)</option>
                  <option value="Cobrança">Cobrança</option>
                  <option value="Manutenção">Manutenção</option>
                  <option value="Administrativo">Administrativo</option>
                  <option value="Financeiro">Financeiro</option>
                </select>
              </div>

              {/* Customer and contract fields */}
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">Cliente *</label>
                  <select
                    name="customer_id"
                    value={formData.customer_id ? String(formData.customer_id) : ''}
                    onChange={e => handleCustomerChange(e.target.value)}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    required
                    disabled={!!isViewOnly}
                  >
                    <option value="">Selecione o cliente</option>
                    {customers.filter(c => !!c.id).map(c => (
                      <option key={c.id} value={String(c.id)}>{c.name}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2 mt-4">Contrato {filteredContracts.length > 0 ? '*' : ''}</label>
                  <select
                    name="contract_id"
                    value={formData.contract_id ? String(formData.contract_id) : ''}
                    onChange={e => setFormData(prev => ({ ...prev, contract_id: e.target.value }))}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    required={!!formData.customer_id && !!filteredContracts.length}
                    disabled={!formData.customer_id || !!isViewOnly}
                  >
                    <option value="">Selecione o contrato</option>
                    {filteredContracts.filter(c => !!c.id).map(c => (
                      <option key={c.id} value={String(c.id)}>{c.id}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-2">
                  Responsável pelo Lançamento
                </label>
                <select
                  name="created_by_employee_id"
                  value={formData.created_by_employee_id || ''}
                  onChange={handleChange}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  disabled={!!isViewOnly}
                >
                  <option value="">Sistema (automático)</option>
                  {employees.map(employee => (
                    <option key={employee.id} value={employee.id}>
                      {employee.name} - {employee.role} {employee.employee_code && `(${employee.employee_code})`}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-2">
                  Descrição *
                </label>
                <input
                  type="text"
                  name="description"
                  value={formData.description}
                  onChange={handleChange}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  placeholder="Descreva o custo..."
                  required
                  disabled={!!isViewOnly}
                />
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Valor (R$) *
                  </label>
                  {isViewOnly && !isAmountToDefine ? (
                    <div className="w-full px-3 py-2 rounded-lg bg-secondary-50 border border-secondary-200 text-secondary-800 font-semibold cursor-not-allowed">
                      {formData.amount === 0 ? 'Orçamento' : `R$ ${formData.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`}
                    </div>
                  ) : (
                    <input
                      type="number"
                      name="amount"
                      value={formData.amount ?? 0}
                      onChange={handleChange}
                      className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                      step="0.01"
                      min="0"
                      required
                      disabled={!!isViewOnly && !isAmountToDefine}
                    />
                  )}
                  {formData.amount === 0 && (
                    <p className="text-xs text-warning-600 mt-1">
                      Valor zerado - será exibido como "Orçamento"
                    </p>
                  )}
                </div>
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Data *
                  </label>
                  <input
                    type="date"
                    name="cost_date"
                    value={formData.cost_date}
                    onChange={handleChange}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    required
                    disabled={!!isViewOnly}
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-2">
                  Status *
                </label>
                <select
                  name="status"
                  value={formData.status || 'Pendente'}
                  onChange={handleChange}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  required
                  disabled={Boolean(isViewOnly && cost?.status !== 'Pendente')}
                >
                  <option value="Pendente">Pendente</option>
                  <option value="Pago">Pago</option>
                  <option value="Autorizado">Autorizado</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-2">
                  Referência do Documento
                </label>
                <input
                  type="text"
                  name="document_ref"
                  value={formData.document_ref || ''}
                  onChange={handleChange}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  placeholder="NF, número da multa, etc."
                  disabled={!!isViewOnly}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-2">
                  Observações
                </label>
                <textarea
                  name="observations"
                  value={formData.observations || ''}
                  onChange={handleChange}
                  rows={3}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  placeholder="Observações adicionais..."
                  disabled={!!(isViewOnly && !isAmountToDefine)}
                />
              </div>
            </>
          )}

          <div className="flex flex-col sm:flex-row justify-end space-y-3 sm:space-y-0 sm:space-x-4 pt-4 lg:pt-6 border-t">
            <Button variant="secondary" onClick={onClose} disabled={loading} className="w-full sm:w-auto">
              {isViewOnly ? 'Fechar' : 'Cancelar'}
            </Button>
            {!isViewOnly && (
              <Button type="submit" disabled={loading} className="w-full sm:w-auto">
                {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
                {cost ? 'Salvar Alterações' : 'Lançar Custo'}
              </Button>
            )}
            {isViewOnly && cost?.status === 'Pendente' && (
              <Button
                type="button"
                disabled={Boolean(loading)}
                className="w-full sm:w-auto"
                onClick={() => {
                  setFormData(prev => ({ ...prev, status: 'Pago' }));
                  handleSubmit({ preventDefault: () => { } } as React.FormEvent);
                }}
              >
                {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
                Marcar como Pago
              </Button>
            )}
          </div>
        </form>
      </div>
    </div>
  );
};

export const Costs: React.FC = () => {
  const { costs, loading, createCost, updateCost, updateCostEstimate, fetchRealCosts, debugAutomaticCosts, reprocessInspectionCosts, authorizePurchase, refetch, markAsPaid } = useCosts();
  const { vehicles } = useVehicles();
  const { employees } = useEmployees();
  const { isAdmin, isManager } = useAuth();
  const { customers } = useCustomers();
  const { contracts } = useContracts();
  const { updatePurchaseOrder } = usePurchaseOrders();
  const {
    recurringCosts,
    generateRecurringCosts,
    createRecurringCost,
    updateRecurringCost,
    deleteRecurringCost,
    markAsPaid: markRecurringAsPaid,
    loading: recurringLoading,
    error: errorRecurring
  } = useRecurringCosts();
  const { contracts: recurringContracts, loading: loadingContracts, error: errorContracts } = useRecurringContracts();
  const [activeTab, setActiveTab] = useState<'costs' | 'recurring'>('costs');
  const [showRecurringForm, setShowRecurringForm] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [vehicleFilter, setVehicleFilter] = useState<string>('');
  const [customerFilter, setCustomerFilter] = useState<string>('');
  const [employeeFilter, setEmployeeFilter] = useState<string>('');
  const [contractFilter, setContractFilter] = useState<string>('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isViewModalOpen, setIsViewModalOpen] = useState(false);
  const [isEstimateModalOpen, setIsEstimateModalOpen] = useState(false);
  const [selectedCost, setSelectedCost] = useState<Cost | undefined>(undefined);
  const [reprocessing, setReprocessing] = useState(false);
  const [loadingRealCosts, setLoadingRealCosts] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [showRecurringEditModal, setShowRecurringEditModal] = useState(false);
  const [recurringFormData, setRecurringFormData] = useState({
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

  // Debug automatic costs on component mount
  useEffect(() => {
    const debugCosts = async () => {
      try {
        await debugAutomaticCosts();
      } catch {
        // erro ignorado
      }
    };

    if (!loading) {
      debugCosts();
    }
  }, [loading, debugAutomaticCosts]);

  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm, vehicleFilter, customerFilter, employeeFilter, contractFilter, costs]);

  // Debug: log dos custos carregados
  console.log('Custos carregados:', costs);
  console.log('Custos com origem Contas ou salario:', costs.filter(c => c.origin === 'Contas' || c.origin === 'salario'));
  
  // Filtros para mostrar todos os custos do sistema
  const filteredCosts = costs.filter(cost => {
    // Não exibir custos avulsos de Seguro ou Despesas recorrentes (contas pagas)
    if (
      cost.origin === 'Contas' &&
      (cost.category === 'Seguro' || cost.category === 'Despesas')
    ) {
      return false;
    }
    // Aplicar filtros de busca se especificados
    const matchesSearch = !searchTerm || 
      cost.description?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      cost.category?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      cost.vehicles?.plate?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      cost.customers?.name?.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesVehicle = !vehicleFilter || cost.vehicle_id === vehicleFilter;
    const matchesCustomer = !customerFilter || cost.customer_id === customerFilter;
    const matchesEmployee = !employeeFilter || cost.created_by_employee_id === employeeFilter;
    const matchesContract = !contractFilter || cost.contract_id === contractFilter;

    return matchesSearch && matchesVehicle && matchesCustomer && matchesEmployee && matchesContract;
  });

  // Get unique departments for filter
  const departments = ['Cobrança', 'Manutenção', 'Administrativo', 'Financeiro'];
  const uniqueDepartments = [...new Set(costs.map(cost => cost.department).filter(Boolean))];
  const allDepartments = [...new Set([...departments, ...uniqueDepartments])];

  // Paginação
  const totalPages = Math.ceil(filteredCosts.length / ITEMS_PER_PAGE);
  const paginatedCosts = filteredCosts.slice((currentPage - 1) * ITEMS_PER_PAGE, currentPage * ITEMS_PER_PAGE);

  const handleView = (cost: Cost) => {
    // Evita travamento: limpa modal de edição, garante selectedCost atualizado e abre modal de visualização
    setIsModalOpen(false); // fecha modal de edição se aberto
    setTimeout(() => {
      setSelectedCost(cost);
      setIsViewModalOpen(true);
    }, 0);
  }

  const handleEdit = (cost: Cost) => {
    setSelectedCost(cost);
    setIsModalOpen(true);
  };

  const handleNew = () => {
    // Only Admin and Manager can create new costs
    if (!isAdmin && !isManager) {
      alert('Apenas administradores e gerentes podem criar novos lançamentos de custos.');
      return;
    }

    setSelectedCost(undefined);
    setIsModalOpen(true);
  };

  const handleSave = async (data: CostInsert) => {
    if (selectedCost) {
      await updateCost(selectedCost.id, data);
    } else {
      await createCost(data);
    }
  };

  const handleAuthorizePurchase = async (cost: Cost) => {
    // Only Admin and Manager can authorize purchases
    if (!isAdmin && !isManager) {
      alert('Apenas administradores e gerentes podem autorizar compras.');
      return;
    }

    if (confirm('Confirmar autorização de compra?')) {
      try {
        await authorizePurchase(cost.id);
        
        // Atualizar status do pedido de compra para 'Aprovada'
        if (cost.source_reference_type === 'purchase_order' && cost.source_reference_id) {
          // Caso direto: custo vinculado ao pedido de compra
          await updatePurchaseOrder(cost.source_reference_id, { status: 'Aprovada' });
        } else if (cost.source_reference_type === 'purchase_order_item' && cost.source_reference_id) {
          // Caso indireto: custo vinculado ao item do pedido de compra
          // Primeiro, buscar o purchase_order_id através do purchase_order_item
          const { data: purchaseOrderItem, error } = await supabase
            .from('purchase_order_items')
            .select('purchase_order_id')
            .eq('id', cost.source_reference_id)
            .single();
          
          if (error) {
            console.error('Error fetching purchase order item:', error);
            throw new Error('Erro ao buscar item do pedido de compra');
          }
          
          if (purchaseOrderItem?.purchase_order_id) {
            await updatePurchaseOrder(purchaseOrderItem.purchase_order_id, { status: 'Aprovada' });
          }
        }
        
        // Refresh the costs list to show updated status
        await refetch();
      } catch (error) {
        console.error('Error authorizing purchase:', error);
        alert('Erro ao autorizar compra: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
      }
    }
  };

  const handleReprocessCosts = async () => {
    // Only Admin can reprocess costs
    if (!isAdmin) {
      alert('Apenas administradores podem reprocessar custos.');
      return;
    }

    setReprocessing(true);
    try {
      const processed = await reprocessInspectionCosts();
      alert(`Reprocessados ${processed} custos de inspeções. A lista será atualizada.`);
    } catch (error) {
      alert('Erro ao reprocessar custos: ' + error);
    } finally {
      setReprocessing(false);
    }
  };

  const handleMarkAsPaid = async (cost: Cost) => {
    if (!isAdmin && !isManager) {
      alert('Apenas administradores e gerentes podem marcar como pago.');
      return;
    }
    if (confirm('Confirmar marcação como pago?')) {
      try {
        await markAsPaid(cost.id);
      } catch (error) {
        alert('Erro ao marcar como pago');
      }
    }
  };

  const handleLoadRealCosts = async () => {
    setLoadingRealCosts(true);
    try {
      await fetchRealCosts();
      alert('Custos reais carregados com sucesso!');
    } catch (error) {
      alert('Erro ao carregar custos reais: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
    } finally {
      setLoadingRealCosts(false);
    }
  };

  const handleEditEstimate = (cost: Cost) => {
    setSelectedCost(cost);
    setIsEstimateModalOpen(true);
  };

  const handleUpdateEstimate = async (amount: number, observations?: string) => {
    if (!selectedCost) return;

    try {
      await updateCostEstimate(selectedCost.id, amount, observations);
      setIsEstimateModalOpen(false);
      setSelectedCost(undefined);
      alert('Orçamento atualizado com sucesso!');
    } catch (error) {
      alert('Erro ao atualizar orçamento: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
    }
  };

  // Funções para custos recorrentes
  const handleMarkRecurringAsPaid = async (costId: string) => {
    if (!isAdmin && !isManager) {
      alert('Apenas administradores e gerentes podem marcar como pago.');
      return;
    }

    if (confirm('Confirmar marcação como pago?')) {
      try {
        await markRecurringAsPaid(costId);
        alert('Custo recorrente marcado como pago com sucesso!');
      } catch (error) {
        alert('Erro ao marcar como pago: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
      }
    }
  };

  const handleEditRecurring = (cost: any) => {
    setSelectedCost(cost);
    setRecurringFormData({
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
    setShowRecurringEditModal(true);
  };

  const handleDeleteRecurring = async (costId: string) => {
    if (!isAdmin && !isManager) {
      alert('Apenas administradores e gerentes podem excluir custos recorrentes.');
      return;
    }

    if (confirm('Tem certeza que deseja excluir este custo recorrente?')) {
      try {
        await deleteRecurringCost(costId);
        alert('Custo recorrente excluído com sucesso!');
      } catch (error) {
        alert('Erro ao excluir custo recorrente: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
      }
    }
  };

  const totalCosts = filteredCosts.reduce((sum, cost) => sum + cost.amount, 0);
  const pendingCosts = filteredCosts.filter(cost => cost.status === 'Pendente').length;
  const costsToDefine = filteredCosts.filter(cost => cost.amount === 0 && cost.status === 'Pendente').length;
  const automaticCosts = filteredCosts.filter(cost => cost.origin !== 'Manual').length;
  const collectionCosts = filteredCosts.filter(cost => cost.department === 'Cobrança').length;

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-primary-600" />
      </div>
    );
  }

  // Utilitários para exibição amigável de categoria e origem
  const CATEGORY_LABELS: Record<string, string> = {
    Multa: 'Multa',
    Funilaria: 'Funilaria',
    Seguro: 'Seguro',
    Avulsa: 'Avulsa',
    Compra: 'Compra',
    'Excesso Km': 'Excesso Km',
    'Diária Extra': 'Diária Extra',
    'Combustível': 'Combustível',
    Avaria: 'Avaria',
    Peças: 'Peças',
  };
  const ORIGIN_LABELS: Record<string, string> = {
    Usuario: 'Usuário',
    Patio: 'Controle de Pátio',
    Manutencao: 'Manutenção',
    Sistema: 'Sistema',
    Compras: 'Compras',
    Multas: 'Multas',
    Abastecimento: 'Abastecimento',
  };
  const getCategoryLabel = (cost: any): string => {
    if (!cost.category) return '-';
    return CATEGORY_LABELS[cost.category] || cost.category;
  };
  const getOriginLabel = (cost: any): string => {
    if (cost.category === 'Multa') return 'Multas';
    if (!cost.origin) return '-';
    return ORIGIN_LABELS[cost.origin] || cost.origin;
  };

  return (
    <div className="space-y-4 lg:space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl lg:text-3xl font-bold text-secondary-900">Custos</h1>
          <p className="text-secondary-600 mt-1 lg:mt-2">Controle todos os custos da operação com rastreabilidade completa</p>
        </div>
        <div className="flex flex-col sm:flex-row space-y-2 sm:space-y-0 sm:space-x-3 w-full sm:w-auto">
          {/* Botão 'Reprocessar Custos' removido */}
        </div>
      </div>

      {/* Tabs */}
      <div className="border-b border-secondary-200">
        <nav className="-mb-px flex space-x-8">
          <button
            onClick={() => setActiveTab('costs')}
            className={`py-2 px-1 border-b-2 font-medium text-sm ${activeTab === 'costs'
                ? 'border-primary-500 text-primary-600'
                : 'border-transparent text-secondary-500 hover:text-secondary-700 hover:border-secondary-300'
              }`}
          >
            <DollarSign className="h-4 w-4 inline mr-2" />
            Custos Avulsos
          </button>
          <button
            onClick={() => setActiveTab('recurring')}
            className={`py-2 px-1 border-b-2 font-medium text-sm ${activeTab === 'recurring'
                ? 'border-primary-500 text-primary-600'
                : 'border-transparent text-secondary-500 hover:text-secondary-700 hover:border-secondary-300'
              }`}
          >
            <Repeat className="h-4 w-4 inline mr-2" />
            Custos Recorrentes
          </button>
        </nav>
      </div>

      {/* Content based on active tab */}
      {activeTab === 'costs' && (
        <>
          {/* Summary Cards */}
          <div className="grid grid-cols-2 lg:grid-cols-5 gap-3 lg:gap-6">
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-secondary-600 text-xs lg:text-sm font-medium">Total de Custos</p>
                    <p className="text-xl lg:text-2xl font-bold text-secondary-900">
                      R$ {totalCosts.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                    </p>
                  </div>
                  <div className="h-8 w-8 lg:h-12 lg:w-12 bg-error-100 rounded-lg flex items-center justify-center">
                    <DollarSign className="h-4 w-4 lg:h-6 lg:w-6 text-error-600" />
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-secondary-600 text-xs lg:text-sm font-medium">Valores A Definir</p>
                    <p className="text-xl lg:text-2xl font-bold text-warning-600">{costsToDefine}</p>
                    <p className="text-xs text-warning-600 mt-1">Aguardando orçamento</p>
                  </div>
                  <div className="h-8 w-8 lg:h-12 lg:w-12 bg-warning-100 rounded-lg flex items-center justify-center">
                    <AlertTriangle className="h-4 w-4 lg:h-6 lg:w-6 text-warning-600" />
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-secondary-600 text-xs lg:text-sm font-medium">Custos Pendentes</p>
                    <p className="text-xl lg:text-2xl font-bold text-secondary-900">{pendingCosts}</p>
                  </div>
                  <div className="h-8 w-8 lg:h-12 lg:w-12 bg-warning-100 rounded-lg flex items-center justify-center">
                    <Calendar className="h-4 w-4 lg:h-6 lg:w-6 text-warning-600" />
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-secondary-600 text-xs lg:text-sm font-medium">Custos Automáticos</p>
                    <p className="text-xl lg:text-2xl font-bold text-secondary-900">{automaticCosts}</p>
                    <p className="text-xs text-secondary-600 mt-1">Gerados pelo sistema</p>
                  </div>
                  <div className="h-8 w-8 lg:h-12 lg:w-12 bg-info-100 rounded-lg flex items-center justify-center">
                    <ClipboardCheck className="h-4 w-4 lg:h-6 lg:w-6 text-info-600" />
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-secondary-600 text-xs lg:text-sm font-medium">Cobrança</p>
                    <p className="text-xl lg:text-2xl font-bold text-secondary-900">{collectionCosts}</p>
                    <p className="text-xs text-secondary-600 mt-1">Departamento de cobrança</p>
                  </div>
                  <div className="h-8 w-8 lg:h-12 lg:w-12 bg-primary-100 rounded-lg flex items-center justify-center">
                    <FileText className="h-4 w-4 lg:h-6 lg:w-6 text-primary-600" />
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Alert for costs to define */}
          {costsToDefine > 0 && (
            <Card className="border-warning-200 bg-warning-50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-3">
                  <AlertTriangle className="h-5 w-5 text-warning-600 flex-shrink-0" />
                  <div>
                    <p className="text-warning-800 font-medium">
                      {costsToDefine} custo{costsToDefine > 1 ? 's' : ''} com valor a definir
                    </p>
                    <p className="text-warning-700 text-sm mt-1">
                      Estes custos foram gerados automaticamente pelo sistema.
                      Clique em "Visualizar" para definir o valor após receber o orçamento.
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}

          {/* Filtros (somente admin) */}
          {isAdmin && (
          <Card>
              <CardContent>
                <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                  <select value={vehicleFilter} onChange={e=>setVehicleFilter(e.target.value)} className="border border-secondary-300 rounded-lg px-3 py-2">
                    <option value="">Todos Veículos</option>
                    {vehicles.map(v=> (
                      <option key={v.id} value={v.id}>{v.plate}</option>
                    ))}
                  </select>
                  <select value={customerFilter} onChange={e=>setCustomerFilter(e.target.value)} className="border border-secondary-300 rounded-lg px-3 py-2">
                    <option value="">Todos Clientes</option>
                    {customers.map(c=> (
                      <option key={c.id} value={c.id}>{c.name}</option>
                    ))}
                  </select>
                  <select value={employeeFilter} onChange={e=>setEmployeeFilter(e.target.value)} className="border border-secondary-300 rounded-lg px-3 py-2">
                    <option value="">Todos Funcionários</option>
                    {employees.map(emp=> (
                      <option key={emp.id} value={emp.id}>{emp.name}</option>
                    ))}
                  </select>
                  <select value={contractFilter} onChange={e=>setContractFilter(e.target.value)} className="border border-secondary-300 rounded-lg px-3 py-2">
                    <option value="">Todos Contratos</option>
                    {contracts.map(ct=> (
                      <option key={ct.id} value={ct.id}>#{ct.contract_number || ct.id.substring(0,8)}</option>
                    ))}
                  </select>
              </div>
            </CardContent>
          </Card>
          )}

          {/* Costs List */}
          <Card>
            <CardHeader className="p-4 lg:p-6">
              <div className="flex justify-between items-center">
                <h3 className="text-lg font-semibold text-secondary-900">
                  Lançamentos de Custos ({filteredCosts.length})
                </h3>
                <Button variant="secondary" size="sm" onClick={refetch}>
                  <RefreshCw className="h-4 w-4 mr-2" />
                  Atualizar
                </Button>
              </div>
            </CardHeader>
            <CardContent className="p-0">
              {/* Mobile view */}
              <div className="lg:hidden">
                <div className="divide-y divide-secondary-200">
                  {paginatedCosts.map((cost) => (
                    <div key={cost.id} className="p-4 space-y-3">
                      <div className="flex justify-between items-start">
                        <div className="flex-1">
                          <div className="flex items-center space-x-2 mb-1">
                            <Badge variant="secondary" className="text-xs">
                              {cost.origin_description || cost.origin}
                            </Badge>
                            <Badge variant="secondary" className="text-xs">
                              {cost.category}
                            </Badge>
                          </div>
                          <p className="text-sm font-medium text-secondary-900 mb-1">
                            {cost.description}
                          </p>
                          <div className="flex items-center text-xs text-secondary-600 space-x-4">
                            <span>{new Date(cost.cost_date).toLocaleDateString('pt-BR')}</span>
                            <span>{cost.vehicles?.plate || cost.vehicle_plate || '-'}</span>
                            <span>{cost.customers?.name || cost.customer_name || '-'}</span>
                            <span>
                              {cost.origin === 'Usuario' ? 'Usuário' : 
                               cost.origin === 'Patio' ? 'Pátio' :
                               cost.origin === 'Manutencao' ? 'Manutenção' :
                               cost.origin === 'Sistema' ? 'Sistema' :
                               cost.origin === 'Compras' ? 'Compras' :
                               cost.origin === 'Multas' ? 'Multas' :
                               cost.origin || '-'}
                            </span>
                          </div>
                        </div>
                        <div className="text-right">
                          <div className="text-sm font-medium text-secondary-900 mb-1">
                            {cost.amount === 0 && cost.status === 'Pendente' ? (
                              <span className="text-warning-600">A Definir</span>
                            ) : (
                              `R$ ${cost.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`
                            )}
                          </div>
                          <Badge variant={cost.status === 'Pago' ? 'success' : cost.status === 'Autorizado' ? 'info' : 'warning'}>
                            {cost.status}
                          </Badge>
                        </div>
                      </div>
                      <div className="flex justify-between items-center mt-2">
                        <div className="text-xs text-secondary-600">
                          {cost.employees?.name || cost.created_by_name || (cost.origin === 'Sistema' ? 'Sistema' : '-')}
                        </div>
                        <div className="flex items-center space-x-2">
                          <Button
                            onClick={() => handleView(cost)}
                            variant="secondary"
                            size="sm"
                            className="text-xs"
                          >
                            Visualizar
                          </Button>
                          {(isAdmin || isManager) && (
                            <Button
                              onClick={() => handleEdit(cost)}
                              variant="secondary"
                              size="sm"
                              className="text-xs"
                            >
                              <Edit2 className="h-3 w-3" />
                            </Button>
                          )}
                          {/* Botão Adicionar Orçamento (mobile) */}
                          {cost.status === 'Pendente' && cost.amount === 0 &&
                            ((['Funilaria', 'Avaria'].includes(cost.category) || cost.origin === 'Patio')) && (
                              <Button
                                onClick={() => handleEditEstimate(cost)}
                                variant="primary"
                                size="sm"
                                className="text-xs"
                              >
                                Adicionar Orçamento
                              </Button>
                            )
                          }
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Desktop Table */}
              <div className="hidden lg:block overflow-x-auto">
                <table className="min-w-full divide-y divide-secondary-200">
                  <thead className="bg-secondary-50">
                    <tr>
                      <th className="px-4 py-2 text-left text-xs font-semibold text-secondary-900">Descrição</th>
                      <th className="px-4 py-2 text-left text-xs font-semibold text-secondary-900">Categoria / Origem</th>
                      <th className="px-4 py-2 text-left text-xs font-semibold text-secondary-900">Valor</th>
                      <th className="px-4 py-2 text-left text-xs font-semibold text-secondary-900">Status</th>
                      <th className="px-4 py-2 text-left text-xs font-semibold text-secondary-900">Data</th>
                      <th className="px-4 py-2 text-left text-xs font-semibold text-secondary-900">Veículo</th>
                      <th className="px-4 py-2 text-left text-xs font-semibold text-secondary-900">Cliente</th>
                      <th className="px-4 py-2 text-left text-xs font-semibold text-secondary-900">Responsável</th>
                      <th className="px-4 py-2 text-left text-xs font-semibold text-secondary-900">Ações</th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-secondary-100">
                    {paginatedCosts.map((cost) => (
                      <tr key={cost.id}>
                        <td className="px-4 py-2 text-secondary-900 font-medium">{cost.description}</td>
                        <td className="px-4 py-2 text-secondary-800">
                          <div className="flex flex-col gap-1">
                            <div className="flex items-center gap-2">
                              <Badge variant="secondary" className="text-xs w-fit">{getCategoryLabel(cost)}</Badge>
                              {cost.status === 'Pendente' && (cost.category === 'Compra' || cost.origin === 'Compras') && (
                                <Button
                                  onClick={() => handleAuthorizePurchase(cost)}
                                  variant="success"
                                  size="sm"
                                  className="ml-1 px-2 py-1 text-xs"
                                >
                                  Aprovar
                                </Button>
                              )}
                            </div>
                            <Badge variant="secondary" className="text-xxs w-fit">{getOriginLabel(cost)}</Badge>
                          </div>
                        </td>
                        <td className="px-4 py-2 text-secondary-900 font-semibold">
                          {cost.amount === 0 && cost.status === 'Pendente' ? (
                            <span className="text-warning-600">A Definir</span>
                          ) : (
                            `R$ ${cost.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`
                          )}
                        </td>
                        <td className="px-4 py-2">
                          {/* Se for pendente e valor zerado, mostrar "Orçamento" e botão */}
                          {cost.status === 'Pendente' && cost.amount === 0 ? (
                            <div className="flex items-center gap-2">
                              <Badge variant="warning">Orçamento</Badge>
                              
                            </div>
                          ) : (
                            <Badge variant={cost.status === 'Pago' ? 'success' : cost.status === 'Autorizado' ? 'info' : 'warning'}>
                              {cost.status}
                            </Badge>
                          )}
                        </td>
                        <td className="px-4 py-2 text-secondary-700">{new Date(cost.cost_date).toLocaleDateString('pt-BR')}</td>
                        <td className="px-4 py-2">{cost.vehicles?.plate || cost.vehicle_plate || '-'}</td>
                        <td className="px-4 py-2">{cost.customers?.name || cost.customer_name || '-'}</td>
                        <td className="px-4 py-2">
                          {cost.employees?.name || cost.created_by_name || (cost.origin === 'Sistema' ? 'Sistema' : '-')}
                        </td>
                        <td className="px-4 py-2">
                          <div className="flex flex-row gap-2">
                            <Button
                              onClick={() => handleView(cost)}
                              variant="secondary"
                              size="sm"
                              className="text-xs"
                            >
                              Visualizar
                            </Button>
                            {(isAdmin || isManager) && (
                              <Button
                                onClick={() => handleEdit(cost)}
                                variant="secondary"
                                size="sm"
                                className="text-xs"
                              >
                                <Edit2 className="h-3 w-3" />
                              </Button>
                            )}
                            {/* Botão Adicionar Orçamento - sempre visível para custos pendentes e zerados */}
                            {cost.status === 'Pendente' && cost.amount === 0 &&
                              ((['Funilaria', 'Avaria'].includes(cost.category) || cost.origin === 'Patio')) && (
                                <Button
                                  onClick={() => handleEditEstimate(cost)}
                                  variant="primary"
                                  size="sm"
                                  className="text-xs"
                                >
                                  Adicionar Orçamento
                                </Button>
                              )
                            }
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {filteredCosts.length === 0 && (
                <div className="text-center py-8">
                  <DollarSign className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
                  <p className="text-secondary-600">Nenhum custo encontrado</p>
                  <p className="text-sm text-secondary-500 mt-2">
                    Todos os custos do sistema são exibidos aqui, incluindo multas, danos, manutenções e custos avulsos.
                  </p>
                </div>
              )}

              <div className="flex justify-between items-center mt-4">
                <button
                  className="px-3 py-1 rounded bg-secondary-100 text-secondary-700 disabled:opacity-50"
                  onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                >
                  Anterior
                </button>
                <span>Página {currentPage} de {totalPages}</span>
                <button
                  className="px-3 py-1 rounded bg-secondary-100 text-secondary-700 disabled:opacity-50"
                  onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                  disabled={currentPage === totalPages}
                >
                  Próxima
                </button>
              </div>
            </CardContent>
          </Card>
        </>
      )}

      {/* Recurring Costs Tab */}
      {activeTab === 'recurring' && (
        <>
          {/* Cards de Resumo - UI aprimorada e traduzida */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <Card>
              <CardContent className="p-4 flex flex-col items-center justify-center">
                <span className="text-xs text-blue-700 font-medium mb-1">Total de Recorrentes</span>
                <span className="text-2xl font-bold text-blue-900">{recurringCosts.length + recurringContracts.length}</span>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4 flex flex-col items-center justify-center">
                <span className="text-xs text-green-700 font-medium mb-1">Valor Mensal Total</span>
                <span className="text-2xl font-bold text-green-700">
                  {(() => {
                    // Soma todos os custos recorrentes
                    const totalRecurringCosts = recurringCosts.reduce((sum, c) => sum + (c.amount || 0), 0);
                    // Soma todos os daily_rate de contratos recorrentes ativos
                    const totalRecurringContracts = recurringContracts.reduce((sum, c) => {
                      if (!c.daily_rate) return sum;
                      if (c.status && c.status !== 'Ativo') return sum;
                      return sum + c.daily_rate;
                    }, 0);
                    const total = totalRecurringCosts + totalRecurringContracts;
                    return `R$ ${total.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`;
                  })()}
                </span>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4 flex flex-col items-center justify-center">
                <span className="text-xs text-orange-700 font-medium mb-1">Próximos Vencimentos</span>
                <span className="text-2xl font-bold text-orange-700">
                  {recurringCosts.filter(c => c.next_due_date && new Date(c.next_due_date) >= new Date()).length}
                </span>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4 flex flex-col items-center justify-center">
                <span className="text-xs text-purple-700 font-medium mb-1">Recorrentes Pagos</span>
                <span className="text-2xl font-bold text-purple-700">{recurringCosts.filter(c => c.status === 'Pago').length}</span>
              </CardContent>
            </Card>
            <div className="flex justify-end col-span-1 md:col-span-4">
              <Button onClick={() => setShowRecurringForm(true)} variant="primary" className="mt-2">+ Novo Custo Recorrente</Button>
            </div>
          </div>

          {/* Lista de Custos Recorrentes - UI aprimorada, traduzida e com dados reais */}
          <Card>
            <CardHeader className="bg-blue-50 border-b border-blue-200 rounded-t-lg">
              <h2 className="text-base font-semibold text-blue-900">Custos Recorrentes ({recurringCosts.length})</h2>
            </CardHeader>
            <CardContent className="p-0">
              {recurringCosts.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-12">
                  <Repeat className="h-8 w-8 text-blue-400 mb-2" />
                  <span className="text-blue-700 font-medium">Nenhum custo recorrente cadastrado</span>
                  <span className="text-blue-500 text-sm mt-1">Cadastre custos que se repetem automaticamente, como aluguel de veículos, seguros ou manutenções.</span>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-secondary-200">
                    <thead className="bg-blue-50">
                      <tr>
                        <th className="px-4 py-2 text-left text-xs font-semibold text-blue-900">Descrição</th>
                        <th className="px-4 py-2 text-left text-xs font-semibold text-blue-900">Categoria</th>
                        <th className="px-4 py-2 text-left text-xs font-semibold text-blue-900">Valor (R$)</th>
                        <th className="px-4 py-2 text-left text-xs font-semibold text-blue-900">Status</th>
                        <th className="px-4 py-2 text-left text-xs font-semibold text-blue-900">Cliente</th>
                        <th className="px-4 py-2 text-left text-xs font-semibold text-blue-900">Veículo</th>
                        <th className="px-4 py-2 text-left text-xs font-semibold text-blue-900">Próx. Vencimento</th>
                        <th className="px-4 py-2 text-left text-xs font-semibold text-blue-900">Ações</th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-secondary-100">
                      {recurringCosts.map((cost) => (
                        <tr key={cost.id}>
                          <td className="px-4 py-2 text-secondary-900 font-medium">{cost.description}</td>
                          <td className="px-4 py-2 text-secondary-800">{cost.category}</td>
                          <td className="px-4 py-2 text-green-700 font-semibold">R$ {cost.amount?.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}</td>
                          <td className="px-4 py-2">
                            <Badge variant={cost.status === 'Pago' ? 'success' : cost.status === 'Autorizado' ? 'info' : 'warning'}>
                              {cost.status === 'Pendente' ? 'Pendente' : cost.status === 'Autorizado' ? 'Autorizado' : 'Pago'}
                            </Badge>
                          </td>
                          <td className="px-4 py-2">{customers.find(c => c.id === cost.customer_id)?.name || '-'}</td>
                          <td className="px-4 py-2">{vehicles.find(v => v.id === cost.vehicle_id)?.plate || '-'}</td>
                          <td className="px-4 py-2 text-secondary-700">{cost.next_due_date ? new Date(cost.next_due_date).toLocaleDateString('pt-BR') : '-'}</td>
                          <td className="px-4 py-2">
                            <Button size="sm" variant="secondary" onClick={() => handleEditRecurring(cost)}>Editar</Button>
                            <Button size="sm" variant="danger" className="ml-2" onClick={() => handleDeleteRecurring(cost.id)}>Excluir</Button>
                            {cost.status !== 'Pago' && (
                              <Button size="sm" variant="success" className="ml-2" onClick={() => handleMarkRecurringAsPaid(cost.id)}>
                                Marcar como Pago
                              </Button>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </CardContent>
          </Card>

          {/* Tabela de Contratos Recorrentes */}
          <div className="mt-8">
            <h3 className="text-lg font-bold mb-2 text-purple-900">Contratos Recorrentes</h3>
            {loadingContracts ? (
              <div className="py-6 text-center text-secondary-600">Carregando contratos recorrentes...</div>
            ) : errorContracts ? (
              <div className="text-red-600 py-6">{errorContracts}</div>
            ) : recurringContracts.length === 0 ? (
              <div className="text-purple-500 py-6">Nenhum contrato recorrente configurado.</div>
            ) : (
              <div className="overflow-x-auto">
              <table className="min-w-full border text-sm bg-purple-50 rounded-lg overflow-hidden">
                <thead>
                  <tr className="bg-purple-100">
                    <th className="px-3 py-2 text-left">Nome</th>
                    <th className="px-3 py-2 text-left">Cliente</th>
                    <th className="px-3 py-2 text-left">Veículo</th>
                    <th className="px-3 py-2 text-left">Início</th>
                    <th className="px-3 py-2 text-left">Fim</th>
                    <th className="px-3 py-2 text-left">Recorrência</th>
                    <th className="px-3 py-2 text-left">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {recurringContracts.map(contract => (
                    <tr key={contract.id} className="border-b border-purple-200 hover:bg-purple-100">
                      <td className="px-3 py-2 font-semibold text-purple-900">{contract.name}</td>
                      <td className="px-3 py-2">{customers.find(c => c.id === contract.customer_id)?.name || contract.customer_id}</td>
                      <td className="px-3 py-2">{vehicles.find(v => v.id === contract.vehicle_id)?.plate || contract.vehicle_id}</td>
                      <td className="px-3 py-2">{contract.start_date ? new Date(contract.start_date).toLocaleDateString('pt-BR') : '-'}</td>
                      <td className="px-3 py-2">{contract.end_date ? new Date(contract.end_date).toLocaleDateString('pt-BR') : '-'}</td>
                        <td className="px-3 py-2">{contract.recurrence_type === 'monthly' ? 'Mensal' : contract.recurrence_type === 'weekly' ? 'Semanal' : contract.recurrence_type === 'yearly' ? 'Anual' : '-'} {contract.recurrence_day ? `(${contract.recurrence_day})` : ''}</td>
                      <td className="px-3 py-2">{contract.status}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              </div>
            )}
          </div>
        </>
      )}

      {/* Recurring Costs Form Modal */}
      {showRecurringForm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-lg font-semibold text-secondary-900">Novo Custo Recorrente</h2>
              <button
                onClick={() => setShowRecurringForm(false)}
                className="text-secondary-400 hover:text-secondary-600 p-2"
              >×</button>
            </div>
            <RecurringCostsForm
              onClose={() => setShowRecurringForm(false)}
              onSave={async (data) => {
                await createRecurringCost({ ...data, is_recurring: true });
                setShowRecurringForm(false);
              }}
            />
          </div>
        </div>
      )}

      {/* Recurring Cost Edit Modal */}
      {showRecurringEditModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-lg font-semibold text-secondary-900">
                {selectedCost ? 'Editar Custo Recorrente' : 'Novo Custo Recorrente'}
              </h2>
              <button
                onClick={() => setShowRecurringEditModal(false)}
                className="text-secondary-400 hover:text-secondary-600 p-2"
              >
                ×
              </button>
            </div>

            <form onSubmit={async (e) => {
              e.preventDefault();
              try {
                if (selectedCost) {
                  await updateRecurringCost(selectedCost.id, recurringFormData);
                  alert('Custo recorrente atualizado com sucesso!');
                } else {
                  await createRecurringCost({
                    ...recurringFormData,
                    is_recurring: true
                  });
                  alert('Custo recorrente criado com sucesso!');
                }
                setShowRecurringEditModal(false);
                setSelectedCost(undefined);
              } catch (error) {
                alert('Erro ao salvar custo recorrente: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
              }
            }}>
              <div className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-secondary-700 mb-2">
                      Categoria *
                    </label>
                    <select
                      value={recurringFormData.category}
                      onChange={(e) => setRecurringFormData(prev => ({ ...prev, category: e.target.value }))}
                      className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                      required
                    >
                      <option value="">Selecione uma categoria</option>
                      <option value="Aluguel de Veículo">Aluguel de Veículo</option>
                      <option value="Seguro">Seguro</option>
                      <option value="Manutenção">Manutenção</option>
                      <option value="Combustível">Combustível</option>
                      <option value="Outros">Outros</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-secondary-700 mb-2">
                      Tipo de Recorrência *
                    </label>
                    <select
                      value={recurringFormData.recurrence_type}
                      onChange={(e) => setRecurringFormData(prev => ({
                        ...prev,
                        recurrence_type: e.target.value as 'monthly' | 'weekly' | 'yearly'
                      }))}
                      className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                      required
                    >
                      <option value="monthly">Mensal</option>
                      <option value="weekly">Semanal</option>
                      <option value="yearly">Anual</option>
                    </select>
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Descrição *
                  </label>
                  <input
                    type="text"
                    value={recurringFormData.description}
                    onChange={(e) => setRecurringFormData(prev => ({ ...prev, description: e.target.value }))}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    placeholder="Descrição do custo recorrente..."
                    required
                  />
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-secondary-700 mb-2">
                      Valor (R$) *
                    </label>
                    <input
                      type="number"
                      value={recurringFormData.amount}
                      onChange={(e) => setRecurringFormData(prev => ({ ...prev, amount: Number(e.target.value) || 0 }))}
                      className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                      step="0.01"
                      min="0"
                      required
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-secondary-700 mb-2">
                      Dia da Recorrência *
                    </label>
                    <input
                      type="number"
                      value={recurringFormData.recurrence_day}
                      onChange={(e) => setRecurringFormData(prev => ({ ...prev, recurrence_day: Number(e.target.value) || 1 }))}
                      className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                      min="1"
                      max="31"
                      required
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Veículo
                  </label>
                  <select
                    value={recurringFormData.vehicle_id}
                    onChange={(e) => setRecurringFormData(prev => ({ ...prev, vehicle_id: e.target.value }))}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  >
                    <option value="">Selecione um veículo (opcional)</option>
                    {vehicles.filter(v => v.status !== 'Inativo').map(vehicle => (
                      <option key={vehicle.id} value={vehicle.id}>
                        {vehicle.plate} - {vehicle.model}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Status *
                  </label>
                  <select
                    value={recurringFormData.status}
                    onChange={(e) => setRecurringFormData(prev => ({
                      ...prev,
                      status: e.target.value as 'Pendente' | 'Autorizado' | 'Pago'
                    }))}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    required
                  >
                    <option value="Pendente">Pendente</option>
                    <option value="Autorizado">Autorizado</option>
                    <option value="Pago">Pago</option>
                  </select>
                </div>
              </div>

              <div className="flex justify-end space-x-3 mt-6">
                <button
                  type="button"
                  onClick={() => setShowRecurringEditModal(false)}
                  className="px-4 py-2 text-secondary-600 hover:text-secondary-800"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-primary-500"
                >
                  {selectedCost ? 'Atualizar' : 'Criar'} Custo Recorrente
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Create/Edit Modal */}

      {/* Create/Edit Modal */}
      <CostModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        cost={selectedCost}
        vehicles={vehicles}
        employees={employees}
        onSave={handleSave}
        isReadOnly={false}
      />

      {/* View Modal */}
      <CostModal
        isOpen={isViewModalOpen}
        onClose={() => setIsViewModalOpen(false)}
        cost={selectedCost}
        vehicles={vehicles}
        employees={employees}
        onSave={handleSave}
        isReadOnly={true}
      />

      {/* Estimate Edit Modal */}
      {isEstimateModalOpen && selectedCost && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg p-6 w-full max-w-md">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-lg font-semibold text-secondary-900">
                Editar Orçamento
              </h2>
              <button
                onClick={() => setIsEstimateModalOpen(false)}
                className="text-secondary-400 hover:text-secondary-600 p-2"
              >
                ×
              </button>
            </div>

            <div className="mb-4">
              <p className="text-sm text-secondary-600 mb-2">
                <strong>Descrição:</strong> {selectedCost.description}
              </p>
              <p className="text-sm text-secondary-600 mb-2">
                <strong>Categoria:</strong> {selectedCost.category}
              </p>
              <p className="text-sm text-secondary-600 mb-2">
                <strong>Veículo:</strong> {selectedCost.vehicles?.plate || selectedCost.vehicle_plate || '-'}
              </p>
            </div>

            <form onSubmit={(e) => {
              e.preventDefault();
              const formData = new FormData(e.currentTarget);
              const amount = Number(formData.get('amount'));
              const observations = formData.get('observations') as string;
              handleUpdateEstimate(amount, observations);
            }}>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Valor do Orçamento *
                  </label>
                  <input
                    type="number"
                    name="amount"
                    step="0.01"
                    min="0"
                    required
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    placeholder="0,00"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-2">
                    Observações
                  </label>
                  <textarea
                    name="observations"
                    rows={3}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    placeholder="Observações sobre o orçamento..."
                  />
                </div>
              </div>

              <div className="flex justify-end space-x-3 mt-6">
                <button
                  type="button"
                  onClick={() => setIsEstimateModalOpen(false)}
                  className="px-4 py-2 text-secondary-600 hover:text-secondary-800"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-primary-500"
                >
                  Salvar Orçamento
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default Costs;

export { CostModal };