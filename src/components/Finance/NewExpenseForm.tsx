import React, { useState } from 'react';
import { Card, CardHeader, CardContent } from '../UI/Card';
import { Button } from '../UI/Button';
import { Plus, DollarSign, Calendar, FileText, Loader2 } from 'lucide-react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import toast from 'react-hot-toast';
import { useFinance } from '../../hooks/useFinance';

// Form validation schema
const expenseSchema = z.object({
  description: z.string().min(3, 'A descrição deve ter pelo menos 3 caracteres'),
  amount: z.number().min(0.01, 'O valor deve ser maior que zero'),
  due_date: z.string().min(1, 'A data de vencimento é obrigatória'),
  category: z.string().min(1, 'A categoria é obrigatória'),
  payment_method: z.string().optional(),
  notes: z.string().optional(),
});

type ExpenseFormValues = z.infer<typeof expenseSchema>;

interface NewExpenseFormProps {
  onCreateExpense: (data: ExpenseFormValues) => Promise<void>;
  loading: boolean;
}

export const NewExpenseForm: React.FC<NewExpenseFormProps> = ({
  onCreateExpense,
  loading
}) => {
  const [isFormOpen, setIsFormOpen] = useState(false);
  const { createRecurringExpense } = useFinance();
  const [submitting, setSubmitting] = useState(false);

  // Form
  const { register, handleSubmit, reset, formState: { errors } } = useForm<ExpenseFormValues>({
    resolver: zodResolver(expenseSchema),
    defaultValues: {
      description: '',
      amount: 0,
      due_date: new Date().toISOString().split('T')[0],
      category: '',
      payment_method: '',
      notes: '',
    },
  });

  // Handle form submission
  const onSubmit = async (data: ExpenseFormValues) => {
    if (submitting) return;
    setSubmitting(true);
    try {
      if (data.category === 'Despesa Recorrente') {
        // Extrair o dia do mês da data de vencimento
        const dueDay = new Date(data.due_date).getDate();
        // Criar despesa recorrente
        const recurring = await createRecurringExpense({
          description: data.description,
          amount: Number(data.amount),
          due_day: dueDay,
          category: data.category,
          is_active: true,
          payment_method: data.payment_method,
          notes: data.notes
        });
        // Criar o próximo lançamento em accounts_payable vinculado à recorrente
        if (recurring && recurring.id) {
          // Calcular próxima data de vencimento
          const now = new Date();
          const nextDue = new Date(now.getFullYear(), now.getMonth(), dueDay);
          if (nextDue < now) {
            nextDue.setMonth(nextDue.getMonth() + 1);
          }
          await onCreateExpense({
            description: data.description,
            amount: Number(data.amount),
            due_date: nextDue.toISOString().split('T')[0],
            category: data.category,
            payment_method: data.payment_method,
            notes: (data.notes ? data.notes + ' ' : '') + `(recorrente:${recurring.id})`
          });
        }
      } else {
        // Criar a despesa (conta a pagar) apenas para Avulsa
        await onCreateExpense({
          ...data,
          amount: Number(data.amount),
        });
      }
      toast.success('Despesa criada com sucesso!');
      reset();
      setIsFormOpen(false);
    } catch {
      toast.error('Erro ao criar despesa');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Card>
      <CardHeader className="p-4 lg:p-6">
        <div className="flex justify-between items-center">
          <h3 className="text-lg font-semibold text-secondary-900">Nova Despesa</h3>
          <Button 
            onClick={() => setIsFormOpen(!isFormOpen)}
            size="sm"
            variant={isFormOpen ? "secondary" : "primary"}
          >
            {isFormOpen ? 'Cancelar' : (
              <>
                <Plus className="h-4 w-4 mr-2" />
                Nova Despesa
              </>
            )}
          </Button>
        </div>
      </CardHeader>
      {isFormOpen && (
        <CardContent className="p-4 lg:p-6">
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label htmlFor="description" className="block text-sm font-medium text-secondary-700 mb-1">
                  Descrição *
                </label>
                <input
                  id="description"
                  type="text"
                  {...register('description')}
                  className="w-full px-3 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                  placeholder="Descrição da despesa"
                />
                {errors.description && (
                  <p className="mt-1 text-sm text-error-600">{errors.description.message}</p>
                )}
              </div>

              <div>
                <label htmlFor="category" className="block text-sm font-medium text-secondary-700 mb-1">
                  Categoria *
                </label>
                <select
                  id="category"
                  {...register('category')}
                  className="w-full px-3 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                >
                  <option value="">Selecione uma categoria</option>
                  <option value="Despesa Recorrente">Despesa Recorrente</option>
                  <option value="Avulsa">Avulsa</option>
                </select>
                {errors.category && (
                  <p className="mt-1 text-sm text-error-600">{errors.category.message}</p>
                )}
              </div>

              <div>
                <label htmlFor="amount" className="block text-sm font-medium text-secondary-700 mb-1">
                  Valor (R$) *
                </label>
                <div className="relative">
                  <DollarSign className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
                  <input
                    id="amount"
                    type="number"
                    step="0.01"
                    min="0.01"
                    {...register('amount', { valueAsNumber: true })}
                    className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                    placeholder="0,00"
                  />
                </div>
                {errors.amount && (
                  <p className="mt-1 text-sm text-error-600">{errors.amount.message}</p>
                )}
              </div>

              <div>
                <label htmlFor="due_date" className="block text-sm font-medium text-secondary-700 mb-1">
                  Data de Vencimento *
                </label>
                <div className="relative">
                  <Calendar className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
                  <input
                    id="due_date"
                    type="date"
                    {...register('due_date')}
                    className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                  />
                </div>
                {errors.due_date && (
                  <p className="mt-1 text-sm text-error-600">{errors.due_date.message}</p>
                )}
              </div>

              <div>
                <label htmlFor="payment_method" className="block text-sm font-medium text-secondary-700 mb-1">
                  Forma de Pagamento
                </label>
                <select
                  id="payment_method"
                  {...register('payment_method')}
                  className="w-full px-3 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                >
                  <option value="">Selecione uma forma de pagamento</option>
                  <option value="Boleto">Boleto</option>
                  <option value="Transferência">Transferência</option>
                  <option value="Cartão de Crédito">Cartão de Crédito</option>
                  <option value="Débito Automático">Débito Automático</option>
                  <option value="Dinheiro">Dinheiro</option>
                  <option value="Pix">Pix</option>
                </select>
              </div>

              <div className="md:col-span-2">
                <label htmlFor="notes" className="block text-sm font-medium text-secondary-700 mb-1">
                  Observações
                </label>
                <div className="relative">
                  <FileText className="absolute left-3 top-3 h-4 w-4 text-secondary-400" />
                  <textarea
                    id="notes"
                    {...register('notes')}
                    rows={3}
                    className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                    placeholder="Observações adicionais..."
                  />
                </div>
              </div>
            </div>

            <div className="flex justify-end">
              <Button
                type="submit"
                disabled={loading || submitting}
              >
                {(loading || submitting) ? (
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                ) : (
                  <Plus className="h-4 w-4 mr-2" />
                )}
                Criar Despesa
              </Button>
            </div>
          </form>
        </CardContent>
      )}
    </Card>
  );
};

export default NewExpenseForm;