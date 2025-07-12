import React from 'react';
import { X } from 'lucide-react';
import RegisterForm from './RegisterForm';

interface RegistrationModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function RegistrationModal({ isOpen, onClose }: RegistrationModalProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <h2 className="text-lg lg:text-xl font-semibold text-secondary-900">
            Cadastre-se no Sistema
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            <X className="h-6 w-6" />
          </button>
        </div>

        <div className="mb-6">
          <p className="text-secondary-600">
            Preencha o formulário abaixo para criar sua conta no sistema OneWay Rent A Car.
            Após o cadastro, você poderá acessar o sistema com seu email e senha.
          </p>
        </div>

        <RegisterForm 
          onSuccess={onClose}
          onCancel={onClose}
        />
      </div>
    </div>
  );
}