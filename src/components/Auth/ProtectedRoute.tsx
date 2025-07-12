import { AuthGuard } from '../UI/AuthGuard'

interface ProtectedRouteProps {
  children: React.ReactNode
  requiredPermissions?: string[]
}

export function ProtectedRoute({ children, requiredPermissions }: ProtectedRouteProps) {
  return (
    <AuthGuard requiredPermissions={requiredPermissions}>
      {children}
    </AuthGuard>
  )
}