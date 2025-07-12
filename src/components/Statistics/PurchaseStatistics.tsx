import React, { useState, useEffect } from 'react';
import { TrendingUp, Package, DollarSign, ShoppingCart, Calendar, Filter } from 'lucide-react';
import { usePurchaseStatistics } from '../../hooks/usePurchaseStatistics';
import { formatCurrency } from '../../utils/formatters';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
} from 'recharts';

interface PurchaseStatisticsProps {
  className?: string;
}

export const PurchaseStatistics: React.FC<PurchaseStatisticsProps> = ({ className }) => {
  const { statistics, priceEvolution, loading, fetchPurchaseStatistics } = usePurchaseStatistics();
  const [selectedPart, setSelectedPart] = useState<string>('');
  const [dateRange, setDateRange] = useState({
    start: new Date(Date.now() - 365 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
    end: new Date().toISOString().split('T')[0]
  });

  useEffect(() => {
    fetchPurchaseStatistics(dateRange.start, dateRange.end);
  }, [dateRange]);

  const handleDateRangeChange = (field: 'start' | 'end', value: string) => {
    setDateRange(prev => ({ ...prev, [field]: value }));
  };

  const getPriceEvolutionForPart = (partName: string) => {
    if (!partName) {
      // Se nenhuma peça selecionada, retornar todas as evoluções agrupadas por peça
      const groupedByPart = priceEvolution.reduce((acc, item) => {
        if (!acc[item.part_name]) {
          acc[item.part_name] = [];
        }
        acc[item.part_name].push(item);
        return acc;
      }, {} as Record<string, typeof priceEvolution>);

      // Retornar apenas o primeiro item de cada peça para mostrar resumo
      return Object.values(groupedByPart).map(group => group[0]);
    }
    
    const filtered = priceEvolution.filter(item => item.part_name === partName);
    return filtered;
  };

  // Obter lista única de peças disponíveis
  const availableParts = Array.from(new Set(priceEvolution.map(item => item.part_name))).filter(Boolean);

  if (loading) {
    return (
      <div className={`bg-white rounded-lg shadow-md p-6 ${className}`}>
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        </div>
      </div>
    );
  }

  return (
    <div className={`bg-white rounded-lg shadow-md ${className}`}>
      <div className="p-6 border-b">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-semibold text-gray-800 flex items-center">
            <ShoppingCart className="w-5 h-5 mr-2" />
            Estatísticas do Departamento de Compras
          </h2>
          
          <div className="flex items-center space-x-4">
            <div className="flex items-center space-x-2">
              <Calendar className="w-4 h-4 text-gray-500" />
              <input
                type="date"
                value={dateRange.start}
                onChange={(e) => handleDateRangeChange('start', e.target.value)}
                className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
              />
              <span className="text-gray-500">até</span>
              <input
                type="date"
                value={dateRange.end}
                onChange={(e) => handleDateRangeChange('end', e.target.value)}
                className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
              />
            </div>
          </div>
        </div>
      </div>

      {statistics && (
        <div className="p-6 space-y-6">
          

          {/* Resumo Geral */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="bg-blue-50 p-4 rounded-lg">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-blue-600">Total de Pedidos</p>
                  <p className="text-2xl font-semibold text-blue-900">{statistics.total_orders}</p>
                </div>
                <ShoppingCart className="w-8 h-8 text-blue-400" />
              </div>
            </div>

            <div className="bg-green-50 p-4 rounded-lg">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-green-600">Valor Total</p>
                  <p className="text-2xl font-semibold text-green-900">
                    {formatCurrency(statistics.total_amount)}
                  </p>
                </div>
                <DollarSign className="w-8 h-8 text-green-400" />
              </div>
            </div>

            <div className="bg-purple-50 p-4 rounded-lg">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-purple-600">Total de Itens</p>
                  <p className="text-2xl font-semibold text-purple-900">{statistics.total_items}</p>
                </div>
                <Package className="w-8 h-8 text-purple-400" />
              </div>
            </div>

            <div className="bg-orange-50 p-4 rounded-lg">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-orange-600">Valor Médio</p>
                  <p className="text-2xl font-semibold text-orange-900">
                    {formatCurrency(statistics.average_order_value)}
                  </p>
                </div>
                <TrendingUp className="w-8 h-8 text-orange-400" />
              </div>
            </div>
          </div>

          {/* Gráfico de Gastos Mensais */}
          <div className="bg-gray-50 p-6 rounded-lg">
            <h3 className="text-lg font-semibold text-gray-800 mb-4">
              Gastos Mensais
            </h3>
            <div className="space-y-2">
              {statistics.monthly_spending.map((month, index) => (
                <div key={index} className="flex items-center justify-between p-3 bg-white rounded">
                  <div>
                    <p className="font-medium text-gray-900">
                      {new Date(month.month + '-01').toLocaleDateString('pt-BR', { 
                        year: 'numeric', 
                        month: 'long' 
                      })}
                    </p>
                    <p className="text-sm text-gray-600">{month.orders_count} pedidos</p>
                  </div>
                  <div className="text-right">
                    <p className="font-semibold text-gray-900">
                      {formatCurrency(month.total_amount)}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Peças Mais Compradas */}
          <div className="bg-gray-50 p-6 rounded-lg">
            <h3 className="text-lg font-semibold text-gray-800 mb-4">
              Peças Mais Compradas
            </h3>
            <div className="space-y-2">
              {statistics.most_purchased_parts.slice(0, 10).map((part, index) => (
                <div key={index} className="flex items-center justify-between p-3 bg-white rounded">
                  <div>
                    <p className="font-medium text-gray-900">{part.part_name}</p>
                    <p className="text-sm text-gray-600">{part.quantity} unidades</p>
                  </div>
                  <div className="text-right">
                    <p className="font-semibold text-gray-900">
                      {formatCurrency(part.total_value)}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Evolução de Preços por Peça */}
          <div className="bg-gray-50 p-6 rounded-lg">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-gray-800">
                Evolução de Preços por Peça
              </h3>
              <div className="flex items-center space-x-2">
                <Filter className="w-4 h-4 text-gray-500" />
                <select
                  value={selectedPart}
                  onChange={(e) => setSelectedPart(e.target.value)}
                  className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
                >
                  <option value="">Todas as peças</option>
                  {availableParts.map(partName => (
                    <option key={partName} value={partName}>{partName}</option>
                  ))}
                </select>
              </div>
            </div>

            <div className="space-y-2">
              {getPriceEvolutionForPart(selectedPart).length > 0 ? (
                getPriceEvolutionForPart(selectedPart).map((item, index) => (
                  <div key={index} className="flex items-center justify-between p-3 bg-white rounded">
                    <div>
                      <p className="font-medium text-gray-900">
                        {selectedPart ? (
                          new Date(item.month + '-01').toLocaleDateString('pt-BR', { 
                            year: 'numeric', 
                            month: 'long' 
                          })
                        ) : (
                          item.part_name
                        )}
                      </p>
                      <p className="text-sm text-gray-600">
                        {selectedPart ? (
                          `${item.quantity_purchased} unidades em ${item.orders_count} pedidos`
                        ) : (
                          `${item.quantity_purchased} unidades • ${item.orders_count} pedidos • ${new Date(item.month + '-01').toLocaleDateString('pt-BR', { 
                            month: 'short',
                            year: '2-digit'
                          })}`
                        )}
                      </p>
                    </div>
                    <div className="text-right">
                      <p className="font-semibold text-gray-900">
                        {formatCurrency(item.avg_price)}
                      </p>
                      <p className="text-sm text-gray-600">preço médio</p>
                    </div>
                  </div>
                ))
              ) : (
                <div className="text-center py-8 text-gray-500">
                  {selectedPart 
                    ? `Nenhum dado de evolução encontrado para "${selectedPart}"`
                    : 'Nenhum dado de evolução de preços disponível'
                  }
                </div>
              )}
            </div>
          </div>

          {/* Gráfico Simples de Evolução */}
          {getPriceEvolutionForPart(selectedPart).length > 0 && (
            <div className="bg-gray-50 p-6 rounded-lg">
              <h3 className="text-lg font-semibold text-gray-800 mb-4">
                Gráfico de Evolução {selectedPart ? `- ${selectedPart}` : 'de Preços'}
              </h3>
              <div className="h-80 w-full">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart
                    data={getPriceEvolutionForPart(selectedPart).map(item => ({
                      ...item,
                      label: selectedPart
                        ? new Date(item.month + '-01').toLocaleDateString('pt-BR', { month: 'short', year: '2-digit' })
                        : item.part_name.substring(0, 8) + '...'
                    }))}
                    margin={{ top: 20, right: 30, left: 0, bottom: 5 }}
                  >
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="label" />
                    <YAxis tickFormatter={formatCurrency} />
                    <Tooltip formatter={(value: number) => formatCurrency(value)} />
                    <Line type="monotone" dataKey="avg_price" stroke="#2563eb" strokeWidth={3} dot={{ r: 4 }} activeDot={{ r: 6 }} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}; 