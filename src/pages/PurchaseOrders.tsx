import React, { useState } from 'react';
import { Card, CardHeader, CardContent } from '../components/UI/Card';
import { Button } from '../components/UI/Button';
import { Badge } from '../components/UI/Badge';
import { usePurchaseOrders, PurchaseOrder } from '../hooks/usePurchaseOrders';
import { useSuppliers } from '../hooks/useSuppliers';
import { useParts } from '../hooks/useParts';
import { useEmployees } from '../hooks/useEmployees';
import { useAuth } from '../hooks/useAuth';
import { PurchaseOrderForm } from '../components/PurchaseOrders/PurchaseOrderForm';
import { PurchaseOrderDetailModal } from '../components/PurchaseOrders/PurchaseOrderDetailModal';
import { Plus, Search, Filter, ShoppingBag, DollarSign, Calendar, Package, Loader2, Edit, Trash2, Building2, RefreshCw, Eye } from 'lucide-react';
import toast from 'react-hot-toast';

interface PurchaseOrderModalProps {
  isOpen: boolean;
  onClose: () => void;
  purchaseOrder?: PurchaseOrder | undefined;
  suppliers: Array<{ id: string; name: string; document?: string | null }>;
  parts: Array<{ id: string; name: string; sku?: string }>;
  employees: Array<{ id: string; name: string; role?: string }>;
  onSave: (orderData: {
    supplier_id: string;
    order_number?: string;
    order_date: string;
    total_amount: number;
    status: 'Pending' | 'Received' | 'Cancelled' | 'Aprovada';
    created_by_employee_id: string | null;
    notes?: string | null;
  }, items: {
    purchase_order_id: string;
    part_id?: string | null;
    description: string;
    quantity: number;
    unit_price: number;
  }[]) => Promise<void>;
}

