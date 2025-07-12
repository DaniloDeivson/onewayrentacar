import React, { useState, useEffect } from 'react';
import { Button } from '../UI/Button';
import { Badge } from '../UI/Badge';
import { Search, Plus, Minus, ShoppingCart, X, Package, AlertTriangle, Save, Loader2 } from 'lucide-react';
import { PartCartItem } from '../../hooks/useServiceOrderParts';

interface Part {
  id: string;
  sku: string;
  name: string;
  quantity: number;
  unit_cost: number;
}

interface PartsCartModalProps {
  isOpen: boolean;
  onClose: () => void;
  parts: Part[];
  initialCart?: PartCartItem[];
  onCartChange?: (cart: PartCartItem[]) => void;
  isEditing?: boolean;
  onSaveParts?: (cartItems: PartCartItem[]) => Promise<void>;
}

export const PartsCartModal: React.FC<PartsCartModalProps> = ({
  isOpen,
  onClose,
  parts,
  initialCart = [],
  onCartChange,
  isEditing = false,
  onSaveParts
}) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [cart, setCart] = useState<PartCartItem[]>(initialCart);
  const [saving, setSaving] = useState(false);

  // Atualizar o carrinho quando initialCart mudar
  useEffect(() => {
    setCart(initialCart);
  }, [initialCart]);



  if (!isOpen) return null;

  const filteredParts = parts.filter(part =>
    part.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    part.sku.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const addToCart = (part: Part) => {
    console.log('PartsCartModal - addToCart called with part:', part);
    console.log('PartsCartModal - current cart before adding:', cart);
    
    const existingItem = cart.find(item => item.part_id === part.id);
    
    if (existingItem) {
      // Se já existe, aumentar quantidade
      console.log('PartsCartModal - part already exists, increasing quantity');
      const updatedCart = cart.map(item =>
        item.part_id === part.id
          ? {
              ...item,
              quantity_to_use: item.quantity_to_use + 1,
              total_cost: (item.quantity_to_use + 1) * item.unit_cost
            }
          : item
      );
      console.log('PartsCartModal - updated cart:', updatedCart);
      setCart(updatedCart);
    } else {
      // Se não existe, adicionar novo item
      console.log('PartsCartModal - adding new part to cart');
      const newItem: PartCartItem = {
        part_id: part.id,
        sku: part.sku,
        name: part.name,
        available_quantity: part.quantity,
        quantity_to_use: 1,
        unit_cost: part.unit_cost,
        total_cost: part.unit_cost
      };
      console.log('PartsCartModal - new item:', newItem);
      const newCart = [...cart, newItem];
      console.log('PartsCartModal - new cart:', newCart);
      setCart(newCart);
    }
    
    // Notificar imediatamente a mudança para atualizar a lista de peças utilizadas
    if (onCartChange) {
      const finalCart = existingItem 
        ? cart.map(item =>
            item.part_id === part.id
              ? {
                  ...item,
                  quantity_to_use: item.quantity_to_use + 1,
                  total_cost: (item.quantity_to_use + 1) * item.unit_cost
                }
              : item
          )
        : [...cart, {
            part_id: part.id,
            sku: part.sku,
            name: part.name,
            available_quantity: part.quantity,
            quantity_to_use: 1,
            unit_cost: part.unit_cost,
            total_cost: part.unit_cost
          }];
      
      onCartChange(finalCart);
    }
  };

  const removeFromCart = (partId: string) => {
    const newCart = cart.filter(item => item.part_id !== partId);
    setCart(newCart);
    
    // Notificar imediatamente a mudança
    if (onCartChange) {
      onCartChange(newCart);
    }
  };

  const updateQuantity = (partId: string, newQuantity: number) => {
    if (newQuantity <= 0) {
      removeFromCart(partId);
      return;
    }

    const updatedCart = cart.map(item =>
      item.part_id === partId
        ? {
            ...item,
            quantity_to_use: newQuantity,
            total_cost: newQuantity * item.unit_cost
          }
        : item
    );
    setCart(updatedCart);
    
    // Notificar imediatamente a mudança
    if (onCartChange) {
      onCartChange(updatedCart);
    }
  };

  const handleSave = async () => {
    if (!onSaveParts) {
      console.log('No save function provided, just closing modal');
      onClose();
      return;
    }

    if (cart.length === 0) {
      alert('Adicione pelo menos uma peça ao carrinho antes de salvar.');
      return;
    }

    try {
      setSaving(true);
      console.log('PartsCartModal - Saving parts:', cart);
      await onSaveParts(cart);
      console.log('PartsCartModal - Parts saved successfully');
      onClose();
    } catch (error) {
      console.error('PartsCartModal - Erro ao salvar peças:', error);
      alert('Erro ao salvar peças: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
    } finally {
      setSaving(false);
    }
  };

  const totalItems = cart.reduce((sum, item) => sum + item.quantity_to_use, 0);
  const totalCost = cart.reduce((sum, item) => sum + item.total_cost, 0);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-6xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <h2 className="text-lg lg:text-xl font-semibold text-secondary-900 flex items-center">
            <ShoppingCart className="h-5 w-5 mr-2" />
            Carrinho de Peças
            {isEditing && <Badge variant="info" className="ml-2">Editando</Badge>}
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            ×
          </button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Lista de Peças */}
          <div>
            <div className="mb-4">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-secondary-400 h-4 w-4" />
                <input
                  type="text"
                  placeholder="Buscar peças..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                />
              </div>
            </div>

            <div className="space-y-2 max-h-96 overflow-y-auto">
              {filteredParts.map((part) => {
                const inCart = cart.find(item => item.part_id === part.id);
                const isLowStock = part.quantity <= 5;
                
                return (
                  <div
                    key={part.id}
                    className={`p-3 border rounded-lg ${
                      inCart ? 'border-primary-300 bg-primary-50' : 'border-secondary-200 hover:border-secondary-300'
                    }`}
                  >
                    <div className="flex justify-between items-start">
                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          <h3 className="font-medium text-secondary-900">{part.name}</h3>
                          {isLowStock && (
                            <Badge variant="warning">
                              <AlertTriangle className="h-3 w-3 mr-1" />
                              Estoque Baixo
                            </Badge>
                          )}
                        </div>
                        <p className="text-sm text-secondary-600">SKU: {part.sku}</p>
                        <div className="flex items-center gap-4 mt-2">
                          <span className="text-sm text-secondary-600">
                            Estoque: {part.quantity}
                          </span>
                          <span className="text-sm font-medium text-secondary-900">
                            R$ {part.unit_cost.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                          </span>
                        </div>
                      </div>
                      <Button
                        onClick={() => addToCart(part)}
                        variant="secondary"
                        size="sm"
                        disabled={part.quantity === 0}
                        className="ml-2"
                      >
                        <Plus className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Carrinho */}
          <div>
            <div className="mb-4">
              <h3 className="text-lg font-semibold text-secondary-900 flex items-center">
                <Package className="h-5 w-5 mr-2" />
                Carrinho ({totalItems} itens)
              </h3>
            </div>

            {cart.length === 0 ? (
              <div className="text-center py-8 text-secondary-500">
                <ShoppingCart className="h-12 w-12 mx-auto mb-4" />
                <p>Carrinho vazio</p>
                <p className="text-sm mt-1">Adicione peças da lista ao lado</p>
              </div>
            ) : (
              <div className="space-y-3 max-h-96 overflow-y-auto">
                {cart.map((item) => (
                  <div key={item.part_id} className="p-3 border border-secondary-200 rounded-lg">
                    <div className="flex justify-between items-start">
                      <div className="flex-1">
                        <h4 className="font-medium text-secondary-900">{item.name}</h4>
                        <p className="text-sm text-secondary-600">SKU: {item.sku}</p>
                        <div className="flex items-center gap-4 mt-2">
                          <div className="flex items-center gap-2">
                            <Button
                              onClick={() => updateQuantity(item.part_id, item.quantity_to_use - 1)}
                              variant="secondary"
                              size="sm"
                              className="h-6 w-6 p-0"
                            >
                              <Minus className="h-3 w-3" />
                            </Button>
                            <span className="text-sm font-medium">{item.quantity_to_use}</span>
                            <Button
                              onClick={() => updateQuantity(item.part_id, item.quantity_to_use + 1)}
                              variant="secondary"
                              size="sm"
                              className="h-6 w-6 p-0"
                              disabled={item.quantity_to_use >= item.available_quantity}
                            >
                              <Plus className="h-3 w-3" />
                            </Button>
                          </div>
                          <span className="text-sm text-secondary-600">
                            R$ {item.unit_cost.toLocaleString('pt-BR', { minimumFractionDigits: 2 })} cada
                          </span>
                        </div>
                      </div>
                      <div className="text-right">
                        <p className="font-medium text-secondary-900">
                          R$ {item.total_cost.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                        </p>
                        <Button
                          onClick={() => removeFromCart(item.part_id)}
                          variant="secondary"
                          size="sm"
                          className="mt-2 h-6 w-6 p-0 text-error-600 hover:text-error-700"
                        >
                          <X className="h-3 w-3" />
                        </Button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}

            {cart.length > 0 && (
              <div className="mt-4 p-4 bg-secondary-50 rounded-lg">
                <div className="flex justify-between items-center mb-2">
                  <span className="font-medium text-secondary-900">Total:</span>
                  <span className="text-lg font-bold text-secondary-900">
                    R$ {totalCost.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                  </span>
                </div>
                
                {isEditing ? (
                  <div className="space-y-2">
                    <p className="text-sm text-secondary-600">
                      Salve as alterações para atualizar a ordem de serviço
                    </p>
                    <div className="flex gap-2">
                      <Button onClick={onClose} variant="secondary" className="flex-1">
                        Cancelar
                      </Button>
                      <Button onClick={handleSave} disabled={saving} className="flex-1">
                        {saving ? (
                          <>
                            <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                            Salvando...
                          </>
                        ) : (
                          <>
                            <Save className="h-4 w-4 mr-2" />
                            Salvar Peças
                          </>
                        )}
                      </Button>
                    </div>
                  </div>
                ) : (
                  <div>
                    <p className="text-sm text-secondary-600 mb-4">
                      As peças selecionadas já foram adicionadas à lista de peças utilizadas
                    </p>
                    <Button onClick={onClose} className="w-full">
                      Fechar Carrinho
                    </Button>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};