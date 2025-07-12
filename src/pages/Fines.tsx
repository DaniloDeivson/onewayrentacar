import React, { useState } from 'react';
import { Card, CardHeader, CardContent } from '../components/UI/Card';
import { Button } from '../components/UI/Button';
import { Badge } from '../components/UI/Badge';
import { useFines } from '../hooks/useFines';
import { useVehicles } from '../hooks/useVehicles';
import { useEmployees } from '../hooks/useEmployees';
import { useAuth } from '../hooks/useAuth';
import { FineForm } from '../components/Fines/FineForm';
import { Plus, Search, Filter, AlertTriangle, DollarSign, Bell, BellOff, Loader2, Edit, Eye, Trash2, Car, User, Clock, UserCheck } from 'lucide-react';
import toast from 'react-hot-toast';

// Modal para editar/adicionar multa
const FineModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  fine?: any;
  vehicles: any[];
  employees: any[];
  onSave: (data: any) => Promise<void>;
}> = ({ isOpen, onClose, fine, vehicles, employees, onSave }) => {
  const [loading, setLoading] = useState(false);

  if (!isOpen) return null;

  // Filtrar veículos inativos para seleção em multas
  const selectableVehicles = vehicles.filter(v => v.status !== 'Inativo');

  const handleSave = async (formData: any) => {
    setLoading(true);
    try {
      await onSave(formData);
      onClose();
    } catch (error) {
      console.error('Error saving fine:', error);
      toast.error('Erro ao salvar multa: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <h2 className="text-lg lg:text-xl font-semibold text-secondary-900">
            {fine ? 'Editar Multa' : 'Registrar Nova Multa'}
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            ×
          </button>
        </div>

        <FineForm
          onSubmit={handleSave}
          onCancel={onClose}
          fine={fine}
          vehicles={selectableVehicles}
          employees={employees}
          loading={loading}
        />
      </div>
    </div>
  );
};

export const Fines: React.FC = () => {
  const { fines, statistics, loading, createFine, updateFine, deleteFine, markAsNotified, markAsNotNotified } = useFines();
  const { vehicles } = useVehicles();
  const { employees } = useEmployees();
  const { isAdmin, isManager, hasPermission } = useAuth();
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [infractionFilter, setInfractionFilter] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedFine, setSelectedFine] = useState<any>(undefined);
  const [isViewModalOpen, setIsViewModalOpen] = useState(false);

  const canManageFines = isAdmin || isManager || hasPermission('fines');

  // Filtrar veículos inativos para seleção em multas
  const selectableVehicles = vehicles.filter(v => v.status !== 'Inativo');

  // Filter fines to show only those managed by the current user or all if admin
  const filteredFines = fines.filter(fine => {
    const matchesSearch = 
      fine.fine_number?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      fine.infraction_type.toLowerCase().includes(searchTerm.toLowerCase()) ||
      fine.vehicles?.plate?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      fine.drivers?.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      fine.created_by_name?.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesStatus = statusFilter === '' || fine.status === statusFilter;
    const matchesInfraction = infractionFilter === '' || fine.infraction_type === infractionFilter;
    
    return matchesSearch && matchesStatus && matchesInfraction;
  });

  const getStatusBadge = (status: string) => {
    const variants = {
      'Pendente': 'warning',
      'Pago': 'success',
      'Contestado': 'info'
    } as const;

    return <Badge variant={variants[status as keyof typeof variants] || 'secondary'}>{status}</Badge>;
  };

  const getNotificationBadge = (notified: boolean) => {
    return notified 
      ? <Badge variant="success" className="flex items-center"><Bell className="h-3 w-3 mr-1" />Notificado</Badge>
      : <Badge variant="warning" className="flex items-center"><BellOff className="h-3 w-3 mr-1" />Não Notificado</Badge>;
  };

  const isOverdue = (fine: any) => {
    if (fine.status !== 'Pendente' || !fine.due_date) return false;
    return new Date(fine.due_date) < new Date();
  };

  const handleEdit = (fine: any) => {
    setSelectedFine(fine);
    setIsModalOpen(true);
  };

  const handleNew = () => {
    setSelectedFine(undefined);
    setIsModalOpen(true);
  };

  const handleView = (fine: any) => {
    setSelectedFine(fine);
    setIsViewModalOpen(true);
  };

  const handleSave = async (data: any) => {
    if (selectedFine) {
      await updateFine(selectedFine.id, data);
    } else {
      await createFine(data);
    }
  };

  const handleDelete = async (id: string) => {
    console.log('handleDelete called with id:', id);
    
    if (!id || id === '') {
      console.error('handleDelete: ID is empty or undefined');
      toast.error('ID da multa é inválido');
      return;
    }
    
    if (confirm('Tem certeza que deseja excluir esta multa?')) {
      console.log('User confirmed deletion, proceeding...');
      try {
        console.log('Calling deleteFine with id:', id);
        await deleteFine(id);
        console.log('deleteFine completed successfully');
        // Note: toast.success is already called in the deleteFine function
      } catch (error) {
        console.error('Error in handleDelete:', error);
        console.error('Error details:', {
          message: error instanceof Error ? error.message : 'Unknown error',
          stack: error instanceof Error ? error.stack : undefined
        });
        // Don't show another toast here since deleteFine already shows one
      }
    } else {
      console.log('User cancelled deletion');
    }
  };

  const handleToggleNotification = async (fine: any) => {
    try {
      if (fine.notified) {
        await markAsNotNotified(fine.id);
        toast.success('Multa marcada como não notificada');
      } else {
        await markAsNotified(fine.id);
        toast.success('Multa marcada como notificada');
      }
    } catch (error) {
      toast.error('Erro ao alterar status de notificação');
    }
  };

  // Get unique infraction types for filter
  const uniqueInfractionTypes = [...new Set(fines.map(fine => fine.infraction_type))].sort();

  // Get responsible name from employee ID
  const getResponsibleName = (employeeId: string) => {
    const employee = employees.find(e => e.id === employeeId);
    return employee ? employee.name : 'Não atribuído';
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
          <h1 className="text-2xl lg:text-3xl font-bold text-secondary-900">Multas</h1>
          <p className="text-secondary-600 mt-1 lg:mt-2">Gerencie multas de trânsito e infrações com integração automática ao painel de custos</p>
        </div>
        {canManageFines && (
          <Button onClick={handleNew} size="sm" className="w-full sm:w-auto">
            <Plus className="h-4 w-4 mr-2" />
            Registrar Multa
          </Button>
        )}
      </div>

      {/* Statistics Cards */}
      {statistics && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 lg:gap-6">
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Total de Multas</p>
                  <p className="text-xl lg:text-2xl font-bold text-secondary-900">{statistics.total_fines}</p>
                </div>
                <div className="h-8 w-8 lg:h-12 lg:w-12 bg-error-100 rounded-lg flex items-center justify-center">
                  <AlertTriangle className="h-4 w-4 lg:h-6 lg:w-6 text-error-600" />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Valor Total</p>
                  <p className="text-xl lg:text-2xl font-bold text-secondary-900">
                    R$ {statistics.total_amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
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
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Pendentes</p>
                  <p className="text-xl lg:text-2xl font-bold text-secondary-900">{statistics.pending_fines}</p>
                  <p className="text-xs text-warning-600 mt-1">
                    R$ {statistics.pending_amount.toLocaleString('pt-BR')}
                  </p>
                </div>
                <div className="h-8 w-8 lg:h-12 lg:w-12 bg-warning-100 rounded-lg flex items-center justify-center">
                  <Clock className="h-4 w-4 lg:h-6 lg:w-6 text-warning-600" />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Não Notificados</p>
                  <p className="text-xl lg:text-2xl font-bold text-secondary-900">{statistics.not_notified_count}</p>
                  <p className="text-xs text-error-600 mt-1">Requer atenção</p>
                </div>
                <div className="h-8 w-8 lg:h-12 lg:w-12 bg-error-100 rounded-lg flex items-center justify-center">
                  <BellOff className="h-4 w-4 lg:h-6 lg:w-6 text-error-600" />
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
                  placeholder="Buscar por número, tipo, veículo ou responsável..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                />
              </div>
            </div>
            <div className="flex flex-col sm:flex-row space-y-2 sm:space-y-0 sm:space-x-2">
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              >
                <option value="">Todos os Status</option>
                <option value="Pendente">Pendente</option>
                <option value="Pago">Pago</option>
                <option value="Contestado">Contestado</option>
              </select>
              <select
                value={infractionFilter}
                onChange={(e) => setInfractionFilter(e.target.value)}
                className="border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              >
                <option value="">Todos os Tipos</option>
                {uniqueInfractionTypes.map(type => (
                  <option key={type} value={type}>{type}</option>
                ))}
              </select>
              <Button variant="secondary" size="sm" className="w-full sm:w-auto">
                <Filter className="h-4 w-4 mr-2" />
                Filtros
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Fines List */}
      <Card>
        <CardHeader className="p-4 lg:p-6">
          <h3 className="text-lg font-semibold text-secondary-900">
            Multas Registradas ({filteredFines.length})
          </h3>
        </CardHeader>
        <CardContent className="p-0">
          {/* Mobile Cards */}
          <div className="lg:hidden space-y-3 p-4">
            {filteredFines.map((fine) => (
              <div key={fine.id} className={`border border-secondary-200 rounded-lg p-4 ${isOverdue(fine) ? 'bg-error-25 border-error-200' : ''}`}>
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <p className="font-medium text-secondary-900">{fine.fine_number}</p>
                    <p className="text-sm text-secondary-600">{fine.infraction_type}</p>
                    <p className="text-sm text-secondary-600">
                      {fine.vehicles?.plate} - {fine.drivers?.name || 'Motorista não informado'}
                    </p>
                  </div>
                  <div className="flex flex-col space-y-1">
                    {getStatusBadge(fine.status)}
                    {getNotificationBadge(fine.notified)}
                    {isOverdue(fine) && <Badge variant="error">Vencida</Badge>}
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-3 text-sm mb-3">
                  <div>
                    <span className="text-secondary-500">Valor:</span>
                    <p className="font-medium">R$ {fine.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}</p>
                  </div>
                  <div>
                    <span className="text-secondary-500">Vencimento:</span>
                    <p className="font-medium">{fine.due_date ? new Date(fine.due_date).toLocaleDateString('pt-BR') : '-'}</p>
                  </div>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs text-secondary-500 flex items-center">
                    <UserCheck className="h-3 w-3 mr-1" />
                    {fine.created_by_name || getResponsibleName(fine.employee_id)}
                  </span>
                  <div className="flex space-x-2">
                    {canManageFines && (
                      <>
                        <button 
                          onClick={() => handleToggleNotification(fine)}
                          className="p-2 text-secondary-400 hover:text-secondary-600"
                          title={fine.notified ? 'Marcar como não notificado' : 'Marcar como notificado'}
                        >
                          {fine.notified ? <BellOff className="h-4 w-4" /> : <Bell className="h-4 w-4" />}
                        </button>
                        <button 
                          onClick={() => handleView(fine)}
                          className="p-2 text-secondary-400 hover:text-secondary-600"
                        >
                          <Eye className="h-4 w-4" />
                        </button>
                        <button 
                          onClick={() => handleEdit(fine)}
                          className="p-2 text-secondary-400 hover:text-secondary-600"
                        >
                          <Edit className="h-4 w-4" />
                        </button>
                        <button 
                          onClick={() => handleDelete(fine.id)}
                          className="p-2 text-secondary-400 hover:text-error-600"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </>
                    )}
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
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Número</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Veículo</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Motorista</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Infração</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Valor</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Vencimento</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Status</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Responsável</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-secondary-200">
                {filteredFines.map((fine) => (
                  <tr key={fine.id} className={`hover:bg-secondary-50 ${isOverdue(fine) ? 'bg-error-25' : ''}`}>
                    <td className="py-4 px-6">
                      <div>
                        <p className="text-sm font-medium text-secondary-900">{fine.fine_number}</p>
                        <p className="text-xs text-secondary-600">{new Date(fine.infraction_date).toLocaleDateString('pt-BR')}</p>
                      </div>
                    </td>
                    <td className="py-4 px-6">
                      <div className="flex items-center">
                        <Car className="h-4 w-4 text-secondary-400 mr-2" />
                        <div>
                          <p className="text-sm font-medium text-secondary-900">{fine.vehicles?.plate}</p>
                          <p className="text-xs text-secondary-600">{fine.vehicles?.model}</p>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-6">
                      <div className="flex items-center">
                        <User className="h-4 w-4 text-secondary-400 mr-2" />
                        <div>
                          <p className="text-sm text-secondary-900">{fine.drivers?.name || 'Não informado'}</p>
                          {fine.drivers?.cpf && (
                            <p className="text-xs text-secondary-600">{fine.drivers.cpf}</p>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600 max-w-xs">
                      <div className="truncate" title={fine.infraction_type}>
                        {fine.infraction_type}
                      </div>
                    </td>
                    <td className="py-4 px-6 text-sm font-medium text-secondary-900">
                      R$ {fine.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                    </td>
                    <td className="py-4 px-6">
                      <div>
                        <p className="text-sm text-secondary-900">
                          {fine.due_date ? new Date(fine.due_date).toLocaleDateString('pt-BR') : '-'}
                        </p>
                        {isOverdue(fine) && (
                          <Badge variant="error" className="text-xs mt-1">Vencida</Badge>
                        )}
                      </div>
                    </td>
                    <td className="py-4 px-6">
                      {getStatusBadge(fine.status)}
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      <div className="flex items-center">
                        <UserCheck className="h-4 w-4 text-secondary-400 mr-1" />
                        <span>{fine.created_by_name || getResponsibleName(fine.employee_id)}</span>
                      </div>
                    </td>
                    <td className="py-4 px-6">
                      {canManageFines ? (
                        <div className="flex items-center space-x-2">
                          <button
                            onClick={() => handleToggleNotification(fine)}
                            className="hover:bg-secondary-100 rounded p-1"
                            title={fine.notified ? 'Marcar como não notificado' : 'Marcar como notificado'}
                          >
                            {getNotificationBadge(fine.notified)}
                          </button>
                          <button 
                            onClick={() => handleView(fine)}
                            className="p-1 text-secondary-400 hover:text-secondary-600"
                          >
                            <Eye className="h-4 w-4" />
                          </button>
                          <button 
                            onClick={() => handleEdit(fine)}
                            className="p-1 text-secondary-400 hover:text-secondary-600"
                          >
                            <Edit className="h-4 w-4" />
                          </button>
                          <button 
                            onClick={() => handleDelete(fine.id)}
                            className="p-1 text-secondary-400 hover:text-error-600"
                          >
                            <Trash2 className="h-4 w-4" />
                          </button>
                        </div>
                      ) : (
                        <div className="flex items-center space-x-2">
                          <button 
                            onClick={() => handleView(fine)}
                            className="p-1 text-secondary-400 hover:text-secondary-600"
                          >
                            <Eye className="h-4 w-4" />
                          </button>
                        </div>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {filteredFines.length === 0 && (
            <div className="text-center py-8">
              <AlertTriangle className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
              <p className="text-secondary-600">Nenhuma multa encontrada</p>
            </div>
          )}
        </CardContent>
      </Card>

      <FineModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        fine={selectedFine}
        vehicles={selectableVehicles}
        employees={employees}
        onSave={handleSave}
      />

      {/* View Fine Modal */}
      {isViewModalOpen && selectedFine && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-4xl max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-xl font-semibold text-secondary-900">
                Detalhes da Multa
              </h2>
              <button 
                onClick={() => setIsViewModalOpen(false)}
                className="text-secondary-400 hover:text-secondary-600 p-2"
              >
                ×
              </button>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Informações da Multa */}
              <div className="space-y-4">
                <div className="border border-secondary-200 rounded-lg p-4">
                  <h3 className="text-lg font-medium text-secondary-900 mb-3">Informações da Multa</h3>
                  <div className="space-y-3">
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Número da Multa:</span>
                      <span className="font-medium">{selectedFine.fine_number}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Tipo de Infração:</span>
                      <span className="font-medium">{selectedFine.infraction_type}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Data da Infração:</span>
                      <span className="font-medium">{new Date(selectedFine.infraction_date).toLocaleDateString('pt-BR')}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Local:</span>
                      <span className="font-medium">{selectedFine.location || 'Não informado'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Valor:</span>
                      <span className="font-medium text-error-600">R$ {selectedFine.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Vencimento:</span>
                      <span className="font-medium">{selectedFine.due_date ? new Date(selectedFine.due_date).toLocaleDateString('pt-BR') : 'Não informado'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Status:</span>
                      <span>{getStatusBadge(selectedFine.status)}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Notificado:</span>
                      <span>{getNotificationBadge(selectedFine.notified)}</span>
                    </div>
                    {isOverdue(selectedFine) && (
                      <div className="flex justify-between">
                        <span className="text-secondary-600">Situação:</span>
                        <Badge variant="error">Vencida</Badge>
                      </div>
                    )}
                  </div>
                </div>

                {/* Observações */}
                {selectedFine.observations && (
                  <div className="border border-secondary-200 rounded-lg p-4">
                    <h3 className="text-lg font-medium text-secondary-900 mb-3">Observações</h3>
                    <p className="text-secondary-700">{selectedFine.observations}</p>
                  </div>
                )}
              </div>

              {/* Informações do Veículo e Motorista */}
              <div className="space-y-4">
                <div className="border border-secondary-200 rounded-lg p-4">
                  <h3 className="text-lg font-medium text-secondary-900 mb-3">Veículo</h3>
                  <div className="space-y-3">
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Placa:</span>
                      <span className="font-medium">{selectedFine.vehicles?.plate || 'Não informado'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Modelo:</span>
                      <span className="font-medium">{selectedFine.vehicles?.model || 'Não informado'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Tipo:</span>
                      <span className="font-medium">{selectedFine.vehicles?.type || 'Não informado'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Ano:</span>
                      <span className="font-medium">{selectedFine.vehicles?.year || 'Não informado'}</span>
                    </div>
                  </div>
                </div>

                <div className="border border-secondary-200 rounded-lg p-4">
                  <h3 className="text-lg font-medium text-secondary-900 mb-3">Motorista</h3>
                  <div className="space-y-3">
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Nome:</span>
                      <span className="font-medium">{selectedFine.drivers?.name || 'Não informado'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary-600">CPF:</span>
                      <span className="font-medium">{selectedFine.drivers?.cpf || 'Não informado'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary-600">CNH:</span>
                      <span className="font-medium">{selectedFine.drivers?.license_number || 'Não informado'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Telefone:</span>
                      <span className="font-medium">{selectedFine.drivers?.phone || 'Não informado'}</span>
                    </div>
                  </div>
                </div>

                <div className="border border-secondary-200 rounded-lg p-4">
                  <h3 className="text-lg font-medium text-secondary-900 mb-3">Responsável</h3>
                  <div className="space-y-3">
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Registrado por:</span>
                      <span className="font-medium">{selectedFine.created_by_name || getResponsibleName(selectedFine.employee_id)}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-secondary-600">Data de Registro:</span>
                      <span className="font-medium">{new Date(selectedFine.created_at).toLocaleDateString('pt-BR')}</span>
                    </div>
                    {selectedFine.updated_at && selectedFine.updated_at !== selectedFine.created_at && (
                      <div className="flex justify-between">
                        <span className="text-secondary-600">Última Atualização:</span>
                        <span className="font-medium">{new Date(selectedFine.updated_at).toLocaleDateString('pt-BR')}</span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>

            <div className="flex justify-end mt-6 space-x-4">
              <Button 
                variant="secondary" 
                onClick={() => setIsViewModalOpen(false)}
              >
                Fechar
              </Button>
              {canManageFines && (
                <Button 
                  onClick={() => {
                    setIsViewModalOpen(false);
                    handleEdit(selectedFine);
                  }}
                >
                  <Edit className="h-4 w-4 mr-2" />
                  Editar
                </Button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};