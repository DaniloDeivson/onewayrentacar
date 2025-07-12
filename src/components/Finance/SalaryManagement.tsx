import React, { useState } from 'react';
import { Card, CardHeader, CardContent } from '../UI/Card';
import { Badge } from '../UI/Badge';
import { Button } from '../UI/Button';
import { Search, Filter, UserCheck, DollarSign, Calendar, CheckCircle, Loader2, FileText, Plus } from 'lucide-react';
import { Salary } from '../../hooks/useFinance';
import { useEmployees } from '../../hooks/useEmployees';
import { useAuth } from '../../hooks/useAuth';
import { Employee } from '../../types/database';

interface SalaryManagementProps {
  salaries: Salary[];
  onMarkAsPaid: (id: string) => Promise<void>;
  onGenerateSalaries: (month: Date) => Promise<void>;
  loading: boolean;
}

interface EditSalaryModalProps {
  isOpen: boolean;
  onClose: () => void;
  salary: Salary | null;
  onSave: (id: string, updates: Partial<Salary>) => Promise<void>;
  loading: boolean;
}

interface NewSalaryModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (data: { employee_id: string; amount: number; payment_date: string; status: string; reference_month: string }) => Promise<void>;
  loading: boolean;
}

interface EmployeePayrollModalProps {
  isOpen: boolean;
  onClose: () => void;
  employee: Employee | null;
  salaries: Salary[];
  onMarkAsPaid: (id: string) => Promise<void>;
  onCreateSalary: (data: { employee_id: string; amount: number; payment_date: string; status: string; reference_month: string }) => Promise<void>;
  onEditSalary: (id: string, updates: Partial<Salary>) => Promise<void>;
  onDeleteSalary: (id: string) => Promise<void>;
  loading: boolean;
}

const EditSalaryModal: React.FC<EditSalaryModalProps> = ({ isOpen, onClose, salary, onSave, loading }) => {
  const [amount, setAmount] = useState(salary?.amount || 0);

  React.useEffect(() => {
    setAmount(salary?.amount || 0);
  }, [salary]);

  if (!isOpen || !salary) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await onSave(salary.id, { amount });
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 w-full max-w-md">
        <h2 className="text-lg font-semibold mb-4">Editar Salário</h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Valor do Salário (R$)</label>
            <input
              type="number"
              value={amount}
              onChange={e => setAmount(Number(e.target.value))}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2"
              min={0}
              required
            />
          </div>
          <div className="flex justify-end space-x-2">
            <Button type="button" variant="secondary" onClick={onClose} disabled={loading}>Cancelar</Button>
            <Button type="submit" variant="primary" disabled={loading}>Salvar</Button>
          </div>
        </form>
      </div>
    </div>
  );
};

