import React, { useState } from 'react';
import { Button } from './UI/Button';
import { Badge } from './UI/Badge';
import { Plus, ShoppingCart, X, Camera, Trash2, MapPin } from 'lucide-react';

interface DamageItem {
  id: string;
  location: string;
  description: string;
  damage_type: 'Arranhão' | 'Amassado' | 'Quebrado' | 'Desgaste' | 'Outro';
  severity: 'Baixa' | 'Média' | 'Alta';
  photo_url?: string;
  requires_repair: boolean;
}

interface DamageCartModalProps {
  isOpen: boolean;
  onClose: () => void;
  damageCart: DamageItem[];
  onUpdateCart: (cart: DamageItem[]) => void;
  onSaveCart: (damages: Omit<DamageItem, 'id'>[]) => Promise<void>;
  onUploadPhoto: (file: File) => Promise<string>;
}

const PREDEFINED_LOCATIONS = [
  'Para-choque dianteiro',
  'Para-choque traseiro',
  'Porta dianteira esquerda',
  'Porta dianteira direita',
  'Porta traseira esquerda',
  'Porta traseira direita',
  'Capô',
  'Teto',
  'Porta-malas',
  'Lateral esquerda',
  'Lateral direita',
  'Farol dianteiro esquerdo',
  'Farol dianteiro direito',
  'Farol traseiro esquerdo',
  'Farol traseiro direito',
  'Retrovisor esquerdo',
  'Retrovisor direito',
  'Para-brisa dianteiro',
  'Para-brisa traseiro',
  'Vidro lateral esquerdo',
  'Vidro lateral direito',
  'Roda dianteira esquerda',
  'Roda dianteira direita',
  'Roda traseira esquerda',
  'Roda traseira direita',
  'Estepe',
  'Painel interno',
  'Bancos',
  'Volante',
  'Outro'
];

