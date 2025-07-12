import React, { useState } from 'react';
import { useAuth } from '../../hooks/useAuth';
import { useEmployees } from '../../hooks/useEmployees';
import { Loader2, Users, Trash2, Edit, Shield, Search, RefreshCw } from 'lucide-react';
import UserRegistrationSection from './UserRegistrationSection';
import UserEditModal from './UserEditModal';
import { toast } from 'react-hot-toast';
import { getRoleLabel } from '../../types';

export default function AdminDashboard() {
  const { isAdmin } = useAuth();
  const { employees: users, loading, deleteEmployee, refetch } = useEmployees();
  const [searchTerm, setSearchTerm] = useState('');
  const [deletingUserId, setDeletingUserId] = useState<string | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const [editingUser, setEditingUser] = useState<any>(null);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);

  const deleteUser = async (userId: string) => {
    try {
      setDeletingUserId(userId);
      await deleteEmployee(userId);
      // Força atualização da lista após exclusão bem-sucedida
      setTimeout(() => {
        refetch();
      }, 100);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Erro desconhecido';
      toast.error(message);
    } finally {
      setDeletingUserId(null);
    }
  };

  const filteredUsers = users.filter(user => 
    user.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.contact_info?.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.role?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleDeleteUser = (userId: string) => {
    // Find the user to get their name
    const user = users.find(u => u.id === userId);
    if (!user) return;
    
    // Confirm deletion
    if (window.confirm(`Tem certeza que deseja excluir o usuário ${user.name}? Esta ação não pode ser desfeita.`)) {
      deleteUser(userId);
    }
  };

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const handleEditUser = (user: any) => {
    setEditingUser(user);
    setIsEditModalOpen(true);
  };

  const handleUserUpdated = () => {
    console.log('User updated, refreshing list...');
    refetch(); // Refresh the user list
  };

  const handleForceRefresh = async () => {
    try {
      setIsRefreshing(true);
      await refetch();
      toast.success('Lista atualizada com sucesso!');
    } catch (error) {
      console.error('Erro ao fazer refresh:', error);
      toast.error('Erro ao atualizar a lista');
    } finally {
      setIsRefreshing(false);
    }
  };

  if (!isAdmin) {
    return (
      <div className="flex flex-col items-center justify-center h-screen">
        <Shield className="h-16 w-16 text-error-500 mb-4" />
        <h1 className="text-2xl font-bold text-secondary-900 mb-2">Acesso Restrito</h1>
        <p className="text-secondary-600">Você não tem permissão para acessar esta página.</p>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto py-8 px-4 sm:px-6 lg:px-8">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-6">
        <div>
          <h1 className="text-2xl font-bold text-secondary-900">Painel de Administração</h1>
          <p className="text-secondary-600">Gerencie usuários e permissões do sistema</p>
        </div>
      </div>

      {/* User Registration Section */}
      <UserRegistrationSection onUserCreated={refetch} />

      {/* Search and Refresh */}
      <div className="mb-6 flex gap-4">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-secondary-400" />
          <input
            type="text"
            placeholder="Buscar por nome, email ou papel..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
          />
        </div>
        <button
          onClick={handleForceRefresh}
          disabled={isRefreshing}
          className="flex items-center gap-2 px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 disabled:opacity-50"
          title="Atualizar lista"
        >
          <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
          {isRefreshing ? 'Atualizando...' : 'Atualizar'}
        </button>
      </div>

      {/* Users list */}
      <div className="bg-white shadow rounded-lg overflow-hidden">
        {loading ? (
          <div className="flex justify-center items-center py-12">
            <Loader2 className="h-8 w-8 animate-spin text-primary-600" />
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-secondary-200">
              <thead className="bg-secondary-50">
                <tr>
                  <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-secondary-500 uppercase tracking-wider">
                    Usuário
                  </th>
                  <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-secondary-500 uppercase tracking-wider">
                    Papel
                  </th>
                  <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-secondary-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-secondary-500 uppercase tracking-wider">
                    Criado em
                  </th>
                  <th scope="col" className="px-6 py-3 text-right text-xs font-medium text-secondary-500 uppercase tracking-wider">
                    Ações
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-secondary-200">
                {filteredUsers.map((user) => (
                  <tr key={user.id} className="hover:bg-secondary-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <div className="h-10 w-10 flex-shrink-0 bg-primary-100 rounded-full flex items-center justify-center">
                          <span className="text-primary-600 font-medium text-sm">
                            {user.name?.charAt(0) || 'U'}
                          </span>
                        </div>
                        <div className="ml-4">
                          <div className="text-sm font-medium text-secondary-900">{user.name}</div>
                          <div className="text-sm text-secondary-500">{user.contact_info?.email}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                        user.role === 'Admin' ? 'bg-error-100 text-error-800' :
                        user.role === 'Inspector' ? 'bg-info-100 text-info-800' :
                        user.role === 'FineAdmin' ? 'bg-warning-100 text-warning-800' :
                        user.role === 'Sales' ? 'bg-success-100 text-success-800' :
                        'bg-secondary-100 text-secondary-800'
                      }`}>
                        {getRoleLabel(user.role) || user.role}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                        user.active 
                          ? 'bg-success-100 text-success-800' 
                          : 'bg-error-100 text-error-800'
                      }`}>
                        {user.active ? 'Ativo' : 'Inativo'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-secondary-500">
                      {new Date(user.created_at).toLocaleDateString('pt-BR')}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button
                        onClick={() => handleEditUser(user)}
                        className="text-primary-600 hover:text-primary-900 mr-4"
                        title="Editar usuário"
                      >
                        <Edit className="h-4 w-4" />
                      </button>

                      <button
                        onClick={() => handleDeleteUser(user.id)}
                        className="text-error-600 hover:text-error-900"
                        disabled={deletingUserId === user.id}
                        title="Excluir usuário"
                      >
                        {deletingUserId === user.id ? (
                          <Loader2 className="h-4 w-4 animate-spin" />
                        ) : (
                          <Trash2 className="h-4 w-4" />
                        )}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {!loading && filteredUsers.length === 0 && (
          <div className="flex flex-col items-center justify-center py-12">
            <Users className="h-12 w-12 text-secondary-400 mb-4" />
            <p className="text-secondary-600 text-lg">Nenhum usuário encontrado</p>
            <p className="text-secondary-500 text-sm">Tente ajustar sua busca</p>
          </div>
        )}
      </div>

      {/* User Edit Modal */}
      <UserEditModal
        isOpen={isEditModalOpen}
        onClose={() => setIsEditModalOpen(false)}
        user={editingUser}
        onUserUpdated={handleUserUpdated}
      />
    </div>
  );
}