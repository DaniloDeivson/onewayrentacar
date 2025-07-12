import React, { useState, useRef, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { LogOut, User, Settings, ChevronDown } from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';
import { Badge } from '../UI/Badge';

export const UserMenu: React.FC = () => {
  const { user, signOut } = useAuth();
  const [isOpen, setIsOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const navigate = useNavigate();

  // Memoizar dados do usuário para evitar re-renders
  const userInitial = useMemo(() => {
    return user?.name?.charAt(0) || 'A';
  }, [user?.name]);

  const userName = useMemo(() => {
    return user?.name || 'Usuário';
  }, [user?.name]);

  const userEmail = useMemo(() => {
    return user?.contact_info?.email || '';
  }, [user?.contact_info?.email]);

  const userRole = useMemo(() => {
    return user?.role || '';
  }, [user?.role]);

  // Close menu when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  const handleLogout = async () => {
    try {
      setIsOpen(false); // Close menu first
      await signOut();
      navigate('/login', { replace: true });
    } catch {
      navigate('/login', { replace: true });
    }
  };

  if (!user) return null;

  return (
    <div className="relative" ref={menuRef}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center space-x-2 text-white hover:text-primary-300 transition-colors w-full"
        aria-expanded={isOpen}
        aria-haspopup="true"
      >
        <div className="h-8 w-8 bg-primary-600 rounded-full flex items-center justify-center flex-shrink-0">
          <span className="text-white text-sm font-medium">{userInitial}</span>
        </div>
        <div className="hidden md:block text-left">
          <p className="text-sm font-medium">{userName}</p>
          <p className="text-xs text-secondary-400">{userRole}</p>
        </div>
        <ChevronDown className="h-4 w-4 text-secondary-400" />
      </button>

      {isOpen && (
        <div className="absolute top-full right-0 mt-2 w-48 bg-white rounded-md shadow-xl py-1 z-[9999] border border-gray-200 overflow-hidden" style={{ maxWidth: '240px' }}>
          <div className="px-3 py-2 border-b border-secondary-200">
            <p className="text-sm font-medium text-secondary-900 truncate">{userName}</p>
            <p className="text-xs text-secondary-500 truncate">{userEmail}</p>
            <div className="flex items-center mt-1">
              <Badge variant="info" className="text-xs">
                {userRole}
              </Badge>
            </div>
          </div>
          <button
            onClick={() => {
              setIsOpen(false);
              navigate('/profile');
            }}
            className="block w-full text-left px-3 py-2 text-sm text-secondary-700 hover:bg-secondary-100 flex items-center"
          >
            <User className="h-4 w-4 mr-2 text-secondary-500" />
            Meu Perfil
          </button>
          <button
            onClick={() => {
              setIsOpen(false);
              navigate('/admin');
            }}
            className="block w-full text-left px-3 py-2 text-sm text-secondary-700 hover:bg-secondary-100 flex items-center"
          >
            <Settings className="h-4 w-4 mr-2 text-secondary-500" />
            Configurações
          </button>
          <div className="border-t border-secondary-200 mt-1"></div>
          <button
            onClick={handleLogout}
            className="block w-full text-left px-3 py-2 text-sm text-error-700 hover:bg-error-50 flex items-center"
          >
            <LogOut className="h-4 w-4 mr-2 text-error-600" />
            Sair
          </button>
        </div>
      )}
    </div>
  );
};

export default UserMenu;