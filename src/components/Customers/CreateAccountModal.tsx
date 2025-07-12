import React, { useState } from 'react';
import { X, User, Mail, Lock, Shield, Loader2 } from 'lucide-react';
import { Button } from '../UI/Button';
import { supabase } from '../../lib/supabase';
import toast from 'react-hot-toast';
import { useCustomerAccountStatus } from '../../hooks/useCustomerAccountStatus';

interface CreateAccountModalProps {
  isOpen: boolean;
  onClose: () => void;
  customer: {
    id: string;
    name: string;
    email?: string;
    phone?: string;
  } | null;
}

const roleOptions = [
  { value: 'Driver', label: 'Motorista', description: 'Acesso para consultar veículos e fazer inspeções' },
  { value: 'User', label: 'Usuário Básico', description: 'Acesso limitado para consultar informações' }
];

export const CreateAccountModal: React.FC<CreateAccountModalProps> = ({
  isOpen,
  onClose,
  customer
}) => {
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    email: customer?.email || '',
    password: '',
    confirmPassword: '',
    role: 'Driver',
    sendInvite: true
  });
  const { hasAccount, loading: loadingAccount } = useCustomerAccountStatus(customer?.id);

  if (!isOpen || !customer) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!formData.email) {
      toast.error('Email é obrigatório');
      return;
    }

    if (formData.password !== formData.confirmPassword) {
      toast.error('Senhas não coincidem');
      return;
    }

    if (formData.password.length < 6) {
      toast.error('Senha deve ter pelo menos 6 caracteres');
      return;
    }

    setLoading(true);
    try {
      // NOVO: Verificar se já existe um admin com esse e-mail
      const { data: existingAdmins, error: adminCheckError } = await supabase
        .from('employees')
        .select('id, name, role, email')
        .eq('email', formData.email)
        .eq('role', 'Admin');
      if (adminCheckError) throw adminCheckError;
      if (existingAdmins && existingAdmins.length > 0) {
        toast.error('Já existe um usuário Admin com este e-mail. Não é permitido criar outra conta para este e-mail.');
        setLoading(false);
        return;
      }

      // 1. Criar usuário no Supabase Auth
      const { data: authData, error: authError } = await supabase.auth.admin.createUser({
        email: formData.email,
        password: formData.password,
        email_confirm: true,
        user_metadata: {
          name: customer.name,
          customer_id: customer.id
        }
      });

      if (authError) throw authError;

      // 2. Criar registro na tabela employees
      const { error: employeeError } = await supabase
        .from('employees')
        .insert({
          id: authData.user.id,
          name: customer.name,
          role: formData.role,
          email: formData.email,
          phone: customer.phone,
          employee_code: `CUST_${customer.id.substring(0, 8)}`,
          active: true,
          permissions: {
            customer_portal: true,
            view_own_data: true,
            ...(formData.role === 'Driver' && {
              driver_inspections: true,
              view_assigned_vehicles: true
            })
          },
          tenant_id: '00000000-0000-0000-0000-000000000001'
        });

      if (employeeError) throw employeeError;

      // 3. Se selecionado, enviar convite por email
      if (formData.sendInvite) {
        const { error: inviteError } = await supabase.auth.admin.inviteUserByEmail(
          formData.email,
          {
            data: {
              name: customer.name,
              customer_id: customer.id,
              role: formData.role
            }
          }
        );

        if (inviteError) {
          console.warn('Erro ao enviar convite:', inviteError);
          // Não falha a operação se o convite falhar
        }
      }

      toast.success('Conta criada com sucesso!');
      onClose();
      
    } catch (error) {
      console.error('Erro ao criar conta:', error);
      toast.error(error instanceof Error ? error.message : 'Erro ao criar conta');
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value, type } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? (e.target as HTMLInputElement).checked : value
    }));
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg w-full max-w-md max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center p-6 border-b">
          <div>
            <h2 className="text-xl font-semibold text-secondary-900">
              Criar Conta de Usuário
            </h2>
            <p className="text-sm text-secondary-600 mt-1">
              Para {customer.name}
            </p>
            <span className={`inline-flex items-center mt-2 px-2 py-0.5 rounded text-xs font-medium ${hasAccount ? 'bg-success-100 text-success-800' : 'bg-secondary-100 text-secondary-600'}`} title={hasAccount ? 'Conta ativa' : 'Sem conta ativa'}>
              {loadingAccount ? '...' : hasAccount ? 'Conta ativa' : 'Sem conta'}
            </span>
          </div>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            <X className="h-5 w-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              <Mail className="h-4 w-4 inline mr-2" />
              Email *
            </label>
            <input
              type="email"
              name="email"
              value={formData.email}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              required
              placeholder="email@exemplo.com"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              <Lock className="h-4 w-4 inline mr-2" />
              Senha *
            </label>
            <input
              type="password"
              name="password"
              value={formData.password}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              required
              minLength={6}
              placeholder="Mínimo 6 caracteres"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              <Lock className="h-4 w-4 inline mr-2" />
              Confirmar Senha *
            </label>
            <input
              type="password"
              name="confirmPassword"
              value={formData.confirmPassword}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              required
              minLength={6}
              placeholder="Digite a senha novamente"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              <Shield className="h-4 w-4 inline mr-2" />
              Tipo de Acesso *
            </label>
            <select
              name="role"
              value={formData.role}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              required
            >
              {roleOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
            
            {/* Descrição do papel selecionado */}
            <div className="mt-2 p-3 bg-info-50 border border-info-200 rounded-lg">
              <p className="text-sm text-info-700">
                <strong>{roleOptions.find(r => r.value === formData.role)?.label}:</strong>{' '}
                {roleOptions.find(r => r.value === formData.role)?.description}
              </p>
            </div>
          </div>

          <div className="flex items-center">
            <input
              type="checkbox"
              name="sendInvite"
              checked={formData.sendInvite}
              onChange={handleChange}
              className="h-4 w-4 text-primary-600 focus:ring-primary-500 border-secondary-300 rounded"
            />
            <label className="ml-2 block text-sm text-secondary-700">
              Enviar convite por email
            </label>
          </div>

          <div className="bg-warning-50 border border-warning-200 rounded-lg p-3">
            <p className="text-sm text-warning-700">
              <strong>Atenção:</strong> O cliente poderá acessar o sistema com as permissões do tipo de acesso selecionado.
            </p>
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
                  Criando...
                </>
              ) : (
                <>
                  <User className="h-4 w-4 mr-2" />
                  Criar Conta
                </>
              )}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}; 