import React from 'react';
import { Camera, AlertTriangle, FileText, MapPin, Wrench, Trash2 } from 'lucide-react';
import { Button } from '../UI/Button';
import { Badge } from '../UI/Badge';

interface DamageItem {
  id: string;
  location: string;
  description: string;
  damage_type: 'Arranhão' | 'Amassado' | 'Quebrado' | 'Desgaste' | 'Outro';
  severity: 'Baixa' | 'Média' | 'Alta';
  photo_url?: string;
  requires_repair: boolean;
}

interface DamageCartSummaryProps {
  damageCount: number;
  inspectionType: string;
  contractId?: string;
  onOpenDamageCart: () => void;
  damageCart?: DamageItem[];
  onRemoveDamage?: (damageId: string) => void;
  onUpdateCart?: (damages: DamageItem[]) => void;
}

export const DamageCartSummary: React.FC<DamageCartSummaryProps> = ({
  damageCount,
  inspectionType,
  contractId,
  onOpenDamageCart,
  damageCart = [],
  onRemoveDamage,
  onUpdateCart
}) => {
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

  const handleRemoveDamage = (damageId: string) => {
    if (onRemoveDamage) {
      onRemoveDamage(damageId);
    } else if (onUpdateCart && damageCart) {
      // Fallback: update cart by removing the item
      const updatedCart = damageCart.filter(damage => damage.id !== damageId);
      onUpdateCart(updatedCart);
    }
  };

  const handleClearAll = () => {
    if (onUpdateCart) {
      onUpdateCart([]);
    }
  };

  return (
    <div className="border-t pt-4 lg:pt-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-4">
        <h3 className="text-lg font-semibold text-secondary-900 flex items-center">
          <Camera className="h-5 w-5 mr-2" />
          Danos Detectados ({damageCount})
        </h3>
        <Button
          type="button"
          variant="secondary"
          size="sm"
          onClick={onOpenDamageCart}
        >
          <Camera className="h-4 w-4 mr-2" />
          Registrar Danos
        </Button>
      </div>

      {damageCount > 0 ? (
        <div className="space-y-4">
          {/* Lista de danos */}
          <div className="bg-secondary-50 p-4 rounded-lg">
            <div className="flex justify-between items-center mb-3">
              <h4 className="font-medium text-secondary-900 flex items-center">
                <MapPin className="h-4 w-4 mr-2" />
                Danos no Carrinho ({damageCart.length})
              </h4>
              {damageCart.length > 0 && (onUpdateCart || onRemoveDamage) && (
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  onClick={handleClearAll}
                  className="text-error-600 hover:text-error-700"
                >
                  <Trash2 className="h-3 w-3 mr-1" />
                  Limpar Tudo
                </Button>
              )}
            </div>
            
            {damageCart.length > 0 ? (
              <div className="space-y-3">
                {damageCart.map((damage, index) => (
                  <div key={damage.id || index} className="bg-white p-3 rounded-lg border border-secondary-200">
                    <div className="flex justify-between items-start mb-2">
                      <div className="flex-1">
                        <div className="flex flex-wrap items-center gap-2 mb-1">
                          <h5 className="font-medium text-secondary-900 text-sm">{damage.location}</h5>
                          {getDamageTypeBadge(damage.damage_type)}
                          {getSeverityBadge(damage.severity)}
                        </div>
                        <p className="text-xs text-secondary-600">{damage.description}</p>
                      </div>
                      <div className="flex items-center gap-2 ml-2">
                        {damage.requires_repair && (
                          <div className="flex items-center text-xs text-warning-600">
                            <Wrench className="h-3 w-3 mr-1" />
                            Reparo
                          </div>
                        )}
                        {(onUpdateCart || onRemoveDamage) && (
                          <button
                            type="button"
                            onClick={() => handleRemoveDamage(damage.id)}
                            className="p-1 text-error-400 hover:text-error-600 hover:bg-error-50 rounded transition-colors"
                            title="Remover dano"
                          >
                            <Trash2 className="h-3 w-3" />
                          </button>
                        )}
                      </div>
                    </div>
                    
                    {damage.photo_url && (
                      <div className="mt-2">
                        <img 
                          src={damage.photo_url} 
                          alt="Foto do dano" 
                          className="w-full h-20 object-cover rounded border"
                          crossOrigin="anonymous"
                        />
                      </div>
                    )}
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-secondary-600">Nenhum dano adicionado ao carrinho ainda.</p>
            )}
          </div>

          {/* Resumo estatístico */}
          <div className="bg-secondary-50 p-3 rounded-lg">
            <div className="grid grid-cols-3 gap-4 text-sm">
              <div className="text-center">
                <span className="text-secondary-600">Total:</span>
                <p className="font-medium text-lg">{damageCount}</p>
              </div>
              <div className="text-center">
                <span className="text-secondary-600">Alta Severidade:</span>
                <p className="font-medium text-lg text-error-600">
                  {damageCart.filter(d => d.severity === 'Alta').length}
                </p>
              </div>
              <div className="text-center">
                <span className="text-secondary-600">Requer Reparo:</span>
                <p className="font-medium text-lg text-warning-600">
                  {damageCart.filter(d => d.requires_repair).length}
                </p>
              </div>
            </div>
          </div>
          
          {/* Alert for CheckOut with damages */}
          {inspectionType === 'CheckOut' && damageCount > 0 && (
            <div className="bg-warning-50 border border-warning-200 rounded-lg p-3">
              <div className="flex items-start">
                <AlertTriangle className="h-5 w-5 text-warning-600 mr-2 mt-0.5" />
                <div>
                  <p className="text-sm font-medium text-warning-800">
                    Notificação Automática
                  </p>
                  <p className="text-xs text-warning-700 mt-1">
                    Um email será enviado automaticamente ao gerente para aprovação de orçamento dos danos detectados.
                    Um lançamento de custo será criado no sistema com valor "A Definir".
                  </p>
                </div>
              </div>
            </div>
          )}
          
          {/* Alert for CheckIn with contract and damages */}
          {inspectionType === 'CheckIn' && contractId && damageCount > 0 && (
            <div className="bg-info-50 border border-info-200 rounded-lg p-3">
              <div className="flex items-start">
                <FileText className="h-5 w-5 text-info-600 mr-2 mt-0.5" />
                <div>
                  <p className="text-sm font-medium text-info-800">
                    Cobrança Automática
                  </p>
                  <p className="text-xs text-info-700 mt-1">
                    Os danos detectados serão automaticamente vinculados ao cliente do contrato selecionado.
                    Um lançamento de cobrança será criado no departamento de Cobrança.
                  </p>
                </div>
              </div>
            </div>
          )}
        </div>
      ) : (
        <div className="text-center py-6 text-secondary-500">
          <Camera className="h-8 w-8 mx-auto mb-2" />
          <p>Nenhum dano registrado</p>
          <p className="text-sm mt-1">Use o botão acima para registrar danos encontrados</p>
        </div>
      )}
    </div>
  );
};