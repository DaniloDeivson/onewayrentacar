import React from 'react';
import { X, Package } from 'lucide-react';

interface ItemsTableProps {
  items: any[];
  onRemoveItem: (index: number) => void;
}

export const ItemsTable: React.FC<ItemsTableProps> = ({ items, onRemoveItem }) => {
  if (items.length === 0) {
    return (
      <div className="text-center py-8 bg-secondary-50 rounded-lg mb-4">
        <Package className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
        <p className="text-secondary-600">Nenhum item adicionado</p>
        <p className="text-sm text-secondary-500 mt-1">
          Adicione itens ao pedido usando o formulário acima
        </p>
      </div>
    );
  }

  const totalAmount = items.reduce((sum, item) => sum + (item.quantity * item.unit_price), 0);
  const totalQuantity = items.reduce((sum, item) => sum + item.quantity, 0);

  return (
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
            {items.map((item, index) => (
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
                    onClick={() => onRemoveItem(index)}
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
            <p className="font-medium">{items.length} itens</p>
          </div>
          <div>
            <p className="text-sm text-secondary-600">Quantidade Total:</p>
            <p className="font-medium">{totalQuantity} unidades</p>
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
  );
};