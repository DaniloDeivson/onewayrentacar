import React, { useState, useEffect } from 'react';
import { Card, CardHeader, CardContent } from '../components/UI/Card';
import { Button } from '../components/UI/Button';
import { Badge } from '../components/UI/Badge';
import { useContracts } from '../hooks/useContracts';
import { useCustomers } from '../hooks/useCustomers';
import { useEmployees } from '../hooks/useEmployees';
import { Plus, Search, Filter, Users, Calendar, DollarSign, TrendingUp, Loader2, Edit, Eye, Trash2, CheckCircle, UserCheck } from 'lucide-react';
import { ContractForm } from '../components/Contracts/ContractForm';
import toast from 'react-hot-toast';
import { supabase } from '../lib/supabase';

const CustomerModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  customer?: any;
  onSave: (data: any) => Promise<void>;
}> = ({ isOpen, onClose, customer, onSave }) => {
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    name: customer?.name || '',
    document: customer?.document || '',
    email: customer?.email || '',
    phone: customer?.phone || '',
    address: customer?.address || ''
  });

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      const submitData = {
        ...formData,
        email: formData.email === '' ? null : formData.email,
        phone: formData.phone === '' ? null : formData.phone,
        address: formData.address === '' ? null : formData.address
      };
      await onSave(submitData);
      onClose();
    } catch (error) {
      console.error('Error saving customer:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-lg">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <h2 className="text-lg lg:text-xl font-semibold text-secondary-900">
            {customer ? 'Editar Cliente' : 'Novo Cliente'}
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            ×
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              Nome *
            </label>
            <input
              type="text"
              name="name"
              value={formData.name}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder="Nome completo"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              CPF/CNPJ *
            </label>
            <input
              type="text"
              name="document"
              value={formData.document}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder="000.000.000-00"
              required
            />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-secondary-700 mb-2">
                Email
              </label>
              <input
                type="email"
                name="email"
                value={formData.email}
                onChange={handleChange}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                placeholder="email@exemplo.com"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-secondary-700 mb-2">
                Telefone
              </label>
              <input
                type="tel"
                name="phone"
                value={formData.phone}
                onChange={handleChange}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                placeholder="(11) 99999-9999"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              Endereço
            </label>
            <textarea
              name="address"
              value={formData.address}
              onChange={handleChange}
              rows={3}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder="Endereço completo..."
            />
          </div>

          <div className="flex flex-col sm:flex-row justify-end space-y-3 sm:space-y-0 sm:space-x-4 pt-4 border-t">
            <Button variant="secondary" onClick={onClose} disabled={loading} className="w-full sm:w-auto">
              Cancelar
            </Button>
            <Button type="submit" disabled={loading} className="w-full sm:w-auto">
              {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
              {customer ? 'Salvar Alterações' : 'Cadastrar Cliente'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
};

const ContractModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  contract?: any;
  customers: any[];
  employees: any[];
  onSave: (data: any, vehiclesList: any[]) => Promise<void>;
}> = ({ isOpen, onClose, contract, customers, employees, onSave }) => {
  const [loading, setLoading] = useState(false);

  if (!isOpen) return null;

  const handleSave = async (formData: any, vehiclesList: any[]) => {
    setLoading(true);
    try {
      await onSave(formData, vehiclesList);
      onClose();
      toast.success('Contrato salvo com sucesso!');
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Erro ao salvar contrato');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <h2 className="text-lg lg:text-xl font-semibold text-secondary-900">
            {contract ? 'Editar Contrato' : 'Novo Contrato'}
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            ×
          </button>
        </div>

        <ContractForm
          onSubmit={handleSave}
          onCancel={onClose}
          contract={contract}
          customers={customers}
          employees={employees}
          loading={loading}
        />
      </div>
    </div>
  );
};

// Modal para visualizar detalhes do contrato
const ContractViewModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  contract?: any;
  getSalespersonName: (id: string | null) => string;
}> = ({ isOpen, onClose, contract, getSalespersonName }) => {
  if (!isOpen || !contract) return null;

  const totalDays = Math.ceil((new Date(contract.end_date).getTime() - new Date(contract.start_date).getTime()) / (1000 * 60 * 60 * 24)) + 1;
  const totalValue = totalDays * contract.daily_rate;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <h2 className="text-lg lg:text-xl font-semibold text-secondary-900">
            Detalhes do Contrato: {contract.name || 'Sem nome'}
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            ×
          </button>
        </div>

        <div className="space-y-6">
          {/* Informações do Cliente */}
          <div className="bg-secondary-50 p-4 rounded-lg">
            <h3 className="font-semibold text-secondary-900 mb-3">Informações do Cliente</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-secondary-700">Nome</label>
                <p className="text-secondary-900">{contract.customers?.name || 'Sem nome'}</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-secondary-700">Documento</label>
                <p className="text-secondary-900">{contract.customers?.document || 'Sem documento'}</p>
              </div>
              {contract.customers?.email && (
                <div>
                  <label className="block text-sm font-medium text-secondary-700">Email</label>
                  <p className="text-secondary-900">{contract.customers.email || 'Sem email'}</p>
                </div>
              )}
              {contract.customers?.phone && (
                <div>
                  <label className="block text-sm font-medium text-secondary-700">Telefone</label>
                  <p className="text-secondary-900">{contract.customers.phone || 'Sem telefone'}</p>
                </div>
              )}
            </div>
          </div>

          {/* Informações do Veículo */}
          <div className="bg-secondary-50 p-4 rounded-lg">
            <h3 className="font-semibold text-secondary-900 mb-3">Informações do Veículo</h3>
            {contract.uses_multiple_vehicles && (contract as any).contract_vehicles && (contract as any).contract_vehicles.length > 0 ? (
              <div className="space-y-4">
                {(contract as any).contract_vehicles.map((contractVehicle: any, index: number) => (
                  <div key={contractVehicle.id} className="grid grid-cols-1 md:grid-cols-2 gap-4 p-3 bg-white rounded-lg">
                    <div>
                      <label className="block text-sm font-medium text-secondary-700">Veículo {index + 1} - Placa</label>
                      <p className="text-secondary-900">{contractVehicle.vehicles?.plate || 'Sem placa'}</p>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-secondary-700">Modelo</label>
                      <p className="text-secondary-900">{contractVehicle.vehicles?.model || 'Sem modelo'} ({contractVehicle.vehicles?.year || 'Sem ano'})</p>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-secondary-700">Tipo</label>
                      <p className="text-secondary-900">{contractVehicle.vehicles?.type || 'Sem tipo'}</p>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-secondary-700">Valor Diário</label>
                      <p className="text-secondary-900">
                        R$ {(contractVehicle.daily_rate || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-secondary-700">Placa</label>
                  <p className="text-secondary-900">{(contract as any).vehicles?.plate || 'Sem placa'}</p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-secondary-700">Modelo</label>
                  <p className="text-secondary-900">{(contract as any).vehicles?.model || 'Sem modelo'} ({(contract as any).vehicles?.year || 'Sem ano'})</p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-secondary-700">Tipo</label>
                  <p className="text-secondary-900">{(contract as any).vehicles?.type || 'Sem tipo'}</p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-secondary-700">Status</label>
                  <p className="text-secondary-900">{(contract as any).vehicles?.status || 'Sem status'}</p>
                </div>
              </div>
            )}
          </div>

          {/* Informações do Contrato */}
          <div className="bg-secondary-50 p-4 rounded-lg">
            <h3 className="font-semibold text-secondary-900 mb-3">Detalhes do Contrato</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-secondary-700">Data de Início</label>
                <p className="text-secondary-900">{new Date(contract.start_date).toLocaleDateString('pt-BR') || 'Sem data de início'}</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-secondary-700">Data de Término</label>
                <p className="text-secondary-900">{new Date(contract.end_date).toLocaleDateString('pt-BR') || 'Sem data de término'}</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-secondary-700">Valor Diário</label>
                <p className="text-secondary-900">R$ {contract.daily_rate.toLocaleString('pt-BR', { minimumFractionDigits: 2 }) || 'Sem valor diário'}</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-secondary-700">Total de Dias</label>
                <p className="text-secondary-900">{totalDays} dias</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-secondary-700">Valor Total</label>
                <p className="text-lg font-semibold text-primary-600">R$ {totalValue.toLocaleString('pt-BR', { minimumFractionDigits: 2 }) || 'Sem valor total'}</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-secondary-700">Status</label>
                <p className="text-secondary-900">{contract.status || 'Sem status'}</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-secondary-700">Vendedor</label>
                <p className="text-secondary-900">{getSalespersonName(contract.salesperson_id) || 'Sem vendedor'}</p>
              </div>
            </div>
          </div>

          {/* Configuração de Recorrência */}
          {contract.is_recurring && (
            <div className="bg-secondary-50 p-4 rounded-lg">
              <h3 className="font-semibold text-secondary-900 mb-3">Configuração de Recorrência</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-secondary-700">Tipo de Recorrência</label>
                  <p className="text-secondary-900">
                    {contract.recurrence_type === 'monthly' && 'Mensal'}
                    {contract.recurrence_type === 'weekly' && 'Semanal'}
                    {contract.recurrence_type === 'yearly' && 'Anual'}
                  </p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-secondary-700">Dia da Recorrência</label>
                  <p className="text-secondary-900">{contract.recurrence_day || '-'}</p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-secondary-700">Renovação Automática</label>
                  <p className="text-secondary-900">{contract.auto_renew ? 'Sim' : 'Não'}</p>
                </div>
              </div>
            </div>
          )}
          {/* Observações */}
          {contract.notes && (
            <div className="bg-secondary-50 p-4 rounded-lg">
              <h3 className="font-semibold text-secondary-900 mb-3">Observações</h3>
              <p className="text-secondary-900 whitespace-pre-wrap">{contract.notes || 'Sem observações'}</p>
            </div>
          )}
        </div>

        <div className="flex justify-end pt-6 border-t mt-6">
          <Button variant="secondary" onClick={onClose}>
            Fechar
          </Button>
        </div>
      </div>
    </div>
  );
};

export const Contracts: React.FC = () => {
  const { contracts, statistics, loading, refetch, createContract, updateContract, deleteContract, finalizeExpiredContracts } = useContracts();
  const { customers, createCustomer, updateCustomer } = useCustomers();
  const { employees } = useEmployees();
  
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [isContractModalOpen, setIsContractModalOpen] = useState(false);
  const [isCustomerModalOpen, setIsCustomerModalOpen] = useState(false);
  const [isContractViewModalOpen, setIsContractViewModalOpen] = useState(false);
  const [selectedContract, setSelectedContract] = useState<any>(null);
  const [selectedCustomer, setSelectedCustomer] = useState<any>(null);
  const [initialized, setInitialized] = useState(false);

  // Inicializar dados apenas uma vez
  useEffect(() => {
    if (!initialized) {
      const initializeData = async () => {
        try {
          await Promise.all([
            refetch(),
            finalizeExpiredContracts()
          ]);
        } catch (error) {
          console.error('Error initializing contract data:', error);
        } finally {
          setInitialized(true);
        }
      };
      
      initializeData();
    }
  }, [initialized]); // Remove refetch and finalizeExpiredContracts from dependencies

  // Filter contracts based on search and status
  const filteredContracts = contracts.filter((contract: any) => {
    const matchesSearch = 
      contract.customers?.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      contract.customers?.document?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      contract.vehicles?.plate?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      contract.vehicles?.model?.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesStatus = statusFilter === '' || contract.status === statusFilter;
    
    return matchesSearch && matchesStatus;
  });

  const getStatusBadge = (status: string) => {
    const variants = {
      'Ativo': 'success',
      'Finalizado': 'info',
      'Cancelado': 'error'
    } as const;

    return <Badge variant={variants[status as keyof typeof variants] || 'secondary'}>{status}</Badge>;
  };

  const handleEditContract = (contract: any) => {
    setSelectedContract(contract);
    setIsContractModalOpen(true);
  };

  const handleViewContract = (contract: any) => {
    setSelectedContract(contract);
    setIsContractViewModalOpen(true);
  };

  const handleNewContract = () => {
    setSelectedContract(null);
    setIsContractModalOpen(true);
  };

  const handleEditCustomer = (customer: any) => {
    setSelectedCustomer(customer);
    setIsCustomerModalOpen(true);
  };

  const handleNewCustomer = () => {
    setSelectedCustomer(null);
    setIsCustomerModalOpen(true);
  };

  const handleSaveContract = async (data: any, vehiclesList: any[]) => {
    try {
      let createdContract;
      if (selectedContract) {
        createdContract = await updateContract(selectedContract.id, data);
      } else {
        createdContract = await createContract(data);
      }
      // Após criar o contrato, se houver veículos múltiplos, crie os registros em contract_vehicles
      if (vehiclesList && vehiclesList.length > 0 && createdContract?.id) {
        const contractVehiclesData = vehiclesList.map(v => ({
          contract_id: createdContract.id,
          vehicle_id: v.vehicle_id,
          daily_rate: v.daily_rate
        }));
        // Insere os registros em contract_vehicles
        // Usa upsert para evitar erro de duplicidade
        // Usa upsert para evitar erro de duplicidade
        const { error: cvError } = await supabase
          .from('contract_vehicles')
          .upsert(contractVehiclesData, { onConflict: 'contract_id,vehicle_id' });
        if (cvError) throw cvError;
      }
      await refetch(); // Atualiza a lista de contratos
      setIsContractModalOpen(false); // Fecha o modal
      toast.success(selectedContract ? 'Contrato atualizado com sucesso!' : 'Contrato criado com sucesso!');
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Erro ao salvar contrato');
    }
  };

  const handleSaveCustomer = async (data: any) => {
    if (selectedCustomer) {
      await updateCustomer(selectedCustomer.id, data);
    } else {
      await createCustomer(data);
    }
  };

  const handleDeleteContract = async (id: string) => {
    if (confirm('Tem certeza que deseja excluir este contrato?')) {
      await deleteContract(id);
    }
  };

  // Get salesperson name
  const getSalespersonName = (id: string | null) => {
    if (!id) return 'Não atribuído';
    const employee = employees.find(e => e.id === id);
    return employee ? employee.name : 'Não encontrado';
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-primary-600" />
      </div>
    );
  }

  return (
    <div className="space-y-4 lg:space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl lg:text-3xl font-bold text-secondary-900">Contratos</h1>
          <p className="text-secondary-600 mt-1 lg:mt-2">Gerencie contratos de locação</p>
        </div>
        <div className="flex flex-col sm:flex-row space-y-2 sm:space-y-0 sm:space-x-3 w-full sm:w-auto">
          <Button onClick={handleNewContract} size="sm" className="w-full sm:w-auto">
            <Plus className="h-4 w-4 mr-2" />
            Novo Contrato
          </Button>
        </div>
      </div>

      {/* Statistics Cards */}
      {statistics && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 lg:gap-6">
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Contratos Ativos</p>
                  <p className="text-xl lg:text-2xl font-bold text-secondary-900">{statistics.active}</p>
                </div>
                <div className="h-8 w-8 lg:h-12 lg:w-12 bg-success-100 rounded-lg flex items-center justify-center">
                  <CheckCircle className="h-4 w-4 lg:h-6 lg:w-6 text-success-600" />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Receita Mensal</p>
                  <p className="text-xl lg:text-2xl font-bold text-secondary-900">
                    R$ {statistics.monthlyRevenue ? statistics.monthlyRevenue.toLocaleString('pt-BR', { minimumFractionDigits: 2 }) : '0,00'}
                  </p>
                </div>
                <div className="h-8 w-8 lg:h-12 lg:w-12 bg-primary-100 rounded-lg flex items-center justify-center">
                  <DollarSign className="h-4 w-4 lg:h-6 lg:w-6 text-primary-600" />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Total Contratos</p>
                  <p className="text-xl lg:text-2xl font-bold text-secondary-900">{statistics.total}</p>
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
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Receita Total</p>
                  <p className="text-xl lg:text-2xl font-bold text-secondary-900">
                    R$ {statistics.totalRevenue ? statistics.totalRevenue.toLocaleString('pt-BR', { minimumFractionDigits: 2 }) : '0,00'}
                  </p>
                </div>
                <div className="h-8 w-8 lg:h-12 lg:w-12 bg-success-100 rounded-lg flex items-center justify-center">
                  <TrendingUp className="h-4 w-4 lg:h-6 lg:w-6 text-success-600" />
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Filters */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col sm:flex-row gap-4">
            <div className="flex-1">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
                <input
                  type="text"
                  placeholder="Buscar por cliente, veículo ou documento..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                />
              </div>
            </div>
            <div className="flex space-x-2">
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              >
                <option value="">Todos os Status</option>
                <option value="Ativo">Ativo</option>
                <option value="Finalizado">Finalizado</option>
                <option value="Cancelado">Cancelado</option>
              </select>
              <Button variant="secondary" size="sm" className="w-full sm:w-auto">
                <Filter className="h-4 w-4 mr-2" />
                Filtros
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Contracts List */}
      <Card>
        <CardHeader className="p-4 lg:p-6">
          <h3 className="text-lg font-semibold text-secondary-900">
            Contratos ({filteredContracts.length})
          </h3>
        </CardHeader>
        <CardContent className="p-0">
          {/* Mobile Cards */}
          <div className="lg:hidden space-y-3 p-4">
            {filteredContracts.map((contract) => (
              <div key={contract.id} className="border border-secondary-200 rounded-lg p-4">
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-xs font-semibold text-primary-700">{(contract as any).name || 'Sem nome'}</span>
                    </div>
                    <div className="text-sm text-secondary-600">
                      {contract.uses_multiple_vehicles && (contract as any).contract_vehicles && (contract as any).contract_vehicles.length > 0 ? (
                        <div>
                          <p className="font-medium">{(contract as any).contract_vehicles.length} veículos:</p>
                          {(contract as any).contract_vehicles.slice(0, 2).map((cv: any, index: number) => (
                            <p key={cv.id}>{cv.vehicles?.plate} - {cv.vehicles?.model}</p>
                          ))}
                          {(contract as any).contract_vehicles.length > 2 && (
                            <p className="text-xs">+{(contract as any).contract_vehicles.length - 2} mais...</p>
                          )}
                        </div>
                      ) : (
                        <p>{(contract as any).vehicles?.plate} - {(contract as any).vehicles?.model}</p>
                      )}
                    </div>
                  </div>
                  {getStatusBadge(contract.status)}
                </div>
                <div className="grid grid-cols-2 gap-3 text-sm mb-3">
                  <div>
                    <span className="text-secondary-500">Período:</span>
                    <p className="font-medium">
                      {new Date(contract.start_date).toLocaleDateString('pt-BR')} - {new Date(contract.end_date).toLocaleDateString('pt-BR')}
                    </p>
                  </div>
                  <div>
                    <span className="text-secondary-500">Valor Diário:</span>
                    <p className="font-medium">
                      {contract.uses_multiple_vehicles && (contract as any).contract_vehicles ? (
                        `R$ ${(contract as any).contract_vehicles.reduce((sum: number, cv: any) => sum + (cv.daily_rate || 0), 0).toLocaleString('pt-BR', { minimumFractionDigits: 2 })} (total)`
                      ) : (
                        `R$ ${contract.daily_rate.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`
                      )}
                    </p>
                  </div>
                  <div>
                    <span className="text-secondary-500">Modalidade:</span>
                    <p className="font-medium">
                      {contract.is_recurring ? (
                        <span className="text-primary-600">
                          Recorrente ({contract.recurrence_type === 'monthly' ? 'Mensal' :
                                       contract.recurrence_type === 'weekly' ? 'Semanal' :
                                       contract.recurrence_type === 'yearly' ? 'Anual' : ''}
                          {contract.auto_renew && ' - Auto'})
                        </span>
                      ) : (
                        'Único'
                      )}
                    </p>
                  </div>
                  <div>
                    <span className="text-secondary-500">Vendedor:</span>
                    <p className="font-medium">{getSalespersonName(contract.salesperson_id)}</p>
                  </div>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-secondary-500">
                    Total: R$ {(() => {
                      const days = (new Date(contract.end_date).getTime() - new Date(contract.start_date).getTime()) / (1000 * 60 * 60 * 24) + 1;
                      if (contract.uses_multiple_vehicles && (contract as any).contract_vehicles) {
                        return ((contract as any).contract_vehicles.reduce((sum: number, cv: any) => sum + (cv.daily_rate || 0), 0) * days).toLocaleString('pt-BR', { minimumFractionDigits: 2 });
                      }
                      return (days * contract.daily_rate).toLocaleString('pt-BR', { minimumFractionDigits: 2 });
                    })()}
                  </span>
                  <div className="flex space-x-2">
                    <button 
                      onClick={() => handleViewContract(contract)}
                      className="p-2 text-secondary-400 hover:text-secondary-600"
                    >
                      <Eye className="h-4 w-4" />
                    </button>
                    <button 
                      onClick={() => handleEditContract(contract)}
                      className="p-2 text-secondary-400 hover:text-secondary-600"
                    >
                      <Edit className="h-4 w-4" />
                    </button>
                    <button 
                      onClick={() => handleDeleteContract(contract.id)}
                      className="p-2 text-secondary-400 hover:text-error-600"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>

          {/* Desktop Table */}
          <div className="hidden lg:block overflow-x-auto">
            <table className="w-full">
              <thead className="bg-secondary-50">
                <tr>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Contrato</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Cliente</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Veículo</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Modalidade</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Período</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Valor Diário</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Vendedor</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Status</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-secondary-200">
                {filteredContracts.map((contract) => (
                  <tr key={contract.id} className="hover:bg-secondary-50">
                    <td className="py-4 px-6 text-sm font-medium text-primary-700">
                      <div>
                        <span>{(contract as any).name || 'Sem nome'}</span>
                        <br />
                        <span className="text-xs text-secondary-500">{contract.id ? contract.id : 'Sem ID'}</span>
                      </div>
                    </td>
                    <td className="py-4 px-6">
                      <div>
                        <p className="text-sm font-medium text-secondary-900">{(contract as any).customers?.name || 'Sem nome'}</p>
                        <p className="text-xs text-secondary-600">{(contract as any).customers?.document || 'Sem documento'}</p>
                      </div>
                    </td>
                    <td className="py-4 px-6">
                      <div>
                        {contract.uses_multiple_vehicles && (contract as any).contract_vehicles && (contract as any).contract_vehicles.length > 0 ? (
                          <div>
                            <p className="text-sm font-medium text-secondary-900">{(contract as any).contract_vehicles.length} veículos</p>
                            <p className="text-xs text-secondary-600">
                              {(contract as any).contract_vehicles.slice(0, 2).map((cv: any, index: number) => (
                                cv.vehicles?.plate
                              )).join(', ')}
                              {(contract as any).contract_vehicles.length > 2 && ` +${(contract as any).contract_vehicles.length - 2}`}
                            </p>
                          </div>
                        ) : (
                          <div>
                            <p className="text-sm font-medium text-secondary-900">{(contract as any).vehicles?.plate || 'Sem placa'}</p>
                            <p className="text-xs text-secondary-600">{(contract as any).vehicles?.model || 'Sem modelo'} ({(contract as any).vehicles?.year || 'Sem ano'})</p>
                          </div>
                        )}
                      </div>
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      {contract.is_recurring ? (
                        <div className="flex flex-col">
                          <span className="font-medium text-primary-600">
                            Recorrente
                          </span>
                          <span className="text-xs text-secondary-500">
                            {contract.recurrence_type === 'monthly' ? 'Mensal' :
                             contract.recurrence_type === 'weekly' ? 'Semanal' :
                             contract.recurrence_type === 'yearly' ? 'Anual' : ''}
                            {contract.auto_renew && ' - Auto'}
                          </span>
                        </div>
                      ) : (
                        <span className="font-medium text-secondary-700">Único</span>
                      )}
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      <div>
                        <p>{new Date(contract.start_date).toLocaleDateString('pt-BR') || 'Sem data de início'}</p>
                        <p>{new Date(contract.end_date).toLocaleDateString('pt-BR') || 'Sem data de término'}</p>
                      </div>
                    </td>
                    <td className="py-4 px-6 text-sm font-medium text-secondary-900">
                      R$ {contract.daily_rate.toLocaleString('pt-BR', { minimumFractionDigits: 2 }) || 'Sem valor diário'}
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      <div className="flex items-center">
                        <UserCheck className="h-4 w-4 mr-1 text-secondary-400" />
                        {getSalespersonName(contract.salesperson_id) || 'Sem vendedor'}
                      </div>
                    </td>
                    <td className="py-4 px-6">
                      {getStatusBadge(contract.status || 'Sem status')}
                    </td>
                    <td className="py-4 px-6">
                      <div className="flex items-center space-x-2">
                        <button 
                          onClick={() => handleViewContract(contract)}
                          className="p-1 text-secondary-400 hover:text-secondary-600"
                        >
                          <Eye className="h-4 w-4" />
                        </button>
                        <button 
                          onClick={() => handleEditContract(contract)}
                          className="p-1 text-secondary-400 hover:text-secondary-600"
                        >
                          <Edit className="h-4 w-4" />
                        </button>
                        <button 
                          onClick={() => handleDeleteContract(contract.id)}
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

          {filteredContracts.length === 0 && (
            <div className="text-center py-8">
              <Calendar className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
              <p className="text-secondary-600">Nenhum contrato encontrado</p>
            </div>
          )}
        </CardContent>
      </Card>

      <ContractModal
        isOpen={isContractModalOpen}
        onClose={() => setIsContractModalOpen(false)}
        contract={selectedContract}
        customers={customers}
        employees={employees}
        onSave={handleSaveContract}
      />

      <CustomerModal
        isOpen={isCustomerModalOpen}
        onClose={() => setIsCustomerModalOpen(false)}
        customer={selectedCustomer}
        onSave={handleSaveCustomer}
      />

      <ContractViewModal
        isOpen={isContractViewModalOpen}
        onClose={() => setIsContractViewModalOpen(false)}
        contract={selectedContract}
        getSalespersonName={getSalespersonName}
      />
    </div>
  );
};