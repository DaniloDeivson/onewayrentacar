import React, { useState, useEffect } from 'react';
import { Button } from '../UI/Button';
import { Loader2, DollarSign, Calendar, User } from 'lucide-react';
import { ItemForm } from './ItemForm';
import { ItemsTable } from './ItemsTable';
import { PurchaseOrderItemInsert } from '../../hooks/usePurchaseOrders';
import { useAuth } from '../../hooks/useAuth';

interface PurchaseOrderFormProps {
  onSubmit: (orderData: {
    supplier_id: string;
    order_number?: string;
    order_date: string;
    total_amount: number;
    status: 'Pending' | 'Received' | 'Cancelled';
    created_by_employee_id: string | null;
    notes?: string | null;
  }, items: PurchaseOrderItemInsert[]) => Promise<void>;
  onCancel: () => void;
  purchaseOrder?: {
    id: string;
    supplier_id: string;
    order_number: string;
    order_date: string;
    status: string;
    created_by_employee_id: string | null;
    notes?: string | null;
  };
  suppliers: Array<{ id: string; name: string; document?: string }>;
  parts: Array<{ id: string; name: string; sku?: string; unit_cost?: number }>;
  employees: Array<{ id: string; name: string; role?: string; active?: boolean; permissions?: { purchases?: boolean } }>;
  loading?: boolean;
}

