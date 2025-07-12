import { Role } from '../types';

// Definir as rotas permitidas para cada papel
export const ROLE_PERMISSIONS: Record<Role, string[]> = {
  Admin: ['*'], // Admin tem acesso a tudo
  Manager: ['*'], // Gerente tem acesso a tudo
  Mechanic: ['/manutencao', '/frota', '/inspecoes', '/combustivel'],
  Inspector: ['/inspecoes', '/frota', '/combustivel'],
  FineAdmin: ['/multas', '/frota', '/combustivel'],
  Sales: ['/contratos', '/frota', '/customers', '/combustivel'],
  User: ['/dashboard', '/combustivel'],
  Driver: [
    '/dashboard',
    '/frota',
    '/inspecoes',
    '/cobranca',
    '/multas',
    '/combustivel',
    '/registros'
  ]
};

// Função para verificar se um papel tem permissão para acessar uma rota
export const hasPermission = (role: Role, path: string): boolean => {
  // Se não houver path, não permitir acesso
  if (!path) return false;

  const permissions = ROLE_PERMISSIONS[role];
  
  // Se tem permissão '*', pode acessar tudo
  if (permissions.includes('*')) return true;

  // Normalizar o caminho removendo query params e hash
  const cleanPath = path.split('?')[0].split('#')[0];
  
  // Remover barra final se existir
  const normalizedPath = cleanPath.endsWith('/') ? cleanPath.slice(0, -1) : cleanPath;
  
  // Pegar apenas o primeiro nível do path (ex: /frota/123 -> /frota)
  const basePath = '/' + normalizedPath.split('/')[1];

  // Verificar se o caminho base está nas permissões
  return permissions.some(permittedPath => {
    const normalizedPermittedPath = permittedPath.endsWith('/') 
      ? permittedPath.slice(0, -1) 
      : permittedPath;
    
    return basePath === normalizedPermittedPath;
  });
};

// Rotas públicas que não precisam de autenticação
export const PUBLIC_ROUTES = [
  '/login',
  '/register',
  '/unauthorized'
]; 