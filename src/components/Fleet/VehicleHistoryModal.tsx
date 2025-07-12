import React, { useState, useEffect } from 'react';
import { X, Calendar, Filter, TrendingUp, Wrench, DollarSign, AlertTriangle, Eye } from 'lucide-react';
import { Button } from '../UI/Button';
import { Badge } from '../UI/Badge';
import { useVehicleHistory, VehicleHistoryEvent, VehicleHistoryFilters } from '../../hooks/useVehicleHistory';
import { formatCurrency } from '../../utils/formatters';

interface VehicleHistoryModalProps {
  isOpen: boolean;
  onClose: () => void;
  vehicle: {
    id: string;
    plate: string;
    model: string;
    brand: string;
    status: string;
  };
}

interface TimelineEvent extends VehicleHistoryEvent {
  month: string;
  events_count: number;
  total_amount: number;
  events: VehicleHistoryEvent[];
}

export const VehicleHistoryModal: React.FC<VehicleHistoryModalProps> = ({
  isOpen,
  onClose,
  vehicle
}) => {
  const { getVehicleHistoryByVehicle, getVehicleHistoryStats, getVehicleTimelineData } = useVehicleHistory();
  const [loading, setLoading] = useState(false);
  const [history, setHistory] = useState<VehicleHistoryEvent[]>([]);
  const [stats, setStats] = useState<Record<string, { total: number; count: number }>>({});
  const [timeline, setTimeline] = useState<TimelineEvent[]>([]);
  const [filters, setFilters] = useState<VehicleHistoryFilters>({
    vehicle_id: vehicle.id
  });
  const [viewMode, setViewMode] = useState<'list' | 'timeline'>('list');

  useEffect(() => {
    if (isOpen && vehicle.id) {
      fetchVehicleData();
    }
  }, [isOpen, vehicle.id]);

  const fetchVehicleData = async () => {
    setLoading(true);
    try {
      const [historyData, statsData, timelineData] = await Promise.all([
        getVehicleHistoryByVehicle(vehicle.id),
        getVehicleHistoryStats(vehicle.id),
        getVehicleTimelineData(vehicle.id)
      ]);

      setHistory(historyData);
      setStats(statsData);
      setTimeline(timelineData as TimelineEvent[]);
    } catch (error) {
      console.error('Erro ao buscar dados do veículo:', error);
    } finally {
      setLoading(false);
    }
  };

  const getEventIcon = (eventType: string) => {
    switch (eventType) {
      case 'cost':
        return <DollarSign className="w-4 h-4 text-red-500" />;
      case 'maintenance':
        return <Wrench className="w-4 h-4 text-blue-500" />;
      case 'inspection':
        return <Eye className="w-4 h-4 text-green-500" />;
      case 'fuel':
        return <TrendingUp className="w-4 h-4 text-yellow-500" />;
      case 'fine':
        return <AlertTriangle className="w-4 h-4 text-red-600" />;
      case 'contract':
      case 'contract_start':
      case 'contract_end':
        return <Calendar className="w-4 h-4 text-purple-600" />;
      default:
        return <Calendar className="w-4 h-4 text-gray-500" />;
    }
  };

  const getEventBadgeColor = (eventType: string) => {
    switch (eventType) {
      case 'cost':
        return 'bg-red-100 text-red-800';
      case 'maintenance':
        return 'bg-blue-100 text-blue-800';
      case 'inspection':
        return 'bg-green-100 text-green-800';
      case 'fuel':
        return 'bg-yellow-100 text-yellow-800';
      case 'fine':
        return 'bg-red-100 text-red-800';
      case 'contract':
      case 'contract_start':
      case 'contract_end':
        return 'bg-purple-100 text-purple-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const getEventTypeName = (eventType: string) => {
    const typeNames: Record<string, string> = {
      cost: 'Custo',
      maintenance: 'Manutenção',
      inspection: 'Inspeção',
      fuel: 'Combustível',
      fine: 'Multa',
      contract: 'Contrato',
      contract_start: 'Contrato (Início)',
      contract_end: 'Contrato (Término)',
      accident: 'Acidente',
      status_change: 'Mudança de Status',
      damage: 'Dano'
    };
    return typeNames[eventType] || eventType;
  };

  const filteredHistory = history.filter(event => {
    if (filters.event_type && event.event_type !== filters.event_type) return false;
    if (filters.start_date && event.event_date < filters.start_date) return false;
    if (filters.end_date && event.event_date > filters.end_date) return false;
    if (filters.min_amount && (!event.amount || event.amount < filters.min_amount)) return false;
    if (filters.max_amount && (!event.amount || event.amount > filters.max_amount)) return false;
    return true;
  });

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-6xl mx-4 max-h-[90vh] overflow-hidden">
        <div className="flex justify-between items-center p-6 border-b">
          <div>
            <h2 className="text-xl font-semibold text-gray-800">
              Histórico do Veículo
            </h2>
            <p className="text-sm text-gray-600">
              {vehicle.plate} - {vehicle.brand} {vehicle.model}
            </p>
            <div className="mt-2">
              <span className={`inline-block px-3 py-1 rounded-full text-sm font-semibold ${
                vehicle.status === 'Disponível' ? 'bg-green-100 text-green-800' :
                vehicle.status === 'Em Uso' ? 'bg-blue-100 text-blue-800' :
                vehicle.status === 'Manutenção' ? 'bg-yellow-100 text-yellow-800' :
                vehicle.status === 'Inativo' ? 'bg-gray-200 text-gray-600' : 'bg-gray-100 text-gray-800'
              }`}>
                {vehicle.status}
              </span>
            </div>
          </div>
          <Button
            variant="secondary"
            size="sm"
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
          >
            <X size={20} />
          </Button>
        </div>

        {/* Estatísticas */}
        <div className="p-6 bg-gray-50 border-b">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {Object.entries(stats).map(([type, data]) => (
              <div key={type} className="bg-white p-4 rounded-lg shadow-sm">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-600">
                      {getEventTypeName(type)}
                    </p>
                    <p className="text-2xl font-semibold text-gray-900">
                      {data.count}
                    </p>
                    <p className="text-xs text-gray-500">
                      {formatCurrency(data.total)}
                    </p>
                  </div>
                  <div className="text-gray-400">
                    {getEventIcon(type)}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Filtros e Controles */}
        <div className="p-6 border-b">
          <div className="flex flex-wrap gap-4 items-center">
            <div className="flex items-center space-x-2">
              <Button
                variant="primary"
                size="sm"
                onClick={() => setViewMode('list')}
              >
                Lista
              </Button>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => setViewMode('timeline')}
              >
                Timeline
              </Button>
            </div>

            <div className="flex items-center space-x-2">
              <Filter className="w-4 h-4 text-gray-500" />
              <select
                value={filters.event_type || ''}
                onChange={(e) => setFilters(prev => ({ ...prev, event_type: e.target.value || undefined }))}
                className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
              >
                <option value="">Todos os tipos</option>
                <option value="cost">Custos</option>
                <option value="maintenance">Manutenção</option>
                <option value="inspection">Inspeções</option>
                <option value="fuel">Combustível</option>
                <option value="fine">Multas</option>
                <option value="contract">Contratos</option>
                <option value="contract_start">Contrato (Início)</option>
                <option value="contract_end">Contrato (Término)</option>
              </select>
            </div>

            <div className="flex items-center space-x-2">
              <input
                type="date"
                value={filters.start_date || ''}
                onChange={(e) => setFilters(prev => ({ ...prev, start_date: e.target.value || undefined }))}
                className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
                placeholder="Data inicial"
              />
              <span className="text-gray-500">até</span>
              <input
                type="date"
                value={filters.end_date || ''}
                onChange={(e) => setFilters(prev => ({ ...prev, end_date: e.target.value || undefined }))}
                className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
                placeholder="Data final"
              />
            </div>
          </div>
        </div>

        {/* Conteúdo */}
        <div className="flex-1 overflow-y-auto p-6">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            </div>
          ) : viewMode === 'list' ? (
            <div className="space-y-4">
              {filteredHistory.length === 0 ? (
                <div className="text-center py-12 text-gray-500">
                  Nenhum evento encontrado
                </div>
              ) : (
                filteredHistory.map((event, index) => (
                  <div key={index} className="border border-gray-200 rounded-lg p-4 hover:bg-gray-50">
                    <div className="flex items-start justify-between">
                      <div className="flex items-start space-x-3">
                        <div className="mt-1">
                          {getEventIcon(event.event_type)}
                        </div>
                        <div className="flex-1">
                          <div className="flex items-center space-x-2">
                            <Badge className={getEventBadgeColor(event.event_type)}>
                              {getEventTypeName(event.event_type)}
                            </Badge>
                            <span className="text-sm text-gray-500">
                              {new Date(event.event_date).toLocaleDateString('pt-BR')}
                            </span>
                          </div>
                          <p className="font-medium text-gray-900 mt-1">
                            {event.description}
                          </p>
                          {event.notes && (
                            <p className="text-sm text-gray-600 mt-1">
                              {event.notes}
                            </p>
                          )}
                          <div className="flex items-center space-x-4 mt-2 text-sm text-gray-500">
                            {event.amount && (
                              <span>Valor: {formatCurrency(event.amount)}</span>
                            )}
                            {event.mileage && (
                              <span>Km: {event.mileage.toLocaleString()}</span>
                            )}
                            {event.created_by && (
                              <span>Por: {event.created_by}</span>
                            )}
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                ))
              )}
            </div>
          ) : (
            <div className="space-y-6">
              {timeline.map((monthData, index) => (
                <div key={index} className="border border-gray-200 rounded-lg p-4">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-lg font-semibold text-gray-900">
                      {new Date(monthData.month + '-01').toLocaleDateString('pt-BR', { 
                        year: 'numeric', 
                        month: 'long' 
                      })}
                    </h3>
                    <div className="flex items-center space-x-4 text-sm text-gray-500">
                      <span>{monthData.events_count} eventos</span>
                      <span>{formatCurrency(monthData.total_amount)}</span>
                    </div>
                  </div>
                  <div className="space-y-2">
                    {monthData.events.map((event: VehicleHistoryEvent, eventIndex: number) => (
                      <div key={eventIndex} className="flex items-center space-x-3 p-2 bg-gray-50 rounded">
                        {getEventIcon(event.event_type)}
                        <div className="flex-1">
                          <div className="flex items-center justify-between">
                            <span className="text-sm font-medium text-gray-900">
                              {event.description}
                            </span>
                            {event.amount && (
                              <span className="text-sm text-gray-600">
                                {formatCurrency(event.amount)}
                              </span>
                            )}
                          </div>
                          <div className="text-xs text-gray-500">
                            {new Date(event.event_date).toLocaleDateString('pt-BR')}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}; 