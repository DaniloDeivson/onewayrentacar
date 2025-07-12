/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable no-unused-expressions */
import React from 'react';
import { Badge } from '../UI/Badge';
import { Button } from '../UI/Button';
import { Edit, AlertTriangle, Car, User, DollarSign } from 'lucide-react';
import { Cost } from '../../hooks/useCosts';

interface CostsListProps {
  costs: Cost[];
  onView: (cost: Cost) => void;
  onEdit?: (cost: Cost) => void;
  onEditEstimate?: (cost: Cost) => void;
  onAuthorize?: (cost: Cost) => void;
  canEdit?: boolean;
}

export const CostsList: React.FC<CostsListProps> = ({
  costs,
  onView,
  onEdit,
  onEditEstimate,
  onAuthorize,
  canEdit = false
}) => {
  const [expandedId, setExpandedId] = React.useState<string | null>(null);
  const [sortKey, setSortKey] = React.useState<'date' | 'amount' | null>(null);
  const [sortDir, setSortDir] = React.useState<'asc' | 'desc'>('asc');

  const toggleSort = (key: 'date' | 'amount') => {
    if (sortKey === key) {
      setSortDir(prev => (prev === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortKey(key);
      setSortDir('asc');
    }
  };

  const sortedCosts = React.useMemo(() => {
    if (!sortKey) return costs;
    const copy = [...costs];
    copy.sort((a, b) => {
      if (sortKey === 'date') {
        const da = new Date(a.cost_date).getTime();
        const db = new Date(b.cost_date).getTime();
        return sortDir === 'asc' ? da - db : db - da;
      }
      if (sortKey === 'amount') {
        return sortDir === 'asc' ? a.amount - b.amount : b.amount - a.amount;
      }
      return 0;
    });
    return copy;
  }, [costs, sortKey, sortDir]);

  const getStatusBadge = (status: string) => {
    if (status === 'Pago') {
      return <Badge variant="success">{status}</Badge>;
    } else if (status === 'Autorizado') {
      return <Badge variant="info">{status}</Badge>;
    } else {
      return <Badge variant="warning">{status}</Badge>;
    }
  };

  // Helper function to check if cost is auto-generated with amount to define
  const isAmountToDefine = (cost: Cost) => {
    return cost.amount === 0 && cost.status === 'Pendente';
  };

  // Helper function to format cost amount
  const formatCostAmount = (cost: Cost) => {
    if (isAmountToDefine(cost)) {
      return (
        <div className="flex items-center space-x-2">
          <span className="text-warning-600 font-medium">Orçamento</span>
          <AlertTriangle className="h-4 w-4 text-warning-600" />
        </div>
      );
    }
    return `R$ ${cost.amount.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`;
  };

  const CATEGORY_LABELS: Record<string, string> = {
    Multa: 'Multa',
    Funilaria: 'Funilaria',
    Seguro: 'Seguro',
    Avulsa: 'Avulsa',
    Compra: 'Compra',
    'Excesso Km': 'Excesso Km',
    'Diária Extra': 'Diária Extra',
    'Combustível': 'Combustível',
    Avaria: 'Avaria',
    Peças: 'Peças',
  };
  const ORIGIN_LABELS: Record<string, string> = {
    Usuario: 'Usuário',
    Patio: 'Controle de Pátio',
    Manutencao: 'Manutenção',
    Sistema: 'Sistema',
    Compras: 'Compras',
    Multas: 'Multas',
  };
  const getCategoryLabel = (cost: Cost): string => {
    if (!cost.category) return '-';
    return CATEGORY_LABELS[cost.category] || cost.category;
  };
  const getOriginLabel = (cost: Cost): string => {
    // Multa sempre exibe Multas
    if (cost.category === 'Multa') return 'Multas';
    if (!cost.origin) return '-';
    return ORIGIN_LABELS[cost.origin] || cost.origin;
  };

  return (
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead className="bg-secondary-50">
          <tr>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600 cursor-pointer" onClick={() => toggleSort('date')}>
              Data {sortKey==='date' && (sortDir==='asc' ? '▲' : '▼')}
            </th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Categoria/Origem</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Veículo</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Cliente</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Responsável</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Descrição</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600 cursor-pointer" onClick={() => toggleSort('amount')}>
              Valor {sortKey==='amount' && (sortDir==='asc' ? '▲' : '▼')}
            </th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Status</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Ação</th>
            <th className="text-left py-3 px-6 text-sm font-medium text-secondary-600">Ações</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-secondary-200">
          {sortedCosts.map((cost) => (
            <React.Fragment key={cost.id}>
            <tr className={`hover:bg-secondary-50 ${isAmountToDefine(cost) ? 'bg-warning-25' : ''}`} onClick={() => setExpandedId(prev => prev===cost.id?null:cost.id)}>
              <td className="py-4 px-6 text-sm text-secondary-600">
                {new Date(cost.cost_date).toLocaleDateString('pt-BR')}
              </td>
              <td className="py-4 px-6">
                <div className="flex flex-col gap-1">
                  <div className="flex items-center gap-2">
                    <Badge variant="secondary" className="text-xs w-fit">{getCategoryLabel(cost)}</Badge>
                    {cost.status === 'Pendente' && (cost.category === 'Compra' || cost.origin === 'Compras') && (
                      <Button
                        onClick={() => onAuthorize && onAuthorize(cost)}
                        variant="success"
                        size="sm"
                        className="ml-1 px-2 py-1 text-xs"
                      >
                        Aprovar
                      </Button>
                    )}
                  </div>
                  <Badge variant="secondary" className="text-xxs w-fit">{getOriginLabel(cost)}</Badge>
                </div>
              </td>
              <td className="py-4 px-6">
                <div className="flex items-center">
                  <Car className="h-4 w-4 text-secondary-400 mr-2" />
                  <div>
                    <span className="text-sm font-medium text-secondary-900">
                      {cost.vehicles?.plate || cost.vehicle_plate || '-'}
                    </span>
                    {cost.vehicles?.model && (
                      <div className="text-xs text-secondary-500">
                        {cost.vehicles.model}
                      </div>
                    )}
                  </div>
                </div>
              </td>
              <td className="py-4 px-6 text-sm text-secondary-600">
                <div className="flex items-center">
                  <User className="h-4 w-4 text-secondary-400 mr-2" />
                  <div>
                    <span className="font-bold text-primary-700 block">
                      {cost.customer_name || cost.customers?.name || '-'}
                    </span>
                    {cost.contract_id && (
                      <div className="text-xs text-secondary-500">
                        Contrato: {cost.contracts?.contract_number || cost.contract_id}
                      </div>
                    )}
                  </div>
                </div>
              </td>
              <td className="py-4 px-6 text-sm text-secondary-600">
                <div className="flex items-center">
                  <User className="h-4 w-4 text-secondary-400 mr-2" />
                  <div>
                    <span className="font-bold text-primary-700 block">
                      {cost.created_by_name || '-'}
                    </span>
                  </div>
                </div>
              </td>
              <td className="py-4 px-6 text-sm text-secondary-600 max-w-xs">
                <div className="truncate" title={cost.description}>
                  {cost.description}
                </div>
              </td>
              <td className="py-4 px-6 text-sm font-medium text-secondary-900">
                {formatCostAmount(cost)}
              </td>
              <td className="py-4 px-6">
                {getStatusBadge(cost.status)}
              </td>
              <td className="py-4 px-6 text-sm text-secondary-600">
                {cost.origin === 'Patio' && cost.description?.toLowerCase().includes('check-out') ? 'Check-Out' :
                 cost.origin === 'Patio' && cost.description?.toLowerCase().includes('check-in') ? 'Check-In' :
                 cost.origin === 'Usuario' ? 'Lançamento Manual' :
                 '-'}
              </td>
              <td className="py-4 px-6">
                <div className="flex items-center space-x-2">
                  <button 
                    onClick={() => onView(cost)}
                    className="text-primary-600 hover:text-primary-800 text-sm font-medium"
                  >
                    Visualizar
                  </button>
                  {canEdit && (
                    <button 
                      onClick={() => onEdit && onEdit(cost)}
                      className="text-secondary-600 hover:text-secondary-800"
                    >
                      <Edit className="h-4 w-4" />
                    </button>
                  )}
                  {isAmountToDefine(cost) && onEditEstimate && (
                    <button 
                      onClick={() => onEditEstimate(cost)}
                      className="text-warning-600 hover:text-warning-800"
                      title="Editar orçamento"
                    >
                      <DollarSign className="h-4 w-4" />
                    </button>
                  )}
                </div>
              </td>
            </tr>
            {expandedId===cost.id && (
              <tr className="bg-secondary-25">
                <td colSpan={12} className="py-4 px-6 text-sm text-secondary-700">
                  <div className="flex flex-col gap-1">
                    <div><strong>ID:</strong> {cost.id}</div>
                    <div><strong>Documento:</strong> {cost.document_ref || '-'}</div>
                    <div><strong>Observações:</strong> {cost.observations || '-'}</div>
                  </div>
                </td>
              </tr>
            )}
            </React.Fragment>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default CostsList;