const PurchaseOrderModal: React.FC<PurchaseOrderModalProps> = ({ isOpen, onClose, purchaseOrder, suppliers, parts, employees, onSave }) => {
  const [loading, setLoading] = useState(false);

  if (!isOpen) return null;

  const handleSave = async (orderData: {
    supplier_id: string;
    order_number?: string;
    order_date: string;
    total_amount: number;
    status: 'Pending' | 'Received' | 'Cancelled' | 'Aprovada';
    created_by_employee_id: string | null;
    notes?: string | null;
  }, items: {
    purchase_order_id: string;
    part_id?: string | null;
    description: string;
    quantity: number;
    unit_price: number;
  }[]) => {
    setLoading(true);
    try {
      await onSave(orderData, items);
      onClose();
    } catch (error) {
      console.error('Error saving purchase order:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-4xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <h2 className="text-lg lg:text-xl font-semibold text-secondary-900">
            {purchaseOrder ? 'Editar Pedido de Compra' : 'Novo Pedido de Compra'}
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            ×
          </button>
        </div>

        <PurchaseOrderForm
          onSubmit={handleSave}
          onCancel={onClose}
          purchaseOrder={purchaseOrder}
          suppliers={suppliers}
          parts={parts}
          employees={employees}
          loading={loading}
        />
      </div>
    </div>
  );
};

export const PurchaseOrders: React.FC = () => {
  const { orders, stats, loading: ordersLoading, createPurchaseOrder, updatePurchaseOrder, deletePurchaseOrder, fetchPurchaseOrderItems, refetch } = usePurchaseOrders();
  const { suppliers } = useSuppliers();
  const { parts } = useParts();
  const { employees } = useEmployees();
  const { isAdmin, isManager, hasPermission } = useAuth();
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isDetailModalOpen, setIsDetailModalOpen] = useState(false);
  const [selectedOrder, setSelectedOrder] = useState<PurchaseOrder | undefined>(undefined);
  const [orderItems, setOrderItems] = useState<unknown[]>([]);
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const canManagePurchases = isAdmin || isManager || hasPermission('purchases');

  const handleRefresh = async () => {
    setRefreshing(true);
    try {
      await refetch();
      toast.success('Dados atualizados com sucesso!');
    } catch {
      toast.error('Erro ao atualizar dados');
    } finally {
      setRefreshing(false);
    }
  };

  const filteredOrders = orders.filter((order: PurchaseOrder) => {
    const matchesSearch = 
      order.order_number.toLowerCase().includes(searchTerm.toLowerCase()) ||
      order.supplier_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      order.created_by_name?.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesStatus = statusFilter === '' || order.status === statusFilter;
    
    return matchesSearch && matchesStatus;
  });

  const getStatusBadge = (status: string) => {
    const variants = {
      'Pending': 'warning',
      'Received': 'success',
      'Cancelled': 'error',
      'Aprovada': 'info'
    } as const;

    const labels = {
      'Pending': 'Pendente',
      'Received': 'Recebido',
      'Cancelled': 'Cancelado',
      'Aprovada': 'Aprovada'
    } as const;

    return <Badge variant={variants[status as keyof typeof variants] || 'secondary'}>
      {labels[status as keyof typeof labels] || status}
    </Badge>;
  };

  const handleEdit = (order: PurchaseOrder) => {
    setSelectedOrder(order);
    setIsModalOpen(true);
  };

  const handleNew = () => {
    setSelectedOrder(undefined);
    setIsModalOpen(true);
  };

  const handleViewDetails = async (order: PurchaseOrder) => {
    setLoading(true);
    try {
      const items = await fetchPurchaseOrderItems(order.id);
      setOrderItems(items);
      setSelectedOrder(order);
      setIsDetailModalOpen(true);
    } catch (error) {
      console.error('Error fetching order items:', error);
      toast.error('Erro ao carregar itens do pedido');
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async (orderData: {
    supplier_id: string;
    order_number?: string;
    order_date: string;
    total_amount: number;
    status: 'Pending' | 'Received' | 'Cancelled' | 'Aprovada';
    created_by_employee_id: string | null;
    notes?: string | null;
  }, items: {
    purchase_order_id: string;
    part_id?: string | null;
    description: string;
    quantity: number;
    unit_price: number;
  }[]) => {
    try {
      if (selectedOrder) {
        await updatePurchaseOrder(selectedOrder.id, orderData);
        toast.success('Pedido de compra atualizado com sucesso!');
      } else {
        await createPurchaseOrder(orderData, items);
        toast.success('Pedido de compra criado com sucesso!');
      }
    } catch (error) {
      toast.error('Erro ao salvar pedido de compra: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
      throw error;
    }
  };

  const handleDelete = async (id: string) => {
    if (confirm('Tem certeza que deseja excluir este pedido de compra?')) {
      try {
        await deletePurchaseOrder(id);
        toast.success('Pedido de compra excluído com sucesso!');
      } catch (error) {
        toast.error('Erro ao excluir pedido: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
      }
    }
  };

  const getSupplierById = (id: string) => {
    return suppliers.find(s => s.id === id);
  };

  if (ordersLoading) {
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
          <h1 className="text-2xl lg:text-3xl font-bold text-secondary-900">Pedidos de Compra</h1>
          <p className="text-secondary-600 mt-1 lg:mt-2">Gerencie pedidos de compra com integração automática ao painel de custos</p>
        </div>
        <div className="flex flex-col sm:flex-row space-y-2 sm:space-y-0 sm:space-x-3 w-full sm:w-auto">
          <Button 
            onClick={handleRefresh} 
            variant="secondary" 
            size="sm" 
            disabled={refreshing}
            className="w-full sm:w-auto"
          >
            <RefreshCw className={`h-4 w-4 mr-2 ${refreshing ? 'animate-spin' : ''}`} />
            {refreshing ? 'Atualizando...' : 'Atualizar'}
          </Button>
          {canManagePurchases && (
            <Button onClick={handleNew} size="sm" className="w-full sm:w-auto">
              <Plus className="h-4 w-4 mr-2" />
              Novo Pedido
            </Button>
          )}
        </div>
      </div>

      {/* Statistics Cards */}
      {stats && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 lg:gap-6">
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Total de Pedidos</p>
                  <p className="text-xl lg:text-2xl font-bold text-secondary-900">{stats.total_orders}</p>
                </div>
                <div className="h-8 w-8 lg:h-12 lg:w-12 bg-primary-100 rounded-lg flex items-center justify-center">
                  <ShoppingBag className="h-4 w-4 lg:h-6 lg:w-6 text-primary-600" />
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
                    R$ {stats.total_amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                  </p>
                </div>
                <div className="h-8 w-8 lg:h-12 lg:w-12 bg-success-100 rounded-lg flex items-center justify-center">
                  <DollarSign className="h-4 w-4 lg:h-6 lg:w-6 text-success-600" />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Pendentes</p>
                  <p className="text-xl lg:text-2xl font-bold text-warning-600">{stats.pending_orders}</p>
                  <p className="text-xs text-warning-600 mt-1">
                    R$ {stats.pending_amount.toLocaleString('pt-BR')}
                  </p>
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
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Recebidos</p>
                  <p className="text-xl lg:text-2xl font-bold text-secondary-900">{stats.received_orders}</p>
                </div>
                <div className="h-8 w-8 lg:h-12 lg:w-12 bg-success-100 rounded-lg flex items-center justify-center">
                  <Package className="h-4 w-4 lg:h-6 lg:w-6 text-success-600" />
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
                  placeholder="Buscar por número, fornecedor ou responsável..."
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
                <option value="Pending">Pendente</option>
                <option value="Aprovada">Aprovada</option>
                <option value="Received">Recebido</option>
                <option value="Cancelled">Cancelado</option>
              </select>
              <Button variant="secondary" size="sm" className="w-full sm:w-auto">
                <Filter className="h-4 w-4 mr-2" />
                Filtros
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Purchase Orders List */}
      <Card>
        <CardHeader className="p-4 lg:p-6">
          <h3 className="text-lg font-semibold text-secondary-900">
            Pedidos de Compra ({filteredOrders.length})
          </h3>
        </CardHeader>
        <CardContent className="p-0">
          {/* Mobile Cards */}
          <div className="lg:hidden space-y-3 p-4">
            {filteredOrders.map((order) => (
              <div key={order.id} className="border border-secondary-200 rounded-lg p-4">
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <p className="font-medium text-secondary-900">{order.order_number}</p>
                    <p className="text-sm text-secondary-600">{order.supplier_name}</p>
                  </div>
                  {getStatusBadge(order.status)}
                </div>
                <div className="grid grid-cols-2 gap-3 text-sm mb-3">
                  <div>
                    <span className="text-secondary-500">Data:</span>
                    <p className="font-medium">{new Date(order.order_date).toLocaleDateString('pt-BR')}</p>
                  </div>
                  <div>
                    <span className="text-secondary-500">Valor:</span>
                    <p className="font-medium">R$ {order.total_amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}</p>
                  </div>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs text-secondary-500">
                    {order.item_count || 0} itens
                  </span>
                  <div className="flex space-x-2">
                    <button 
                      onClick={() => handleViewDetails(order)}
                      className="p-2 text-secondary-400 hover:text-secondary-600"
                    >
                      <Eye className="h-4 w-4" />
                    </button>
                    {canManagePurchases && (
                      <>
                        <button 
                          onClick={() => handleEdit(order)}
                          className="p-2 text-secondary-400 hover:text-secondary-600"
                        >
                          <Edit className="h-4 w-4" />
                        </button>
                        <button 
                          onClick={() => handleDelete(order.id)}
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
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Fornecedor</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Data</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Valor</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Status</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Itens</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-secondary-200">
                {filteredOrders.map((order) => (
                  <tr key={order.id} className="hover:bg-secondary-50">
                    <td className="py-4 px-6 text-sm font-medium text-secondary-900">
                      {order.order_number}
                    </td>
                    <td className="py-4 px-6">
                      <div className="flex items-center">
                        <Building2 className="h-4 w-4 text-secondary-400 mr-2" />
                        <div>
                          <p className="text-sm font-medium text-secondary-900">{order.supplier_name}</p>
                          {order.supplier_document && (
                            <p className="text-xs text-secondary-600">{order.supplier_document}</p>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      {new Date(order.order_date).toLocaleDateString('pt-BR')}
                    </td>
                    <td className="py-4 px-6 text-sm font-medium text-secondary-900">
                      R$ {order.total_amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                    </td>
                    <td className="py-4 px-6">
                      {getStatusBadge(order.status)}
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      {order.item_count || 0} itens
                    </td>
                    <td className="py-4 px-6">
                      <div className="flex items-center space-x-2">
                        <button 
                          onClick={() => handleViewDetails(order)}
                          className="p-1 text-secondary-400 hover:text-secondary-600"
                          title="Visualizar detalhes"
                        >
                          <Eye className="h-4 w-4" />
                        </button>
                        {canManagePurchases && (
                          <>
                            <button 
                              onClick={() => handleEdit(order)}
                              className="p-1 text-secondary-400 hover:text-secondary-600"
                              title="Editar"
                            >
                              <Edit className="h-4 w-4" />
                            </button>
                            <button 
                              onClick={() => handleDelete(order.id)}
                              className="p-1 text-secondary-400 hover:text-error-600"
                              title="Excluir"
                            >
                              <Trash2 className="h-4 w-4" />
                            </button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {filteredOrders.length === 0 && (
            <div className="text-center py-8">
              <ShoppingBag className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
              <p className="text-secondary-600">Nenhum pedido de compra encontrado</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Loading Overlay */}
      {loading && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white p-4 rounded-lg">
            <Loader2 className="h-8 w-8 animate-spin text-primary-600" />
          </div>
        </div>
      )}

      {/* Modals */}
      <PurchaseOrderModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        purchaseOrder={selectedOrder}
        suppliers={suppliers}
        parts={parts}
        employees={employees}
        onSave={handleSave}
      />

      <PurchaseOrderDetailModal
        isOpen={isDetailModalOpen}
        onClose={() => setIsDetailModalOpen(false)}
        purchaseOrder={selectedOrder}
        items={orderItems}
        supplier={selectedOrder ? getSupplierById(selectedOrder.supplier_id) : undefined}
      />
    </div>
  );
};

export default PurchaseOrders;