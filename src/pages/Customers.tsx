import React, { useState, useEffect } from 'react';
import { Card, CardHeader, CardContent } from '../components/UI/Card';
import { Button } from '../components/UI/Button';
import { useCustomers } from '../hooks/useCustomers';
import { useAuth } from '../hooks/useAuth';
import { CustomerHistoryModal } from '../components/Customers/CustomerHistoryModal';
import { CreateAccountModal } from '../components/Customers/CreateAccountModal';
import { 
  Plus, 
  Search, 
  User, 
  Loader2, 
  Edit2, 
  Trash2, 
  RefreshCw,
  Phone,
  Mail,
  MapPin,
  FileText,
  History,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { Database } from '../types/database';
import { useCustomerAccountStatus } from '../hooks/useCustomerAccountStatus';
import { supabase } from '../lib/supabase';

type Customer = Database['public']['Tables']['customers']['Row'];
type CustomerInsert = Omit<Database['public']['Tables']['customers']['Insert'], 'tenant_id'>;
type CustomerUpdate = Database['public']['Tables']['customers']['Update'];

const ITEMS_PER_PAGE = 20;

// Modal para criar/editar cliente
const CustomerModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  customer?: Customer;
  onSave: (data: CustomerInsert | CustomerUpdate) => Promise<void>;
}> = ({ isOpen, onClose, customer, onSave }) => {
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    phone: '',
    address: '',
    document: ''
  });

  // Atualizar formData quando customer mudar
  useEffect(() => {
    if (customer) {
      setFormData({
        name: customer.name || '',
        email: customer.email || '',
        phone: customer.phone || '',
        address: customer.address || '',
        document: customer.document || ''
      });
    } else {
      setFormData({
        name: '',
        email: '',
        phone: '',
        address: '',
        document: ''
      });
    }
  }, [customer]);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setLoading(true);
    try {
      const submitData = {
        ...formData,
        document: formData.document,
        email: formData.email || undefined,
        phone: formData.phone || undefined,
        address: formData.address || undefined
      };
      await onSave(submitData);
      onClose();
      // Reset form
      setFormData({
        name: '',
        email: '',
        phone: '',
        address: '',
        document: ''
      });
    } catch (error) {
      console.error('Error saving customer:', error);
      toast.error('Erro ao salvar cliente: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
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
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              CPF/CNPJ
            </label>
            <input
              type="text"
              name="document"
              value={formData.document}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
            />
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
            />
          </div>

          <div className="flex justify-end space-x-3 pt-4">
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
              variant="primary"
              disabled={loading}
            >
              {loading ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Salvando...
                </>
              ) : (
                customer ? 'Atualizar Cliente' : 'Criar Cliente'
              )}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
};

// Modal para visualizar detalhes do cliente
const ViewCustomerModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  customer: Customer | undefined;
}> = ({ isOpen, onClose, customer }) => {
  if (!isOpen || !customer) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <h2 className="text-lg lg:text-xl font-semibold text-secondary-900">Detalhes do Cliente</h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            ×
          </button>
        </div>

        <div className="space-y-4">
          <div className="flex items-center space-x-2">
            <User className="h-5 w-5 text-secondary-400" />
            <span className="text-lg font-semibold text-secondary-900">{customer.name}</span>
          </div>

          {customer.email && (
            <div className="flex items-center space-x-2">
              <Mail className="h-4 w-4 text-secondary-400" />
              <span className="text-secondary-900">{customer.email}</span>
            </div>
          )}

          {customer.phone && (
            <div className="flex items-center space-x-2">
              <Phone className="h-4 w-4 text-secondary-400" />
              <span className="text-secondary-900">{customer.phone}</span>
            </div>
          )}

          {customer.document && (
            <div className="flex items-center space-x-2">
              <FileText className="h-4 w-4 text-secondary-400" />
              <span className="text-secondary-900">{customer.document}</span>
            </div>
          )}

          {customer.address && (
            <div className="flex items-start space-x-2">
              <MapPin className="h-4 w-4 text-secondary-400 mt-1 flex-shrink-0" />
              <span className="text-secondary-900">{customer.address}</span>
            </div>
          )}

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-secondary-700 mb-2">Data de Criação</label>
              <span className="text-secondary-900">
                {new Date(customer.created_at).toLocaleDateString('pt-BR')}
              </span>
            </div>
            <div>
              <label className="block text-sm font-medium text-secondary-700 mb-2">Última Atualização</label>
              <span className="text-secondary-900">
                {new Date(customer.updated_at).toLocaleDateString('pt-BR')}
              </span>
            </div>
          </div>
        </div>

        <div className="flex justify-end mt-6">
          <Button variant="secondary" onClick={onClose}>
            Fechar
          </Button>
        </div>
      </div>
    </div>
  );
};

