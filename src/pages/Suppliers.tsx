import React, { useState } from 'react';
import { Card, CardHeader, CardContent } from '../components/UI/Card';
import { Button } from '../components/UI/Button';
import { Badge } from '../components/UI/Badge';
import { useSuppliers, Supplier, SupplierInsert, SupplierUpdate } from '../hooks/useSuppliers';
import { usePurchaseOrders } from '../hooks/usePurchaseOrders';
import { Plus, Search, Filter, Building2, Phone, Mail, MapPin, Loader2, Edit, Eye, Trash2, ShoppingBag, DollarSign, Package, FileText } from 'lucide-react';

const SupplierModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  supplier?: Supplier;
  onSave: (data: SupplierInsert | SupplierUpdate) => Promise<void>;
}> = ({ isOpen, onClose, supplier, onSave }) => {
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    name: supplier?.name || '',
    document: supplier?.document || '',
    email: supplier?.contact_info?.email || '',
    phone: supplier?.contact_info?.phone || '',
    address: supplier?.contact_info?.address || '',
    contact_person: supplier?.contact_info?.contact_person || ''
  });

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      const submitData = {
        name: formData.name,
        document: formData.document || null,
        contact_info: {
          email: formData.email || null,
          phone: formData.phone || null,
          address: formData.address || null,
          contact_person: formData.contact_person || null
        }
      };
      await onSave(submitData);
      onClose();
    } catch (error) {
      console.error('Error saving supplier:', error);
      alert('Erro ao salvar fornecedor: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
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
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <h2 className="text-lg lg:text-xl font-semibold text-secondary-900">
            {supplier ? 'Editar Fornecedor' : 'Novo Fornecedor'}
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            ×
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 lg:space-y-6">
          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              Nome do Fornecedor *
            </label>
            <input
              type="text"
              name="name"
              value={formData.name}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder="Nome da empresa fornecedora"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              CNPJ
            </label>
            <input
              type="text"
              name="document"
              value={formData.document}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder="00.000.000/0000-00"
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
                placeholder="contato@fornecedor.com"
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
                placeholder="(00) 0000-0000"
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
              placeholder="Endereço completo do fornecedor"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              Pessoa de Contato
            </label>
            <input
              type="text"
              name="contact_person"
              value={formData.contact_person}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder="Nome da pessoa de contato"
            />
          </div>

          <div className="flex flex-col sm:flex-row justify-end space-y-3 sm:space-y-0 sm:space-x-4 pt-4 lg:pt-6 border-t">
            <Button variant="secondary" onClick={onClose} disabled={loading} className="w-full sm:w-auto">
              Cancelar
            </Button>
            <Button type="submit" disabled={loading} className="w-full sm:w-auto">
              {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
              {supplier ? 'Salvar Alterações' : 'Cadastrar Fornecedor'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
};

const SupplierDetailModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  supplier?: Supplier;
  orders: any[];
}> = ({ isOpen, onClose, supplier, orders }) => {
  if (!isOpen || !supplier) return null;

  const supplierOrders = orders.filter(po => po.supplier_id === supplier.id);
  const totalOrdered = supplierOrders.reduce((sum, po) => sum + po.total_amount, 0);
  const pendingOrders = supplierOrders.filter(po => po.status === 'Pending').length;

  const getStatusBadge = (status: string) => {
    const variants = {
      'Pending': 'warning',
      'Received': 'success',
      'Cancelled': 'error'
    } as const;

    const labels = {
      'Pending': 'Pendente',
      'Received': 'Recebido',
      'Cancelled': 'Cancelado'
    } as const;

    return <Badge variant={variants[status as keyof typeof variants] || 'secondary'}>
      {labels[status as keyof typeof labels] || status}
    </Badge>;
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-4xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <h2 className="text-lg lg:text-xl font-semibold text-secondary-900">
            Detalhes do Fornecedor
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            ×
          </button>
        </div>

        {/* Supplier Info */}
        <div className="bg-secondary-50 p-4 rounded-lg mb-6">
          <div className="flex items-center mb-4">
            <div className="h-12 w-12 bg-primary-100 rounded-lg flex items-center justify-center mr-4">
              <Building2 className="h-6 w-6 text-primary-600" />
            </div>
            <div>
              <h3 className="text-xl font-semibold text-secondary-900">{supplier.name}</h3>
              {supplier.document && (
                <p className="text-sm text-secondary-600">CNPJ: {supplier.document}</p>
              )}
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mt-4">
            {supplier.contact_info.email && (
              <div className="flex items-center">
                <Mail className="h-5 w-5 text-secondary-400 mr-2" />
                <div>
                  <p className="text-sm text-secondary-600">Email:</p>
                  <p className="font-medium">{supplier.contact_info.email}</p>
                </div>
              </div>
            )}
            
            {supplier.contact_info.phone && (
              <div className="flex items-center">
                <Phone className="h-5 w-5 text-secondary-400 mr-2" />
                <div>
                  <p className="text-sm text-secondary-600">Telefone:</p>
                  <p className="font-medium">{supplier.contact_info.phone}</p>
                </div>
              </div>
            )}
            
            {supplier.contact_info.contact_person && (
              <div className="flex items-center">
                <Eye className="h-5 w-5 text-secondary-400 mr-2" />
                <div>
                  <p className="text-sm text-secondary-600">Contato:</p>
                  <p className="font-medium">{supplier.contact_info.contact_person}</p>
                </div>
              </div>
            )}
            
            {supplier.contact_info.address && (
              <div className="flex items-start lg:col-span-2">
                <MapPin className="h-5 w-5 text-secondary-400 mr-2 mt-0.5" />
                <div>
                  <p className="text-sm text-secondary-600">Endereço:</p>
                  <p className="font-medium">{supplier.contact_info.address}</p>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Purchase Order Summary */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-6">
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-sm font-medium">Total de Pedidos</p>
                  <p className="text-2xl font-bold text-secondary-900">{supplierOrders.length}</p>
                </div>
                <ShoppingBag className="h-8 w-8 text-primary-600" />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-sm font-medium">Valor Total</p>
                  <p className="text-2xl font-bold text-secondary-900">
                    R$ {totalOrdered.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                  </p>
                </div>
                <DollarSign className="h-8 w-8 text-success-600" />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-sm font-medium">Pedidos Pendentes</p>
                  <p className="text-2xl font-bold text-secondary-900">{pendingOrders}</p>
                </div>
                <Package className="h-8 w-8 text-warning-600" />
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Recent Purchase Orders */}
        <div>
          <h3 className="text-lg font-semibold text-secondary-900 mb-4">
            Pedidos de Compra Recentes
          </h3>
          
          {supplierOrders.length > 0 ? (
            <div className="space-y-3">
              {supplierOrders.slice(0, 5).map((order) => (
                <div key={order.id} className="border border-secondary-200 rounded-lg p-4">
                  <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
                    <div className="flex-1">
                      <div className="flex items-center space-x-3 mb-2">
                        <h4 className="font-medium text-secondary-900">{order.order_number}</h4>
                        {getStatusBadge(order.status)}
                      </div>
                      <p className="text-sm text-secondary-600 mb-1">
                        Data: {new Date(order.order_date).toLocaleDateString('pt-BR')}
                      </p>
                      {order.notes && (
                        <p className="text-sm text-secondary-600 line-clamp-2">{order.notes}</p>
                      )}
                    </div>
                    <div className="text-right">
                      <p className="text-lg font-bold text-secondary-900">
                        R$ {order.total_amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                      </p>
                      <p className="text-sm text-secondary-600">
                        {order.item_count || 0} itens
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-8">
              <ShoppingBag className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
              <p className="text-secondary-600">Nenhum pedido registrado para este fornecedor</p>
            </div>
          )}
        </div>

        <div className="flex justify-end pt-6 border-t mt-6">
          <Button onClick={onClose}>
            Fechar
          </Button>
        </div>
      </div>
    </div>
  );
};

export const Suppliers: React.FC = () => {
  const { suppliers, loading: suppliersLoading, createSupplier, updateSupplier, deleteSupplier } = useSuppliers();
  const { orders, loading: ordersLoading } = usePurchaseOrders();
  const [searchTerm, setSearchTerm] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isDetailModalOpen, setIsDetailModalOpen] = useState(false);
  const [selectedSupplier, setSelectedSupplier] = useState<Supplier | undefined>(undefined);

  const loading = suppliersLoading || ordersLoading;

  const filteredSuppliers = suppliers.filter(supplier =>
    supplier.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    supplier.document?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    supplier.contact_info.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    supplier.contact_info.phone?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleEdit = (supplier: Supplier) => {
    setSelectedSupplier(supplier);
    setIsModalOpen(true);
  };

  const handleNew = () => {
    setSelectedSupplier(undefined);
    setIsModalOpen(true);
  };

  const handleViewDetails = (supplier: Supplier) => {
    setSelectedSupplier(supplier);
    setIsDetailModalOpen(true);
  };

  const handleSave = async (data: SupplierInsert | SupplierUpdate) => {
    if (selectedSupplier) {
      await updateSupplier(selectedSupplier.id, data);
    } else {
      await createSupplier(data as SupplierInsert);
    }
  };

  const handleDelete = async (id: string) => {
    if (confirm('Tem certeza que deseja excluir este fornecedor?')) {
      try {
        await deleteSupplier(id);
      } catch (error) {
        alert('Erro ao excluir fornecedor: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
      }
    }
  };

  // Calculate statistics
  const totalSuppliers = filteredSuppliers.length;
  const suppliersWithOrders = filteredSuppliers.filter(
    supplier => orders.some(po => po.supplier_id === supplier.id)
  ).length;
  
  const getSupplierOrdersCount = (supplierId: string) => {
    return orders.filter(po => po.supplier_id === supplierId).length;
  };

  const getSupplierTotalOrdered = (supplierId: string) => {
    return orders
      .filter(po => po.supplier_id === supplierId)
      .reduce((sum, po) => sum + po.total_amount, 0);
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
          <h1 className="text-2xl lg:text-3xl font-bold text-secondary-900">Fornecedores</h1>
          <p className="text-secondary-600 mt-1 lg:mt-2">Gerencie seus fornecedores e acompanhe os pedidos de compra</p>
        </div>
        <Button onClick={handleNew} size="sm" className="w-full sm:w-auto">
          <Plus className="h-4 w-4 mr-2" />
          Novo Fornecedor
        </Button>
      </div>

      {/* Statistics Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 lg:gap-6">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-secondary-600 text-xs lg:text-sm font-medium">Total de Fornecedores</p>
                <p className="text-xl lg:text-2xl font-bold text-secondary-900">{totalSuppliers}</p>
              </div>
              <div className="h-8 w-8 lg:h-12 lg:w-12 bg-primary-100 rounded-lg flex items-center justify-center">
                <Building2 className="h-4 w-4 lg:h-6 lg:w-6 text-primary-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-secondary-600 text-xs lg:text-sm font-medium">Com Pedidos</p>
                <p className="text-xl lg:text-2xl font-bold text-secondary-900">{suppliersWithOrders}</p>
              </div>
              <div className="h-8 w-8 lg:h-12 lg:w-12 bg-success-100 rounded-lg flex items-center justify-center">
                <ShoppingBag className="h-4 w-4 lg:h-6 lg:w-6 text-success-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-secondary-600 text-xs lg:text-sm font-medium">Total de Pedidos</p>
                <p className="text-xl lg:text-2xl font-bold text-secondary-900">{orders.length}</p>
              </div>
              <div className="h-8 w-8 lg:h-12 lg:w-12 bg-warning-100 rounded-lg flex items-center justify-center">
                <FileText className="h-4 w-4 lg:h-6 lg:w-6 text-warning-600" />
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
                  R$ {orders.reduce((sum, po) => sum + po.total_amount, 0).toLocaleString('pt-BR')}
                </p>
              </div>
              <div className="h-8 w-8 lg:h-12 lg:w-12 bg-error-100 rounded-lg flex items-center justify-center">
                <DollarSign className="h-4 w-4 lg:h-6 lg:w-6 text-error-600" />
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col sm:flex-row gap-4">
            <div className="flex-1">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
                <input
                  type="text"
                  placeholder="Buscar por nome, CNPJ, email ou telefone..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                />
              </div>
            </div>
            <Button variant="secondary" size="sm" className="w-full sm:w-auto">
              <Filter className="h-4 w-4 mr-2" />
              Filtros
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Suppliers List */}
      <Card>
        <CardHeader className="p-4 lg:p-6">
          <h3 className="text-lg font-semibold text-secondary-900">
            Fornecedores ({filteredSuppliers.length})
          </h3>
        </CardHeader>
        <CardContent className="p-0">
          {/* Mobile Cards */}
          <div className="lg:hidden space-y-3 p-4">
            {filteredSuppliers.map((supplier) => {
              const ordersCount = getSupplierOrdersCount(supplier.id);
              const totalOrdered = getSupplierTotalOrdered(supplier.id);
              
              return (
                <div key={supplier.id} className="border border-secondary-200 rounded-lg p-4">
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <p className="font-medium text-secondary-900">{supplier.name}</p>
                      <p className="text-sm text-secondary-600">{supplier.document || 'CNPJ não informado'}</p>
                    </div>
                    <Badge variant={ordersCount > 0 ? 'success' : 'secondary'}>
                      {ordersCount} pedidos
                    </Badge>
                  </div>
                  
                  <div className="space-y-1 text-sm text-secondary-600 mb-3">
                    {supplier.contact_info.email && (
                      <div className="flex items-center">
                        <Mail className="h-4 w-4 mr-2" />
                        {supplier.contact_info.email}
                      </div>
                    )}
                    {supplier.contact_info.phone && (
                      <div className="flex items-center">
                        <Phone className="h-4 w-4 mr-2" />
                        {supplier.contact_info.phone}
                      </div>
                    )}
                  </div>
                  
                  <div className="flex justify-between items-center">
                    <span className="text-sm font-medium">
                      {totalOrdered > 0 ? `R$ ${totalOrdered.toLocaleString('pt-BR')}` : 'Sem compras'}
                    </span>
                    <div className="flex space-x-2">
                      <button 
                        onClick={() => handleViewDetails(supplier)}
                        className="p-2 text-secondary-400 hover:text-secondary-600"
                      >
                        <Eye className="h-4 w-4" />
                      </button>
                      <button 
                        onClick={() => handleEdit(supplier)}
                        className="p-2 text-secondary-400 hover:text-secondary-600"
                      >
                        <Edit className="h-4 w-4" />
                      </button>
                      <button 
                        onClick={() => handleDelete(supplier.id)}
                        className="p-2 text-secondary-400 hover:text-error-600"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Desktop Table */}
          <div className="hidden lg:block overflow-x-auto">
            <table className="w-full">
              <thead className="bg-secondary-50">
                <tr>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Nome</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">CNPJ</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Contato</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Pedidos</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Total Comprado</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-secondary-200">
                {filteredSuppliers.map((supplier) => {
                  const ordersCount = getSupplierOrdersCount(supplier.id);
                  const totalOrdered = getSupplierTotalOrdered(supplier.id);
                  
                  return (
                    <tr key={supplier.id} className="hover:bg-secondary-50">
                      <td className="py-4 px-6">
                        <div>
                          <p className="text-sm font-medium text-secondary-900">{supplier.name}</p>
                          <p className="text-xs text-secondary-600">
                            Cadastrado em {new Date(supplier.created_at).toLocaleDateString('pt-BR')}
                          </p>
                        </div>
                      </td>
                      <td className="py-4 px-6 text-sm text-secondary-600">
                        {supplier.document || '-'}
                      </td>
                      <td className="py-4 px-6">
                        <div className="space-y-1 text-sm text-secondary-600">
                          {supplier.contact_info.email && (
                            <div className="flex items-center">
                              <Mail className="h-3 w-3 mr-1" />
                              {supplier.contact_info.email}
                            </div>
                          )}
                          {supplier.contact_info.phone && (
                            <div className="flex items-center">
                              <Phone className="h-3 w-3 mr-1" />
                              {supplier.contact_info.phone}
                            </div>
                          )}
                        </div>
                      </td>
                      <td className="py-4 px-6">
                        <Badge variant={ordersCount > 0 ? 'success' : 'secondary'}>
                          {ordersCount} pedidos
                        </Badge>
                      </td>
                      <td className="py-4 px-6 text-sm font-medium text-secondary-900">
                        {totalOrdered > 0 
                          ? `R$ ${totalOrdered.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}` 
                          : '-'
                        }
                      </td>
                      <td className="py-4 px-6">
                        <div className="flex items-center space-x-2">
                          <button 
                            onClick={() => handleViewDetails(supplier)}
                            className="p-1 text-secondary-400 hover:text-secondary-600"
                          >
                            <Eye className="h-4 w-4" />
                          </button>
                          <button 
                            onClick={() => handleEdit(supplier)}
                            className="p-1 text-secondary-400 hover:text-secondary-600"
                          >
                            <Edit className="h-4 w-4" />
                          </button>
                          <button 
                            onClick={() => handleDelete(supplier.id)}
                            className="p-1 text-secondary-400 hover:text-error-600"
                          >
                            <Trash2 className="h-4 w-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {filteredSuppliers.length === 0 && (
            <div className="text-center py-8">
              <Building2 className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
              <p className="text-secondary-600">Nenhum fornecedor encontrado</p>
            </div>
          )}
        </CardContent>
      </Card>

      <SupplierModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        supplier={selectedSupplier}
        onSave={handleSave}
      />

      <SupplierDetailModal
        isOpen={isDetailModalOpen}
        onClose={() => setIsDetailModalOpen(false)}
        supplier={selectedSupplier}
        orders={orders}
      />
    </div>
  );
};