import React, { useState, useEffect } from 'react';
import { Button } from '../UI/Button';
import { Plus, Minus, X, Loader2, Package, DollarSign } from 'lucide-react';
import { PurchaseOrderItemInsert } from '../../hooks/usePurchaseOrders';

interface PurchaseOrderModalProps {
  isOpen: boolean;
  onClose: () => void;
  purchaseOrder?: any;
  suppliers: any[];
  parts: any[];
  employees: any[];
  onSave: (orderData: any, items: PurchaseOrderItemInsert[]) => Promise<void>;
}

export const PurchaseOrderModal: React.FC<PurchaseOrderModalProps> = ({
  isOpen,
  onClose,
  purchaseOrder,
  suppliers,
  parts,
  employees,
  onSave
}) => {
  const [loading, setLoading] = useState(false);
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

  // Reset form when modal opens/closes or when editing a different order
  useEffect(() => {
    if (isOpen) {
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
          created_by_employee_id: ''
        });
        setOrderItems([]);
      }
      
      // Reset new item form
      resetNewItemForm();
    }
  }, [isOpen, purchaseOrder]);

  if (!isOpen) return null;

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
    
    setLoading(true);
    try {
      // Calculate total amount from items
      const totalAmount = orderItems.reduce((sum, item) => sum + (item.quantity * item.unit_price), 0);
      
      const orderData = {
        ...formData,
        total_amount: totalAmount,
        created_by_employee_id: formData.created_by_employee_id,
        notes: formData.notes || null
      };
      
      await onSave(orderData, orderItems);
      onClose();
    } catch (error) {
      console.error('Error saving purchase order:', error);
      alert('Erro ao salvar pedido de compra: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
    } finally {
      setLoading(false);
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
    emp.active && (emp.role === 'Admin' || emp.permissions?.purchases)
  );

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-4xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <h2 className="text-lg lg:text-xl font-semibold text-secondary-900">
            {purchaseOrder ? 'Editar Pedido de Compra' : 'Novo Pedido de Compra'}
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            <X className="h-6 w-6" />
          </button>
        </div>

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
              <input
                type="date"
                name="order_date"
                value={formData.order_date}
                onChange={handleChange}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                required
              />
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
              <select
                name="created_by_employee_id"
                value={formData.created_by_employee_id}
                onChange={handleChange}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                required
              >
                <option value="">Selecione um responsável</option>
                {purchaseDepartmentEmployees.map(employee => (
                  <option key={employee.id} value={employee.id}>
                    {employee.name} ({employee.role === 'Admin' ? 'Administrador' : 'Compras'})
                  </option>
                ))}
              </select>
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
            <div className="bg-secondary-50 p-4 rounded-lg mb-4">
              <h4 className="font-medium text-secondary-900 mb-3">Adicionar Item</h4>
              <div className="grid grid-cols-1 lg:grid-cols-4 gap-3">
                <div className="lg:col-span-2">
                  <label className="block text-xs font-medium text-secondary-700 mb-1">
                    Peça (opcional)
                  </label>
                  <select
                    name="part_id"
                    value={newItem.part_id}
                    onChange={handlePartSelect}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  >
                    <option value="">Selecione uma peça ou digite manualmente</option>
                    {parts.map(part => (
                      <option key={part.id} value={part.id}>
                        {part.name} ({part.sku}) - R$ {part.unit_cost.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="lg:col-span-2">
                  <label className="block text-xs font-medium text-secondary-700 mb-1">
                    Descrição *
                  </label>
                  <input
                    type="text"
                    name="description"
                    value={newItem.description}
                    onChange={handleItemChange}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    placeholder="Descrição do item"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-secondary-700 mb-1">
                    Quantidade *
                  </label>
                  <input
                    type="number"
                    name="quantity"
                    value={newItem.quantity}
                    onChange={handleItemChange}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    min="1"
                    step="1"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-secondary-700 mb-1">
                    Preço Unitário *
                  </label>
                  <input
                    type="number"
                    name="unit_price"
                    value={newItem.unit_price}
                    onChange={handleItemChange}
                    className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                    min="0"
                    step="0.01"
                    required
                  />
                </div>
                <div className="lg:col-span-2">
                  <label className="block text-xs font-medium text-secondary-700 mb-1">
                    Total
                  </label>
                  <div className="w-full border border-secondary-300 bg-secondary-50 rounded-lg px-3 py-2 text-secondary-700">
                    R$ {(newItem.quantity * newItem.unit_price).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                  </div>
                </div>
                <div className="lg:col-span-2 flex items-end">
                  <Button
                    type="button"
                    onClick={addItem}
                    disabled={!newItem.description || newItem.quantity <= 0 || newItem.unit_price <= 0}
                    className="w-full"
                  >
                    <Plus className="h-4 w-4 mr-2" />
                    Adicionar Item
                  </Button>
                </div>
              </div>
            </div>

            {/* Items List */}
            {orderItems.length > 0 ? (
              <div className="space-y-3 mb-4">
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead className="bg-secondary-50">
                      <tr>
                        <th className="text-left py-2 px-4 text-xs font-medium text-secondary-600">Descrição</th>
                        <th className="text-left py-2 px-4 text-xs font-medium text-secondary-600">Quantidade</th>
                        <th className="text-left py-2 px-4 text-xs font-medium text-secondary-600">Preço Unit.</th>
                        <th className="text-left py-2 px-4 text-xs font-medium text-secondary-600">Total</th>
                        <th className="text-left py-2 px-4 text-xs font-medium text-secondary-600">Ações</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-secondary-200">
                      {orderItems.map((item, index) => (
                        <tr key={index} className="hover:bg-secondary-50">
                          <td className="py-2 px-4 text-sm text-secondary-900">
                            {item.description}
                          </td>
                          <td className="py-2 px-4 text-sm text-secondary-600">
                            {item.quantity}
                          </td>
                          <td className="py-2 px-4 text-sm text-secondary-600">
                            R$ {item.unit_price.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                          </td>
                          <td className="py-2 px-4 text-sm font-medium text-secondary-900">
                            R$ {(item.quantity * item.unit_price).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                          </td>
                          <td className="py-2 px-4">
                            <button
                              type="button"
                              onClick={() => removeItem(index)}
                              className="text-error-600 hover:text-error-800"
                            >
                              <X className="h-4 w-4" />
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                <div className="bg-secondary-50 p-4 rounded-lg">
                  <div className="flex justify-between items-center">
                    <div>
                      <p className="text-sm text-secondary-600">Total de Itens:</p>
                      <p className="font-medium">{orderItems.length} itens</p>
                    </div>
                    <div>
                      <p className="text-sm text-secondary-600">Quantidade Total:</p>
                      <p className="font-medium">{orderItems.reduce((sum, item) => sum + item.quantity, 0)} unidades</p>
                    </div>
                    <div>
                      <p className="text-sm text-secondary-600">Valor Total:</p>
                      <p className="text-lg font-bold text-primary-600">
                        R$ {totalAmount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            ) : (
              <div className="text-center py-8 bg-secondary-50 rounded-lg mb-4">
                <Package className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
                <p className="text-secondary-600">Nenhum item adicionado</p>
                <p className="text-sm text-secondary-500 mt-1">
                  Adicione itens ao pedido usando o formulário acima
                </p>
              </div>
            )}
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
            <Button variant="secondary" onClick={onClose} disabled={loading} className="w-full sm:w-auto">
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
      </div>
    </div>
  );
};