export const PurchaseOrderForm: React.FC<PurchaseOrderFormProps> = ({
  onSubmit,
  onCancel,
  purchaseOrder,
  suppliers,
  parts,
  employees,
  loading = false
}) => {
  const { user, isAdmin, isManager } = useAuth();
  const [orderItems, setOrderItems] = useState<PurchaseOrderItemInsert[]>([]);
  const [formData, setFormData] = useState({
    supplier_id: '',
    order_number: '',
    order_date: new Date().toISOString().split('T')[0],
    status: 'Pending',
    notes: '',
    created_by_employee_id: ''
  });

  // For new item form
  const [newItem, setNewItem] = useState({
    part_id: '',
    description: '',
    quantity: 1,
    unit_price: 0
  });

  // Auto-fill created_by_employee_id with current user
  useEffect(() => {
    if (!purchaseOrder && user && !formData.created_by_employee_id) {
      setFormData(prev => ({ ...prev, created_by_employee_id: user.id }));
    }
  }, [purchaseOrder, user, formData.created_by_employee_id]);

  // Reset form when modal opens/closes or when editing a different order
  useEffect(() => {
    if (purchaseOrder) {
      setFormData({
        supplier_id: purchaseOrder.supplier_id || '',
        order_number: purchaseOrder.order_number || '',
        order_date: purchaseOrder.order_date || new Date().toISOString().split('T')[0],
        status: purchaseOrder.status || 'Pending',
        notes: purchaseOrder.notes || '',
        created_by_employee_id: purchaseOrder.created_by_employee_id || ''
      });
    } else {
      // Reset form for new order
      setFormData({
        supplier_id: '',
        order_number: '',
        order_date: new Date().toISOString().split('T')[0],
        status: 'Pending',
        notes: '',
        created_by_employee_id: user?.id || ''
      });
      setOrderItems([]);
    }
    
    // Reset new item form
    resetNewItemForm();
  }, [purchaseOrder, user]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (orderItems.length === 0) {
      alert('Adicione pelo menos um item ao pedido antes de salvar.');
      return;
    }
    
    if (!formData.created_by_employee_id) {
      alert('Por favor, selecione um responsável pelo pedido de compra.');
      return;
    }
    
    try {
      // Calculate total amount from items
      const totalAmount = orderItems.reduce((sum, item) => sum + (item.quantity * item.unit_price), 0);
      const orderData = {
        ...formData,
        total_amount: totalAmount,
        created_by_employee_id: formData.created_by_employee_id,
        notes: formData.notes || null,
        status: formData.status as 'Pending' | 'Received' | 'Cancelled'
      };
      
      await onSubmit(orderData, orderItems);
    } catch (error) {
      console.error('Error saving purchase order:', error);
      alert('Erro ao salvar pedido de compra: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleItemChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setNewItem(prev => ({
      ...prev,
      [name]: name === 'quantity' || name === 'unit_price' ? Number(value) || 0 : value
    }));
  };

  const handlePartSelect = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const partId = e.target.value;
    if (partId) {
      const selectedPart = parts.find(p => p.id === partId);
      if (selectedPart) {
        setNewItem({
          part_id: partId,
          description: selectedPart.name,
          quantity: 1,
          unit_price: selectedPart.unit_cost
        });
      }
    } else {
      resetNewItemForm();
    }
  };

  const resetNewItemForm = () => {
    setNewItem({
      part_id: '',
      description: '',
      quantity: 1,
      unit_price: 0
    });
  };

  const addItem = () => {
    if (!newItem.description || !newItem.quantity || newItem.quantity <= 0 || !newItem.unit_price || newItem.unit_price <= 0) {
      alert('Preencha todos os campos do item corretamente');
      return;
    }
    
    const newOrderItem: PurchaseOrderItemInsert = {
      purchase_order_id: purchaseOrder?.id || '',
      part_id: newItem.part_id || null,
      description: newItem.description,
      quantity: newItem.quantity,
      unit_price: newItem.unit_price
    };
    
    setOrderItems(prev => [...prev, newOrderItem]);
    
    // Reset new item form
    resetNewItemForm();
  };

  const removeItem = (index: number) => {
    setOrderItems(prev => prev.filter((_, i) => i !== index));
  };

  const totalAmount = orderItems.reduce((sum, item) => sum + (item.quantity * item.unit_price), 0);

  // Filter employees to only show Admin users
  const purchaseDepartmentEmployees = employees.filter(emp => 
    emp.active && (emp.role === 'Admin' || emp.role === 'Manager' || emp.permissions?.purchases)
  );

  return (
    <form onSubmit={handleSubmit} className="space-y-4 lg:space-y-6">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            Fornecedor *
          </label>
          <select
            name="supplier_id"
            value={formData.supplier_id}
            onChange={handleChange}
            className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
            required
          >
            <option value="">Selecione um fornecedor</option>
            {suppliers.map(supplier => (
              <option key={supplier.id} value={supplier.id}>
                {supplier.name} {supplier.document && `(${supplier.document})`}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            Número do Pedido
          </label>
          <input
            type="text"
            name="order_number"
            value={formData.order_number}
            onChange={handleChange}
            className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
            placeholder="Será gerado automaticamente se vazio"
            disabled={!!purchaseOrder}
          />
          {!purchaseOrder && (
            <p className="text-xs text-secondary-500 mt-1">
              Deixe vazio para gerar automaticamente
            </p>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            Data do Pedido *
          </label>
          <div className="relative">
            <Calendar className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
            <input
              type="date"
              name="order_date"
              value={formData.order_date}
              onChange={handleChange}
              className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              required
            />
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            Status *
          </label>
          <select
            name="status"
            value={formData.status}
            onChange={handleChange}
            className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
            required
          >
            <option value="Pending">Pendente</option>
            <option value="Received">Recebido</option>
            <option value="Cancelled">Cancelado</option>
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            Responsável *
          </label>
          <div className="relative">
            <User className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
            <select
              name="created_by_employee_id"
              value={formData.created_by_employee_id}
              onChange={handleChange}
              className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              required
              disabled={!isAdmin && !isManager}
            >
              <option value="">Selecione um responsável</option>
              {purchaseDepartmentEmployees.map(employee => (
                <option key={employee.id} value={employee.id}>
                  {employee.name} ({employee.role === 'Admin' ? 'Administrador' : employee.role === 'Manager' ? 'Gerente' : 'Compras'})
                </option>
              ))}
            </select>
          </div>
          {purchaseDepartmentEmployees.length === 0 && (
            <p className="text-xs text-error-600 mt-1">
              Nenhum usuário com permissão de compras encontrado. Adicione usuários com esta permissão no Admin Panel.
            </p>
          )}
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium text-secondary-700 mb-2">
          Observações
        </label>
        <textarea
          name="notes"
          value={formData.notes}
          onChange={handleChange}
          rows={3}
          className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
          placeholder="Observações sobre o pedido..."
        />
      </div>

      {/* Items Section */}
      <div className="border-t pt-4 lg:pt-6">
        <h3 className="text-lg font-semibold text-secondary-900 mb-4">
          Itens do Pedido
        </h3>

        {/* Add New Item Form */}
        <ItemForm
          newItem={newItem}
          parts={parts}
          onItemChange={handleItemChange}
          onPartSelect={handlePartSelect}
          onAddItem={addItem}
        />

        {/* Items List */}
        <ItemsTable
          items={orderItems}
          onRemoveItem={removeItem}
        />
      </div>

      {/* Integração com Custos - Aviso */}
      <div className="bg-info-50 border border-info-200 rounded-lg p-4">
        <div className="flex items-start">
          <DollarSign className="h-5 w-5 text-info-600 mr-2 mt-0.5" />
          <div>
            <p className="text-sm font-medium text-info-800">
              Integração Automática com Custos
            </p>
            <p className="text-xs text-info-700 mt-1">
              Ao registrar este pedido de compra, um lançamento de custo será criado automaticamente no painel financeiro 
              para cada item, com categoria "Compra" e status "Pendente". Estes custos precisarão ser autorizados pela gerência.
            </p>
          </div>
        </div>
      </div>

      <div className="flex flex-col sm:flex-row justify-end space-y-3 sm:space-y-0 sm:space-x-4 pt-4 lg:pt-6 border-t">
        <Button variant="secondary" onClick={onCancel} disabled={loading} className="w-full sm:w-auto">
          Cancelar
        </Button>
        <Button 
          type="submit" 
          disabled={loading || orderItems.length === 0 || !formData.created_by_employee_id} 
          className="w-full sm:w-auto"
        >
          {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
          {purchaseOrder ? 'Salvar Alterações' : 'Criar Pedido de Compra'}
        </Button>
      </div>
    </form>
  );
};

export default PurchaseOrderForm;