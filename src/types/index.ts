import { Database } from './database'

export type Tables<T extends keyof Database['public']['Tables']> = Database['public']['Tables'][T]['Row']
export type Functions<T extends keyof Database['public']['Functions']> = Database['public']['Functions'][T]

// Tipos específicos
export type Employee = Tables<'employees'>
export type RemovedUser = Tables<'removed_users'>

// Tipos de inserção/atualização
export type EmployeeInsert = Database['public']['Tables']['employees']['Insert']
export type EmployeeUpdate = Database['public']['Tables']['employees']['Update']

export type RemovedUserInsert = Database['public']['Tables']['removed_users']['Insert']
export type RemovedUserUpdate = Database['public']['Tables']['removed_users']['Update']

// Tipos de funções
export type ValidateSession = Functions<'validate_session'>
export type HasPermission = Functions<'has_permission'>

// Tipos de contexto
export interface SecurityContext {
  isAuthenticated: boolean
  user: Employee | null
  hasPermission: (permission: string) => Promise<boolean>
  validateSession: () => Promise<boolean>
}

// Tipos de resposta
export interface AuthResponse {
  success: boolean
  message: string
  data?: unknown
}

export interface UserPermissions {
  admin: boolean;
  contracts: boolean;
  costs: boolean;
  cobranca: boolean;
  dashboard: boolean;
  employees: boolean;
  finance: boolean;
  fines: boolean;
  fleet: boolean;
  inspections: boolean;
  inventory: boolean;
  maintenance: boolean;
  purchases: boolean;
  statistics: boolean;
  suppliers: boolean;
}

export interface ContactInfo {
  email: string
  phone: string | null
  status?: 'orphaned' | 'orphaned_duplicate' | 'duplicate_resolved' | null
  updated_reason?: string
}

export type PermissionType = keyof UserPermissions

export type Role = 
  | 'Admin'
  | 'Manager'
  | 'Mechanic'
  | 'Inspector'
  | 'FineAdmin'
  | 'Sales'
  | 'User'
  | 'Driver';

export interface Vehicle {
  id: string;
  plate: string;
  model: string;
  year: number;
  type: 'Furgão' | 'Van';
  color: string;
  fuel: 'Diesel' | 'Gasolina' | 'Elétrico';
  category: string;
  chassis: string;
  renavam: string;
  cargoCapacity: number;
  location: string;
  acquisitionDate: string;
  acquisitionValue: number;
  mileage: number;
  initial_mileage: number;
  totalCosts?: number;
  status: 'Disponível' | 'Em Uso' | 'Manutenção' | 'Inativo';
}

export interface Cost {
  id: string;
  category: 'Multa' | 'Funilaria' | 'Seguro' | 'Avulsa';
  vehicleId: string;
  vehiclePlate?: string;
  description: string;
  amount: number;
  costDate: string;
  status: 'Pendente' | 'Pago';
  documentRef?: string;
  observations?: string;
}

export interface ServiceNote {
  id: string;
  vehicleId: string;
  vehiclePlate?: string;
  maintenanceType: string;
  startDate: string;
  mechanic: string;
  priority: 'Baixa' | 'Média' | 'Alta';
  mileage: number;
  description: string;
  observations?: string;
  status: 'Aberta' | 'Em Andamento' | 'Concluída';
}

export interface Part {
  id: string;
  sku: string;
  name: string;
  quantity: number;
  unitCost: number;
  minStock: number;
}

export interface Customer {
  id: string;
  name: string;
  document: string;
  email: string;
  phone: string;
  address: string;
}

export interface Contract {
  id: string;
  customerId: string;
  customerName?: string;
  vehicleId: string;
  vehiclePlate?: string;
  startDate: string;
  endDate: string;
  dailyRate: number;
  status: 'Ativo' | 'Finalizado' | 'Cancelado';
}

export interface Fine {
  id: string;
  vehicleId: string;
  vehiclePlate?: string;
  driverName: string;
  fineNumber: string;
  infractionType: string;
  amount: number;
  infractionDate: string;
  dueDate: string;
  notified: boolean;
  status: 'Pendente' | 'Pago' | 'Contestado';
}

export interface StatsData {
  totalVehicles: number;
  activeContracts: number;
  monthlyRevenue: number;
  monthlyCosts: number;
  pendingMaintenance: number;
  activeVehicles: number;
}

// Utilitário central de mapeamento de papéis (roles)
export const ROLE_LABELS: Record<string, string> = {
  'Admin': 'Administrador',
  'Manager': 'Gerente',
  'Mechanic': 'Mecânico',
  'PatioInspector': 'Inspetor de Pátio',
  'FineAdmin': 'Admin. Multas',
  'Comercial': 'Comercial',
  'Sales': 'Comercial',
  'Driver': 'Motorista',
  'Finance': 'Financeiro',
  'Financeiro': 'Financeiro',
  'Inventory': 'Estoque',
  'Estoque': 'Estoque',
  'Compras': 'Compras',
  'Inspector': 'Inspetor',
  'User': 'Usuário',
  // Adicione outras variações se necessário
};

export const ROLE_VALUES: Record<string, string> = {
  'Administrador': 'Admin',
  'Mecânico': 'Mechanic',
  'Inspetor de Pátio': 'PatioInspector',
  'Admin. Multas': 'FineAdmin',
  'Comercial': 'Sales',
  'Gerente': 'Manager',
  'Motorista': 'Driver',
  'Financeiro': 'Finance',
  'Estoque': 'Inventory',
  'Compras': 'Compras',
  'Inspetor': 'Inspector',
  'Usuário': 'User',
  // Adicione outros papéis conforme necessário
};

export function getRoleLabel(role: string): string {
  return ROLE_LABELS[role] || role;
}

export function getRoleValue(label: string): string {
  return ROLE_VALUES[label] || label;
}

// Array de roles únicos para uso em selects (evita duplicidade)
export const ROLES_UNICOS = [
  'Admin',
  'Manager',
  'Mechanic',
  'Inspector',
  'FineAdmin',
  'Sales',
  'User',
  'Driver'
];