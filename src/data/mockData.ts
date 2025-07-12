import { Vehicle, Cost, ServiceNote, Part, Customer, Contract, Fine } from '../types';

export const mockVehicles: Vehicle[] = [
  {
    id: '1',
    plate: 'ABC-1234',
    model: 'Fiat Ducato',
    year: 2022,
    type: 'Furgão',
    color: 'Branco',
    fuel: 'Diesel',
    category: 'Carga',
    chassis: '9BD15502XE1234567',
    renavam: '12345678901',
    cargoCapacity: 2000,
    location: 'São Paulo - SP',
    acquisitionDate: '2022-01-15',
    acquisitionValue: 120000,
    totalCosts: 15000,
    status: 'Em Uso'
  },
  {
    id: '2',
    plate: 'DEF-5678',
    model: 'Mercedes Sprinter',
    year: 2021,
    type: 'Van',
    color: 'Prata',
    fuel: 'Diesel',
    category: 'Passageiros',
    chassis: 'WDB9066321234567',
    renavam: '10987654321',
    cargoCapacity: 1500,
    location: 'Rio de Janeiro - RJ',
    acquisitionDate: '2021-03-20',
    acquisitionValue: 180000,
    totalCosts: 22000,
    status: 'Disponível'
  },
  {
    id: '3',
    plate: 'GHI-9012',
    model: 'Iveco Daily',
    year: 2023,
    type: 'Furgão',
    color: 'Branco',
    fuel: 'Diesel',
    category: 'Carga',
    chassis: 'ZCFC35A00N1234567',
    renavam: '11223344556',
    cargoCapacity: 2500,
    location: 'Belo Horizonte - MG',
    acquisitionDate: '2023-05-10',
    acquisitionValue: 140000,
    totalCosts: 8000,
    status: 'Manutenção'
  }
];

export const mockCosts: Cost[] = [
  {
    id: '1',
    category: 'Multa',
    vehicleId: '1',
    vehiclePlate: 'ABC-1234',
    description: 'Excesso de velocidade',
    amount: 195.23,
    costDate: '2024-01-15',
    status: 'Pendente',
    documentRef: 'MULTA-2024-001'
  },
  {
    id: '2',
    category: 'Funilaria',
    vehicleId: '2',
    vehiclePlate: 'DEF-5678',
    description: 'Reparo porta lateral',
    amount: 850.00,
    costDate: '2024-01-10',
    status: 'Pago',
    documentRef: 'NF-8796'
  },
  {
    id: '3',
    category: 'Seguro',
    vehicleId: '1',
    vehiclePlate: 'ABC-1234',
    description: 'Seguro mensal',
    amount: 420.00,
    costDate: '2024-01-01',
    status: 'Pago',
    documentRef: 'SEG-2024-01'
  }
];

export const mockServiceNotes: ServiceNote[] = [
  {
    id: '1',
    vehicleId: '1',
    vehiclePlate: 'ABC-1234',
    maintenanceType: 'Preventiva',
    startDate: '2024-01-20',
    mechanic: 'João Silva',
    priority: 'Média',
    mileage: 45000,
    description: 'Troca de óleo e filtros',
    status: 'Concluída'
  },
  {
    id: '2',
    vehicleId: '3',
    vehiclePlate: 'GHI-9012',
    maintenanceType: 'Corretiva',
    startDate: '2024-01-25',
    mechanic: 'Pedro Santos',
    priority: 'Alta',
    mileage: 12000,
    description: 'Problema no sistema de freios',
    status: 'Em Andamento'
  }
];

export const mockParts: Part[] = [
  {
    id: '1',
    sku: 'FLT-001',
    name: 'Filtro de Óleo',
    quantity: 25,
    unitCost: 45.00,
    minStock: 10
  },
  {
    id: '2',
    sku: 'PST-001',
    name: 'Pastilha de Freio',
    quantity: 8,
    unitCost: 120.00,
    minStock: 5
  },
  {
    id: '3',
    sku: 'OLE-001',
    name: 'Óleo Motor 15W40',
    quantity: 50,
    unitCost: 28.00,
    minStock: 20
  }
];

export const mockCustomers: Customer[] = [
  {
    id: '1',
    name: 'Transportadora ABC Ltda',
    document: '12.345.678/0001-90',
    email: 'contato@transportadoraabc.com',
    phone: '(11) 99999-9999',
    address: 'Rua das Flores, 123 - São Paulo, SP'
  },
  {
    id: '2',
    name: 'Logística XYZ',
    document: '98.765.432/0001-10',
    email: 'admin@logisticaxyz.com',
    phone: '(21) 88888-8888',
    address: 'Av. Principal, 456 - Rio de Janeiro, RJ'
  }
];

export const mockContracts: Contract[] = [
  {
    id: '1',
    customerId: '1',
    customerName: 'Transportadora ABC Ltda',
    vehicleId: '1',
    vehiclePlate: 'ABC-1234',
    startDate: '2024-01-01',
    endDate: '2024-12-31',
    dailyRate: 180.00,
    status: 'Ativo'
  },
  {
    id: '2',
    customerId: '2',
    customerName: 'Logística XYZ',
    vehicleId: '2',
    vehiclePlate: 'DEF-5678',
    startDate: '2024-01-15',
    endDate: '2024-06-15',
    dailyRate: 220.00,
    status: 'Ativo'
  }
];

export const mockFines: Fine[] = [
  {
    id: '1',
    vehicleId: '1',
    vehiclePlate: 'ABC-1234',
    driverName: 'Carlos Motorista',
    fineNumber: 'SP-2024-001234',
    infractionType: 'Excesso de velocidade',
    amount: 195.23,
    infractionDate: '2024-01-15',
    dueDate: '2024-02-15',
    notified: true,
    status: 'Pendente'
  },
  {
    id: '2',
    vehicleId: '2',
    vehiclePlate: 'DEF-5678',
    driverName: 'Maria Silva',
    fineNumber: 'RJ-2024-005678',
    infractionType: 'Estacionamento irregular',
    amount: 88.38,
    infractionDate: '2024-01-12',
    dueDate: '2024-02-12',
    notified: false,
    status: 'Pendente'
  }
];