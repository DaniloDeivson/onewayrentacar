import React, { useState } from 'react';
import { useFinance } from '../hooks/useFinance';
import { Loader2 } from 'lucide-react';
import FinancialSummary from '../components/Finance/FinancialSummary';
import AccountsPayableList from '../components/Finance/AccountsPayableList';
import SalaryManagement from '../components/Finance/SalaryManagement';
import NewExpenseForm from '../components/Finance/NewExpenseForm';
import toast from 'react-hot-toast';
import { useCosts } from '../hooks/useCosts';
import { useAuth } from '../hooks/useAuth';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts';

export const Finance: React.FC = () => {
  const {
    accountsPayable,
    salaries,
    summary,
    loading,
    markAsPaid,
    createAccountPayable,
    generateSalaries,
    updateSalary,
    deleteSalary,
    createSalary,
    refetch: refetchFinance
  } = useFinance();
  
  const [processingAction, setProcessingAction] = useState(false);
  const { costs, refetch: refetchCosts } = useCosts();
  const { user } = useAuth();

  // Função para atualizar todos os dados
  const refetch = async () => {
    await Promise.all([
      refetchFinance(),
      refetchCosts()
    ]);
  };

  // Custos por categoria (dados reais)
  const costsByCategoryData = Object.entries(
    costs.reduce((acc, cost) => {
      // Para custos "Avulsa", usar a descrição como categoria específica
      // Para outras categorias, usar a categoria normal
      const categoryKey = cost.category === 'Avulsa' ? cost.description : cost.category;
      acc[categoryKey] = (acc[categoryKey] || 0) + cost.amount;
      return acc;
    }, {} as Record<string, number>)
  ).map(([name, value]) => ({ name, value }));

  // Mark account as paid (contas a pagar)
  const handleMarkAsPaid = async (id: string) => {
    setProcessingAction(true);
    try {
      await markAsPaid(id);
      await refetch();
      toast.success('Conta marcada como paga com sucesso!');
    } catch {
      toast.error('Erro ao marcar conta como paga');
    } finally {
      setProcessingAction(false);
    }
  };

  // Marcar salário como pago
  const handleMarkSalaryAsPaid = async (id: string) => {
    setProcessingAction(true);
    try {
      await updateSalary(id, { status: 'Pago' });
      await refetch();
      toast.success('Salário marcado como pago com sucesso!');
    } catch {
      toast.error('Erro ao marcar salário como pago');
    } finally {
      setProcessingAction(false);
    }
  };

  // Create new expense
  const handleCreateExpense = async (data: { amount: number; description: string; category: string; due_date: string; payment_method?: string; notes?: string }) => {
    setProcessingAction(true);
    try {
      const expenseData = {
        amount: data.amount,
        description: data.description,
        category: data.category,
        due_date: data.due_date,
        payment_method: data.payment_method,
        document_ref: undefined
      };
      await createAccountPayable({ 
        ...expenseData, 
        status: 'Pendente', 
        created_by_employee_id: user?.id || undefined,
        supplier_id: undefined
      });
      await refetch();
    } catch {
      toast.error('Erro ao criar despesa');
    } finally {
      setProcessingAction(false);
    }
  };

  // Generate salaries
  const handleGenerateSalaries = async (month: Date) => {
    setProcessingAction(true);
    try {
      const count = await generateSalaries(month);
      await refetch();
      toast.success(`${count} salários gerados com sucesso!`);
    } catch {
      toast.error('Erro ao gerar salários');
    } finally {
      setProcessingAction(false);
    }
  };

  if (loading && !accountsPayable.length) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-primary-600" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl lg:text-3xl font-bold text-secondary-900">Financeiro</h1>
        <p className="text-secondary-600 mt-1 lg:mt-2">Gerencie contas a pagar, salários e despesas recorrentes</p>
      </div>

      {/* Financial Summary */}
      <FinancialSummary summary={summary} />

      {/* Gráfico de Custos por Categoria */}
      <div className="bg-white rounded-lg shadow p-4">
        <h3 className="text-lg font-semibold text-secondary-900 mb-4">Custos por Categoria</h3>
        <ResponsiveContainer width="100%" height={Math.max(300, costsByCategoryData.length * 40)}>
          <BarChart data={costsByCategoryData} layout="vertical">
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis type="number" />
            <YAxis
              dataKey="name"
              type="category"
              width={200}
              tick={{ fontSize: 12 }}
              interval={0}
              tickFormatter={label => label.length > 40 ? label.slice(0, 37) + '...' : label}
            />
            <Tooltip />
            <Legend />
            <Bar dataKey="value" fill="#0ea5e9" />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* New Expense Form */}
      <NewExpenseForm 
        onCreateExpense={handleCreateExpense}
        loading={processingAction}
      />

      {/* Accounts Payable List */}
      <AccountsPayableList 
        accountsPayable={accountsPayable}
        onMarkAsPaid={handleMarkAsPaid}
        loading={processingAction}
      />

      {/* Salary Management */}
      <SalaryManagement 
        salaries={salaries}
        onMarkAsPaid={handleMarkSalaryAsPaid}
        onGenerateSalaries={handleGenerateSalaries}
        loading={processingAction}
        onEditSalary={async (id, updates) => {
          await updateSalary(id, updates);
          toast.success('Salário atualizado com sucesso!');
          await refetch();
        }}
        onDeleteSalary={async (id) => {
          await deleteSalary(id);
          toast.success('Salário removido com sucesso!');
          await refetch();
        }}
        onCreateSalary={async (data) => {
          if (!user?.id) {
            toast.error('Usuário não identificado');
            return;
          }
          await createSalary({ 
            ...data, 
            status: data.status as 'Pago' | 'Pendente' | 'Autorizado',
            employee_id: user.id
          });
          toast.success('Salário criado com sucesso!');
          await refetch();
        }}
      />
    </div>
  );
};

export default Finance;