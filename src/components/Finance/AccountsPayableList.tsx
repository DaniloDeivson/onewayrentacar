import React, { useState } from 'react';
import { Card, CardHeader, CardContent } from '../UI/Card';
import { Badge } from '../UI/Badge';
import { Button } from '../UI/Button';
import { Search, DollarSign, Calendar, CheckCircle, AlertTriangle } from 'lucide-react';
import { AccountPayable } from '../../hooks/useFinance';

interface AccountsPayableListProps {
  accountsPayable: AccountPayable[];
  onMarkAsPaid: (id: string) => Promise<void>;
  loading: boolean;
}

export const AccountsPayableList: React.FC<AccountsPayableListProps> = ({
  accountsPayable,
  onMarkAsPaid,
  loading
}) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  // Get unique categories for filter
  const categories = [...new Set(accountsPayable.map(item => item.category))];

  // Filter accounts payable
  const filteredItems = accountsPayable.filter(item => {
    const matchesSearch = item.description.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesCategory = categoryFilter === '' || item.category === categoryFilter;
    const matchesStatus = statusFilter === '' || item.status === statusFilter;
    return matchesSearch && matchesCategory && matchesStatus;
  });

  // Get status badge
  const getStatusBadge = (status: string, isOverdue: boolean) => {
    if (status === 'Pago') {
      return <Badge variant="success">Pago</Badge>;
    } else if (status === 'Autorizado') {
      return <Badge variant="info">Autorizado</Badge>;
    } else if (isOverdue) {
      return <Badge variant="error">Vencido</Badge>;
    } else {
      return <Badge variant="warning">Pendente</Badge>;
    }
  };

  // Format currency
  const formatCurrency = (value: number) => {
    return value.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
  };

  // Função para marcar como paga
  const handleMarkAsPaid = async (item: AccountPayable) => {
    await onMarkAsPaid(item.id);
  };

  return (
    <Card>
      <CardHeader className="p-4 lg:p-6">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <h3 className="text-lg font-semibold text-secondary-900">Contas a Pagar</h3>
          <div className="flex space-x-2">
            <select
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
              className="border border-secondary-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
            >
              <option value="">Todas as Categorias</option>
              {categories.map(category => (
                <option key={category} value={category}>{category}</option>
              ))}
            </select>
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="border border-secondary-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
            >
              <option value="">Todos os Status</option>
              <option value="Pendente">Pendente</option>
              <option value="Pago">Pago</option>
              <option value="Autorizado">Autorizado</option>
            </select>
          </div>
        </div>
      </CardHeader>
      <CardContent className="p-4 lg:p-6">
        {/* Search */}
        <div className="mb-6">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
            <input
              type="text"
              placeholder="Buscar por descrição..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
            />
          </div>
        </div>

        {/* List */}
        <div className="space-y-4">
          {filteredItems.length > 0 ? (
            filteredItems.map((item) => (
              <div 
                key={item.id} 
                className={`border ${item.is_overdue ? 'border-error-200 bg-error-50' : 'border-secondary-200'} rounded-lg p-4`}
              >
                <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
                  <div className="flex-1">
                    <div className="flex items-center space-x-3 mb-2">
                      <h4 className="font-medium text-secondary-900">{item.description}</h4>
                      {getStatusBadge(item.status, item.is_overdue)}
                    </div>
                    <div className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-6 text-sm text-secondary-600">
                      <div className="flex items-center">
                        <Calendar className="h-4 w-4 mr-1 text-secondary-400" />
                        <span>Vencimento: {new Date(item.due_date).toLocaleDateString('pt-BR')}</span>
                      </div>
                      <div className="flex items-center">
                        <DollarSign className="h-4 w-4 mr-1 text-secondary-400" />
                        <span>Categoria: {item.category}</span>
                      </div>
                      {item.is_overdue && (
                        <div className="flex items-center text-error-600">
                          <AlertTriangle className="h-4 w-4 mr-1" />
                          <span>{item.days_overdue} dias em atraso</span>
                        </div>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center space-x-4">
                    <div className="text-right">
                      <p className="text-lg font-bold text-secondary-900">{formatCurrency(item.amount)}</p>
                    </div>
                    {item.status === 'Pendente' && (
                      <Button 
                        onClick={() => handleMarkAsPaid(item)}
                        disabled={loading}
                        size="sm"
                        variant="success"
                      >
                        <CheckCircle className="h-4 w-4 mr-2" />
                        Pagar
                      </Button>
                    )}
                  </div>
                </div>
              </div>
            ))
          ) : (
            <div className="text-center py-12">
              <DollarSign className="h-12 w-12 mx-auto text-secondary-400 mb-4" />
              <p className="text-secondary-600 text-lg">Nenhuma conta a pagar encontrada</p>
              <p className="text-secondary-500 text-sm mt-2">Tente ajustar os filtros ou criar uma nova conta</p>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
};

export default AccountsPayableList;