/* eslint-disable @typescript-eslint/no-explicit-any */
import React, { useState, useEffect } from 'react';
import { Card, CardHeader, CardContent } from '../components/UI/Card';
import { Button } from '../components/UI/Button';
import { Badge } from '../components/UI/Badge';
import { useParts } from '../hooks/useParts';
import { useStockMovements } from '../hooks/useStockMovements';
import { useAuth } from '../hooks/useAuth';
import { Plus, Search, Filter, Package, AlertTriangle, TrendingDown, Loader2, Edit, Eye, Trash2, ArrowUp, ArrowDown } from 'lucide-react';

// Modal para editar/adicionar peça
const PartModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  part?: any;
  onSave: (data: any) => Promise<void>;
}> = ({ isOpen, onClose, part, onSave }) => {
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    sku: part?.sku || '',
    name: part?.name || '',
    unit_cost: part?.unit_cost || 0,
    quantity: part?.quantity || 0,
    min_stock: part?.min_stock || 0
  });

  // Reset form data whenever the modal is opened or the part changes
  useEffect(() => {
    if (isOpen) {
      setFormData({
        sku: part?.sku || '',
        name: part?.name || '',
        unit_cost: part?.unit_cost || 0,
        quantity: part?.quantity || 0,
        min_stock: part?.min_stock || 0
      });
    }
  }, [isOpen, part]);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      await onSave(formData);
      onClose();
    } catch (error) {
      console.error('Error saving part:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: name === 'unit_cost' || name === 'quantity' || name === 'min_stock' 
        ? Number(value) || 0 
        : value
    }));
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-6 w-full max-w-lg">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-xl font-semibold text-secondary-900">
            {part ? 'Editar Peça' : 'Nova Peça'}
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600">
            ×
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              SKU *
            </label>
            <input
              type="text"
              name="sku"
              value={formData.sku}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder="FLT-001"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              Nome da Peça *
            </label>
            <input
              type="text"
              name="name"
              value={formData.name}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder="Filtro de Óleo"
              required
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-secondary-700 mb-2">
                Custo Unitário (R$) *
              </label>
              <input
                type="number"
                name="unit_cost"
                value={formData.unit_cost}
                onChange={handleChange}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                step="0.01"
                min="0"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-secondary-700 mb-2">
                Quantidade Inicial
              </label>
              <input
                type="number"
                name="quantity"
                value={formData.quantity}
                onChange={handleChange}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                min="0"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              Estoque Mínimo
            </label>
            <input
              type="number"
              name="min_stock"
              value={formData.min_stock}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              min="0"
            />
          </div>

          <div className="flex justify-end space-x-4 pt-6 border-t">
            <Button variant="secondary" onClick={onClose} disabled={loading}>
              Cancelar
            </Button>
            <Button type="submit" disabled={loading}>
              {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
              {part ? 'Salvar Alterações' : 'Cadastrar Peça'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
};

// Modal para movimentação de estoque
const MovementModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  parts: any[];
  onSave: (data: any) => Promise<void>;
}> = ({ isOpen, onClose, parts, onSave }) => {
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    part_id: '',
    type: 'Entrada' as 'Entrada' | 'Saída',
    quantity: 1,
    movement_date: new Date().toISOString().split('T')[0],
    service_note_id: ''
  });
  const [selectedPart, setSelectedPart] = useState<any>(null);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      const submitData = {
        ...formData,
        service_note_id: formData.service_note_id === '' ? null : formData.service_note_id
      };
      await onSave(submitData);
      onClose();
    } catch (error) {
      console.error('Error saving movement:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    
    if (name === 'part_id') {
      const part = parts.find(p => p.id === value);
      setSelectedPart(part);
    }
    
    setFormData(prev => ({
      ...prev,
      [name]: name === 'quantity' ? Number(value) || 1 : value
    }));
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-6 w-full max-w-lg">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-xl font-semibold text-secondary-900">
            Nova Movimentação
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600">
            ×
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              Peça *
            </label>
            <select
              name="part_id"
              value={formData.part_id}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              required
            >
              <option value="">Selecione uma peça</option>
              {parts.map(part => (
                <option key={part.id} value={part.id}>
                  {part.sku} - {part.name} (Estoque: {part.quantity})
                </option>
              ))}
            </select>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-secondary-700 mb-2">
                Tipo *
              </label>
              <select
                name="type"
                value={formData.type}
                onChange={handleChange}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                required
              >
                <option value="Entrada">Entrada</option>
                <option value="Saída">Saída</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-secondary-700 mb-2">
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
              {formData.type === 'Saída' && selectedPart && (
                <p className="text-xs mt-1 text-secondary-500">
                  Disponível: {selectedPart.quantity} unidades
                </p>
              )}
              {formData.type === 'Saída' && selectedPart && formData.quantity > selectedPart.quantity && (
                <p className="text-xs mt-1 text-error-600">
                  Quantidade excede o estoque disponível!
                </p>
              )}
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              Data *
            </label>
            <input
              type="date"
              name="movement_date"
              value={formData.movement_date}
              onChange={handleChange}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              required
            />
          </div>

          <div className="flex justify-end space-x-4 pt-6 border-t">
            <Button variant="secondary" onClick={onClose} disabled={loading}>
              Cancelar
            </Button>
            <Button 
              type="submit" 
              disabled={loading || (formData.type === 'Saída' && selectedPart && formData.quantity > selectedPart.quantity)}
            >
              {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
              Registrar Movimentação
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
};

// Modal para visualizar movimentações de uma peça
const PartMovementsModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  part?: any;
  stockMovements: any[];
}> = ({ isOpen, onClose, part, stockMovements }) => {
  if (!isOpen || !part) return null;

  // Filtrar movimentações da peça selecionada
  const partMovements = stockMovements.filter(movement => movement.part_id === part.id);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-6 w-full max-w-3xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-xl font-semibold text-secondary-900">
            Movimentações - {part.name} ({part.sku})
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600">
            ×
          </button>
        </div>

        <div className="bg-secondary-50 p-4 rounded-lg mb-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <p className="text-sm text-secondary-600">Estoque Atual:</p>
              <p className="font-bold text-xl">{part.quantity} unidades</p>
            </div>
            <div>
              <p className="text-sm text-secondary-600">Estoque Mínimo:</p>
              <p className="font-medium">{part.min_stock} unidades</p>
            </div>
            <div>
              <p className="text-sm text-secondary-600">Custo Unitário:</p>
              <p className="font-medium">R$ {part.unit_cost.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}</p>
            </div>
          </div>
        </div>

        {partMovements.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-secondary-50">
                <tr>
                  <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Data</th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Tipo</th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Quantidade</th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600">Ordem de Serviço</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-secondary-200">
                {partMovements.map((movement) => (
                  <tr key={movement.id} className="hover:bg-secondary-50">
                    <td className="py-3 px-4 text-sm text-secondary-600">
                      {new Date(movement.movement_date).toLocaleDateString('pt-BR')}
                    </td>
                    <td className="py-3 px-4">
                      <Badge 
                        variant={movement.type === 'Entrada' ? 'success' : 'error'}
                        className="flex items-center"
                      >
                        {movement.type === 'Entrada' ? (
                          <ArrowUp className="h-3 w-3 mr-1" />
                        ) : (
                          <ArrowDown className="h-3 w-3 mr-1" />
                        )}
                        {movement.type}
                      </Badge>
                    </td>
                    <td className="py-3 px-4 text-sm font-medium text-secondary-900">
                      {movement.quantity} unidades
                    </td>
                    <td className="py-3 px-4 text-sm text-secondary-600">
                      {movement.service_notes?.description || '-'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="text-center py-8">
            <Package className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
            <p className="text-secondary-600">Nenhuma movimentação encontrada para esta peça</p>
          </div>
        )}

        <div className="flex justify-end pt-6 border-t mt-6">
          <Button onClick={onClose}>
            Fechar
          </Button>
        </div>
      </div>
    </div>
  );
};

export const Inventory: React.FC = () => {
  const { parts, loading: partsLoading, createPart, updatePart, deletePart, refetch: refetchParts } = useParts();
  const { stockMovements, loading: movementsLoading, createStockMovement } = useStockMovements();
  const { isAdmin, isManager, hasPermission } = useAuth();
  const [searchTerm, setSearchTerm] = useState('');
  const [isPartModalOpen, setIsPartModalOpen] = useState(false);
  const [isMovementModalOpen, setIsMovementModalOpen] = useState(false);
  const [isMovementsViewOpen, setIsMovementsViewOpen] = useState(false);
  const [selectedPart, setSelectedPart] = useState<any>(undefined);
  const [stockFilter, setStockFilter] = useState('');

  const canManageInventory = isAdmin || isManager || hasPermission('inventory');

  const filteredParts = parts.filter(part => {
    const matchesSearch = 
      part.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      part.sku.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesStock = 
      stockFilter === '' || 
      (stockFilter === 'low' && part.quantity <= part.min_stock) ||
      (stockFilter === 'out' && part.quantity === 0) ||
      (stockFilter === 'normal' && part.quantity > part.min_stock);
    
    return matchesSearch && matchesStock;
  });

  const getStockStatus = (part: any) => {
    if (part.quantity <= 0) {
      return <Badge variant="error">Sem Estoque</Badge>;
    } else if (part.quantity <= part.min_stock) {
      return <Badge variant="warning">Estoque Baixo</Badge>;
    }
    return <Badge variant="success">Normal</Badge>;
  };

  const handleEditPart = (part: any) => {
    setSelectedPart(part);
    setIsPartModalOpen(true);
  };

  const handleViewMovements = (part: any) => {
    setSelectedPart(part);
    setIsMovementsViewOpen(true);
  };

  const handleNewPart = () => {
    setSelectedPart(undefined);
    setIsPartModalOpen(true);
  };

  const handleNewMovement = () => {
    setIsMovementModalOpen(true);
  };

  const handleSavePart = async (data: any) => {
    if (selectedPart) {
      await updatePart(selectedPart.id, data);
    } else {
      await createPart(data);
    }
  };

  const handleSaveMovement = async (data: any) => {
    try {
      await createStockMovement(data);
      // Fazer refetch das peças para atualizar as quantidades
      await refetchParts();
      setIsMovementModalOpen(false);
    } catch (error) {
      console.error('Error saving movement:', error);
    }
  };

  const handleDeletePart = async (id: string) => {
    if (confirm('Tem certeza que deseja excluir esta peça?')) {
      try {
        await deletePart(id);
      } catch (error) {
        console.error('Error deleting part:', error);
      }
    }
  };

  const lowStockItems = filteredParts.filter(part => part.quantity <= part.min_stock).length;
  const outOfStockItems = filteredParts.filter(part => part.quantity === 0).length;
  const totalValue = filteredParts.reduce((sum, part) => sum + (part.quantity * part.unit_cost), 0);

  const loading = partsLoading || movementsLoading;

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-primary-600" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold text-secondary-900">Estoque</h1>
          <p className="text-secondary-600 mt-2">Controle de peças e suprimentos</p>
        </div>
        <div className="flex space-x-3">
          {canManageInventory && (
            <>
              <Button variant="secondary" onClick={handleNewMovement}>
                <Plus className="h-4 w-4 mr-2" />
                Nova Movimentação
              </Button>
              <Button onClick={handleNewPart}>
                <Plus className="h-4 w-4 mr-2" />
                Nova Peça
              </Button>
            </>
          )}
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardContent>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-secondary-600 text-sm font-medium">Valor Total do Estoque</p>
                <p className="text-2xl font-bold text-secondary-900">
                  R$ {totalValue.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                </p>
              </div>
              <div className="h-12 w-12 bg-primary-100 rounded-lg flex items-center justify-center">
                <Package className="h-6 w-6 text-primary-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-secondary-600 text-sm font-medium">Itens em Estoque Baixo</p>
                <p className="text-2xl font-bold text-secondary-900">{lowStockItems}</p>
                <p className="text-xs text-warning-600 mt-1">Necessitam reposição</p>
              </div>
              <div className="h-12 w-12 bg-warning-100 rounded-lg flex items-center justify-center">
                <AlertTriangle className="h-6 w-6 text-warning-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-secondary-600 text-sm font-medium">Itens Sem Estoque</p>
                <p className="text-2xl font-bold text-secondary-900">{outOfStockItems}</p>
                <p className="text-xs text-error-600 mt-1">Indisponíveis</p>
              </div>
              <div className="h-12 w-12 bg-error-100 rounded-lg flex items-center justify-center">
                <TrendingDown className="h-6 w-6 text-error-600" />
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Filters */}
      <Card>
        <CardContent>
          <div className="flex flex-col sm:flex-row gap-4">
            <div className="flex-1">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
                <input
                  type="text"
                  placeholder="Buscar por nome ou SKU..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                />
              </div>
            </div>
            <div className="flex space-x-2">
              <select
                value={stockFilter}
                onChange={(e) => setStockFilter(e.target.value)}
                className="border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              >
                <option value="">Todos os Status</option>
                <option value="low">Estoque Baixo</option>
                <option value="out">Sem Estoque</option>
                <option value="normal">Estoque Normal</option>
              </select>
              <Button variant="secondary">
                <Filter className="h-4 w-4 mr-2" />
                Filtros
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Parts List */}
      <Card>
        <CardHeader>
          <h3 className="text-lg font-semibold text-secondary-900">
            Peças em Estoque ({filteredParts.length})
          </h3>
        </CardHeader>
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-secondary-50">
                <tr>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">SKU</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Nome</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Categoria</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Quantidade</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Estoque Mín.</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Custo Unit.</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Valor Total</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Status</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-secondary-200">
                {filteredParts.map((part) => (
                  <tr key={part.id} className="hover:bg-secondary-50">
                    <td className="py-4 px-6 text-sm font-medium text-secondary-900">
                      {part.sku}
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      {part.name}
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">{part.category || '-'}</td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      {part.quantity}
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      {part.min_stock}
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      R$ {part.unit_cost.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                    </td>
                    <td className="py-4 px-6 text-sm font-medium text-secondary-900">
                      R$ {(part.quantity * part.unit_cost).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                    </td>
                    <td className="py-4 px-6">
                      {getStockStatus(part)}
                    </td>
                    <td className="py-4 px-6">
                      <div className="flex items-center space-x-2">
                        <button 
                          onClick={() => handleViewMovements(part)}
                          className="p-1 text-secondary-400 hover:text-secondary-600"
                          title="Ver movimentações"
                        >
                          <Eye className="h-4 w-4" />
                        </button>
                        {canManageInventory && (
                          <>
                            <button 
                              onClick={() => handleEditPart(part)}
                              className="p-1 text-secondary-400 hover:text-secondary-600"
                              title="Editar"
                            >
                              <Edit className="h-4 w-4" />
                            </button>
                            <button 
                              onClick={() => handleDeletePart(part.id)}
                              className="p-1 text-secondary-400 hover:text-error-600"
                              title="Excluir"
                            >
                              <Trash2 className="h-4 w-4" />
                            </button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>

      {/* Recent Stock Movements */}
      <Card>
        <CardHeader>
          <h3 className="text-lg font-semibold text-secondary-900">
            Movimentações Recentes
          </h3>
        </CardHeader>
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-secondary-50">
                <tr>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Data</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Peça</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Tipo</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Quantidade</th>
                  <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Referência</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-secondary-200">
                {stockMovements.slice(0, 10).map((movement) => (
                  <tr key={movement.id} className="hover:bg-secondary-50">
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      {new Date(movement.movement_date).toLocaleDateString('pt-BR')}
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      {movement.parts?.name || 'Peça não encontrada'} ({movement.parts?.sku || 'N/A'})
                    </td>
                    <td className="py-4 px-6">
                      <Badge 
                        variant={movement.type === 'Entrada' ? 'success' : 'error'}
                        className="flex items-center"
                      >
                        {movement.type === 'Entrada' ? (
                          <ArrowUp className="h-3 w-3 mr-1" />
                        ) : (
                          <ArrowDown className="h-3 w-3 mr-1" />
                        )}
                        {movement.type}
                      </Badge>
                    </td>
                    <td className="py-4 px-6 text-sm font-medium text-secondary-900">
                      {movement.quantity} unidades
                    </td>
                    <td className="py-4 px-6 text-sm text-secondary-600">
                      {movement.service_notes?.description || '-'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {stockMovements.length === 0 && (
            <div className="text-center py-8">
              <Package className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
              <p className="text-secondary-600">Nenhuma movimentação de estoque encontrada</p>
            </div>
          )}
        </CardContent>
      </Card>

      <PartModal
        isOpen={isPartModalOpen}
        onClose={() => setIsPartModalOpen(false)}
        part={selectedPart}
        onSave={handleSavePart}
      />

      <MovementModal
        isOpen={isMovementModalOpen}
        onClose={() => setIsMovementModalOpen(false)}
        parts={parts}
        onSave={handleSaveMovement}
      />

      <PartMovementsModal
        isOpen={isMovementsViewOpen}
        onClose={() => setIsMovementsViewOpen(false)}
        part={selectedPart}
        stockMovements={stockMovements}
      />
    </div>
  );
};

export default Inventory;