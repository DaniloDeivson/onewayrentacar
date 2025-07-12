import React from 'react';
import { Badge } from '../UI/Badge';
import { Button } from '../UI/Button';
import { Edit, AlertTriangle, Car, User, FileText, Calendar, DollarSign, CheckCircle, Trash2 } from 'lucide-react';
import { Database } from '../../types/database';

type CustomerCharge = Database['public']['Tables']['customer_charges']['Row'] & {
  customers?: { name: string };
  contracts?: { 
    vehicles?: { plate: string; model: string }; 
  };
  vehicles?: { plate: string; model: string };
};

interface ChargesListProps {
  charges: CustomerCharge[];
  onView: (charge: CustomerCharge) => void;
  onEdit?: (charge: CustomerCharge) => void;
  onMarkAsPaid?: (charge: CustomerCharge) => void;
  onDelete?: (charge: CustomerCharge) => void;
  canEdit?: boolean;
  canMarkAsPaid?: boolean;
  canDelete?: boolean;
}

export const ChargesList: React.FC<ChargesListProps> = ({
  charges,
  onView,
  onEdit,
  onMarkAsPaid,
  onDelete,
  canEdit = false,
  canMarkAsPaid = false,
  canDelete = false
}) => {
  const getStatusBadge = (status: string) => {
    if (status === 'Pago') {
      return <Badge variant="success">{status}</Badge>;
    } else if (status === 'Autorizado') {
      return <Badge variant="info">{status}</Badge>;
    } else if (status === 'Contestado') {
      return <Badge variant="error">{status}</Badge>;
    } else {
      return <Badge variant="warning">{status}</Badge>;
    }
  };

  // Helper function to check if charge is overdue
  const isOverdue = (charge: CustomerCharge) => {
    if (charge.status === 'Pago') return false;
    const today = new Date();
    const dueDate = new Date(charge.due_date);
    return dueDate < today;
  };

  // Helper function to format charge amount
  const formatChargeAmount = (charge: CustomerCharge) => {
    return `R$ ${charge.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`;
  };

  const getCategoryLabel = (charge: CustomerCharge) => {
    switch (charge.charge_type) {
      case 'Multa': return 'Multa';
      case 'Dano': return 'Dano';
      case 'Excesso KM': return 'Excesso KM';
      case 'Combustível': return 'Combustível';
      case 'Diária Extra': return 'Diária Extra';
      default: return charge.charge_type || '-';
    }
  };

  const getOriginLabel = (charge: CustomerCharge) => {
    if (charge.charge_type === 'Multa') return 'Multas';
    if (charge.generated_from === 'Manual') return 'Manual';
    if (charge.generated_from === 'Automatic') return 'Automática';
    return charge.generated_from && charge.generated_from !== 'Sistema' ? charge.generated_from : '-';
  };

  return (
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead className="bg-secondary-50">
          <tr>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Data</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Categoria/Origem</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Veículo</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Cliente</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Descrição</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Vencimento</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Valor</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Status</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Ações</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-secondary-200">
          {charges.map((charge) => (
            <tr key={charge.id} className={`hover:bg-secondary-50 ${isOverdue(charge) ? 'bg-red-25' : ''}`}>
              <td className="py-4 px-6 text-sm text-secondary-600">
                {new Date(charge.charge_date).toLocaleDateString('pt-BR')}
              </td>
              <td className="py-4 px-6">
                <div className="flex flex-col gap-1">
                  <Badge variant="secondary" className="text-xs w-fit">{getCategoryLabel(charge)}</Badge>
                  <Badge variant="secondary" className="text-xxs w-fit">{getOriginLabel(charge)}</Badge>
                </div>
              </td>
              <td className="py-4 px-6">
                <div className="flex items-center">
                  <Car className="h-4 w-4 text-secondary-400 mr-2" />
                  <span className="text-sm font-medium text-secondary-900">
                    {charge.vehicles?.plate || charge.contracts?.vehicles?.plate || '-'}
                  </span>
                </div>
                {charge.vehicles?.model || charge.contracts?.vehicles?.model ? (
                  <div className="text-xs text-secondary-500 mt-1">
                    {charge.vehicles?.model || charge.contracts?.vehicles?.model}
                  </div>
                ) : null}
              </td>
              <td className="py-4 px-6 text-sm text-secondary-600">
                {charge.customers?.name ? (
                  <div className="flex items-center">
                    <User className="h-4 w-4 text-secondary-400 mr-2" />
                    <span>{charge.customers.name}</span>
                  </div>
                ) : (
                  <span>-</span>
                )}
                {charge.contract_id && (
                  <div className="text-xs text-secondary-500 mt-1 flex items-center">
                    <FileText className="h-3 w-3 mr-1" />
                    Contrato #{charge.contract_id.substring(0, 8)}
                  </div>
                )}
              </td>
              <td className="py-4 px-6 text-sm text-secondary-600 max-w-xs">
                <div className="truncate" title={charge.description || 'Sem descrição'}>
                  {charge.description || 'Sem descrição'}
                </div>
              </td>
              <td className="py-4 px-6 text-sm text-secondary-600">
                <div className="flex items-center">
                  <Calendar className="h-4 w-4 text-secondary-400 mr-2" />
                  <span className={isOverdue(charge) ? 'text-red-600 font-medium' : ''}>
                    {new Date(charge.due_date).toLocaleDateString('pt-BR')}
                  </span>
                </div>
                {isOverdue(charge) && (
                  <div className="text-xs text-red-600 mt-1 flex items-center">
                    <AlertTriangle className="h-3 w-3 mr-1" />
                    Vencido
                  </div>
                )}
              </td>
              <td className="py-4 px-6 text-sm font-medium text-secondary-900">
                <div className="flex items-center">
                  <DollarSign className="h-4 w-4 text-secondary-400 mr-1" />
                  {formatChargeAmount(charge)}
                </div>
              </td>
              <td className="py-4 px-6">
                {getStatusBadge(charge.status)}
              </td>
              <td className="py-4 px-6">
                <div className="flex items-center space-x-2">
                  {charge.status === 'Pendente' && canMarkAsPaid && (
                    <Button 
                      onClick={() => onMarkAsPaid && onMarkAsPaid(charge)}
                      variant="success"
                      size="sm"
                      className="flex items-center"
                    >
                      <CheckCircle className="h-3 w-3 mr-1" />
                      Pago
                    </Button>
                  )}
                  <button 
                    onClick={() => onView(charge)}
                    className="text-primary-600 hover:text-primary-800 text-sm font-medium"
                  >
                    Visualizar
                  </button>
                  {canEdit && (
                    <button 
                      onClick={() => onEdit && onEdit(charge)}
                      className="text-secondary-600 hover:text-secondary-800"
                    >
                      <Edit className="h-4 w-4" />
                    </button>
                  )}
                  {canDelete && (
                    <button 
                      onClick={() => onDelete && onDelete(charge)}
                      className="text-error-600 hover:text-error-800"
                      title="Excluir cobrança"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  )}
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default ChargesList; 