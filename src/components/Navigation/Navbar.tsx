import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Car, Menu, X } from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';
import UserMenu from '../Layout/UserMenu';
import AuthModal from '../Auth/AuthModal';
import { ROLE_PERMISSIONS } from '../../config/permissions';
import { DRIVER_ALLOWED_ROUTES } from '../../constants/driverRoutes';

interface NavItemProps {
  to: string;
  children: React.ReactNode;
  active?: boolean;
}

const NavItem: React.FC<NavItemProps> = ({ to, children, active }) => (
  <Link
    to={to}
    className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors duration-150 ${
      active
        ? 'bg-primary-100 text-primary-900'
        : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
    }`}
  >
    {children}
  </Link>
);

export default function Navbar() {
  const location = useLocation();
  const { user } = useAuth();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [authModalOpen, setAuthModalOpen] = useState(false);

  // Definir os itens de menu com suas rotas e rótulos
  const menuItems = [
    { path: '/dashboard', label: 'Dashboard', permission: 'dashboard' },
    { path: '/frota', label: 'Frota', permission: 'fleet' },
    { path: '/contratos', label: 'Contratos', permission: 'contracts' },
    { path: '/custos', label: 'Custos', permission: 'costs' },
    { path: '/multas', label: 'Multas', permission: 'fines' },
    { path: '/manutencao', label: 'Manutenção', permission: 'maintenance' },
    { path: '/inspecoes', label: 'Inspeções', permission: 'inspections' },
    { path: '/combustivel', label: 'Combustível', permission: 'fuel' },
    { path: '/financeiro', label: 'Financeiro', permission: 'finance' },
    { path: '/estoque', label: 'Estoque', permission: 'inventory' },
    { path: '/fornecedores', label: 'Fornecedores', permission: 'suppliers' },
    { path: '/funcionarios', label: 'Funcionários', permission: 'employees' },
    { path: '/estatisticas', label: 'Estatísticas', permission: 'statistics' },
  ];

  // Para drivers, usar diretamente as rotas fixas
  const finalMenuItems = user 
    ? (user.role === 'Driver' 
        ? DRIVER_ALLOWED_ROUTES 
        : user.role === 'Admin' 
          ? menuItems 
          : menuItems.filter(item => ROLE_PERMISSIONS[user.role].includes(item.path))
      )
    : [];

  console.log('🔍 DEBUG NAVBAR:');
  console.log('user.role:', user?.role);
  console.log('DRIVER_ALLOWED_ROUTES:', DRIVER_ALLOWED_ROUTES);
  console.log('finalMenuItems:', finalMenuItems);
  console.log('user?.permissions:', user?.permissions);

  return (
    <nav className="bg-white shadow-sm">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex items-center">
            <Link to="/" className="flex items-center">
              <Car className="h-8 w-8 text-primary-600" />
              <span className="ml-2 text-xl font-bold text-gray-900">
                OneWay
              </span>
            </Link>
          </div>

          {/* Menu Desktop */}
          <div className="hidden md:flex items-center space-x-4">
            {finalMenuItems.map((item) => (
              <NavItem
                key={item.path}
                to={item.path}
                active={location.pathname === item.path}
              >
                {item.label}
              </NavItem>
            ))}
            {user ? (
              <UserMenu />
            ) : (
              <button
                onClick={() => setAuthModalOpen(true)}
                className="ml-4 px-4 py-2 rounded-lg text-sm font-medium text-white bg-primary-600 hover:bg-primary-700"
              >
                Entrar
              </button>
            )}
          </div>

          {/* Menu Mobile */}
          <div className="flex items-center md:hidden">
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100"
            >
              {mobileMenuOpen ? (
                <X className="h-6 w-6" />
              ) : (
                <Menu className="h-6 w-6" />
              )}
            </button>
          </div>
        </div>

        {/* Mobile Menu Panel */}
        {mobileMenuOpen && (
          <div className="md:hidden">
            <div className="pt-2 pb-3 space-y-1">
              {finalMenuItems.map((item) => {
                console.log('🔍 Mobile menu item:', item);
                return (
                  <Link
                    key={item.path}
                    to={item.path}
                    className={`block px-3 py-2 rounded-md text-base font-medium ${
                      location.pathname === item.path
                        ? 'bg-primary-100 text-primary-900'
                        : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
                    }`}
                    onClick={() => setMobileMenuOpen(false)}
                  >
                    {item.label}
                  </Link>
                );
              })}
            </div>
            {!user && (
              <div className="pt-4 pb-3 border-t border-gray-200">
                <button
                  onClick={() => {
                    setMobileMenuOpen(false);
                    setAuthModalOpen(true);
                  }}
                  className="block w-full px-4 py-2 text-center text-sm font-medium text-white bg-primary-600 hover:bg-primary-700 rounded-lg"
                >
                  Entrar
                </button>
              </div>
            )}
          </div>
        )}
      </div>

      <AuthModal isOpen={authModalOpen} onClose={() => setAuthModalOpen(false)} />
    </nav>
  );
}