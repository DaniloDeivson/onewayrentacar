import React, { Fragment, useState, useEffect } from 'react';
import { Dialog, Transition } from '@headlessui/react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { X, Mail, Lock, Eye, EyeOff, LogIn, Loader2 } from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';
import { useNavigate } from 'react-router-dom';

const loginSchema = z.object({
  email: z
    .string()
    .min(1, 'Email é obrigatório')
    .email('Email deve ser válido'),
  password: z
    .string()
    .min(6, 'Senha deve ter pelo menos 6 caracteres')
    .max(50, 'Senha deve ter no máximo 50 caracteres'),
});

type LoginFormData = z.infer<typeof loginSchema>;

interface LoginModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const LoginModal: React.FC<LoginModalProps> = ({ isOpen, onClose }) => {
  const { signIn, isLoading, error } = useAuth();
  const navigate = useNavigate();
  const [showPassword, setShowPassword] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors },
    reset,
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
    mode: 'onTouched',
  });

  // Redirect when user is authenticated
  useEffect(() => {
    if (signIn.user && isOpen) {
      navigate('/', { replace: true });
      onClose();
    }
  }, [signIn.user, isOpen, onClose, navigate]);

  // Reset form when modal opens
  useEffect(() => {
    if (isOpen) {
      reset({
        email: '',
        password: '',
      });
      setErrorMsg(null);
      setIsSubmitting(false);
    }
  }, [isOpen, reset]);

  // Update error message when auth error changes
  useEffect(() => {
    if (error) {
      setErrorMsg(error);
      setIsSubmitting(false);
    }
  }, [error]);

  const onSubmit = async (data: LoginFormData) => {
    if (isSubmitting) return;
    
    try {
      setIsSubmitting(true);
      setErrorMsg(null);
      
      await signIn(data.email, data.password);
    } catch (error) {
      setErrorMsg('Erro inesperado ao tentar fazer login.');
      console.error('Erro no submit do login:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleClose = () => {
    if (!isSubmitting && !isLoading) {
      reset();
      setErrorMsg(null);
      setIsSubmitting(false);
      onClose();
    }
  };

  const isLoadingModal = isSubmitting || isLoading;

  return (
    <Transition appear show={isOpen} as={Fragment}>
      <Dialog as="div" className="relative z-50" onClose={handleClose}>
        <Transition.Child
          as={Fragment}
          enter="ease-out duration-300"
          enterFrom="opacity-0"
          enterTo="opacity-100"
          leave="ease-in duration-200"
          leaveFrom="opacity-100"
          leaveTo="opacity-0"
        >
          <div className="fixed inset-0 bg-black/60 backdrop-blur-sm" />
        </Transition.Child>

        <div className="fixed inset-0 overflow-y-auto">
          <div className="flex min-h-full items-center justify-center p-4 text-center">
            <Transition.Child
              as={Fragment}
              enter="ease-out duration-300"
              enterFrom="opacity-0 scale-95"
              enterTo="opacity-100 scale-100"
              leave="ease-in duration-200"
              leaveFrom="opacity-100 scale-100"
              leaveTo="opacity-0 scale-95"
            >
              <Dialog.Panel className="w-full max-w-md transform overflow-hidden rounded-2xl bg-white shadow-2xl transition-all">
                <div className="relative bg-gradient-to-br from-blue-50 to-indigo-100 px-6 py-8">
                  <button
                    onClick={handleClose}
                    disabled={isLoadingModal}
                    className="absolute right-4 top-4 rounded-full p-2 text-gray-400 hover:bg-white/50 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200"
                  >
                    <X className="h-5 w-5" />
                  </button>

                  <div className="text-center">
                    <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-gradient-to-r from-blue-500 to-indigo-600 mb-4">
                      <LogIn className="h-8 w-8 text-white" />
                    </div>
                    <Dialog.Title
                      as="h3"
                      className="text-2xl font-bold text-gray-900 mb-2"
                    >
                      Bem-vindo de volta
                    </Dialog.Title>
                    <p className="text-gray-600">
                      Entre na sua conta para continuar
                    </p>
                  </div>
                </div>

                <div className="px-6 py-8">
                  <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
                    {errorMsg && (
                      <div className="rounded-lg bg-red-50 border border-red-200 p-4">
                        <div className="flex">
                          <div className="ml-3">
                            <h3 className="text-sm font-medium text-red-800">
                              {errorMsg}
                            </h3>
                          </div>
                        </div>
                      </div>
                    )}

                    <div className="space-y-1">
                      <label htmlFor="email" className="block text-sm font-medium text-gray-700">
                        Email
                      </label>
                      <div className="relative">
                        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                          <Mail className="h-5 w-5 text-gray-400" />
                        </div>
                        <input
                          {...register('email')}
                          type="email"
                          id="email"
                          className={`
                            block w-full pl-10 pr-3 py-3 border rounded-lg shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors duration-200
                            ${errors.email 
                              ? 'border-red-300 bg-red-50' 
                              : 'border-gray-300 bg-white hover:border-gray-400'
                            }
                          `}
                          placeholder="seu@email.com"
                          disabled={isLoadingModal}
                          autoComplete="email"
                        />
                      </div>
                      {errors.email && (
                        <p className="text-sm text-red-600 mt-1">{errors.email.message}</p>
                      )}
                    </div>

                    <div className="space-y-1">
                      <label htmlFor="password" className="block text-sm font-medium text-gray-700">
                        Senha
                      </label>
                      <div className="relative">
                        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                          <Lock className="h-5 w-5 text-gray-400" />
                        </div>
                        <input
                          {...register('password')}
                          type={showPassword ? 'text' : 'password'}
                          id="password"
                          className={`
                            block w-full pl-10 pr-10 py-3 border rounded-lg shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors duration-200
                            ${errors.password 
                              ? 'border-red-300 bg-red-50' 
                              : 'border-gray-300 bg-white hover:border-gray-400'
                            }
                          `}
                          placeholder="Sua senha"
                          disabled={isLoadingModal}
                          autoComplete="current-password"
                        />
                        <button
                          type="button"
                          onClick={() => setShowPassword(!showPassword)}
                          disabled={isLoadingModal}
                          className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-200"
                        >
                          {showPassword ? (
                            <EyeOff className="h-5 w-5" />
                          ) : (
                            <Eye className="h-5 w-5" />
                          )}
                        </button>
                      </div>
                      {errors.password && (
                        <p className="text-sm text-red-600 mt-1">{errors.password.message}</p>
                      )}
                    </div>

                    <button
                      type="submit"
                      disabled={isLoadingModal}
                      className="w-full flex justify-center items-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-200"
                    >
                      {isLoadingModal ? (
                        <>
                          <Loader2 className="animate-spin h-5 w-5 mr-2" />
                          Entrando...
                        </>
                      ) : (
                        'Entrar'
                      )}
                    </button>
                  </form>
                </div>
              </Dialog.Panel>
            </Transition.Child>
          </div>
        </div>
      </Dialog>
    </Transition>
  );
};

export default LoginModal;