const CustomerAccountActions: React.FC<{ customer: Customer, onView: () => void, onHistory: () => void, onEdit: () => void, onDelete: () => void }> = ({ customer, onView, onHistory, onEdit, onDelete }) => {
  const { hasAccount, loading } = useCustomerAccountStatus(customer.id);
  const [isAdminEmail, setIsAdminEmail] = React.useState<boolean>(false);
  React.useEffect(() => {
    let mounted = true;
    async function checkAdmin() {
      if (!customer.email) return setIsAdminEmail(false);
      const { data, error } = await supabase
        .from('employees')
        .select('id')
        .filter('contact_info->>email', 'eq', customer.email)
        .eq('role', 'Admin');
      if (mounted) setIsAdminEmail(!!data && data.length > 0);
    }
    checkAdmin();
    return () => { mounted = false; };
  }, [customer.email]);
  return (
    <div className="flex items-center space-x-1">
      <Button onClick={onView} variant="secondary" size="sm">Ver</Button>
      <Button onClick={onHistory} variant="secondary" size="sm"><History className="h-4 w-4" /></Button>
      <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${isAdminEmail ? 'bg-primary-100 text-primary-800' : hasAccount ? 'bg-success-100 text-success-800' : 'bg-secondary-100 text-secondary-600'}`} title={isAdminEmail ? 'Conta admin' : hasAccount ? 'Conta ativa' : 'Sem conta ativa'}>
        {loading ? '...' : isAdminEmail ? 'admin' : hasAccount ? 'Conta ativa' : 'Sem conta ativa'}
      </span>
      <Button onClick={onEdit} variant="secondary" size="sm"><Edit2 className="h-4 w-4" /></Button>
      <Button onClick={onDelete} variant="error" size="sm"><Trash2 className="h-4 w-4" /></Button>
    </div>
  );
};

const Customers = () => {
  const { hasPermission } = useAuth();
  const { customers, loading, refetch, createCustomer, updateCustomer, deleteCustomer } = useCustomers();

  const [showModal, setShowModal] = useState(false);
  const [showViewModal, setShowViewModal] = useState(false);
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | undefined>(undefined);
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [showHistoryModal, setShowHistoryModal] = useState(false);

  // Check if user has permission to access this page
  const canAccess = hasPermission('admin') || hasPermission('employees');

  useEffect(() => {
    if (!canAccess) {
      // toast.error('Você não tem permissão para acessar esta página');
      return;
    }
    refetch();
  }, [canAccess, refetch]);

  const handleNewCustomer = () => {
    setSelectedCustomer(undefined);
    setShowModal(true);
  };

  const handleEditCustomer = (customer: Customer) => {
    console.log('✏️ Editando cliente:', customer);
    setSelectedCustomer(customer);
    setShowModal(true);
  };

  const handleViewCustomer = (customer: Customer) => {
    setSelectedCustomer(customer);
    setShowViewModal(true);
  };

  const handleSave = async (data: CustomerInsert | CustomerUpdate) => {
    try {
      if (selectedCustomer) {
        await updateCustomer(selectedCustomer.id, data as CustomerUpdate);
        toast.success('Cliente atualizado com sucesso!');
      } else {
        await createCustomer(data as CustomerInsert);
        toast.success('Cliente criado com sucesso!');
      }
      await refetch();
    } catch (error) {
      console.error('Error saving customer:', error);
      toast.error('Erro ao salvar cliente: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
    }
  };

  const handleDeleteCustomer = async (customer: Customer) => {
    if (confirm(`Tem certeza que deseja excluir o cliente "${customer.name}"?`)) {
      try {
        await deleteCustomer(customer.id, customer.email || undefined);
        toast.success('Cliente excluído com sucesso!');
        await refetch();
      } catch (error) {
        console.error('Error deleting customer:', error);
        toast.error('Erro ao excluir cliente: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
      }
    }
  };

  const handleShowHistory = (customer: Customer) => {
    setSelectedCustomer(customer);
    setShowHistoryModal(true);
  };

  const convertCustomerForModal = (customer: Customer | null) => {
    if (!customer) return null;
    return {
      id: customer.id,
      name: customer.name,
      email: customer.email || undefined,
      phone: customer.phone || undefined
    };
  };

  // Filter customers based on search term
  const filteredCustomers = customers.filter((customer) => {
    if (!searchTerm.trim()) return true;
    
    const term = searchTerm.toLowerCase().trim();
    return (
      customer.name.toLowerCase().includes(term) ||
      (customer.email && customer.email.toLowerCase().includes(term)) ||
      (customer.phone && customer.phone.includes(term)) ||
      (customer.document && customer.document.includes(term))
    );
  });

  // Pagination
  const totalPages = Math.ceil(filteredCustomers.length / ITEMS_PER_PAGE);
  const startIndex = (currentPage - 1) * ITEMS_PER_PAGE;
  const endIndex = startIndex + ITEMS_PER_PAGE;
  const paginatedCustomers = filteredCustomers.slice(startIndex, endIndex);

  if (!canAccess) {
    return null;
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-center">
          <Loader2 className="h-8 w-8 animate-spin mx-auto mb-4" />
          <p className="text-secondary-600">Carregando clientes...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-secondary-900">Administração de Clientes</h1>
          <p className="text-secondary-600">Gerencie os clientes do sistema</p>
        </div>
        <div className="flex flex-col sm:flex-row gap-2">
          <Button
            onClick={() => refetch()}
            variant="secondary"
            className="flex items-center"
          >
            <RefreshCw className="h-4 w-4 mr-2" />
            Atualizar
          </Button>
          <Button
            onClick={handleNewCustomer}
            variant="primary"
            className="flex items-center"
          >
            <Plus className="h-4 w-4 mr-2" />
            Novo Cliente
          </Button>
        </div>
      </div>

      {/* Search */}
      <div className="flex items-center gap-2">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
          <input
            type="text"
            placeholder="Buscar por nome, email, telefone, CPF/CNPJ..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
          />
        </div>
        {searchTerm && (
          <Button
            onClick={() => setSearchTerm('')}
            variant="secondary"
            size="sm"
          >
            Limpar
          </Button>
        )}
      </div>

      {/* Statistics */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-secondary-600">Total de Clientes</p>
                <p className="text-2xl font-bold text-secondary-900">{customers.length}</p>
              </div>
              <User className="h-8 w-8 text-secondary-400" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-secondary-600">Com Email</p>
                <p className="text-2xl font-bold text-primary-600">
                  {customers.filter(c => c.email).length}
                </p>
              </div>
              <Mail className="h-8 w-8 text-primary-400" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-secondary-600">Com Telefone</p>
                <p className="text-2xl font-bold text-success-600">
                  {customers.filter(c => c.phone).length}
                </p>
              </div>
              <Phone className="h-8 w-8 text-success-400" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Customers List */}
      <Card>
        <CardHeader>
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
            <h2 className="text-lg font-semibold text-secondary-900">
              Lista de Clientes ({filteredCustomers.length})
            </h2>
            {searchTerm && (
              <span className="text-sm text-secondary-500">
                {filteredCustomers.length} de {customers.length} resultados
              </span>
            )}
          </div>
        </CardHeader>
        <CardContent>
          {paginatedCustomers.length === 0 ? (
            <div className="text-center py-8">
              <User className="h-12 w-12 text-secondary-300 mx-auto mb-4" />
              <p className="text-secondary-600">
                {searchTerm ? 'Nenhum cliente encontrado com os filtros aplicados' : 'Nenhum cliente cadastrado'}
              </p>
            </div>
          ) : (
            <>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead className="bg-secondary-50">
                    <tr>
                      <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Nome</th>
                      <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Contato</th>
                      <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">CPF/CNPJ</th>
                      <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Endereço</th>
                      <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Ações</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-secondary-200">
                    {paginatedCustomers.map((customer) => (
                      <tr key={customer.id} className="hover:bg-secondary-50">
                        <td className="py-4 px-6">
                          <div className="flex items-center">
                            <User className="h-4 w-4 text-secondary-400 mr-2" />
                            <span className="font-medium text-secondary-900">{customer.name}</span>
                          </div>
                        </td>
                        <td className="py-4 px-6 text-sm text-secondary-600">
                          <div className="space-y-1">
                            {customer.email && (
                              <div className="flex items-center">
                                <Mail className="h-3 w-3 mr-1" />
                                {customer.email}
                              </div>
                            )}
                            {customer.phone && (
                              <div className="flex items-center">
                                <Phone className="h-3 w-3 mr-1" />
                                {customer.phone}
                              </div>
                            )}
                          </div>
                        </td>
                        <td className="py-4 px-6 text-sm text-secondary-600">
                          {customer.document || '-'}
                        </td>
                        <td className="py-4 px-6 text-sm text-secondary-600 max-w-xs">
                          <div className="truncate" title={customer.address || undefined}>
                            {customer.address || '-'}
                          </div>
                        </td>
                        <td className="py-4 px-6">
                          <CustomerAccountActions
                            customer={customer}
                            onView={() => handleViewCustomer(customer)}
                            onHistory={() => handleShowHistory(customer)}
                            onEdit={() => handleEditCustomer(customer)}
                            onDelete={() => handleDeleteCustomer(customer)}
                          />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* Pagination */}
              {totalPages > 1 && (
                <div className="flex justify-between items-center mt-4">
                  <div className="text-sm text-secondary-600">
                    Página {currentPage} de {totalPages} ({filteredCustomers.length} clientes)
                  </div>
                  <div className="flex gap-2">
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                      disabled={currentPage === 1}
                    >
                      Anterior
                    </Button>
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                      disabled={currentPage === totalPages}
                    >
                      Próxima
                    </Button>
                  </div>
                </div>
              )}
            </>
          )}
        </CardContent>
      </Card>

      {/* Modals */}
      <CustomerModal
        isOpen={showModal}
        onClose={() => setShowModal(false)}
        customer={selectedCustomer}
        onSave={handleSave}
      />

      <ViewCustomerModal
        isOpen={showViewModal}
        onClose={() => setShowViewModal(false)}
        customer={selectedCustomer}
      />

      <CustomerHistoryModal
        isOpen={showHistoryModal}
        onClose={() => setShowHistoryModal(false)}
        customer={convertCustomerForModal(selectedCustomer || null)}
      />
    </div>
  );
};

export default Customers; 