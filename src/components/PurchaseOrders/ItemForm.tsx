import React from 'react';
import { Button } from '../UI/Button';
import { Plus } from 'lucide-react';

interface ItemFormProps {
  newItem: {
    part_id: string;
    description: string;
    quantity: number;
    unit_price: number;
  };
  parts: any[];
  onItemChange: (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => void;
  onPartSelect: (e: React.ChangeEvent<HTMLSelectElement>) => void;
  onAddItem: () => void;
}

export const ItemForm: React.FC<ItemFormProps> = ({
  newItem,
  parts,
  onItemChange,
  onPartSelect,
  onAddItem
}) => {
  const isFormValid = newItem.description && newItem.quantity > 0 && newItem.unit_price > 0;
  
  return (
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
            onChange={onPartSelect}
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
            onChange={onItemChange}
            className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
            placeholder="Descrição do item"
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
            onChange={onItemChange}
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
            onChange={onItemChange}
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
            onClick={onAddItem}
            disabled={!isFormValid}
            className="w-full"
          >
            <Plus className="h-4 w-4 mr-2" />
            Adicionar Item
          </Button>
        </div>
      </div>
    </div>
  );
};