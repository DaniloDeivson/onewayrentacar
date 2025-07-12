import React from 'react';
import { Link } from 'react-router-dom';
import { ShieldAlert, Home, ArrowLeft } from 'lucide-react';

export const Unauthorized: React.FC = () => {
  return (
    <div className="min-h-screen bg-secondary-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-lg p-8 max-w-md w-full text-center">
        <div className="flex justify-center mb-6">
          <div className="h-20 w-20 bg-error-100 rounded-full flex items-center justify-center">
            <ShieldAlert className="h-10 w-10 text-error-600" />
          </div>
        </div>
        
        <h1 className="text-2xl font-bold text-secondary-900 mb-2">Acesso Não Autorizado</h1>
        
        <p className="text-secondary-600 mb-6">
          Você não tem permissão para acessar esta página. Entre em contato com o administrador do sistema para solicitar acesso.
        </p>
        
        <div className="space-y-3">
          <Link to="/" className="block w-full py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500">
            <div className="flex items-center justify-center">
              <Home className="h-4 w-4 mr-2" />
              Voltar para o Dashboard
            </div>
          </Link>
          
          <button 
            onClick={() => window.history.back()} 
            className="block w-full py-2 px-4 border border-secondary-300 rounded-md shadow-sm text-sm font-medium text-secondary-700 bg-white hover:bg-secondary-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
          >
            <div className="flex items-center justify-center">
              <ArrowLeft className="h-4 w-4 mr-2" />
              Voltar para a página anterior
            </div>
          </button>
        </div>
      </div>
    </div>
  );
};

export default Unauthorized;