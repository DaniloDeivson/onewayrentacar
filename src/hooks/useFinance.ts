import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';

export interface AccountPayable {
  id: string;
  description: string;
  amount: number;
  due_date: string;
  category: string;
  status: 'Pendente' | 'Pago' | 'Autorizado';
  supplier_id?: string;
  supplier_name?: string;
  document_ref?: string;
  payment_method?: string;
  is_overdue: boolean;
  days_overdue: number;
  source_type: 'Salário' | 'Despesa Recorrente' | 'Custo' | 'Manual';
  created_at: string;
}

export interface Salary {
  id: string;
  employee_id: string;
  employee_name: string;
  employee_role: string;
  employee_code?: string;
  amount: number;
  payment_date: string;
  status: 'Pendente' | 'Pago' | 'Autorizado';
  reference_month: string;
  reference_month_formatted: string;
  created_at: string;
  updated_at: string;
}

export interface RecurringExpense {
  id: string;
  description: string;
  amount: number;
  due_day: number;
  category: string;
  is_active: boolean;
  last_generated_date?: string;
  payment_method?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface RecurringCostData {
  tenant_id?: string;
  category: string;
  description: string;
  amount: number;
  cost_date: string;
  status?: 'Pendente' | 'Pago' | 'Autorizado';
  vehicle_id?: string | null;
  customer_id?: string;
  customer_name?: string;
  contract_id?: string;
  guest_id?: string;
  is_recurring: boolean;
  recurrence_type?: 'monthly' | 'weekly' | 'yearly';
  recurrence_day?: number;
  auto_generated?: boolean;
  parent_recurring_cost_id?: string | null;
  origin?: string;
  created_by_employee_id?: string | null;
  created_by_name?: string;
  observations?: string;
  document_ref?: string;
  department?: string;
}

export interface FinancialSummary {
  total_pending: number;
  total_paid: number;
  total_overdue: number;
  overdue_count: number;
  upcoming_payments: number;
  upcoming_count: number;
  salary_total: number;
  recurring_total: number;
}

export const useFinance = () => {
  const [accountsPayable, setAccountsPayable] = useState<AccountPayable[]>([]);
  const [salaries, setSalaries] = useState<Salary[]>([]);
  const [recurringExpenses, setRecurringExpenses] = useState<RecurringExpense[]>([]);
  const [summary, setSummary] = useState<FinancialSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchAccountsPayable = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('vw_upcoming_payments')
        .select('*')
        .order('due_date', { ascending: true });

      if (error) throw error;
      setAccountsPayable(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const fetchSalaries = async () => {
    try {
      const { data, error } = await supabase
        .from('vw_employee_salaries')
        .select('*')
        .order('reference_month', { ascending: false });

      if (error) throw error;
      setSalaries(data || []);
    } catch {
      // Error handling for salaries
    }
  };

  const fetchRecurringExpenses = async () => {
    try {
      const { data, error } = await supabase
        .from('recurring_expenses')
        .select('*')
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('due_day', { ascending: true });

      if (error) throw error;
      setRecurringExpenses(data || []);
    } catch {
      // Error handling for recurring expenses
    }
  };

  const fetchFinancialSummary = async () => {
    try {
      // Get accounts payable summary
      const { data: summaryData, error: summaryError } = await supabase
        .rpc('fn_financial_summary', { p_tenant_id: DEFAULT_TENANT_ID });

      if (summaryError) throw summaryError;
      
      if (summaryData && summaryData.length > 0) {
        setSummary(summaryData[0]);
      }
    } catch (err) {
      console.error('Error fetching financial summary:', err);
    }
  };

  const markAsPaid = async (id: string) => {
    try {
      // Buscar a conta a pagar para obter o source_reference_id
      const { data: accountPayable, error: fetchError } = await supabase
      .from('accounts_payable')
      .select('*')
      .eq('id', id)
      .single();

      if (fetchError) throw fetchError;

      // Verificar se já existe custo recorrente para este salário
      const { data: existingCosts, error: existingCostError } = await supabase
        .from('costs')
        .select('id')
        .eq('category', 'Salário')
        .eq('amount', accountPayable.amount)
        .eq('cost_date', accountPayable.due_date)
        .eq('description', `Salário Pago: ${accountPayable.description}`)
        .eq('is_recurring', true);

      if (existingCostError) throw existingCostError;

      if (existingCosts && existingCosts.length > 0) {
        // Já existe, só vincula
        await supabase
          .from('accounts_payable')
          .update({ cost_id: existingCosts[0].id })
          .eq('id', accountPayable.id);
        return;
      }

      // Atualizar a conta a pagar para paga
      const { error: updateError } = await supabase
        .from('accounts_payable')
        .update({ status: 'Pago' })
        .eq('id', id);

      if (updateError) throw updateError;

      // Se existe um source_reference_id, atualizar o custo correspondente
      if (accountPayable?.source_reference_id) {
        const { error: costUpdateError } = await supabase
        .from('costs')
          .update({ status: 'Pago' })
          .eq('id', accountPayable.source_reference_id);

        if (costUpdateError) {
          console.error('Erro ao atualizar custo:', costUpdateError);
          // Não falha a operação se não conseguir atualizar o custo
        }
      } else {
        // Se não existe um custo associado, criar um novo custo
        // Padronizar categoria para custos recorrentes conforme constraint do banco
        let recurringCategory = accountPayable.category;
        if (recurringCategory === 'Despesa Recorrente') recurringCategory = 'Despesas';
        if (recurringCategory === 'Seguro') recurringCategory = 'Seguro';
        const allowedCategories = [
          'Multa', 'Funilaria', 'Seguro', 'Avulsa', 'Compra',
          'Excesso Km', 'Diária Extra', 'Combustível', 'Avaria', 'Despesas'
        ];
        if (!allowedCategories.includes(recurringCategory)) recurringCategory = 'Despesas';
        console.log('Categoria do custo recorrente:', recurringCategory);

        // Para salários, sempre criar como custo recorrente
        if (accountPayable.category === 'Salário') {
          // Extrair o dia do mês da data de vencimento
          const dueDay = new Date(accountPayable.due_date).getDate();
          
          const recurringCostData: RecurringCostData = {
            category: 'Salário',
            description: `Salário Pago: ${accountPayable.description}`,
            amount: accountPayable.amount,
            cost_date: accountPayable.due_date,
            status: 'Pago',
            is_recurring: true,
            recurrence_type: 'monthly',
            recurrence_day: dueDay,
            origin: 'Financeiro',
            created_by_employee_id: null,
            created_by_name: 'Sistema',
            observations: `Pagamento de salário - ${new Date(accountPayable.due_date).toLocaleDateString('pt-BR', { month: '2-digit', year: 'numeric' })}`,
            vehicle_id: undefined,
            customer_id: undefined,
            customer_name: undefined,
            contract_id: undefined,
            parent_recurring_cost_id: undefined,
            auto_generated: false,
            guest_id: undefined,
            document_ref: undefined
          };

          const newRecurringCost = await createRecurringCost(recurringCostData);
          if (!newRecurringCost || !newRecurringCost.id) throw new Error('Falha ao criar custo recorrente do salário');

          // Atualizar a conta a pagar com o ID do custo recorrente criado
          await supabase
            .from('accounts_payable')
            .update({ cost_id: newRecurringCost.id })
            .eq('id', accountPayable.id);
        } else if (
          accountPayable.category === 'Despesa Recorrente' ||
          accountPayable.category === 'Seguro' ||
          accountPayable.category === 'Despesas'
        ) {
          // Extrair o dia do mês da data de vencimento
          const dueDay = new Date(accountPayable.due_date).getDate();
          
          const recurringCostData: RecurringCostData = {
            category: recurringCategory, // Sempre permitido pelo banco
            description: accountPayable.category === 'Salário' 
              ? `Salário Pago: ${accountPayable.description}`
              : `Despesa Recorrente: ${accountPayable.description}`,
            amount: accountPayable.amount,
            cost_date: accountPayable.due_date,
            status: 'Pago',
            is_recurring: true,
            recurrence_type: 'monthly',
            recurrence_day: dueDay,
            origin: 'Financeiro',
            created_by_employee_id: null,
            created_by_name: 'Sistema',
            observations: accountPayable.category === 'Salário'
              ? `Pagamento de salário via Financeiro - ${accountPayable.description}`
              : `Pagamento de conta a pagar recorrente - ${accountPayable.category}`,
            document_ref: undefined,
            department: 'Financeiro',
            vehicle_id: null,
            tenant_id: DEFAULT_TENANT_ID
          };
          
          await createRecurringCost(recurringCostData);
          return; // Evita duplicidade de lançamentos
        } else {
          // Todas as outras categorias são criadas como custos normais (avulsos)
          const costData = {
            tenant_id: DEFAULT_TENANT_ID,
            category: recurringCategory,
            vehicle_id: null,
            description: `Conta Paga: ${accountPayable.description}`,
            amount: accountPayable.amount,
            cost_date: accountPayable.due_date,
            status: 'Pago',
            document_ref: accountPayable.document_ref || `Conta Paga - ${accountPayable.category}`,
            observations: `Conta a pagar marcada como paga via Financeiro | Método de pagamento: ${accountPayable.payment_method || 'Não informado'} | Vencimento: ${accountPayable.due_date}`,
            origin: 'Financeiro',
            created_by_employee_id: null,
            source_reference_id: accountPayable.id,
            source_reference_type: 'manual',
            department: 'Financeiro',
            customer_id: undefined,
            customer_name: undefined,
            contract_id: undefined,
            is_recurring: false
          };

          const { error: costError } = await supabase
            .from('costs')
            .insert([costData]);

          if (costError) {
            console.error('Erro ao criar custo para conta paga:', costError);
            // Não falha a operação principal se o custo não for criado
          }
        }
      }

      // Se a conta a pagar é de uma despesa recorrente, gerar nova conta para o próximo mês
      if (accountPayable?.category === 'Despesa Recorrente') {
        await generateNextRecurringExpense(accountPayable);
      }

      await fetchAccountsPayable();
      await fetchSalaries();
      await fetchFinancialSummary();
    } catch (error) {
      console.error('Error marking as paid:', error);
      throw error;
    }
  };

  const createAccountPayable = async (accountData: Omit<AccountPayable, 'id' | 'created_at' | 'is_overdue' | 'days_overdue' | 'source_type'> & { created_by_employee_id?: string }) => {
    try {
      // Primeiro, criar a conta a pagar
      const { data: accountPayable, error: accountError } = await supabase
        .from('accounts_payable')
        .insert([{ 
          tenant_id: DEFAULT_TENANT_ID,
          description: accountData.description,
          amount: accountData.amount,
          due_date: accountData.due_date,
          category: accountData.category,
          status: accountData.status,
          supplier_id: accountData.supplier_id,
          document_ref: accountData.document_ref,
          payment_method: accountData.payment_method
        }])
        .select()
        .single();

      if (accountError) {
        throw accountError;
      }

      // Removido: criação de custo para contas avulsas aqui
      // O custo será criado apenas ao marcar como paga (markAsPaid)
      
      // Refresh data
      await fetchAccountsPayable();
      await fetchFinancialSummary();
      
      return accountPayable;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to create account payable');
    }
  };

  const createSalary = async (salaryData: Omit<Salary, 'id' | 'created_at' | 'updated_at' | 'employee_name' | 'employee_role' | 'employee_code' | 'reference_month_formatted'> & { created_by_employee_id?: string }) => {
    try {
      // Primeiro, criar o salário
      const { data: salary, error: salaryError } = await supabase
        .from('salaries')
        .insert([{ ...salaryData, tenant_id: DEFAULT_TENANT_ID }])
        .select()
        .single();

      if (salaryError) throw salaryError;

      // Buscar informações do funcionário
      const { data: employeeData } = await supabase
        .from('employees')
        .select('name, role, employee_code')
        .eq('id', salaryData.employee_id)
        .single();

      // Criar registro na tabela de custos como RECORRENTE
      const recurrenceDay = new Date(salaryData.payment_date).getDate();
      const recurrence_type = 'monthly' as const;
      const recurringCostData = {
        tenant_id: DEFAULT_TENANT_ID,
        category: 'Salário',
        vehicle_id: null,
        description: `Salário - ${employeeData?.name || 'Funcionário'} - ${salaryData.reference_month}`,
        amount: salaryData.amount,
        cost_date: salaryData.payment_date,
        status: salaryData.status,
        document_ref: undefined,
        observations: `Salário registrado via Financeiro | Funcionário: ${employeeData?.name} (${employeeData?.role}) | Mês de referência: ${salaryData.reference_month} | Responsável pelo lançamento: ${salaryData.created_by_employee_id || 'Sistema'}`,
        origin: 'Usuario',
        created_by_employee_id: salaryData.created_by_employee_id || null,
        source_reference_id: salary.id,
        source_reference_type: 'manual',
        department: 'Financeiro',
        customer_id: undefined,
        customer_name: undefined,
        contract_id: undefined,
        is_recurring: true,
        recurrence_type,
        recurrence_day: recurrenceDay,
        next_due_date: undefined, // será calculado pela função de custos recorrentes
        parent_recurring_cost_id: undefined,
        auto_generated: false,
        guest_id: undefined
      };

      await createRecurringCost(recurringCostData);
      
      // Refresh data
      await fetchSalaries();
      await fetchAccountsPayable();
      await fetchFinancialSummary();
      
      return salary;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to create salary');
    }
  };

  const createRecurringExpense = async (expenseData: Omit<RecurringExpense, 'id' | 'created_at' | 'updated_at'>) => {
    try {
      const { data, error } = await supabase
        .from('recurring_expenses')
        .insert([{ ...expenseData, tenant_id: DEFAULT_TENANT_ID }])
        .select()
        .single();

      if (error) throw error;
      
      // Refresh data
      await fetchRecurringExpenses();
      
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to create recurring expense');
    }
  };

  const createRecurringCost = async (costData: RecurringCostData) => {
    try {
      // Calcular próxima data de vencimento
      const costDate = new Date(costData.cost_date);
      const nextDueDate = new Date(costDate);
      
      switch (costData.recurrence_type || 'monthly') {
        case 'monthly':
          nextDueDate.setMonth(nextDueDate.getMonth() + 1);
          break;
        case 'weekly':
          nextDueDate.setDate(nextDueDate.getDate() + 7);
          break;
        case 'yearly':
          nextDueDate.setFullYear(nextDueDate.getFullYear() + 1);
          break;
      }

      const costToInsert = {
        ...costData,
        tenant_id: costData.tenant_id || DEFAULT_TENANT_ID,
        status: costData.status || 'Pendente',
        auto_generated: costData.auto_generated || false,
        origin: costData.origin || 'Usuario',
        next_due_date: nextDueDate.toISOString().split('T')[0],
        is_recurring: true,
        parent_recurring_cost_id: costData.parent_recurring_cost_id === '' ? null : costData.parent_recurring_cost_id ?? null,
        vehicle_id: costData.vehicle_id === '' ? null : costData.vehicle_id,
        customer_id: costData.customer_id === '' ? null : costData.customer_id,
        contract_id: costData.contract_id === '' ? null : costData.contract_id,
        guest_id: costData.guest_id === '' ? null : costData.guest_id,
      };

      const { data, error } = await supabase
        .from('costs')
        .insert([costToInsert])
        .select()
        .single();

      if (error) throw error;
      
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to create recurring cost');
    }
  };

  const generateRecurringExpenses = async (month: Date) => {
    try {
      const { data, error } = await supabase
        .rpc('fn_generate_recurring_expenses', { 
          p_tenant_id: DEFAULT_TENANT_ID,
          p_month: month.toISOString().slice(0, 7) + '-01'
        });

      if (error) throw error;
      return data || 0;
    } catch (err) {
      console.error('Error generating recurring expenses:', err);
      throw new Error('Failed to generate recurring expenses');
    }
  };

  // Função auxiliar para gerar próxima conta recorrente ao pagar
  const generateNextRecurringExpense = async (accountPayable: AccountPayable) => {
    try {
      // Buscar a despesa recorrente correspondente
      const { data: recurringExpense, error: fetchError } = await supabase
        .from('recurring_expenses')
        .select('*')
        .eq('description', accountPayable.description)
        .eq('amount', accountPayable.amount)
        .eq('category', accountPayable.category)
        .eq('is_active', true)
        .single();

      if (fetchError || !recurringExpense) {
        console.warn('Despesa recorrente não encontrada para:', accountPayable.description);
        return;
      }

      // Calcular a próxima data de vencimento
      const currentDueDate = new Date(accountPayable.due_date);
      const nextDueDate = new Date(currentDueDate);
      nextDueDate.setMonth(nextDueDate.getMonth() + 1);
      nextDueDate.setDate(recurringExpense.due_day);

      // Criar nova conta a pagar para o próximo mês
      const { data: newAccountPayable, error: createError } = await supabase
        .from('accounts_payable')
        .insert([{
          tenant_id: DEFAULT_TENANT_ID,
          description: recurringExpense.description,
          amount: recurringExpense.amount,
          due_date: nextDueDate.toISOString().split('T')[0],
          category: recurringExpense.category,
          status: 'Pendente',
          supplier_id: null,
          document_ref: `Recorrente - ${recurringExpense.description}`,
          payment_method: recurringExpense.payment_method
        }])
        .select()
        .single();

      if (createError) {
        console.error('Erro ao criar nova conta recorrente:', createError);
        return;
      }

      // Atualizar a data da última geração na despesa recorrente
      await supabase
        .from('recurring_expenses')
        .update({ last_generated_date: nextDueDate.toISOString().split('T')[0] })
        .eq('id', recurringExpense.id);

      console.log('Nova conta recorrente criada:', newAccountPayable.id);
    } catch (error) {
      console.error('Erro ao gerar próxima despesa recorrente:', error);
    }
  };

  const generateSalaries = async (month: Date) => {
    try {
      const { data, error } = await supabase
        .rpc('fn_generate_salary_payments', { 
          p_tenant_id: DEFAULT_TENANT_ID,
          p_month: month.toISOString()
        });

      if (error) throw error;
      
      // Refresh data
      await fetchAccountsPayable();
      await fetchSalaries();
      await fetchFinancialSummary();
      
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to generate salaries');
    }
  };

  const syncCostsToAccountsPayable = async () => {
    try {
      const { data, error } = await supabase
        .rpc('fn_sync_costs_to_accounts_payable', { 
          p_tenant_id: DEFAULT_TENANT_ID
        });

      if (error) throw error;
      
      // Refresh data
      await fetchAccountsPayable();
      await fetchFinancialSummary();
      
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to sync costs');
    }
  };

  const deleteRecurringExpense = async (id: string) => {
    try {
      const { error } = await supabase
        .from('recurring_expenses')
        .delete()
        .eq('id', id)
        .eq('tenant_id', DEFAULT_TENANT_ID);
      if (error) throw error;
      await fetchRecurringExpenses();
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to delete recurring expense');
    }
  };

  const updateSalary = async (id: string, updates: Partial<Salary>) => {
    try {
      // Buscar o salário para obter o source_reference_id
      const { data: salary, error: fetchError } = await supabase
        .from('salaries')
        .select('*')
        .eq('id', id)
        .single();

      if (fetchError) throw fetchError;

      // Atualizar o salário
      const { error: updateError } = await supabase
      .from('salaries')
      .update(updates)
        .eq('id', id);

      if (updateError) throw updateError;

      // Se existe um source_reference_id e o status foi alterado, atualizar o custo correspondente
      if (salary?.source_reference_id && updates.status) {
        const { error: costUpdateError } = await supabase
          .from('costs')
          .update({ status: updates.status })
          .eq('id', salary.source_reference_id);

        if (costUpdateError) {
          console.error('Erro ao atualizar custo:', costUpdateError);
          // Não falha a operação se não conseguir atualizar o custo
        }
      }

    await fetchSalaries();
      await fetchAccountsPayable();
      await fetchFinancialSummary();
    } catch (error) {
      console.error('Error updating salary:', error);
      throw error;
    }
  };

  const deleteSalary = async (id: string) => {
    const { error } = await supabase
      .from('salaries')
      .delete()
      .eq('id', id);
    if (error) throw error;
    await fetchSalaries();
  };

  useEffect(() => {
    fetchAccountsPayable();
    fetchSalaries();
    fetchRecurringExpenses();
    fetchFinancialSummary();
  }, []);

  return {
    accountsPayable,
    salaries,
    recurringExpenses,
    summary,
    loading,
    error,
    markAsPaid,
    createSalary,
    createRecurringExpense,
    createRecurringCost,
    createAccountPayable,
    generateRecurringExpenses,
    generateSalaries,
    syncCostsToAccountsPayable,
    deleteRecurringExpense,
    updateSalary,
    deleteSalary,
    refetch: async () => {
      await fetchAccountsPayable();
      await fetchSalaries();
      await fetchFinancialSummary();
    }
  };
};