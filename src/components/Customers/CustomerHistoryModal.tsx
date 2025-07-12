import React, { useState } from 'react';
import { X, Car, DollarSign, AlertTriangle, FileText, Loader2, Eye, UserPlus } from 'lucide-react';
import { useCustomerHistory } from '../../hooks/useCustomerHistory';
import { Badge } from '../UI/Badge';
import { Button } from '../UI/Button';
import { formatCurrency } from '../../utils/formatters';

interface CustomerHistoryModalProps {
  isOpen: boolean;
  onClose: () => void;
  customer: {
    id: string;
    name: string;
    email?: string;
    phone?: string;
  } | null;
  onCreateAccount?: (customerId: string) => void;
}

export const CustomerHistoryModal: React.FC<CustomerHistoryModalProps> = ({
  isOpen,
  onClose,
  customer,
  onCreateAccount
}) => {
  const [activeTab, setActiveTab] = useState<'overview' | 'contracts' | 'costs' | 'fines'>('overview');
  const { history, loading, error } = useCustomerHistory(customer?.id);

  if (!isOpen || !customer) return null;

  const tabs = [
    { id: 'overview', label: 'Resumo', icon: Eye },
    { id: 'contracts', label: 'Contratos', icon: FileText },
    { id: 'costs', label: 'Custos', icon: DollarSign },
    { id: 'fines', label: 'Multas', icon: AlertTriangle }
  ];

  const getStatusBadge = (status: string) => {
    switch (status.toLowerCase()) {
      case 'ativo':
        return <Badge variant="success">{status}</Badge>;
      case 'finalizado':
        return <Badge variant="secondary">{status}</Badge>;
      case 'cancelado':
        return <Badge variant="error">{status}</Badge>;
      case 'pago':
        return <Badge variant="success">{status}</Badge>;
      case 'pendente':
        return <Badge variant="warning">{status}</Badge>;
      case 'autorizado':
        return <Badge variant="info">{status}</Badge>;
      default:
        return <Badge variant="secondary">{status}</Badge>;
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg w-full max-w-6xl max-h-[90vh] overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex justify-between items-center p-6 border-b">
          <div>
            <h2 className="text-xl font-semibold text-secondary-900">
              Histórico de {customer.name}
            </h2>
            <div className="flex items-center space-x-4 mt-1 text-sm text-secondary-600">
              {customer.email && <span>{customer.email}</span>}
              {customer.phone && <span>{customer.phone}</span>}
            </div>
          </div>
          <div className="flex items-center space-x-3">
            {onCreateAccount && (
              <Button
                variant="primary"
                size="sm"
                onClick={() => onCreateAccount(customer.id)}
              >
                <UserPlus className="h-4 w-4 mr-2" />
                Criar Conta
              </Button>
            )}
            <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
              <X className="h-5 w-5" />
            </button>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex border-b">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as 'overview' | 'contracts' | 'costs' | 'fines')}
              className={`flex items-center px-6 py-3 text-sm font-medium border-b-2 transition-colors ${
                activeTab === tab.id
                  ? 'border-primary-500 text-primary-600'
                  : 'border-transparent text-secondary-500 hover:text-secondary-700'
              }`}
            >
              <tab.icon className="h-4 w-4 mr-2" />
              {tab.label}
              {tab.id === 'contracts' && history.contracts.length > 0 && (
                <span className="ml-2 px-2 py-0.5 text-xs bg-secondary-100 text-secondary-600 rounded-full">
                  {history.contracts.length}
                </span>
              )}
              {tab.id === 'costs' && history.costs.length > 0 && (
                <span className="ml-2 px-2 py-0.5 text-xs bg-secondary-100 text-secondary-600 rounded-full">
                  {history.costs.length}
                </span>
              )}
              {tab.id === 'fines' && history.fines.length > 0 && (
                <span className="ml-2 px-2 py-0.5 text-xs bg-secondary-100 text-secondary-600 rounded-full">
                  {history.fines.length}
                </span>
              )}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-primary-600" />
              <span className="ml-3 text-secondary-600">Carregando histórico...</span>
            </div>
          ) : error ? (
            <div className="text-center py-12">
              <AlertTriangle className="h-12 w-12 text-error-400 mx-auto mb-4" />
              <p className="text-error-600">{error}</p>
            </div>
          ) : (
            <div>
              {/* Overview Tab */}
              {activeTab === 'overview' && (
                <div className="space-y-6">
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                    <div className="bg-primary-50 p-4 rounded-lg">
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="text-sm font-medium text-primary-600">Contratos Ativos</p>
                          <p className="text-2xl font-bold text-primary-900">{history.activeContracts}</p>
                        </div>
                        <FileText className="h-8 w-8 text-primary-600" />
                      </div>
                    </div>
                    
                    <div className="bg-secondary-50 p-4 rounded-lg">
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="text-sm font-medium text-secondary-600">Total Contratos</p>
                          <p className="text-2xl font-bold text-secondary-900">{history.totalContracts}</p>
                        </div>
                        <FileText className="h-8 w-8 text-secondary-600" />
                      </div>
                    </div>

                    <div className="bg-success-50 p-4 rounded-lg">
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="text-sm font-medium text-success-600">Total Custos</p>
                          <p className="text-2xl font-bold text-success-900">{formatCurrency(history.totalCosts)}</p>
                        </div>
                        <DollarSign className="h-8 w-8 text-success-600" />
                      </div>
                    </div>

                    <div className="bg-error-50 p-4 rounded-lg">
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="text-sm font-medium text-error-600">Total Multas</p>
                          <p className="text-2xl font-bold text-error-900">{formatCurrency(history.totalFines)}</p>
                        </div>
                        <AlertTriangle className="h-8 w-8 text-error-600" />
                      </div>
                    </div>
                  </div>

                  {/* Recent Activity */}
                  <div>
                    <h3 className="text-lg font-semibold text-secondary-900 mb-4">Atividade Recente</h3>
                    <div className="space-y-3">
                      {/* Contratos recentes */}
                      {history.contracts.slice(0, 3).map((contract) => (
                        <div key={contract.id} className="flex items-center justify-between p-3 bg-secondary-50 rounded-lg">
                          <div className="flex items-center space-x-3">
                            <FileText className="h-5 w-5 text-secondary-400" />
                            <div>
                              <p className="font-medium text-secondary-900">
                                Contrato #{contract.contract_number}
                              </p>
                              <p className="text-sm text-secondary-600">
                                {contract.vehicles?.plate} - {contract.vehicles?.model} ({contract.vehicles?.type})
                              </p>
                            </div>
                          </div>
                          <div className="text-right">
                            {getStatusBadge(contract.status)}
                            <p className="text-sm text-secondary-600 mt-1">
                              {new Date(contract.start_date).toLocaleDateString('pt-BR')}
                            </p>
                          </div>
                        </div>
                      ))}

                      {/* Custos recentes */}
                      {history.costs.slice(0, 3).map((cost) => (
                        <div key={cost.id} className="flex items-center justify-between p-3 bg-secondary-50 rounded-lg">
                          <div className="flex items-center space-x-3">
                            <DollarSign className="h-5 w-5 text-secondary-400" />
                            <div>
                              <p className="font-medium text-secondary-900">{cost.description}</p>
                              <p className="text-sm text-secondary-600">
                                {cost.vehicles?.plate} - {cost.category}
                              </p>
                            </div>
                          </div>
                          <div className="text-right">
                            <p className="font-medium text-secondary-900">{formatCurrency(cost.amount)}</p>
                            <p className="text-sm text-secondary-600">
                              {new Date(cost.cost_date).toLocaleDateString('pt-BR')}
                            </p>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              )}

              {/* Contracts Tab */}
              {activeTab === 'contracts' && (
                <div className="space-y-4">
                  <h3 className="text-lg font-semibold text-secondary-900">
                    Contratos ({history.contracts.length})
                  </h3>
                  
                  {history.contracts.length === 0 ? (
                    <div className="text-center py-12">
                      <FileText className="h-12 w-12 text-secondary-300 mx-auto mb-4" />
                      <p className="text-secondary-500">Nenhum contrato encontrado</p>
                    </div>
                  ) : (
                    <div className="overflow-x-auto">
                      <table className="w-full">
                        <thead className="bg-secondary-50">
                          <tr>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Contrato</th>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Veículo</th>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Período</th>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Diária</th>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Status</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-secondary-200">
                          {history.contracts.map((contract) => (
                            <tr key={contract.id} className="hover:bg-secondary-50">
                              <td className="py-3 px-4 text-sm font-medium text-secondary-900">
                                #{contract.contract_number}
                              </td>
                              <td className="py-3 px-4 text-sm text-secondary-600">
                                <div className="flex items-center">
                                  <Car className="h-4 w-4 mr-2 text-secondary-400" />
                                  {contract.vehicles?.plate} - {contract.vehicles?.model}
                                </div>
                              </td>
                              <td className="py-3 px-4 text-sm text-secondary-600">
                                {new Date(contract.start_date).toLocaleDateString('pt-BR')} - {new Date(contract.end_date).toLocaleDateString('pt-BR')}
                              </td>
                              <td className="py-3 px-4 text-sm font-medium text-secondary-900">
                                {formatCurrency(contract.daily_rate)}
                              </td>
                              <td className="py-3 px-4">
                                {getStatusBadge(contract.status)}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              )}

              {/* Costs Tab */}
              {activeTab === 'costs' && (
                <div className="space-y-4">
                  <h3 className="text-lg font-semibold text-secondary-900">
                    Custos ({history.costs.length})
                  </h3>
                  
                  {history.costs.length === 0 ? (
                    <div className="text-center py-12">
                      <DollarSign className="h-12 w-12 text-secondary-300 mx-auto mb-4" />
                      <p className="text-secondary-500">Nenhum custo encontrado</p>
                    </div>
                  ) : (
                    <div className="overflow-x-auto">
                      <table className="w-full">
                        <thead className="bg-secondary-50">
                          <tr>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Data</th>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Descrição</th>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Veículo</th>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Categoria</th>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Valor</th>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Status</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-secondary-200">
                          {history.costs.map((cost) => (
                            <tr key={cost.id} className="hover:bg-secondary-50">
                              <td className="py-3 px-4 text-sm text-secondary-600">
                                {new Date(cost.cost_date).toLocaleDateString('pt-BR')}
                              </td>
                              <td className="py-3 px-4 text-sm text-secondary-900">
                                {cost.description}
                              </td>
                              <td className="py-3 px-4 text-sm text-secondary-600">
                                {cost.vehicles?.plate && (
                                  <div className="flex items-center">
                                    <Car className="h-4 w-4 mr-2 text-secondary-400" />
                                    {cost.vehicles.plate}
                                  </div>
                                )}
                              </td>
                              <td className="py-3 px-4 text-sm text-secondary-600">
                                {cost.category}
                              </td>
                              <td className="py-3 px-4 text-sm font-medium text-secondary-900">
                                {formatCurrency(cost.amount)}
                              </td>
                              <td className="py-3 px-4">
                                {getStatusBadge(cost.status)}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              )}

              {/* Fines Tab */}
              {activeTab === 'fines' && (
                <div className="space-y-4">
                  <h3 className="text-lg font-semibold text-secondary-900">
                    Multas ({history.fines.length})
                  </h3>
                  
                  {history.fines.length === 0 ? (
                    <div className="text-center py-12">
                      <AlertTriangle className="h-12 w-12 text-secondary-300 mx-auto mb-4" />
                      <p className="text-secondary-500">Nenhuma multa encontrada</p>
                    </div>
                  ) : (
                    <div className="overflow-x-auto">
                      <table className="w-full">
                        <thead className="bg-secondary-50">
                          <tr>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Número</th>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Infração</th>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Veículo</th>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Data</th>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Valor</th>
                            <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Status</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-secondary-200">
                          {history.fines.map((fine) => (
                            <tr key={fine.id} className="hover:bg-secondary-50">
                              <td className="py-3 px-4 text-sm font-medium text-secondary-900">
                                {fine.fine_number}
                              </td>
                              <td className="py-3 px-4 text-sm text-secondary-900">
                                {fine.infraction_type}
                              </td>
                              <td className="py-3 px-4 text-sm text-secondary-600">
                                {fine.vehicles?.plate && (
                                  <div className="flex items-center">
                                    <Car className="h-4 w-4 mr-2 text-secondary-400" />
                                    {fine.vehicles.plate}
                                  </div>
                                )}
                              </td>
                              <td className="py-3 px-4 text-sm text-secondary-600">
                                {new Date(fine.infraction_date).toLocaleDateString('pt-BR')}
                              </td>
                              <td className="py-3 px-4 text-sm font-medium text-secondary-900">
                                {formatCurrency(fine.amount)}
                              </td>
                              <td className="py-3 px-4">
                                {getStatusBadge(fine.status)}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}; 