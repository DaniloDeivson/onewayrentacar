import React, { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Loader2, UserPlus } from 'lucide-react';
import toast from 'react-hot-toast';
import { DEFAULT_TENANT_ID } from '../../lib/supabase';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';
import type { Employee } from '../../types/database';
import { ROLE_LABELS } from '../../types';
import { ROLES_UNICOS } from '../../types';

// Roles públicas permitidas para registro
const ROLES_PUBLICAS = [
  'Sales',
  'Mechanic',
  'Inspector',
  'User',
  'Driver'
];

// Form validation schema
const registerSchema = z.object({
  name: z.string().min(3, 'O nome deve ter pelo menos 3 caracteres'),
  email: z.string().email('Email inválido'),
  password: z.string().min(6, 'A senha deve ter pelo menos 6 caracteres'),
  confirmPassword: z.string().min(6, 'A senha deve ter pelo menos 6 caracteres'),
  role: z.string().min(1, 'Selecione uma função'),
  phone: z.string().optional(),
}).refine((data) => data.password === data.confirmPassword, {
  message: "As senhas não coincidem",
  path: ["confirmPassword"],
});

type RegisterFormValues = z.infer<typeof registerSchema>;

interface RegisterFormProps {
  onSuccess?: () => void;
  onCancel?: () => void;
  initialData?: RegisterFormValues;
  isAdminPanel?: boolean;
}

export default function RegisterForm({ onSuccess, initialData, isAdminPanel }: RegisterFormProps) {
  const { signUp, loading, error } = useAuth();
  const [selectedRoles, setSelectedRoles] = useState<string[]>([]);
  const navigate = useNavigate();

  const { register, handleSubmit, formState: { errors }, watch, reset } = useForm<RegisterFormValues>({
    resolver: zodResolver(registerSchema),
    defaultValues: initialData || {
      name: '',
      email: '',
      password: '',
      confirmPassword: '',
      role: '', // Papel padrão
      phone: '',
    },
  });

  const watchedRole = watch('role');

  // Update selected roles when primary role changes
  useEffect(() => {
    if (watchedRole && !selectedRoles.includes(watchedRole)) {
      setSelectedRoles(prev => [...prev, watchedRole]);
    }
  }, [watchedRole, selectedRoles]);



  // Reset form when initialData changes
  useEffect(() => {
    if (initialData) {
      reset(initialData);
    }
  }, [initialData, reset]);

  const onSubmit = async (data: RegisterFormValues) => {
    try {
      const userData: Partial<Employee> = {
        name: data.name,
        contact_info: { email: data.email.toLowerCase().trim(), phone: data.phone || undefined },
        role: data.role as 'Admin' | 'Sales' | 'Mechanic' | 'User' | 'Driver' | 'Inspector',
        tenant_id: DEFAULT_TENANT_ID,
        roles_extra: selectedRoles.filter(r => r !== data.role),
        active: true,
        permissions: {
          admin: false,
          costs: data.role === 'Driver',
          fines: false,
          fleet: data.role === 'Driver',
          finance: false,
          contracts: false,
          dashboard: true,
          employees: false,
          inventory: false,
          purchases: false,
          suppliers: false,
          statistics: false,
          inspections: data.role === 'Driver',
          maintenance: false
        }
      };

      const result = await signUp(data.email, data.password, userData);
      if (result?.success) {
        toast.success(result.message);
        reset();
        if (onSuccess) {
          onSuccess();
        } else {
          navigate('/login');
        }
      }
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'Erro ao criar conta';
      console.error('Error registering user:', err);
      toast.error(errorMessage);
    }
  };

  if (error) {
    return (
      <div className="rounded-md bg-red-50 p-4">
        <div className="flex">
          <div className="ml-3">
            <h3 className="text-sm font-medium text-red-800">
              Erro ao fazer registro
            </h3>
            <div className="mt-2 text-sm text-red-700">
              <p>{error}</p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
            <form className="space-y-4" onSubmit={handleSubmit(onSubmit)}>
          <div className="space-y-4">
            <div>
              <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-1">
                Nome completo
              </label>
              <input
                id="name"
                type="text"
                required
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                placeholder="Digite o nome completo"
                {...register('name')}
              />
              {errors.name && (
                <p className="mt-1 text-sm text-red-600">{errors.name.message}</p>
              )}
            </div>
            
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
                Email
              </label>
              <input
                id="email"
                type="email"
                autoComplete="email"
                required
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                placeholder="Digite o email"
                {...register('email')}
              />
              {errors.email && (
                <p className="mt-1 text-sm text-red-600">{errors.email.message}</p>
              )}
            </div>
            
            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-1">
                Senha
              </label>
              <input
                id="password"
                type="password"
                autoComplete="new-password"
                required
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                placeholder="Digite a senha"
                {...register('password')}
              />
              {errors.password && (
                <p className="mt-1 text-sm text-red-600">{errors.password.message}</p>
              )}
            </div>
            
            <div>
              <label htmlFor="confirmPassword" className="block text-sm font-medium text-gray-700 mb-1">
                Confirmar senha
              </label>
              <input
                id="confirmPassword"
                type="password"
                autoComplete="new-password"
                required
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                placeholder="Confirme a senha"
                {...register('confirmPassword')}
              />
              {errors.confirmPassword && (
                <p className="mt-1 text-sm text-red-600">{errors.confirmPassword.message}</p>
              )}
            </div>
            
            <div>
              <label htmlFor="phone" className="block text-sm font-medium text-gray-700 mb-1">
                Telefone (opcional)
              </label>
              <input
                id="phone"
                type="tel"
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                placeholder="(00) 00000-0000"
                {...register('phone')}
              />
            </div>
            
            <div>
              <label htmlFor="role" className="block text-sm font-medium text-gray-700 mb-1">
                Função principal
              </label>
              <select
                id="role"
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                {...register('role')}
              >
                <option value="">Selecione uma função</option>
                {(isAdminPanel ? ROLES_UNICOS : ROLES_PUBLICAS).map(key => (
                  <option key={key} value={key}>{ROLE_LABELS[key]}</option>
                ))}
              </select>
              {errors.role && (
                <p className="mt-1 text-sm text-red-600">{errors.role.message}</p>
              )}
            </div>
          </div>

          <div className="pt-2">
            <button
              type="submit"
              disabled={loading}
              className={`group relative w-full flex justify-center py-3 px-4 border border-transparent text-sm font-medium rounded-lg text-white transition-colors duration-200 ${
                loading
                  ? 'bg-indigo-400 cursor-not-allowed'
                  : 'bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500'
              }`}
            >
              {loading ? (
                <div className="flex items-center">
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Registrando...
                </div>
              ) : (
                <div className="flex items-center">
                  <UserPlus className="h-4 w-4 mr-2" />
                  Registrar
                </div>
              )}
            </button>
          </div>
        </form>
      );
    }