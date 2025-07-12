import React, { useMemo } from 'react';
import { NavLink } from 'react-router-dom';
import {
  Home,
  Car,
  DollarSign,
  Wrench,
  Package,
  AlertTriangle,
  Building2,
  BarChart3,
  Settings,
  UserCheck,
  Search,
  X,
  ClipboardCheck,
  ShoppingBag,
  Wallet,
  Receipt,
  CreditCard,
  FileText,
  UserPlus,
  FileCheck
} from 'lucide-react';
import { UserMenu } from './UserMenu';
import { useAuth } from '../../hooks/useAuth';
import { DRIVER_ALLOWED_ROUTES } from '../../constants/driverRoutes';

const navigationItems = [
  { name: 'Dashboard', href: '/', icon: Home, permission: 'dashboard' },
  { name: 'Frota', href: '/frota', icon: Car, permission: 'fleet' },
  { name: 'Custos', href: '/custos', icon: DollarSign, permission: 'costs' },
  { name: 'Financeiro', href: '/financeiro', icon: Wallet, permission: 'finance' },
  { name: 'Notas Fiscais', href: '/notas', icon: Receipt, permission: 'finance' },
  { name: 'Cobrança', href: '/cobranca', icon: CreditCard, permission: 'cobranca' },
  { name: 'Manutenção', href: '/manutencao', icon: Wrench, permission: 'maintenance' },
  { name: 'Estoque', href: '/estoque', icon: Package, permission: 'inventory' },
  { name: 'Contratos', href: '/contratos', icon: FileCheck, permission: 'contracts' },
  { name: 'Clientes', href: '/clientes', icon: UserPlus, permission: 'admin' },
  { name: 'Controle de Pátio', href: '/inspecoes', icon: ClipboardCheck, permission: 'inspections' },
  { name: 'Multas', href: '/multas', icon: AlertTriangle, permission: 'fines' },
  { name: 'Fornecedores', href: '/fornecedores', icon: Building2, permission: 'suppliers' },
  { name: 'Compras', href: '/compras', icon: ShoppingBag, permission: 'purchases' },
  { name: 'Estatísticas', href: '/estatisticas', icon: BarChart3, permission: 'statistics' },
  { name: 'Admin Panel', href: '/admin', icon: Settings, permission: 'admin' },
  { name: 'Funcionários', href: '/funcionarios', icon: UserCheck, permission: 'employees' },
  { name: 'Registros', href: '/registros', icon: FileText, permission: 'registros' },
];

interface SidebarProps {
  onClose?: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({ onClose }) => {
  const { hasPermission, isAdmin, user } = useAuth();
  
  // Memoizar a lista de navegação filtrada para evitar re-renders
  const filteredNavItems = useMemo(() => {
    // Para drivers, usar as rotas fixas
    if (user?.role === 'Driver') {
      const allowedPaths = DRIVER_ALLOWED_ROUTES.map(route => route.path);
      return navigationItems.filter(item => allowedPaths.includes(item.href));
    }
    
    // Para outros papéis, usar a lógica normal
    return navigationItems.filter(item => {
      // Admin sempre vê tudo
      if (isAdmin) return true;
      // Se não houver permissão definida, mostra para todos
      if (!item.permission) return true;
      // Checa permissão específica
      return hasPermission(item.permission);
    });
  }, [hasPermission, isAdmin, user?.role]);

  // Logs de depuração
  console.log('🔍 DEBUG SIDEBAR:');
  console.log('user.role:', user?.role);
  console.log('DRIVER_ALLOWED_ROUTES:', DRIVER_ALLOWED_ROUTES);
  console.log('filteredNavItems:', filteredNavItems);

  return (
    <div className="flex flex-col w-64 bg-secondary-900 h-screen sticky top-0 overflow-y-auto">
      {/* Logo */}
      <div className="flex items-center justify-between px-6 py-8">
        <div className="flex items-center">
          <Car className="h-8 w-8 text-primary-400" />
          <div className="ml-3">
            <h1 className="text-white font-bold text-lg">OneWay</h1>
            <p className="text-secondary-400 text-sm">Rent A Car</p>
          </div>
        </div>
        
        {/* Close button for mobile */}
        {onClose && (
          <button
            onClick={onClose}
            className="lg:hidden p-2 rounded-lg hover:bg-secondary-800 text-secondary-400 hover:text-white transition-colors"
          >
            <X className="h-6 w-6" />
          </button>
        )}
      </div>

      {/* Search - Hidden on mobile for space */}
      <div className="px-6 mb-8 hidden lg:block">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
          <input
            type="text"
            placeholder="Buscar..."
            className="w-full bg-secondary-800 text-white placeholder-secondary-400 rounded-lg pl-10 pr-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
          />
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-4">
        <ul className="space-y-2">
          {filteredNavItems.map((item) => (
            <li key={item.name}>
              <NavLink
                to={item.href}
                // Só fecha o menu mobile, nunca recarrega a página
                onClick={onClose ? () => onClose() : undefined}
                className={({ isActive }) =>
                  `group flex items-center px-4 py-3 text-sm font-medium rounded-lg transition-colors ${
                    isActive
                      ? 'bg-primary-600 text-white'
                      : 'text-secondary-300 hover:bg-secondary-800 hover:text-white'
                  }`
                }
              >
                <item.icon className="mr-3 h-5 w-5 flex-shrink-0" />
                <span className="truncate">{item.name}</span>
              </NavLink>
            </li>
          ))}
        </ul>
      </nav>

      {/* User Profile */}
      <div className="px-6 py-6 relative">
        <UserMenu />
      </div>
    </div>
  );
};

export default Sidebar;