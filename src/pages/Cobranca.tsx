import React, { useState } from 'react';
import { Card, CardHeader, CardContent } from '../components/UI/Card';
import { Button } from '../components/UI/Button';
import { Loader2, Clock, Receipt, CheckCircle } from 'lucide-react';
import { useCosts } from '../hooks/useCosts';
import { useVehicles } from '../hooks/useVehicles';
import { useCustomers } from '../hooks/useCustomers';
import { useEmployees } from '../hooks/useEmployees';
import { useAuth } from '../hooks/useAuth';
import { Badge } from '../components/UI/Badge';
import { Database } from '../types/database';

type Cost = Database['public']['Tables']['costs']['Row'] & {
  vehicles?: { plate: string; model: string };
  customers?: { id: string; name: string };
  vehicle_plate?: string;
  created_by_name?: string;
  driver_id?: string;
};

const ITEMS_PER_PAGE = 20;

const Cobranca = () => {
  const { user } = useAuth();
  const { costs, loading, error } = useCosts();
  const { vehicles } = useVehicles();
  const { customers } = useCustomers();
  const { employees } = useEmployees();

  // Filtros
  const [searchTerm, setSearchTerm] = useState('');
  const [vehicleFilter, setVehicleFilter] = useState('');
  const [customerFilter, setCustomerFilter] = useState('');
  const [employeeFilter, setEmployeeFilter] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [isViewModalOpen, setIsViewModalOpen] = useState(false);
  const [selectedCost, setSelectedCost] = useState<Cost | null>(null);

  // Utilitários para exibição amigável de categoria e origem
  const CATEGORY_LABELS: Record<string, string> = {
    Multa: 'Multa',
    Funilaria: 'Funilaria',
    Avulsa: 'Avulsa',
    Compra: 'Compra',
    'Excesso Km': 'Excesso Km',
    'Diária Extra': 'Diária Extra',
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
  };
  const getCategoryLabel = (cost: Cost): string => {
    if (!cost.category) return '-';
    return CATEGORY_LABELS[cost.category] || cost.category;
  };
  const getOriginLabel = (cost: Cost): string => {
    if (cost.category === 'Multa') return 'Multas';
    if (!cost.origin) return '-';
    return ORIGIN_LABELS[cost.origin] || cost.origin;
  };

  // Filtragem - Incluir apenas custos de cobrança (danos do pátio e multas)
  let filteredCosts = costs.filter(cost => {
    // Incluir multas e danos do pátio
    if (cost.category === 'Multa' || cost.category === 'Multas' as any) return true;
    if (cost.origin === 'Patio' && (cost.category === 'Funilaria' || cost.category === 'Avaria')) return true;
    
    // EXCLUIR custos de combustível (não devem aparecer na cobrança)
    if (cost.category === 'Combustível') return false;

    // EXCLUIR custos de contas pagas e salários
    if (cost.origin === 'Contas' || cost.origin === 'salario') return false;
    if (cost.category === 'Despesas') return false;

    // Excluir outros tipos de custos
    const excludedCategories = ['Seguro', 'Peças', 'Avulsa', 'Compra'];
    const excludedOrigins = ['Manutencao', 'Compras'];
    if (excludedCategories.includes(cost.category)) return false;
    if (excludedOrigins.includes(cost.origin)) return false;
    return true;
  });
  if (user?.role === 'Driver') {
    filteredCosts = filteredCosts.filter(cost => (cost as any).driver_id === user.id);
  }
  filteredCosts = filteredCosts.filter(cost => {
    const matchesSearch = searchTerm.trim() === '' ||
      (cost.description && cost.description.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (cost.category && cost.category.toLowerCase().includes(searchTerm.toLowerCase()));
    const matchesVehicle = !vehicleFilter || cost.vehicle_id === vehicleFilter;
    const matchesCustomer = !customerFilter || cost.customer_id === customerFilter;
    const matchesEmployee = !employeeFilter || cost.created_by_employee_id === employeeFilter;
    return matchesSearch && matchesVehicle && matchesCustomer && matchesEmployee;
  });

  // Paginação
  const totalPages = Math.ceil(filteredCosts.length / ITEMS_PER_PAGE);
  const paginatedCosts = filteredCosts.slice((currentPage - 1) * ITEMS_PER_PAGE, currentPage * ITEMS_PER_PAGE);

  // Estatísticas
  const total = filteredCosts.length;
  const pending = filteredCosts.filter(c => c.status === 'Pendente').length;
  const paid = filteredCosts.filter(c => c.status === 'Pago').length;
  const pendingAmount = filteredCosts.filter(c => c.status === 'Pendente').reduce((s, c) => s + (c.amount || 0), 0);
  const paidAmount = filteredCosts.filter(c => c.status === 'Pago').reduce((s, c) => s + (c.amount || 0), 0);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin mx-auto mb-4" />
        <p className="text-secondary-600">Carregando custos...</p>
      </div>
    );
  }
  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <p className="text-error-600">{error}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-secondary-900">Cobrança de Clientes</h1>
          <p className="text-secondary-600">Visualização de todos os custos lançados</p>
        </div>
      </div>

      {/* Estatísticas */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-secondary-600">Total de Cobranças</p>
                <p className="text-2xl font-bold text-secondary-900">{total}</p>
              </div>
              <Receipt className="h-8 w-8 text-secondary-400" />
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-secondary-600">Pendentes</p>
                <p className="text-2xl font-bold text-warning-600">{pending}</p>
                <p className="text-sm text-secondary-500">
                  R$ {pendingAmount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                </p>
              </div>
              <Clock className="h-8 w-8 text-warning-400" />
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-secondary-600">Pagas</p>
                <p className="text-2xl font-bold text-success-600">{paid}</p>
                <p className="text-sm text-secondary-500">
                  R$ {paidAmount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                </p>
              </div>
              <CheckCircle className="h-8 w-8 text-success-400" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Filtros (apenas admin/manager) */}
      {(user?.role === 'Admin' || user?.role === 'Manager') && (
        <Card>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <input
                type="text"
                placeholder="Buscar por descrição ou categoria..."
                value={searchTerm}
                onChange={e => setSearchTerm(e.target.value)}
                className="border border-secondary-300 rounded-lg px-3 py-2"
              />
              <select value={vehicleFilter} onChange={e => setVehicleFilter(e.target.value)} className="border border-secondary-300 rounded-lg px-3 py-2">
                <option value="">Todos Veículos</option>
                {vehicles.map(v => (
                  <option key={v.id} value={v.id}>{v.plate}</option>
                ))}
              </select>
              <select value={customerFilter} onChange={e => setCustomerFilter(e.target.value)} className="border border-secondary-300 rounded-lg px-3 py-2">
                <option value="">Todos Clientes</option>
                {customers.map(c => (
                  <option key={c.id} value={c.id}>{c.name}</option>
                ))}
              </select>
              <select value={employeeFilter} onChange={e => setEmployeeFilter(e.target.value)} className="border border-secondary-300 rounded-lg px-3 py-2">
                <option value="">Todos Funcionários</option>
                {employees.map(emp => (
                  <option key={emp.id} value={emp.id}>{emp.name}</option>
                ))}
              </select>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Lista de Cobranças (Custos) - Tabela Desktop */}
      <Card>
        <CardHeader>
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
            <h2 className="text-lg font-semibold text-secondary-900">Lista de Cobranças</h2>
            <Button onClick={() => window.location.reload()} variant="secondary" size="sm" className="flex items-center">
              Atualizar
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto hidden lg:block">
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
                        <Badge variant="secondary" className="text-xs w-fit">{getCategoryLabel(cost)}</Badge>
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
                      <Badge variant={cost.status === 'Pago' ? 'success' : cost.status === 'Autorizado' ? 'info' : 'warning'}>
                        {cost.status}
                      </Badge>
                    </td>
                    <td className="px-4 py-2 text-secondary-700">{new Date(cost.cost_date).toLocaleDateString('pt-BR')}</td>
                    <td className="px-4 py-2">{cost.vehicles?.plate || cost.vehicle_plate || '-'}</td>
                    <td className="px-4 py-2">{cost.customers?.name || cost.customer_name || '-'}</td>
                    <td className="px-4 py-2">{cost.created_by_name || (cost.origin === 'Sistema' ? 'Sistema' : '-')}</td>
                    <td className="px-4 py-2">
                      <Button
                        onClick={() => { setSelectedCost(cost); setIsViewModalOpen(true); }}
                        variant="secondary"
                        size="sm"
                        className="text-xs"
                      >
                        Visualizar
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {/* Mobile view simplificado */}
          <div className="lg:hidden">
            <div className="divide-y divide-secondary-200">
              {paginatedCosts.map((cost) => (
                <div key={cost.id} className="p-4 space-y-3">
                  <div className="flex justify-between items-start">
                    <div className="flex-1">
                      <div className="flex items-center space-x-2 mb-1">
                        <Badge variant="secondary" className="text-xs">
                          {getCategoryLabel(cost)}
                        </Badge>
                        <Badge variant="secondary" className="text-xs">
                          {getOriginLabel(cost)}
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
                          {getOriginLabel(cost)}
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
                      {cost.created_by_name || (cost.origin === 'Sistema' ? 'Sistema' : '-')}
                    </div>
                    <div className="flex items-center space-x-2">
                      <Button
                        onClick={() => { setSelectedCost(cost); setIsViewModalOpen(true); }}
                        variant="secondary"
                        size="sm"
                        className="text-xs"
                      >
                        Visualizar
                      </Button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
          {/* Paginação */}
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
      {/* Modal de Visualização Customizado para Cobrança */}
      {isViewModalOpen && selectedCost && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4 lg:mb-6">
              <h2 className="text-lg lg:text-xl font-semibold text-secondary-900">
                Visualizar Cobrança
              </h2>
              <button onClick={() => setIsViewModalOpen(false)} className="text-secondary-400 hover:text-secondary-600 p-2">
                ×
              </button>
            </div>

            {/* Informações da Cobrança */}
            <div className="p-4 bg-green-50 border border-green-200 rounded-xl shadow-sm mb-4">
              <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4 mb-4">
                <div className="flex items-center gap-2">
                  <span className="font-semibold text-green-900 text-lg">{selectedCost.customer_name || '-'}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="font-semibold text-green-900 text-lg">R$ {selectedCost.amount?.toLocaleString('pt-BR', { minimumFractionDigits: 2 }) || '-'}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="font-semibold text-green-900 text-lg">{selectedCost.status || '-'}</span>
                </div>
              </div>
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-2">
                <div className="flex items-center gap-2">
                  <span className="text-secondary-800">Contrato:</span>
                  <span className="font-medium text-secondary-900">{selectedCost.contract_id || '-'}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-secondary-800">Veículo:</span>
                  <span className="font-medium text-secondary-900">{selectedCost.vehicles?.plate || selectedCost.vehicle_plate || '-'}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-secondary-800">Categoria:</span>
                  <span className="font-medium text-secondary-900">{selectedCost.category || '-'}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-secondary-800">Data:</span>
                  <span className="font-medium text-secondary-900">{selectedCost.cost_date ? new Date(selectedCost.cost_date).toLocaleDateString('pt-BR') : '-'}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-secondary-800">Responsável:</span>
                  <span className="font-medium text-secondary-900">{selectedCost.created_by_name || (selectedCost.origin === 'Sistema' ? 'Sistema' : '-')}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-secondary-800">Origem:</span>
                  <span className="font-medium text-secondary-900">
                    {selectedCost.origin === 'Usuario' ? 'Usuário' : 
                     selectedCost.origin === 'Patio' ? 'Controle de Pátio' :
                     selectedCost.origin === 'Manutencao' ? 'Manutenção' :
                     selectedCost.origin === 'Sistema' ? 'Sistema' :
                     selectedCost.origin === 'Compras' ? 'Compras' :
                     selectedCost.origin === 'Multas' ? 'Multas' :
                     selectedCost.origin || '-'}
                  </span>
                </div>
              </div>
              <div className="mt-4">
                <label className="block text-xs text-secondary-600 mb-1">Observações</label>
                <div className="font-medium text-secondary-900 bg-secondary-50 rounded p-2 min-h-[32px]">{selectedCost.observations || '-'}</div>
              </div>
            </div>

            <div className="flex justify-end pt-4 lg:pt-6 border-t">
              <Button variant="secondary" onClick={() => setIsViewModalOpen(false)}>
                Fechar
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Cobranca;