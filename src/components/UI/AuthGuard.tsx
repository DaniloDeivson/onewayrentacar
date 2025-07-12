import { useEffect, useState, useMemo } from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../hooks/useAuth'
import { hasPermission, PUBLIC_ROUTES } from '../../config/permissions'
import { DRIVER_ALLOWED_ROUTES } from '../../constants/driverRoutes'

interface AuthGuardProps {
  children: React.ReactNode
}

export function AuthGuard({ children }: AuthGuardProps) {
  const { user, loading } = useAuth()
  const [checking, setChecking] = useState(true)
  const location = useLocation()

  // Verificar se a rota atual é permitida para o papel do usuário
  const hasRoutePermission = useMemo(() => {
    if (!user) return false;
    if (PUBLIC_ROUTES.includes(location.pathname)) return true;

    // Se for Driver, verificar se a rota está na lista permitida
    if (user.role === 'Driver') {
      const allowedPaths = DRIVER_ALLOWED_ROUTES.map(route => route.path);
      return allowedPaths.includes(location.pathname);
    }

    // Para outros papéis, usar a verificação normal
    const rolePermission = hasPermission(user.role, location.pathname);
    return rolePermission;
  }, [user, location.pathname]);

  useEffect(() => {
    if (!loading) {
      setChecking(false);
    }
  }, [loading]);

  // Mostrar loading enquanto verifica autenticação
  if (loading || checking) {
    return (
      <div className="flex items-center justify-center h-screen bg-gray-100">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600 text-lg">Verificando permissões...</p>
        </div>
      </div>
    )
  }

  // Se não há usuário e não é rota pública, redirecionar para login
  if (!user && !PUBLIC_ROUTES.includes(location.pathname)) {
    return <Navigate to="/login" state={{ from: location }} replace />
  }

  // Se o usuário não está ativo, redirecionar para unauthorized
  if (user?.active === false) {
    return <Navigate to="/unauthorized" state={{ reason: 'inactive' }} replace />
  }

  // Se o usuário não tem permissão para a rota atual
  if (user && !hasRoutePermission) {
    console.log('Verificação de Permissões:', {
      role: user.role,
      path: location.pathname,
      basePath: location.pathname.split('/')[1],
      permissions: user.permissions,
      hasRoutePermission,
      driverAllowedRoutes: user.role === 'Driver' ? DRIVER_ALLOWED_ROUTES.map(r => r.path) : 'N/A'
    });
    return <Navigate to="/unauthorized" state={{ reason: 'insufficient_permissions' }} replace />
  }

  return <>{children}</>
}