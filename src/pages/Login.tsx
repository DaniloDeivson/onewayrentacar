import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Car, UserPlus } from 'lucide-react';
import { useAuth } from '../hooks/useAuth';
import LoginModal from '../components/Auth/LoginModal';
import RegistrationModal from '../components/Auth/RegistrationModal';

export const Login: React.FC = () => {
  const [isLoginModalOpen, setIsLoginModalOpen] = useState(true);
  const [isRegistrationModalOpen, setIsRegistrationModalOpen] = useState(false);
  const { user, loading } = useAuth();
  const navigate = useNavigate();

  // If user is already logged in, redirect to dashboard
  useEffect(() => {
    // Only redirect if we have finished loading and have a user
    if (!loading && user) {
      navigate('/', { replace: true });
    }
  }, [user, loading, navigate]);

  // Show loading state while checking auth
  if (loading) {
    return (
      <div className="min-h-screen bg-secondary-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      </div>
    );
  }

  // Don't render login form if user is already authenticated
  if (user) {
    return null;
  }

  const handleOpenRegistration = () => {
    setIsLoginModalOpen(false);
    setIsRegistrationModalOpen(true);
  };

  return (
    <div className="min-h-screen bg-secondary-50 flex flex-col">
      {/* Simple header */}
      <header className="bg-secondary-900 text-white py-4">
        <div className="container mx-auto px-4 flex items-center">
          <Car className="h-8 w-8 text-primary-400 mr-3" />
          <div>
            <h1 className="font-bold text-lg">OneWay</h1>
            <p className="text-secondary-400 text-xs">Rent A Car</p>
          </div>
        </div>
      </header>

      {/* Main content */}
      <main className="flex-1 flex items-center justify-center p-4">
        <div className="max-w-md w-full bg-white rounded-lg shadow-lg overflow-hidden">
          <div className="p-8">
            <div className="text-center mb-8">
              <div className="flex justify-center mb-4">
                <div className="h-16 w-16 bg-primary-100 rounded-full flex items-center justify-center">
                  <Car className="h-8 w-8 text-primary-600" />
                </div>
              </div>
              <h1 className="text-2xl font-bold text-secondary-900">OneWay Rent A Car</h1>
              <p className="text-secondary-600 mt-2">Sistema de Gestão de Frota</p>
            </div>

            <div className="space-y-4">
              <button
                onClick={() => setIsLoginModalOpen(true)}
                className="w-full flex justify-center items-center py-3 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
              >
                Entrar no Sistema
              </button>

              <button
                onClick={handleOpenRegistration}
                className="w-full flex justify-center items-center py-3 px-4 border border-secondary-300 rounded-md shadow-sm text-sm font-medium text-secondary-700 bg-white hover:bg-secondary-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
              >
                <UserPlus className="h-4 w-4 mr-2" />
                Criar Nova Conta
              </button>
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="bg-secondary-900 text-secondary-400 py-4">
        <div className="container mx-auto px-4 text-center text-sm">
          &copy; {new Date().getFullYear()} OneWay Rent A Car. Todos os direitos reservados.
        </div>
      </footer>

      {/* Login Modal */}
      {!loading && (
        <>
          <LoginModal 
            isOpen={isLoginModalOpen} 
            onClose={() => setIsLoginModalOpen(false)} 
          />

          {/* Registration Modal */}
          <RegistrationModal
            isOpen={isRegistrationModalOpen}
            onClose={() => setIsRegistrationModalOpen(false)}
          />
        </>
      )}
    </div>
  );
};

export default Login;