// @ts-nocheck
import React, { useState, useEffect } from 'react';
import { Card, CardHeader, CardContent } from '../components/UI/Card';
import { Button } from '../components/UI/Button';
import { Loader2, Clock, Receipt, CheckCircle } from 'lucide-react';
import { useCosts } from '../hooks/useCosts';
import { useVehicles } from '../hooks/useVehicles';
import { useCustomers } from '../hooks/useCustomers';
import { useEmployees } from '../hooks/useEmployees';
import { useAuth } from '../hooks/useAuth';
import { CostsList } from '../components/Costs/CostsList';

const Cobranca = () => {
  const { user } = useAuth();
  const { costs, loading, error } = useCosts();
  const { vehicles } = useVehicles();
  const { customers } = useCustomers();
  const { employees } = useEmployees();

  // Filtros
  const [searchTerm, setSearchTerm] = useState('');
  const [vehicleFilter, setVehicleFilter] = useState('');
  const [customerFilter, setCustomerFilter] = useState('');
  const [employeeFilter, setEmployeeFilter] = useState('');
  const [contractFilter, setContractFilter] = useState('');

  // Filtragem
  const filteredCosts = costs.filter(cost => {
    const matchesSearch = searchTerm.trim() === '' ||
      (cost.description && cost.description.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (cost.category && cost.category.toLowerCase().includes(searchTerm.toLowerCase()));
    const matchesVehicle = !vehicleFilter || cost.vehicle_id === vehicleFilter;
    const matchesCustomer = !customerFilter || cost.customer_id === customerFilter;
    const matchesEmployee = !employeeFilter || cost.created_by_employee_id === employeeFilter;
    const matchesContract = !contractFilter || cost.contract_id === contractFilter;
    return matchesSearch && matchesVehicle && matchesCustomer && matchesEmployee && matchesContract;
  });

  // Estatísticas
  const total = filteredCosts.length;
  const pending = filteredCosts.filter(c => c.status === 'Pendente').length;
  const paid = filteredCosts.filter(c => c.status === 'Pago').length;
  const totalAmount = filteredCosts.reduce((s, c) => s + (c.amount || 0), 0);
  const pendingAmount = filteredCosts.filter(c => c.status === 'Pendente').reduce((s, c) => s + (c.amount || 0), 0);
  const paidAmount = filteredCosts.filter(c => c.status === 'Pago').reduce((s, c) => s + (c.amount || 0), 0);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin mx-auto mb-4" />
        <p className="text-secondary-600">Carregando custos...</p>
      </div>
    );
  }
  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <p className="text-error-600">{error}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-secondary-900">Cobrança de Clientes</h1>
          <p className="text-secondary-600">Visualização de todos os custos lançados</p>
        </div>
      </div>

      {/* Estatísticas */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-secondary-600">Total de Cobranças</p>
                <p className="text-2xl font-bold text-secondary-900">{total}</p>
              </div>
              <Receipt className="h-8 w-8 text-secondary-400" />
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-secondary-600">Pendentes</p>
                <p className="text-2xl font-bold text-warning-600">{pending}</p>
                <p className="text-sm text-secondary-500">
                  R$ {pendingAmount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                </p>
              </div>
              <Clock className="h-8 w-8 text-warning-400" />
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-secondary-600">Pagas</p>
                <p className="text-2xl font-bold text-success-600">{paid}</p>
                <p className="text-sm text-secondary-500">
                  R$ {paidAmount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                </p>
              </div>
              <CheckCircle className="h-8 w-8 text-success-400" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Filtros (apenas admin/manager) */}
      {(user?.role === 'Admin' || user?.role === 'Manager') && (
        <Card>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <input
                type="text"
                placeholder="Buscar por descrição ou categoria..."
                value={searchTerm}
                onChange={e => setSearchTerm(e.target.value)}
                className="border border-secondary-300 rounded-lg px-3 py-2"
              />
              <select value={vehicleFilter} onChange={e => setVehicleFilter(e.target.value)} className="border border-secondary-300 rounded-lg px-3 py-2">
                <option value="">Todos Veículos</option>
                {vehicles.map(v => (
                  <option key={v.id} value={v.id}>{v.plate}</option>
                ))}
              </select>
              <select value={customerFilter} onChange={e => setCustomerFilter(e.target.value)} className="border border-secondary-300 rounded-lg px-3 py-2">
                <option value="">Todos Clientes</option>
                {customers.map(c => (
                  <option key={c.id} value={c.id}>{c.name}</option>
                ))}
              </select>
              <select value={employeeFilter} onChange={e => setEmployeeFilter(e.target.value)} className="border border-secondary-300 rounded-lg px-3 py-2">
                <option value="">Todos Funcionários</option>
                {employees.map(emp => (
                  <option key={emp.id} value={emp.id}>{emp.name}</option>
                ))}
              </select>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Lista de Cobranças (Custos) */}
      <Card>
        <CardHeader>
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
            <h2 className="text-lg font-semibold text-secondary-900">Lista de Cobranças</h2>
            <Button onClick={() => window.location.reload()} variant="secondary" size="sm" className="flex items-center">
              Atualizar
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <CostsList
            costs={filteredCosts}
            canEdit={false}
            canMarkAsPaid={false}
            canDelete={false}
            onView={() => {}}
          />
        </CardContent>
      </Card>
    </div>
  );
};

export default Cobranca; 