const NewSalaryModal: React.FC<NewSalaryModalProps> = ({ isOpen, onClose, onSave, loading }) => {
  const [employee_id, setEmployeeId] = useState('');
  const [amount, setAmount] = useState(0);
  const [payment_date, setPaymentDate] = useState('');
  const [status, setStatus] = useState('Pendente');
  const [reference_month, setReferenceMonth] = useState('');
  const { employees, loading: loadingEmployees } = useEmployees();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!employee_id || !amount || !payment_date || !reference_month) {
      alert('Preencha todos os campos obrigatórios!');
      return;
    }
    // Converte YYYY-MM para YYYY-MM-01 (date)
    const refMonthDate = reference_month.length === 7 ? `${reference_month}-01` : reference_month;
    await onSave({ employee_id, amount, payment_date, status, reference_month: refMonthDate });
    onClose();
    setEmployeeId(''); setAmount(0); setPaymentDate(''); setStatus('Pendente'); setReferenceMonth('');
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 w-full max-w-md">
        <h2 className="text-lg font-semibold mb-4">Adicionar Salário</h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Funcionário</label>
            <select
              value={employee_id}
              onChange={e => setEmployeeId(e.target.value)}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2"
              required
              disabled={loadingEmployees}
            >
              <option value="">Selecione o funcionário</option>
              {employees.map(emp => (
                <option key={emp.id} value={emp.id}>
                  {emp.name} ({emp.role})
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Valor do Salário (R$)</label>
            <input
              type="number"
              value={amount}
              onChange={e => setAmount(Number(e.target.value))}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2"
              min={0}
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Data de Pagamento</label>
            <input
              type="date"
              value={payment_date}
              onChange={e => setPaymentDate(e.target.value)}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2"
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Status</label>
            <select
              value={status}
              onChange={e => setStatus(e.target.value)}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2"
              required
            >
              <option value="Pendente">Pendente</option>
              <option value="Pago">Pago</option>
              <option value="Autorizado">Autorizado</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Mês de Referência (MM-YYYY)</label>
            <input
              type="month"
              value={reference_month}
              onChange={e => setReferenceMonth(e.target.value)}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2"
              required
            />
          </div>
          <div className="flex justify-end space-x-2">
            <Button type="button" variant="secondary" onClick={onClose} disabled={loading}>Cancelar</Button>
            <Button type="submit" variant="primary" disabled={loading}>Salvar</Button>
          </div>
        </form>
      </div>
    </div>
  );
};

const EmployeePayrollModal: React.FC<EmployeePayrollModalProps> = ({
  isOpen,
  onClose,
  employee,
  salaries,
  onMarkAsPaid,
  onCreateSalary,
  onEditSalary,
  onDeleteSalary,
  loading
}) => {
  const { isAdmin, isManager } = useAuth();
  const [showExtraForm, setShowExtraForm] = useState(false);
  const [extraAmount, setExtraAmount] = useState(0);
  const [extraDate, setExtraDate] = useState('');
  const [extraRefMonth, setExtraRefMonth] = useState('');
  const [extraObs, setExtraObs] = useState('');
  const [editSalaryId, setEditSalaryId] = useState<string | null>(null);
  const [editAmount, setEditAmount] = useState(0);
  const [editDate, setEditDate] = useState('');
  const [editStatus, setEditStatus] = useState<'Pendente' | 'Pago' | 'Autorizado'>('Pendente');

  if (!isOpen || !employee) return null;
  
  const employeeSalaries = salaries.filter(s => s.employee_id === employee.id);
  const pagos = employeeSalaries.filter(s => s.status === 'Pago');
  const pendentes = employeeSalaries.filter(s => s.status === 'Pendente');
  const autorizados = employeeSalaries.filter(s => s.status === 'Autorizado');
  const extras = employeeSalaries.filter(s => (s as { is_extra?: boolean }).is_extra);

  // Calcular totais
  const totalPago = pagos.reduce((sum, s) => sum + s.amount, 0);
  const totalPendente = pendentes.reduce((sum, s) => sum + s.amount, 0);
  const totalAutorizado = autorizados.reduce((sum, s) => sum + s.amount, 0);
  const totalExtras = extras.reduce((sum, s) => sum + s.amount, 0);

  // Função para registrar pagamento extra
  const handleSaveExtra = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!extraAmount || !extraDate || !extraRefMonth) {
      alert('Preencha todos os campos obrigatórios!');
      return;
    }
    await onCreateSalary({
      employee_id: employee.id,
      amount: extraAmount,
      payment_date: extraDate,
      status: 'Pago',
      reference_month: extraRefMonth,
      is_extra: true
    });
    setShowExtraForm(false);
    setExtraAmount(0);
    setExtraDate('');
    setExtraRefMonth('');
    setExtraObs('');
  };

  // Função para editar salário
  const handleEditSalary = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editSalaryId) return;
    await onEditSalary(editSalaryId, {
      amount: editAmount,
      payment_date: editDate,
      status: editStatus
    });
    setEditSalaryId(null);
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-6 w-full max-w-4xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-6">
          <div>
            <h2 className="text-xl font-semibold text-secondary-900">Folha de Pagamento - {employee.name}</h2>
            <p className="text-secondary-600 mt-1">{translateRole(employee.role)} • {employee.active ? 'Ativo' : 'Inativo'}</p>
          </div>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">×</button>
        </div>

        {/* Resumo Financeiro */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <div className="bg-green-50 border border-green-200 rounded-lg p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-green-700 text-sm font-medium">Total Pago</p>
                <p className="text-green-900 text-xl font-bold">R$ {totalPago.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}</p>
                <p className="text-green-600 text-xs">{pagos.length} pagamento{pagos.length !== 1 ? 's' : ''}</p>
              </div>
              <CheckCircle className="h-8 w-8 text-green-600" />
            </div>
          </div>

          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-yellow-700 text-sm font-medium">Pendente</p>
                <p className="text-yellow-900 text-xl font-bold">R$ {totalPendente.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}</p>
                <p className="text-yellow-600 text-xs">{pendentes.length} salário{pendentes.length !== 1 ? 's' : ''}</p>
              </div>
              <Calendar className="h-8 w-8 text-yellow-600" />
            </div>
          </div>

          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-blue-700 text-sm font-medium">Autorizado</p>
                <p className="text-blue-900 text-xl font-bold">R$ {totalAutorizado.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}</p>
                <p className="text-blue-600 text-xs">{autorizados.length} salário{autorizados.length !== 1 ? 's' : ''}</p>
              </div>
              <UserCheck className="h-8 w-8 text-blue-600" />
            </div>
          </div>

          <div className="bg-purple-50 border border-purple-200 rounded-lg p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-purple-700 text-sm font-medium">Extras</p>
                <p className="text-purple-900 text-xl font-bold">R$ {totalExtras.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}</p>
                <p className="text-purple-600 text-xs">{extras.length} pagamento{extras.length !== 1 ? 's' : ''}</p>
              </div>
              <DollarSign className="h-8 w-8 text-purple-600" />
            </div>
          </div>
        </div>

        {/* Histórico Completo */}
        <div className="mb-6">
          <h3 className="text-lg font-semibold text-secondary-900 mb-4 flex items-center">
            <FileText className="h-5 w-5 mr-2" />
            Histórico Completo de Pagamentos
          </h3>
          
          {employeeSalaries.length === 0 ? (
            <div className="text-center py-8 bg-secondary-50 rounded-lg">
              <UserCheck className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
              <p className="text-secondary-600">Nenhum registro de pagamento encontrado</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-secondary-200">
                <thead className="bg-secondary-50">
                  <tr>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-secondary-700">Mês de Referência</th>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-secondary-700">Data de Pagamento</th>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-secondary-700">Valor</th>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-secondary-700">Status</th>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-secondary-700">Tipo</th>
                  {(isAdmin || isManager) && (
                      <th className="px-4 py-3 text-left text-xs font-semibold text-secondary-700">Ações</th>
                    )}
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-secondary-100">
                  {employeeSalaries
                    .sort((a, b) => new Date(b.payment_date).getTime() - new Date(a.payment_date).getTime())
                    .map((salary) => (
                      <tr key={salary.id} className="hover:bg-secondary-25">
                        <td className="px-4 py-3 text-sm text-secondary-900 font-medium">
                          {salary.reference_month_formatted}
                        </td>
                        <td className="px-4 py-3 text-sm text-secondary-700">
                          {new Date(salary.payment_date).toLocaleDateString('pt-BR')}
                        </td>
                        <td className="px-4 py-3 text-sm font-semibold text-secondary-900">
                          R$ {salary.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                        </td>
                        <td className="px-4 py-3">
                          <Badge 
                            variant={
                              salary.status === 'Pago' ? 'success' : 
                              salary.status === 'Autorizado' ? 'info' : 'warning'
                            }
                          >
                            {salary.status}
                          </Badge>
                        </td>
                        <td className="px-4 py-3 text-sm text-secondary-700">
                          {(salary as { is_extra?: boolean }).is_extra ? (
                            <Badge variant="secondary" className="bg-purple-100 text-purple-800">
                              Extra
                            </Badge>
                          ) : (
                            <Badge variant="secondary" className="bg-blue-100 text-blue-800">
                              Regular
                            </Badge>
                          )}
                        </td>
                        {(isAdmin || isManager) && (
                          <td className="px-4 py-3">
                            <div className="flex gap-2">
                              <Button
                                size="sm"
                                variant="secondary"
                                onClick={() => {
                                  setEditSalaryId(salary.id);
                                  setEditAmount(salary.amount);
                                  setEditDate(salary.payment_date);
                                  setEditStatus(salary.status);
                                }}
                              >
                                Editar
                              </Button>
                              {salary.status !== 'Pago' && (
                                <Button
                                  size="sm"
                                  variant="success"
                                  onClick={() => onMarkAsPaid(salary.id)}
                                  disabled={loading}
                                >
                      Pagar
                    </Button>
                  )}
                              <Button
                                size="sm"
                                variant="error"
                                onClick={() => onDeleteSalary(salary.id)}
                                disabled={loading}
                              >
                                Remover
                              </Button>
        </div>
                          </td>
                        )}
                      </tr>
                    ))}
                </tbody>
              </table>
        </div>
          )}
        </div>

        {/* Botão para adicionar pagamento extra */}
        {(isAdmin || isManager) && (
          <div className="border-t border-secondary-200 pt-4">
            <Button 
              onClick={() => setShowExtraForm(true)}
              variant="primary"
              className="w-full sm:w-auto"
            >
              <Plus className="h-4 w-4 mr-2" />
              Registrar Pagamento Extra
            </Button>
          </div>
        )}

        {/* Formulário de pagamento extra */}
            {showExtraForm && (
          <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50">
            <div className="bg-white rounded-lg p-6 w-full max-w-md">
              <h3 className="text-lg font-semibold mb-4">Registrar Pagamento Extra</h3>
              <form onSubmit={handleSaveExtra} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-1">
                    Valor do Extra (R$)
                  </label>
                  <input
                    type="number"
                    value={extraAmount}
                    onChange={e => setExtraAmount(Number(e.target.value))}
                    required
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    min="0.01"
                    step="0.01"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-1">
                    Data do Pagamento
                  </label>
                  <input
                    type="date"
                    value={extraDate}
                    onChange={e => setExtraDate(e.target.value)}
                    required
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-1">
                    Mês de Referência
                  </label>
                  <input
                    type="month"
                    value={extraRefMonth}
                    onChange={e => setExtraRefMonth(e.target.value)}
                    required
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-1">
                    Observações
                  </label>
                  <input
                    type="text"
                    value={extraObs}
                    onChange={e => setExtraObs(e.target.value)}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    placeholder="Motivo do pagamento extra..."
                  />
                </div>
                <div className="flex gap-2 pt-4">
                  <Button type="submit" variant="primary" className="flex-1">
                    Salvar Extra
                  </Button>
                  <Button 
                    type="button" 
                    variant="secondary" 
                    onClick={() => setShowExtraForm(false)}
                    className="flex-1"
                  >
                    Cancelar
                  </Button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal de edição de salário */}
        {editSalaryId && (
          <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50">
            <div className="bg-white rounded-lg p-6 w-full max-w-md">
              <h3 className="text-lg font-semibold mb-4">Editar Salário</h3>
              <form onSubmit={handleEditSalary} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-1">
                    Valor (R$)
                  </label>
                  <input
                    type="number"
                    value={editAmount}
                    onChange={e => setEditAmount(Number(e.target.value))}
                    required
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    min="0.01"
                    step="0.01"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-1">
                    Data de Pagamento
                  </label>
                  <input
                    type="date"
                    value={editDate}
                    onChange={e => setEditDate(e.target.value)}
                    required
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-secondary-700 mb-1">
                    Status
                  </label>
                  <select
                    value={editStatus}
                    onChange={e => setEditStatus(e.target.value as any)}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  >
                    <option value="Pendente">Pendente</option>
                    <option value="Autorizado">Autorizado</option>
                    <option value="Pago">Pago</option>
                  </select>
                </div>
                <div className="flex gap-2 pt-4">
                  <Button type="submit" variant="primary" className="flex-1">
                    Salvar
                  </Button>
                  <Button 
                    type="button" 
                    variant="secondary" 
                    onClick={() => setEditSalaryId(null)}
                    className="flex-1"
                  >
                    Cancelar
                  </Button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

const translateRole = (role: string) => {
  switch (role) {
    case 'Admin': return 'Administrador';
    case 'Manager': return 'Gerente';
    case 'Sales': return 'Vendas';
    case 'Mechanic': return 'Mecânico';
    case 'User': return 'Usuário';
    case 'Driver': return 'Motorista';
    case 'Inspector': return 'Inspetor';
    case 'FineAdmin': return 'Administrador de Multas';
    case 'Finance': return 'Financeiro';
    case 'HR': return 'Recursos Humanos';
    case 'IT': return 'Tecnologia da Informação';
    case 'Maintenance': return 'Manutenção';
    case 'Operations': return 'Operações';
    case 'CustomerService': return 'Atendimento ao Cliente';
    case 'Supervisor': return 'Supervisor';
    case 'Coordinator': return 'Coordenador';
    case 'Assistant': return 'Assistente';
    case 'Analyst': return 'Analista';
    case 'Specialist': return 'Especialista';
    case 'Technician': return 'Técnico';
    case 'Operator': return 'Operador';
    case 'Receptionist': return 'Recepcionista';
    case 'Accountant': return 'Contador';
    case 'Secretary': return 'Secretário';
    case 'Cleaner': return 'Auxiliar de Limpeza';
    case 'Security': return 'Segurança';
    case 'Cook': return 'Cozinheiro';
    case 'Waiter': return 'Garçom';
    case 'Cashier': return 'Caixa';
    case 'Stockist': return 'Almoxarife';
    case 'Purchaser': return 'Comprador';
    case 'Seller': return 'Vendedor';
    case 'Consultant': return 'Consultor';
    case 'Advisor': return 'Assessor';
    case 'Director': return 'Diretor';
    case 'President': return 'Presidente';
    case 'VicePresident': return 'Vice-Presidente';
    case 'CEO': return 'Diretor Executivo';
    case 'CFO': return 'Diretor Financeiro';
    case 'CTO': return 'Diretor de Tecnologia';
    case 'COO': return 'Diretor de Operações';
    case 'Intern': return 'Estagiário';
    case 'Trainee': return 'Trainee';
    case 'Junior': return 'Júnior';
    case 'Senior': return 'Sênior';
    case 'Lead': return 'Líder';
    case 'Head': return 'Chefe';
    case 'Chief': return 'Chefe';
    default: return role;
  }
};

export const SalaryManagement: React.FC<SalaryManagementProps & {
  onEditSalary: (id: string, updates: Partial<Salary>) => Promise<void>;
  onDeleteSalary: (id: string) => Promise<void>;
  onCreateSalary: (data: { employee_id: string; amount: number; payment_date: string; status: string; reference_month: string }) => Promise<void>;
}> = ({
  salaries,
  onMarkAsPaid,
  onGenerateSalaries,
  loading,
  onEditSalary,
  onDeleteSalary,
  onCreateSalary
}) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [isGenerating, setIsGenerating] = useState(false);
  const [editModalOpen, setEditModalOpen] = useState(false);
  const [salaryToEdit, setSalaryToEdit] = useState<Salary | null>(null);
  const [newModalOpen, setNewModalOpen] = useState(false);
  const { employees } = useEmployees();
  const [payrollModalOpen, setPayrollModalOpen] = useState(false);
  const [selectedEmployee, setSelectedEmployee] = useState<Employee | null>(null);

  // Handle generate salaries for current month
  const handleGenerateSalaries = async () => {
    setIsGenerating(true);
    try {
      await onGenerateSalaries(new Date());
    } finally {
      setIsGenerating(false);
    }
  };

  return (
    <Card>
      <CardHeader className="p-4 lg:p-6">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <h3 className="text-lg font-semibold text-secondary-900">Folha de Pagamento</h3>
          <div className="flex gap-2">
            <Button 
              onClick={handleGenerateSalaries}
              disabled={isGenerating}
              size="sm"
            >
              {isGenerating ? (
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              ) : (
                <DollarSign className="h-4 w-4 mr-2" />
              )}
              Gerar Folha do Mês
            </Button>
            <Button
              onClick={() => setNewModalOpen(true)}
              size="sm"
              variant="primary"
            >
              + Adicionar Salário
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
                placeholder="Buscar por funcionário ou mês..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              />
            </div>
          </div>
          <div className="flex space-x-2">
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
            <Button variant="secondary" size="sm">
              <Filter className="h-4 w-4 mr-2" />
              Filtros
            </Button>
          </div>
        </div>

        {/* Salaries List */}
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-secondary-200 text-sm">
            <thead className="bg-secondary-50">
              <tr>
                <th className="px-4 py-2 text-left font-semibold text-secondary-700">Funcionário</th>
                <th className="px-4 py-2 text-left font-semibold text-secondary-700">Mês de Referência</th>
                <th className="px-4 py-2 text-left font-semibold text-secondary-700">Data de Pagamento</th>
                <th className="px-4 py-2 text-left font-semibold text-secondary-700">Valor</th>
                <th className="px-4 py-2 text-left font-semibold text-secondary-700">Cargo</th>
                <th className="px-4 py-2 text-left font-semibold text-secondary-700">Status</th>
                <th className="px-4 py-2 text-left font-semibold text-secondary-700">Ações</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-secondary-200">
              {employees
                .map(emp => {
                  // Pega o salário mais recente do funcionário
                  const empSalaries = salaries.filter(s => s.employee_id === emp.id);
                  const latestSalary = empSalaries.length > 0 ? empSalaries[0] : null;
                  return { employee: emp, latestSalary };
                })
                .filter(item => item.latestSalary) // Só mostra funcionários com salários
                .map(item => {
                  const { employee: emp, latestSalary } = item;
                  if (!latestSalary) return null; // TypeScript guard
                  return (
                    <tr key={emp.id} className="hover:bg-secondary-25">
                      <td className="px-4 py-2 font-medium text-secondary-900">{emp.name}</td>
                      <td className="px-4 py-2">{latestSalary.reference_month_formatted}</td>
                      <td className="px-4 py-2">{new Date(latestSalary.payment_date).toLocaleDateString('pt-BR')}</td>
                      <td className="px-4 py-2">{`R$ ${latestSalary.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`}</td>
                      <td className="px-4 py-2">{translateRole(emp.role)}</td>
                      <td className="px-4 py-2">{emp.active ? 'Ativo' : 'Inativo'}</td>
                      <td className="px-4 py-2 flex gap-2 flex-wrap">
                        <Button size="sm" onClick={() => { setSelectedEmployee(emp); setPayrollModalOpen(true); }}>
                          Visualizar
                        </Button>
                        <Button size="sm" variant="secondary" onClick={() => { setSelectedEmployee(emp); setEditModalOpen(true); setSalaryToEdit(latestSalary); }}>
                          Editar
                        </Button>
                        <Button size="sm" variant="error" onClick={() => onDeleteSalary(latestSalary.id)}>
                          Remover
                        </Button>
                      </td>
                    </tr>
                  );
                }).filter(Boolean)}
            </tbody>
          </table>
        </div>

        <EditSalaryModal
          isOpen={editModalOpen}
          onClose={() => setEditModalOpen(false)}
          salary={salaryToEdit}
          onSave={onEditSalary}
          loading={loading}
        />

        <NewSalaryModal
          isOpen={newModalOpen}
          onClose={() => setNewModalOpen(false)}
          onSave={onCreateSalary}
          loading={loading}
        />

        <EmployeePayrollModal
          isOpen={payrollModalOpen}
          onClose={() => setPayrollModalOpen(false)}
          employee={selectedEmployee as Employee}
          salaries={salaries}
          onMarkAsPaid={onMarkAsPaid}
          onCreateSalary={onCreateSalary}
          onEditSalary={onEditSalary}
          onDeleteSalary={onDeleteSalary}
          loading={loading}
        />

        {salaries.length === 0 && (
          <div className="text-center py-12">
            <UserCheck className="h-12 w-12 mx-auto text-secondary-400 mb-4" />
            <p className="text-secondary-600 text-lg">Nenhum salário encontrado</p>
            <p className="text-secondary-500 text-sm mt-2">Tente ajustar os filtros ou gerar a folha de pagamento</p>
          </div>
        )}
      </CardContent>
    </Card>
  );
};

export default SalaryManagement;