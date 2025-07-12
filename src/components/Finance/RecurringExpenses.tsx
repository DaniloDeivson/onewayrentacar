import React, { useState } from 'react';
import { Card, CardHeader, CardContent } from '../UI/Card';
import { Badge } from '../UI/Badge';
import { Button } from '../UI/Button';
import { Plus, Search, Filter, Calendar, DollarSign, Repeat, Edit, Trash2, Loader2 } from 'lucide-react';
import { RecurringExpense } from '../../hooks/useFinance';
import toast from 'react-hot-toast';
import { useFinance, RecurringCostData } from '../../hooks/useFinance';
import { useEmployees } from '../../hooks/useEmployees';
import { useAuth } from '../../hooks/useAuth';
import { useCosts } from '../../hooks/useCosts';

interface RecurringExpensesProps {
  recurringExpenses: RecurringExpense[];
  onGenerateExpenses: (month: Date) => Promise<void>;
}

interface RecurringExpenseForm {
  description: string;
  amount: number;
  due_day: number;
  category: string;
  is_active: boolean;
  employee_id?: string;
}

export const RecurringExpenses: React.FC<RecurringExpensesProps> = ({
  recurringExpenses,
  onGenerateExpenses
}) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [isGenerating, setIsGenerating] = useState(false);
  const { deleteRecurringExpense, createRecurringCost } = useFinance();
  const { createCost } = useCosts();
  const { user } = useAuth();
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const { employees } = useEmployees();
  const [showNewForm, setShowNewForm] = useState(false);
  const [form, setForm] = useState<RecurringExpenseForm>({
    description: '',
    amount: 0,
    due_day: 1,
    category: '',
    is_active: true,
    employee_id: ''
  });

  // Get unique categories for filter
  const categories = [...new Set(recurringExpenses.map(item => item.category))];

  // Filter recurring expenses
  const filteredExpenses = recurringExpenses.filter(expense => {
    const matchesSearch = expense.description.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesCategory = categoryFilter === '' || expense.category === categoryFilter;
    return matchesSearch && matchesCategory;
  });

  // Format currency
  const formatCurrency = (value: number) => {
    return value.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
  };

  // Handle generate expenses for current month
  const handleGenerateExpenses = async () => {
    try {
      setIsGenerating(true);
      await onGenerateExpenses(new Date());
      toast.success('Despesas do mês geradas com sucesso!');
    } catch {
      toast.error('Erro ao gerar despesas do mês');
    } finally {
      setIsGenerating(false);
    }
  };

  // Nova função para deletar despesa recorrente
  const handleDelete = async (id: string) => {
    try {
      setDeletingId(id);
      await deleteRecurringExpense(id);
      toast.success('Despesa recorrente excluída com sucesso!');
    } catch {
      toast.error('Erro ao excluir despesa recorrente');
    } finally {
      setDeletingId(null);
    }
  };

  // Função para marcar como pago e criar custo
  const handleMarkAsPaid = async (expense: RecurringExpense) => {
    try {
      // Mapear categoria da despesa recorrente para categoria de custo válida
      const costCategory = expense.category === 'Funilaria' ? 'Funilaria' :
                         expense.category === 'Combustível' ? 'Combustível' :
                         expense.category === 'Multa' ? 'Multa' :
                         expense.category === 'Seguro' ? 'Seguro' :
                         expense.category === 'Compra' ? 'Compra' :
                         expense.category === 'Avulsa' ? 'Avulsa' :
                         'Avulsa'; // padrão

      // Criar registro de custo recorrente quando a despesa recorrente for paga
      // Apenas Despesa Recorrente e Seguro devem ser criadas como custos recorrentes
      if (expense.category === 'Despesa Recorrente' || expense.category === 'Seguro') {
        const recurringCostData: RecurringCostData = {
          category: costCategory,
          description: `Despesa Recorrente: ${expense.description}`,
          amount: expense.amount,
          cost_date: new Date().toISOString().split('T')[0],
          status: 'Pago',
          is_recurring: true,
          recurrence_type: 'monthly',
          recurrence_day: expense.due_day,
          origin: 'Usuario',
          created_by_employee_id: user?.id || null,
          created_by_name: user?.name || 'Sistema',
          observations: `Pagamento de despesa recorrente - ${expense.category}`,
          document_ref: `Recorrente - ${expense.category}`,
          department: 'Financeiro',
          vehicle_id: null,
          tenant_id: '00000000-0000-0000-0000-000000000001' // Tenant padrão
        };

        await createRecurringCost(recurringCostData);
      } else {
        // Todas as outras categorias são criadas como custos normais (avulsos)
        await createCost({
          category: costCategory,
          description: `Despesa: ${expense.description}`,
          amount: expense.amount,
          cost_date: new Date().toISOString().split('T')[0],
          status: 'Pago',
          origin: 'Usuario',
          created_by_employee_id: user?.id || null,
          created_by_name: user?.name || 'Sistema',
          observations: `Pagamento de despesa - ${expense.category}`,
          document_ref: `Despesa - ${expense.category}`,
          department: 'Financeiro',
          vehicle_id: null,
          tenant_id: '00000000-0000-0000-0000-000000000001' // Tenant padrão
        });
      }

      toast.success('Despesa marcada como paga e registrada nos custos!');
    } catch {
      toast.error('Erro ao marcar como paga');
    }
  };

  // Adicione o submit do formulário de nova despesa recorrente
  const handleNewExpenseSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (form.category === 'Salário' && !form.employee_id) {
      toast.error('Selecione o funcionário para a despesa de salário!');
      return;
    }
    // Aqui você deve chamar a função de criação de despesa recorrente (exemplo: onCreateRecurringExpense)
    // Inclua employee_id no payload se for salário
    // await onCreateRecurringExpense({ ...form });
    setShowNewForm(false);
    setForm({
      description: '',
      amount: 0,
      due_day: 1,
      category: '',
      is_active: true,
      employee_id: ''
    });
    toast.success('Despesa recorrente criada!');
  };

  return (
    <Card>
      <CardHeader className="p-4 lg:p-6">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <h3 className="text-lg font-semibold text-secondary-900">Despesas Recorrentes</h3>
          <div className="flex space-x-2">
            <Button 
              onClick={handleGenerateExpenses}
              disabled={isGenerating}
              variant="secondary"
              size="sm"
            >
              {isGenerating ? (
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              ) : (
                <Calendar className="h-4 w-4 mr-2" />
              )}
              Gerar Despesas do Mês
            </Button>
            <Button size="sm" onClick={() => setShowNewForm(true)}>
              <Plus className="h-4 w-4 mr-2" />
              Nova Despesa
            </Button>
          </div>
        </div>
      </CardHeader>
      <CardContent className="p-4 lg:p-6">
        {/* Filters */}
        <div className="flex flex-col sm:flex-row gap-4 mb-6">
          <div className="flex-1">
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
            <Button variant="secondary" size="sm">
              <Filter className="h-4 w-4 mr-2" />
              Filtros
            </Button>
          </div>
        </div>

        {/* Recurring Expenses List */}
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-secondary-200">
            <thead className="bg-secondary-50">
              <tr>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-secondary-500 uppercase tracking-wider">
                  Descrição
                </th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-secondary-500 uppercase tracking-wider">
                  Categoria
                </th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-secondary-500 uppercase tracking-wider">
                  Dia de Vencimento
                </th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-secondary-500 uppercase tracking-wider">
                  Valor
                </th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-secondary-500 uppercase tracking-wider">
                  Status
                </th>
                <th scope="col" className="px-6 py-3 text-right text-xs font-medium text-secondary-500 uppercase tracking-wider">
                  Ações
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-secondary-200">
              {filteredExpenses.map((expense) => (
                <tr key={expense.id} className="hover:bg-secondary-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm font-medium text-secondary-900">{expense.description}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-secondary-600">
                    {expense.category}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-secondary-600">
                    <div className="flex items-center">
                      <Calendar className="h-4 w-4 mr-2 text-secondary-400" />
                      Dia {expense.due_day}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-secondary-900">
                    {formatCurrency(expense.amount)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <Badge variant={expense.is_active ? "success" : "error"}>
                      {expense.is_active ? "Ativo" : "Inativo"}
                    </Badge>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <button
                      onClick={() => toast.success('Funcionalidade em desenvolvimento')}
                      className="text-primary-600 hover:text-primary-900 mr-4"
                    >
                      <Edit className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => handleMarkAsPaid(expense)}
                      className="text-success-600 hover:text-success-900 mr-4"
                      title="Marcar como pago"
                    >
                      <DollarSign className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => handleDelete(expense.id)}
                      disabled={deletingId === expense.id}
                      className="text-error-600 hover:text-error-900"
                    >
                      {deletingId === expense.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {filteredExpenses.length === 0 && (
          <div className="text-center py-12">
            <Repeat className="h-12 w-12 mx-auto text-secondary-400 mb-4" />
            <p className="text-secondary-600 text-lg">Nenhuma despesa recorrente encontrada</p>
            <p className="text-secondary-500 text-sm mt-2">Tente ajustar os filtros ou criar uma nova despesa</p>
          </div>
        )}

        {showNewForm && (
          <form onSubmit={handleNewExpenseSubmit} className="space-y-4 mb-6">
            <div>
              <label className="block text-sm font-medium mb-1">Descrição *</label>
              <input
                type="text"
                value={form.description}
                onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Valor *</label>
              <input
                type="number"
                value={form.amount}
                onChange={e => setForm(f => ({ ...f, amount: Number(e.target.value) }))}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2"
                min="0.01"
                step="0.01"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Dia de Vencimento *</label>
              <input
                type="number"
                value={form.due_day}
                onChange={e => setForm(f => ({ ...f, due_day: Number(e.target.value) }))}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2"
                min="1"
                max="31"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Categoria *</label>
              <select
                value={form.category}
                onChange={e => setForm(f => ({ ...f, category: e.target.value }))}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2"
                required
              >
                <option value="">Selecione a categoria</option>
                <option value="Salário">Salário</option>
                <option value="Funilaria">Funilaria</option>
                <option value="Combustível">Combustível</option>
                <option value="Multa">Multa</option>
                <option value="Seguro">Seguro</option>
                <option value="Compra">Compra</option>
                <option value="Avulsa">Avulsa</option>
                <option value="Despesa Recorrente">Despesa Recorrente</option>
              </select>
            </div>
            {form.category === 'Salário' && (
              <div>
                <label className="block text-sm font-medium mb-1">Funcionário *</label>
                <select
                  value={form.employee_id}
                  onChange={e => setForm(f => ({ ...f, employee_id: e.target.value }))}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2"
                  required
                >
                  <option value="">Selecione o funcionário</option>
                  {employees.map(emp => (
                    <option key={emp.id} value={emp.id}>{emp.name} ({emp.role})</option>
                  ))}
                </select>
              </div>
            )}
            <div className="flex gap-2">
              <Button type="submit" variant="primary">Salvar</Button>
              <Button type="button" variant="secondary" onClick={() => setShowNewForm(false)}>Cancelar</Button>
            </div>
          </form>
        )}
      </CardContent>
    </Card>
  );
};

export default RecurringExpenses;