export const DamageCartModal: React.FC<DamageCartModalProps> = ({
  isOpen,
  onClose,
  damageCart,
  onUpdateCart,
  onSaveCart,
  onUploadPhoto
}) => {
  const [loading, setLoading] = useState(false);
  const [uploadingPhoto, setUploadingPhoto] = useState<string | null>(null);
  const [newDamage, setNewDamage] = useState<Omit<DamageItem, 'id'>>({
    location: '',
    description: '',
    damage_type: 'Arranhão',
    severity: 'Baixa',
    photo_url: '',
    requires_repair: true
  });

  if (!isOpen) return null;

  const addDamageToCart = () => {
    if (!newDamage.location || !newDamage.description) return;

    const damageWithId: DamageItem = {
      ...newDamage,
      id: Date.now().toString() + Math.random().toString()
    };

    onUpdateCart([...damageCart, damageWithId]);
    
    // Reset form
    setNewDamage({
      location: '',
      description: '',
      damage_type: 'Arranhão',
      severity: 'Baixa',
      photo_url: '',
      requires_repair: true
    });
  };

  const removeDamageFromCart = (damageId: string) => {
    onUpdateCart(damageCart.filter(item => item.id !== damageId));
  };

  const updateDamageInCart = (damageId: string, updates: Partial<DamageItem>) => {
    onUpdateCart(damageCart.map(item => 
      item.id === damageId ? { ...item, ...updates } : item
    ));
  };

  const handlePhotoUpload = async (e: React.ChangeEvent<HTMLInputElement>, damageId?: string) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      alert('Por favor, selecione um arquivo de imagem válido.');
      return;
    }

    const targetId = damageId || 'new';
    setUploadingPhoto(targetId);
    
    try {
      const photoUrl = await onUploadPhoto(file);
      
      if (damageId) {
        updateDamageInCart(damageId, { photo_url: photoUrl });
      } else {
        setNewDamage(prev => ({ ...prev, photo_url: photoUrl }));
      }
    } catch (error) {
      console.error('Error uploading photo:', error);
      alert('Erro ao fazer upload da foto');
    } finally {
      setUploadingPhoto(null);
    }
  };

  const handleSaveCart = async () => {
    if (damageCart.length === 0) {
      alert('Adicione pelo menos um dano antes de finalizar.');
      return;
    }
    
    setLoading(true);
    try {
      const damagesWithoutId = damageCart.map(damage => {
        const { id, ...damageWithoutId } = damage;
        return damageWithoutId;
      });
      await onSaveCart(damagesWithoutId);
      // Don't clear cart here - let parent component handle it
      onClose();
    } catch (error) {
      console.error('Error saving damage cart:', error);
      alert('Erro ao salvar danos. Tente novamente.');
    } finally {
      setLoading(false);
    }
  };

  const getSeverityBadge = (severity: string) => {
    const variants = {
      'Baixa': 'secondary',
      'Média': 'warning',
      'Alta': 'error'
    } as const;

    return <Badge variant={variants[severity as keyof typeof variants] || 'secondary'}>{severity}</Badge>;
  };

  const getDamageTypeBadge = (damageType: string) => {
    return <Badge variant="info">{damageType}</Badge>;
  };

  const totalDamages = damageCart.length;
  const highSeverityCount = damageCart.filter(d => d.severity === 'Alta').length;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg w-full max-w-6xl max-h-[95vh] overflow-hidden flex flex-col lg:flex-row">
        {/* Left Panel - Add New Damage */}
        <div className="flex-1 p-4 lg:p-6 border-b lg:border-b-0 lg:border-r border-secondary-200">
          <div className="flex justify-between items-center mb-4 lg:mb-6">
            <h2 className="text-lg lg:text-xl font-semibold text-secondary-900 flex items-center">
              <Camera className="h-5 w-5 mr-2" />
              Registrar Novo Dano
            </h2>
            <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 lg:hidden">
              <X className="h-6 w-6" />
            </button>
          </div>

          {/* New Damage Form */}
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-secondary-700 mb-2">
                <MapPin className="h-4 w-4 inline mr-1" />
                Local do Dano *
              </label>
              <select
                value={newDamage.location}
                onChange={(e) => setNewDamage(prev => ({ ...prev, location: e.target.value }))}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              >
                <option value="">Selecione o local do dano</option>
                {PREDEFINED_LOCATIONS.map((location) => (
                  <option key={location} value={location}>
                    {location}
                  </option>
                ))}
              </select>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-2">
                  Tipo de Dano *
                </label>
                <select
                  value={newDamage.damage_type}
                  onChange={(e) => setNewDamage(prev => ({ ...prev, damage_type: e.target.value as DamageItem['damage_type'] }))}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                >
                  <option value="Arranhão">Arranhão</option>
                  <option value="Amassado">Amassado</option>
                  <option value="Quebrado">Quebrado</option>
                  <option value="Desgaste">Desgaste</option>
                  <option value="Outro">Outro</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-secondary-700 mb-2">
                  Severidade *
                </label>
                <select
                  value={newDamage.severity}
                  onChange={(e) => setNewDamage(prev => ({ ...prev, severity: e.target.value as DamageItem['severity'] }))}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                >
                  <option value="Baixa">Baixa</option>
                  <option value="Média">Média</option>
                  <option value="Alta">Alta</option>
                </select>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-secondary-700 mb-2">
                Descrição Detalhada *
              </label>
              <textarea
                value={newDamage.description}
                onChange={(e) => setNewDamage(prev => ({ ...prev, description: e.target.value }))}
                rows={3}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                placeholder="Descreva detalhadamente o dano encontrado, incluindo tamanho, profundidade, extensão..."
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-secondary-700 mb-2">
                Foto do Dano
              </label>
              <div className="space-y-2">
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (!file) return;
                    if (!file.type.startsWith('image/')) {
                      alert('Por favor, selecione um arquivo de imagem válido.');
                      return;
                    }
                    handlePhotoUpload(e);
                  }}
                  className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                  disabled={uploadingPhoto === 'new'}
                />
                {uploadingPhoto === 'new' && (
                  <p className="text-sm text-secondary-600">Fazendo upload da foto...</p>
                )}
                {newDamage.photo_url && (
                  <div className="mt-2">
                    <img 
                      src={newDamage.photo_url} 
                      alt="Foto do dano" 
                      className="w-full h-32 object-cover rounded-lg border"
                    />
                  </div>
                )}
              </div>
            </div>

            <div className="flex items-center">
              <input
                type="checkbox"
                checked={newDamage.requires_repair}
                onChange={(e) => setNewDamage(prev => ({ ...prev, requires_repair: e.target.checked }))}
                className="h-4 w-4 text-primary-600 focus:ring-primary-500 border-secondary-300 rounded"
              />
              <label className="ml-2 block text-sm text-secondary-700">
                Requer reparo
              </label>
            </div>

            <Button
              onClick={addDamageToCart}
              disabled={!newDamage.location || !newDamage.description}
              className="w-full"
            >
              <Plus className="h-4 w-4 mr-2" />
              Adicionar ao Carrinho
            </Button>
          </div>
        </div>

        {/* Right Panel - Damage Cart */}
        <div className="w-full lg:w-96 p-4 lg:p-6 bg-secondary-50">
          <div className="flex items-center justify-between mb-4 lg:mb-6">
            <h3 className="text-lg font-semibold text-secondary-900 flex items-center">
              <ShoppingCart className="h-5 w-5 mr-2" />
              Carrinho ({totalDamages})
            </h3>
            <div className="flex items-center space-x-2">
              {damageCart.length > 0 && (
                <button
                  onClick={() => onUpdateCart([])}
                  className="text-sm text-error-600 hover:text-error-800"
                >
                  Limpar
                </button>
              )}
              <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 hidden lg:block">
                <X className="h-6 w-6" />
              </button>
            </div>
          </div>

          {damageCart.length === 0 ? (
            <div className="text-center py-8">
              <ShoppingCart className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
              <p className="text-secondary-600">Carrinho vazio</p>
              <p className="text-sm text-secondary-500 mt-1">
                Adicione danos encontrados na inspeção
              </p>
            </div>
          ) : (
            <>
              {/* Cart Summary */}
              <div className="bg-white p-4 rounded-lg border border-secondary-200 mb-4">
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <span className="text-secondary-600">Total de Danos:</span>
                    <p className="font-medium text-lg">{totalDamages}</p>
                  </div>
                  <div>
                    <span className="text-secondary-600">Alta Severidade:</span>
                    <p className="font-medium text-lg text-error-600">{highSeverityCount}</p>
                  </div>
                </div>
              </div>

              {/* Cart Items */}
              <div className="space-y-3 mb-6 max-h-64 lg:max-h-80 overflow-y-auto">
                {damageCart.map((damage) => (
                  <div key={damage.id} className="bg-white p-3 rounded-lg border border-secondary-200">
                    <div className="flex justify-between items-start mb-2">
                      <div className="flex-1 min-w-0">
                        <div className="flex flex-wrap items-center gap-2 mb-1">
                          <h4 className="font-medium text-secondary-900 text-sm truncate">{damage.location}</h4>
                          {getDamageTypeBadge(damage.damage_type)}
                          {getSeverityBadge(damage.severity)}
                        </div>
                        <p className="text-xs text-secondary-600 line-clamp-2">{damage.description}</p>
                      </div>
                      <button
                        onClick={() => removeDamageFromCart(damage.id)}
                        className="text-error-600 hover:text-error-800 flex-shrink-0 ml-2"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                    
                    {damage.photo_url && (
                      <div className="mt-2">
                        <img 
                          src={damage.photo_url} 
                          alt="Foto do dano" 
                          className="w-full h-20 object-cover rounded border"
                        />
                      </div>
                    )}

                    {!damage.requires_repair && (
                      <div className="mt-2">
                        <Badge variant="secondary" className="text-xs">Não requer reparo</Badge>
                      </div>
                    )}

                    <div>
                      <label className="block text-sm font-medium text-secondary-700 mb-2">
                        Foto do Dano
                      </label>
                      <div className="space-y-2">
                        <input
                          type="file"
                          accept="image/*"
                          onChange={(e) => handlePhotoUpload(e, damage.id)}
                          disabled={uploadingPhoto === damage.id}
                        />
                        {uploadingPhoto === damage.id && (
                          <p className="text-sm text-secondary-600">Fazendo upload da foto...</p>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              {/* Action Buttons */}
              <div className="space-y-3">
                <Button
                  onClick={handleSaveCart}
                  disabled={loading}
                  className="w-full"
                >
                  {loading ? 'Processando...' : 'Adicionar Danos à Inspeção'}
                </Button>
                <Button
                  variant="secondary"
                  onClick={onClose}
                  className="w-full"
                >
                  Cancelar
                </Button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default DamageCartModal;