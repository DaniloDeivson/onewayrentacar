import React from 'react';
import { Badge } from '../UI/Badge';
import { Button } from '../UI/Button';
import { Edit, AlertTriangle, Car, User, FileText, DollarSign, CheckCircle, Eye } from 'lucide-react';
import { DetailedCost } from '../../hooks/useDetailedCosts';

interface DetailedCostsListProps {
  costs: DetailedCost[];
  onView: (cost: DetailedCost) => void;
  onEdit?: (cost: DetailedCost) => void;
  onEditEstimate?: (cost: DetailedCost) => void;
  onAuthorize?: (cost: DetailedCost) => void;
  onMarkAsPaid?: (cost: DetailedCost) => void;
  canEdit?: boolean;
  canAuthorize?: boolean;
}

export const DetailedCostsList: React.FC<DetailedCostsListProps> = ({
  costs,
  onView,
  onEdit,
  onEditEstimate,
  onAuthorize,
  onMarkAsPaid,
  canEdit = false,
  canAuthorize = false
}) => {
  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'Pendente':
        return <Badge variant="warning">Pendente</Badge>;
      case 'Autorizado':
        return <Badge variant="info">Autorizado</Badge>;
      case 'Pago':
        return <Badge variant="success">Pago</Badge>;
      case 'Cancelado':
        return <Badge variant="error">Cancelado</Badge>;
      default:
        return <Badge variant="secondary">{status}</Badge>;
    }
  };

  const getCategoryBadge = (category: string) => {
    const colors: Record<string, 'error' | 'warning' | 'info' | 'success' | 'secondary'> = {
      'Multa': 'error',
      'Funilaria': 'warning',
      'Peças': 'info',
      'Combustível': 'info',
      'Seguro': 'success',
      'Avulsa': 'secondary',
      'Compra': 'warning',
      'Excesso Km': 'error',
      'Diária Extra': 'warning'
    };

    return (
      <Badge variant={colors[category] || 'secondary'}>
        {category}
      </Badge>
    );
  };

  const getOriginIcon = (origin: string) => {
    switch (origin) {
      case 'Patio':
        return <Car className="h-4 w-4" />;
      case 'Manutencao':
        return <AlertTriangle className="h-4 w-4" />;
      case 'Sistema':
        return <FileText className="h-4 w-4" />;
      case 'Usuario':
        return <User className="h-4 w-4" />;
      case 'Compras':
        return <DollarSign className="h-4 w-4" />;
      default:
        return <FileText className="h-4 w-4" />;
    }
  };

  if (costs.length === 0) {
    return (
      <div className="text-center py-8">
        <FileText className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
        <p className="text-secondary-600">Nenhum custo encontrado</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {costs.map((cost) => (
        <div
          key={cost.id}
          className="bg-white rounded-lg border border-secondary-200 p-4 hover:shadow-md transition-shadow"
        >
          <div className="flex items-start justify-between">
            <div className="flex-1">
              {/* Header */}
              <div className="flex items-center gap-2 mb-2">
                {getOriginIcon(cost.origin)}
                <span className="text-sm text-secondary-600">
                  {cost.origin_description}
                </span>
                <span className="text-secondary-400">•</span>
                <span className="text-sm text-secondary-600">
                  {new Date(cost.created_at).toLocaleDateString('pt-BR')}
                </span>
              </div>

              {/* Title and Category */}
              <div className="flex items-center gap-2 mb-2">
                <h3 className="font-medium text-secondary-900">
                  {cost.description}
                </h3>
                {getCategoryBadge(cost.category)}
                {cost.is_amount_to_define && (
                  <Badge variant="warning">Valor a Definir</Badge>
                )}
              </div>

              {/* Vehicle Info */}
              {cost.vehicle_plate && (
                <div className="flex items-center gap-2 mb-2 text-sm text-secondary-600">
                  <Car className="h-4 w-4" />
                  <span>{cost.vehicle_plate}</span>
                  <span>•</span>
                  <span>{cost.vehicle_model}</span>
                </div>
              )}

              {/* Customer Info */}
              {cost.customer_name && (
                <div className="flex items-center gap-2 mb-2 text-sm text-secondary-600">
                  <User className="h-4 w-4" />
                  <span>Cliente: {cost.customer_name}</span>
                </div>
              )}

              {/* Created By */}
              <div className="flex items-center gap-2 mb-2 text-sm text-secondary-600">
                <span>Criado por: {cost.created_by_name}</span>
                {cost.created_by_role && (
                  <>
                    <span>•</span>
                    <span>{cost.created_by_role}</span>
                  </>
                )}
                {cost.created_by_code && (
                  <>
                    <span>•</span>
                    <span>Código: {cost.created_by_code}</span>
                  </>
                )}
              </div>

              {/* Amount and Status */}
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="text-lg font-semibold text-secondary-900">
                    R$ {cost.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
                  </div>
                  {getStatusBadge(cost.status)}
                </div>

                {/* Actions */}
                <div className="flex items-center gap-2">
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => onView(cost)}
                    className="text-secondary-600 hover:text-secondary-900"
                  >
                    <Eye className="h-4 w-4" />
                  </Button>

                  {canEdit && onEdit && (
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={() => onEdit(cost)}
                      className="text-secondary-600 hover:text-secondary-900"
                    >
                      <Edit className="h-4 w-4" />
                    </Button>
                  )}

                  {cost.is_amount_to_define && onEditEstimate && (
                    <Button
                      variant="warning"
                      size="sm"
                      onClick={() => onEditEstimate(cost)}
                    >
                      Definir Valor
                    </Button>
                  )}

                  {canAuthorize && cost.status === 'Pendente' && onAuthorize && (
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={() => onAuthorize(cost)}
                    >
                      Autorizar
                    </Button>
                  )}

                  {canAuthorize && cost.status === 'Autorizado' && onMarkAsPaid && (
                    <Button
                      variant="success"
                      size="sm"
                      onClick={() => onMarkAsPaid(cost)}
                    >
                      <CheckCircle className="h-4 w-4 mr-1" />
                      Marcar Pago
                    </Button>
                  )}
                </div>
              </div>

              {/* Observations */}
              {cost.observations && (
                <div className="mt-2 p-2 bg-secondary-50 rounded text-sm text-secondary-700">
                  <strong>Observações:</strong> {cost.observations}
                </div>
              )}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}; 