import React from 'react';
import { Button } from '../UI/Button';
import { Badge } from '../UI/Badge';
import { FileText, X, Building2, Mail, Phone, Package } from 'lucide-react';

interface PurchaseOrderDetailModalProps {
  isOpen: boolean;
  onClose: () => void;
  purchaseOrder?: any;
  items: any[];
  supplier?: any;
}

export const PurchaseOrderDetailModal: React.FC<PurchaseOrderDetailModalProps> = ({ 
  isOpen, 
  onClose, 
  purchaseOrder, 
  items, 
  supplier 
}) => {
  if (!isOpen || !purchaseOrder) return null;

  const getStatusBadge = (status: string) => {
    const variants = {
      'Pending': 'warning',
      'Received': 'success',
      'Cancelled': 'error'
    } as const;

    const labels = {
      'Pending': 'Pendente',
      'Received': 'Recebido',
      'Cancelled': 'Cancelado'
    } as const;

    return <Badge variant={variants[status as keyof typeof variants] || 'secondary'}>
      {labels[status as keyof typeof labels] || status}
    </Badge>;
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-4xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <div>
            <h2 className="text-lg lg:text-xl font-semibold text-secondary-900 flex items-center">
              <FileText className="h-5 w-5 mr-2 text-primary-600" />
              Pedido de Compra: {purchaseOrder.order_number}
            </h2>
            <p className="text-sm text-secondary-600">
              {new Date(purchaseOrder.order_date).toLocaleDateString('pt-BR')}
            </p>
          </div>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            <X className="h-6 w-6" />
          </button>
        </div>

        {/* Order Info */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
          <div className="bg-secondary-50 p-4 rounded-lg">
            <h3 className="font-semibold text-secondary-900 mb-3">Informações do Pedido</h3>
            <div className="space-y-3">
              <div className="flex justify-between">
                <span className="text-sm text-secondary-600">Status:</span>
                <div>{getStatusBadge(purchaseOrder.status)}</div>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-secondary-600">Data do Pedido:</span>
                <span className="font-medium">{new Date(purchaseOrder.order_date).toLocaleDateString('pt-BR')}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-secondary-600">Total:</span>
                <span className="font-medium">R$ {purchaseOrder.total_amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-secondary-600">Itens:</span>
                <span className="font-medium">{items.length}</span>
              </div>
              {purchaseOrder.created_by_name && (
                <div className="flex justify-between">
                  <span className="text-sm text-secondary-600">Criado por:</span>
                  <span className="font-medium">{purchaseOrder.created_by_name}</span>
                </div>
              )}
            </div>
          </div>

          <div className="bg-secondary-50 p-4 rounded-lg">
            <h3 className="font-semibold text-secondary-900 mb-3">Fornecedor</h3>
            {supplier ? (
              <div className="space-y-3">
                <div className="flex items-center">
                  <Building2 className="h-5 w-5 text-secondary-400 mr-2" />
                  <div>
                    <p className="font-medium">{supplier.name}</p>
                    {supplier.document && <p className="text-sm text-secondary-600">{supplier.document}</p>}
                  </div>
                </div>
                {supplier.contact_info?.email && (
                  <div className="flex items-center">
                    <Mail className="h-4 w-4 text-secondary-400 mr-2" />
                    <span>{supplier.contact_info.email}</span>
                  </div>
                )}
                {supplier.contact_info?.phone && (
                  <div className="flex items-center">
                    <Phone className="h-4 w-4 text-secondary-400 mr-2" />
                    <span>{supplier.contact_info.phone}</span>
                  </div>
                )}
              </div>
            ) : (
              <p className="text-secondary-600">Fornecedor não encontrado</p>
            )}
          </div>
        </div>

        {/* Notes */}
        {purchaseOrder.notes && (
          <div className="bg-secondary-50 p-4 rounded-lg mb-6">
            <h3 className="font-semibold text-secondary-900 mb-2">Observações</h3>
            <p className="text-secondary-700">{purchaseOrder.notes}</p>
          </div>
        )}

        {/* Items List */}
        <div>
          <h3 className="text-lg font-semibold text-secondary-900 mb-4">
            Itens do Pedido
          </h3>
          
          {items.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-secondary-50">
                  <tr>
                    <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Descrição</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Peça</th>
                    <th className="text-right py-3 px-4 text-sm font-medium text-secondary-600">Quantidade</th>
                    <th className="text-right py-3 px-4 text-sm font-medium text-secondary-600">Preço Unit.</th>
                    <th className="text-right py-3 px-4 text-sm font-medium text-secondary-600">Total</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-secondary-200">
                  {items.map((item) => (
                    <tr key={item.id} className="hover:bg-secondary-50">
                      <td className="py-3 px-4 text-sm text-secondary-900">
                        {item.description}
                      </td>
                      <td className="py-3 px-4 text-sm text-secondary-600">
                        {item.part_name ? (
                          <div>
                            <p>{item.part_name}</p>
                            <p className="text-xs text-secondary-500">{item.part_sku}</p>
                          </div>
                        ) : (
                          '-'
                        )}
                      </td>
                      <td className="py-3 px-4 text-sm text-secondary-600 text-right">
                        {item.quantity}
                      </td>
                      <td className="py-3 px-4 text-sm text-secondary-600 text-right">
                        R$ {item.unit_price.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                      </td>
                      <td className="py-3 px-4 text-sm font-medium text-secondary-900 text-right">
                        R$ {item.line_total.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                      </td>
                    </tr>
                  ))}
                </tbody>
                <tfoot className="bg-secondary-50">
                  <tr>
                    <td colSpan={4} className="py-3 px-4 text-sm font-medium text-secondary-900 text-right">
                      Total:
                    </td>
                    <td className="py-3 px-4 text-base font-bold text-secondary-900 text-right">
                      R$ {purchaseOrder.total_amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>
          ) : (
            <div className="text-center py-8">
              <Package className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
              <p className="text-secondary-600">Nenhum item encontrado neste pedido</p>
            </div>
          )}
        </div>

        <div className="flex justify-end pt-6 border-t mt-6">
          <Button onClick={onClose}>
            Fechar
          </Button>
        </div>
      </div>
    </div>
  );
};