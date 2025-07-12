import React, { useState, useEffect } from 'react';
import { Card, CardHeader, CardContent } from '../components/UI/Card';
import { Button } from '../components/UI/Button';
import { Badge } from '../components/UI/Badge';
import { Receipt, Search, Filter, Plus, Loader2, Eye, Download, Trash2, Calendar, DollarSign, FileText, Building2 } from 'lucide-react';
import { useCustomers } from '../hooks/useCustomers';
import { supabase } from '../lib/supabase';

type Invoice = {
  id: string;
  number: string;
  customer: string;
  customerDocument: string;
  issueDate: string;
  amount: number;
  status: string;
  items: { description: string; quantity: number; unitPrice: number }[];
};

// Função para formatar data de forma segura - movida para fora do componente
const formatDate = (dateString: string | null | undefined): string => {
  if (!dateString) return '-';
  try {
    const date = new Date(dateString);
    if (isNaN(date.getTime())) return '-';
    return date.toLocaleDateString('pt-BR');
  } catch {
    return '-';
  }
};

const InvoiceModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  invoice?: Invoice | null;
}> = ({ isOpen, onClose, invoice }) => {
  if (!isOpen || !invoice) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-3xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-xl font-semibold text-secondary-900 flex items-center">
            <Receipt className="h-5 w-5 mr-2 text-primary-600" />
            Detalhes da Nota Fiscal
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            ×
          </button>
        </div>

        {/* Cabeçalho da Nota */}
        <div className="bg-secondary-50 p-4 rounded-lg mb-6">
          <div className="flex justify-between items-start">
            <div>
              <h3 className="font-semibold text-lg">{invoice.number}</h3>
              <p className="text-secondary-600">Emitida em: {formatDate(invoice.issueDate)}</p>
            </div>
            <Badge variant={invoice.status === 'Emitida' ? 'success' : 'warning'}>
              {invoice.status}
            </Badge>
          </div>
        </div>

        {/* Informações do Cliente */}
        <div className="mb-6">
          <h4 className="font-medium text-secondary-900 mb-2">Dados do Cliente</h4>
          <div className="bg-white border border-secondary-200 rounded-lg p-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <p className="text-sm text-secondary-600">Nome/Razão Social:</p>
                <p className="font-medium">{invoice.customer}</p>
              </div>
              <div>
                <p className="text-sm text-secondary-600">CNPJ/CPF:</p>
                <p className="font-medium">{invoice.customerDocument}</p>
              </div>
            </div>
          </div>
        </div>

        {/* Itens da Nota */}
        <div className="mb-6">
          <h4 className="font-medium text-secondary-900 mb-2">Itens da Nota</h4>
          <div className="overflow-x-auto">
            <table className="w-full border-collapse">
              <thead className="bg-secondary-50">
                <tr>
                  <th className="text-left p-3 text-sm font-medium text-secondary-600">Descrição</th>
                  <th className="text-center p-3 text-sm font-medium text-secondary-600">Qtde</th>
                  <th className="text-right p-3 text-sm font-medium text-secondary-600">Valor Unit.</th>
                  <th className="text-right p-3 text-sm font-medium text-secondary-600">Valor Total</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-secondary-200">
                {invoice.items.map((item: any, index: number) => (
                  <tr key={index} className="hover:bg-secondary-50">
                    <td className="p-3 text-sm">{item.description}</td>
                    <td className="p-3 text-sm text-center">{item.quantity}</td>
                    <td className="p-3 text-sm text-right">
                      R$ {item.unitPrice.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                    </td>
                    <td className="p-3 text-sm font-medium text-right">
                      R$ {(item.quantity * item.unitPrice).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                    </td>
                  </tr>
                ))}
              </tbody>
              <tfoot className="bg-secondary-50">
                <tr>
                  <td colSpan={3} className="p-3 text-right font-medium">Valor Total:</td>
                  <td className="p-3 text-right font-bold text-primary-600">
                    R$ {invoice.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>

        {/* Ações */}
        <div className="flex justify-end space-x-3 pt-4 border-t">
          <Button variant="secondary" onClick={onClose}>
            Fechar
          </Button>
          <Button>
            <Download className="h-4 w-4 mr-2" />
            Baixar PDF
          </Button>
        </div>
      </div>
    </div>
  );
};

const NewInvoiceModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  onInvoiceCreated: () => void;
}> = ({ isOpen, onClose, onInvoiceCreated }) => {
  const { customers } = useCustomers();
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    customer: '',
    customerDocument: '',
    issueDate: new Date().toISOString().split('T')[0],
    description: '',
    quantity: 1,
    unitPrice: 0,
    notes: ''
  });

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      // Inserir nota fiscal no banco
      const { error } = await supabase.from('invoices').insert([
        {
          customer: formData.customer,
          customer_document: formData.customerDocument,
          issue_date: formData.issueDate,
          amount: formData.quantity * formData.unitPrice,
          status: 'Emitida',
          items: [{
            description: formData.description,
            quantity: formData.quantity,
            unitPrice: formData.unitPrice
          }],
          notes: formData.notes
        }
      ]);
      if (error) throw error;
      setLoading(false);
      onClose();
      onInvoiceCreated();
      alert('Nota fiscal emitida com sucesso!');
    } catch (err) {
      setLoading(false);
      alert('Erro ao emitir nota fiscal!');
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    if (name === 'customer') {
      const selected = customers.find((c: any) => c.name === value);
      setFormData(prev => ({
        ...prev,
        customer: value,
        customerDocument: selected?.document || ''
      }));
    } else {
      setFormData(prev => ({
        ...prev,
        [name]: name === 'quantity' || name === 'unitPrice' ? Number(value) || 0 : value
      }));
    }
  };

  const totalAmount = formData.quantity * formData.unitPrice;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-3xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-xl font-semibold text-secondary-900 flex items-center">
            <Receipt className="h-5 w-5 mr-2 text-primary-600" />
            Emitir Nova Nota Fiscal
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            ×
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Dados do Cliente */}
          <div>
            <h3 className="font-medium text-secondary-900 mb-3">Dados do Cliente</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-1">
                  Cliente *
                </label>
                <select
                  name="customer"
                  value={formData.customer}
                  onChange={handleChange}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  required
                >
                  <option value="">Selecione um cliente</option>
                  {customers.map((c: any) => (
                    <option key={c.id} value={c.name}>{c.name}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-1">
                  CNPJ/CPF *
                </label>
                <input
                  type="text"
                  name="customerDocument"
                  value={formData.customerDocument}
                  onChange={handleChange}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  placeholder="00.000.000/0000-00"
                  required
                  readOnly={!!formData.customer}
                />
              </div>
            </div>
          </div>

          {/* Dados da Nota */}
          <div>
            <h3 className="font-medium text-secondary-900 mb-3">Dados da Nota</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-1">
                  Data de Emissão *
                </label>
                <input
                  type="date"
                  name="issueDate"
                  value={formData.issueDate}
                  onChange={handleChange}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  required
                />
              </div>
              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-secondary-700 mb-1">
                  Descrição do Serviço *
                </label>
                <input
                  type="text"
                  name="description"
                  value={formData.description}
                  onChange={handleChange}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  placeholder="Ex: Aluguel de veículo - Fiat Ducato"
                  required
                />
              </div>
            </div>
          </div>

          {/* Valores */}
          <div>
            <h3 className="font-medium text-secondary-900 mb-3">Valores</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-1">
                  Quantidade *
                </label>
                <input
                  type="number"
                  name="quantity"
                  value={formData.quantity}
                  onChange={handleChange}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  min="1"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-1">
                  Valor Unitário (R$) *
                </label>
                <input
                  type="number"
                  name="unitPrice"
                  value={formData.unitPrice}
                  onChange={handleChange}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  min="0"
                  step="0.01"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-1">
                  Valor Total (R$)
                </label>
                <div className="w-full border border-secondary-300 bg-secondary-50 rounded-lg px-3 py-2 text-secondary-900 font-medium">
                  {totalAmount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                </div>
              </div>
            </div>
          </div>

          {/* Observações */}
          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-1">
              Observações
            </label>
            <textarea
              name="notes"
              value={formData.notes}
              onChange={handleChange}
              rows={3}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder="Informações adicionais para a nota fiscal..."
            />
          </div>

          {/* Ações */}
          <div className="flex justify-end space-x-3 pt-4 border-t">
            <Button variant="secondary" onClick={onClose} disabled={loading}>
              Cancelar
            </Button>
            <Button type="submit" disabled={loading}>
              {loading ? (
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              ) : (
                <Receipt className="h-4 w-4 mr-2" />
              )}
              Emitir Nota Fiscal
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
};

export const Notas: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [isViewModalOpen, setIsViewModalOpen] = useState(false);
  const [isNewModalOpen, setIsNewModalOpen] = useState(false);
  const [selectedInvoice, setSelectedInvoice] = useState<Invoice | null>(null);
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchInvoices = async () => {
    setLoading(true);
    try {
      // Buscar notas fiscais com dados relacionados
      const { data, error } = await supabase
        .from('invoices')
        .select(`
          *,
          customers (
            name,
            document
          )
        `)
        .order('issue_date', { ascending: false });

      if (error) throw error;

      // Transformar dados para o formato esperado
      const transformedInvoices = (data || []).map((invoice: any) => ({
        id: invoice.id,
        number: invoice.number || `NF-${invoice.id.slice(0, 8)}`,
        customer: invoice.customer || invoice.customers?.name || 'Cliente não informado',
        customerDocument: invoice.customer_document || invoice.customers?.document || 'Documento não informado',
        issueDate: invoice.issue_date || invoice.created_at,
        amount: invoice.amount || 0,
        status: invoice.status || 'Pendente',
        items: invoice.items || []
      }));

      setInvoices(transformedInvoices);
    } catch (error) {
      console.error('Erro ao buscar notas fiscais:', error);
      setInvoices([]);
    } finally {
    setLoading(false);
    }
  };

  useEffect(() => {
    fetchInvoices();
  }, []);

  // Filtrar notas fiscais
  const filteredInvoices = invoices.filter((invoice: Invoice) => {
    const matchesSearch = 
      invoice.number?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      invoice.customer?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      invoice.customerDocument?.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesStatus = statusFilter === '' || invoice.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const handleViewInvoice = (invoice: Invoice) => {
    setSelectedInvoice(invoice);
    setIsViewModalOpen(true);
  };

  const handleNewInvoice = () => {
    setIsNewModalOpen(true);
  };

  // Excluir nota fiscal real do Supabase
  const handleDeleteInvoice = async (id: string) => {
    if (confirm('Tem certeza que deseja excluir esta nota fiscal?')) {
      const { error } = await supabase.from('invoices').delete().eq('id', id);
      if (!error) {
        setInvoices(prev => prev.filter(inv => inv.id !== id));
        alert('Nota fiscal excluída com sucesso!');
      }
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl lg:text-3xl font-bold text-secondary-900">Notas Fiscais</h1>
          <p className="text-secondary-600 mt-1 lg:mt-2">Emissão e gerenciamento de notas fiscais eletrônicas</p>
        </div>
        <Button onClick={() => setIsNewModalOpen(true)} size="sm" className="w-full sm:w-auto">
          <Plus className="h-4 w-4 mr-2" />
          Nova Nota Fiscal
        </Button>
      </div>

      {/* Statistics Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 lg:gap-6">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-secondary-600 text-xs lg:text-sm font-medium">Total de Notas</p>
                <p className="text-xl lg:text-2xl font-bold text-secondary-900">{invoices.length}</p>
              </div>
              <div className="h-8 w-8 lg:h-12 lg:w-12 bg-primary-100 rounded-lg flex items-center justify-center">
                <Receipt className="h-4 w-4 lg:h-6 lg:w-6 text-primary-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-secondary-600 text-xs lg:text-sm font-medium">Valor Total</p>
                <p className="text-xl lg:text-2xl font-bold text-secondary-900">
                  R$ {invoices.reduce((sum, inv) => sum + inv.amount, 0).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                </p>
              </div>
              <div className="h-8 w-8 lg:h-12 lg:w-12 bg-success-100 rounded-lg flex items-center justify-center">
                <DollarSign className="h-4 w-4 lg:h-6 lg:w-6 text-success-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-secondary-600 text-xs lg:text-sm font-medium">Emitidas</p>
                <p className="text-xl lg:text-2xl font-bold text-secondary-900">
                  {invoices.filter(inv => inv.status === 'Emitida').length}
                </p>
              </div>
              <div className="h-8 w-8 lg:h-12 lg:w-12 bg-success-100 rounded-lg flex items-center justify-center">
                <FileText className="h-4 w-4 lg:h-6 lg:w-6 text-success-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-secondary-600 text-xs lg:text-sm font-medium">Pendentes</p>
                <p className="text-xl lg:text-2xl font-bold text-secondary-900">
                  {invoices.filter(inv => inv.status === 'Pendente').length}
                </p>
              </div>
              <div className="h-8 w-8 lg:h-12 lg:w-12 bg-warning-100 rounded-lg flex items-center justify-center">
                <Calendar className="h-4 w-4 lg:h-6 lg:w-6 text-warning-600" />
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col sm:flex-row gap-4">
            <div className="flex-1">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
                <input
                  type="text"
                  placeholder="Buscar por número, cliente ou CNPJ..."
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
                className="border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              >
                <option value="">Todos os Status</option>
                <option value="Emitida">Emitida</option>
                <option value="Pendente">Pendente</option>
              </select>
              <Button variant="secondary" size="sm" className="w-full sm:w-auto">
                <Filter className="h-4 w-4 mr-2" />
                Filtros
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Invoices List */}
      <Card>
        <CardHeader className="p-4 lg:p-6">
          <h3 className="text-lg font-semibold text-secondary-900">
            Notas Fiscais ({filteredInvoices.length})
          </h3>
        </CardHeader>
        <CardContent className="p-0">
          {/* Mobile Cards */}
          <div className="lg:hidden space-y-3 p-4">
            {filteredInvoices.map((invoice) => (
              <div key={invoice.id} className="border border-secondary-200 rounded-lg p-4">
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <p className="font-medium text-secondary-900">{invoice.number}</p>
                    <p className="text-sm text-secondary-600">{invoice.customer}</p>
                  </div>
                  <Badge variant={invoice.status === 'Emitida' ? 'success' : 'warning'}>
                    {invoice.status}
                  </Badge>
                </div>
                <div className="grid grid-cols-2 gap-3 text-sm mb-3">
                  <div>
                    <span className="text-secondary-500">Data:</span>
                    <p className="font-medium">{formatDate(invoice.issueDate)}</p>
                  </div>
                  <div>
                    <span className="text-secondary-500">Valor:</span>
                    <p className="font-medium">R$ {invoice.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}</p>
                  </div>
                </div>
                <div className="flex justify-end space-x-2">
                  <button 
                    onClick={() => handleViewInvoice(invoice)}
                    className="p-2 text-secondary-400 hover:text-secondary-600"
                  >
                    <Eye className="h-4 w-4" />
                  </button>
                  <button className="p-2 text-secondary-400 hover:text-secondary-600">
                    <Download className="h-4 w-4" />
                  </button>
                  <button 
                    onClick={() => handleDeleteInvoice(invoice.id)}
                    className="p-2 text-secondary-400 hover:text-error-600"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>

          {/* Desktop Table */}
          <div className="hidden lg:block overflow-x-auto">
            <table className="w-full">
              <thead className="bg-secondary-50">
                <tr>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Número</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Cliente</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">CNPJ/CPF</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Data</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Valor</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Status</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-secondary-200">
                {filteredInvoices.map((invoice) => (
                  <tr key={invoice.id} className="hover:bg-secondary-50">
                    <td className="py-4 px-6 text-sm font-medium text-secondary-900">
                      {invoice.number}
                    </td>
                    <td className="py-4 px-6">
                      <div className="flex items-center">
                        <Building2 className="h-4 w-4 text-secondary-400 mr-2" />
                        <span className="text-sm">{invoice.customer}</span>
                      </div>
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      {invoice.customerDocument}
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      {formatDate(invoice.issueDate)}
                    </td>
                    <td className="py-4 px-6 text-sm font-medium text-secondary-900">
                      R$ {invoice.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                    </td>
                    <td className="py-4 px-6">
                      <Badge variant={invoice.status === 'Emitida' ? 'success' : 'warning'}>
                        {invoice.status}
                      </Badge>
                    </td>
                    <td className="py-4 px-6">
                      <div className="flex items-center space-x-2">
                        <button 
                          onClick={() => handleViewInvoice(invoice)}
                          className="p-1 text-secondary-400 hover:text-secondary-600"
                          title="Visualizar"
                        >
                          <Eye className="h-4 w-4" />
                        </button>
                        <button 
                          className="p-1 text-secondary-400 hover:text-secondary-600"
                          title="Baixar PDF"
                        >
                          <Download className="h-4 w-4" />
                        </button>
                        <button 
                          onClick={() => handleDeleteInvoice(invoice.id)}
                          className="p-1 text-secondary-400 hover:text-error-600"
                          title="Excluir"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {filteredInvoices.length === 0 && (
            <div className="text-center py-8">
              <Receipt className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
              <p className="text-secondary-600">Nenhuma nota fiscal encontrada</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Modals */}
      <InvoiceModal 
        isOpen={isViewModalOpen}
        onClose={() => setIsViewModalOpen(false)}
        invoice={selectedInvoice}
      />

      <NewInvoiceModal
        isOpen={isNewModalOpen}
        onClose={() => setIsNewModalOpen(false)}
        onInvoiceCreated={fetchInvoices}
      />
    </div>
  );
};

export default Notas;