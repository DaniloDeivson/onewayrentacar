import React, { useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import { Navigate, useNavigate } from 'react-router-dom';
import { Dialog } from '@headlessui/react';
import { UserPlus, X } from 'lucide-react';
import RegisterForm from '../components/Auth/RegisterForm';

export default function Register() {
  const { isAdmin, user } = useAuth();
  const navigate = useNavigate();
  const [isOpen, setIsOpen] = useState(true);

  // If not admin, redirect to unauthorized
  if (user && !isAdmin) {
    return <Navigate to="/unauthorized" replace />;
  }

  const handleClose = () => {
    setIsOpen(false);
    setTimeout(() => navigate(-1), 200); // Volta para a página anterior
  };

  return (
    <Dialog open={isOpen} onClose={handleClose} className="relative z-50">
      {/* Fundo escurecido */}
      <div className="fixed inset-0 bg-black/60 backdrop-blur-sm" aria-hidden="true" />
      <div className="fixed inset-0 flex items-center justify-center p-4">
        <Dialog.Panel className="w-full max-w-lg transform overflow-hidden rounded-2xl bg-white shadow-2xl transition-all">
          {/* Topo gradiente e botão fechar */}
          <div className="relative bg-gradient-to-br from-blue-50 to-indigo-100 px-6 py-6">
            <button
              onClick={handleClose}
              className="absolute right-4 top-4 rounded-full p-2 text-gray-400 hover:bg-white/50 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-all duration-200"
            >
              <X className="h-5 w-5" />
            </button>
            <div className="text-center">
              <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-gradient-to-r from-blue-500 to-indigo-600 mb-3">
                <UserPlus className="h-7 w-7 text-white" />
              </div>
              <Dialog.Title as="h3" className="text-xl font-bold text-gray-900 mb-1">
                Criar nova conta
              </Dialog.Title>
              <p className="text-sm text-gray-600">
                Preencha o formulário para cadastrar um novo usuário no sistema
              </p>
            </div>
          </div>
          {/* Formulário */}
          <div className="px-6 py-6">
            <RegisterForm onSuccess={() => navigate('/admin')} />
          </div>
        </Dialog.Panel>
      </div>
    </Dialog>
  );
}