import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';

export interface PurchasePriceEvolution {
  part_name: string;
  month: string;
  avg_price: number;
  quantity_purchased: number;
  orders_count: number;
}

export interface PurchaseStatistics {
  total_orders: number;
  total_amount: number;
  total_items: number;
  average_order_value: number;
  most_purchased_parts: Array<{
    part_name: string;
    quantity: number;
    total_value: number;
  }>;
  monthly_spending: Array<{
    month: string;
    total_amount: number;
    orders_count: number;
  }>;
  price_evolution: PurchasePriceEvolution[];
}

export const usePurchaseStatistics = () => {
  const [statistics, setStatistics] = useState<PurchaseStatistics | null>(null);
  const [priceEvolution, setPriceEvolution] = useState<PurchasePriceEvolution[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchPriceEvolution = async (startDate?: string, endDate?: string) => {
    try {
      console.log('Buscando evolução de preços...', { startDate, endDate });
      
      // Buscar dados diretamente do banco (mais confiável)
      const { data, error } = await supabase
        .from('purchase_order_items')
        .select(`
          unit_price,
          quantity,
          purchase_orders!inner(order_date, tenant_id),
          parts!inner(name)
        `)
        .eq('purchase_orders.tenant_id', DEFAULT_TENANT_ID)
        .gte('purchase_orders.order_date', startDate || new Date(Date.now() - 365 * 24 * 60 * 60 * 1000).toISOString().split('T')[0])
        .lte('purchase_orders.order_date', endDate || new Date().toISOString().split('T')[0]);

      console.log('Dados brutos:', data);
      console.log('Erro:', error);

      if (error) throw error;

      if (data && data.length > 0) {
        // Agrupar por peça e mês
        const grouped = data.reduce((acc: any, item: any) => {
          const month = new Date(item.purchase_orders.order_date).toISOString().slice(0, 7);
          const key = `${item.parts.name}-${month}`;
          
          if (!acc[key]) {
            acc[key] = {
              part_name: item.parts.name,
              month,
              prices: [],
              quantities: [],
              orders: new Set()
            };
          }
          
          acc[key].prices.push(item.unit_price);
          acc[key].quantities.push(item.quantity);
          acc[key].orders.add(item.purchase_orders.id);
          
          return acc;
        }, {});

        const evolutionData = Object.values(grouped).map((group: any) => ({
          part_name: group.part_name,
          month: group.month,
          avg_price: group.prices.reduce((a: number, b: number) => a + b, 0) / group.prices.length,
          quantity_purchased: group.quantities.reduce((a: number, b: number) => a + b, 0),
          orders_count: group.orders.size
        }));

        console.log('Dados processados:', evolutionData);
        setPriceEvolution(evolutionData);
        return evolutionData;
      } else {
        console.log('Nenhum dado encontrado');
        const emptyData: PurchasePriceEvolution[] = [];
        setPriceEvolution(emptyData);
        return emptyData;
      }
    } catch (err) {
      console.error('Error fetching price evolution:', err);
      const emptyData: PurchasePriceEvolution[] = [];
      setPriceEvolution(emptyData);
      return emptyData;
    }
  };

  const fetchPurchaseStatistics = async (startDate?: string, endDate?: string) => {
    try {
      setLoading(true);

      // Usar fn_purchase_order_statistics que existe no banco
      const { data: statsData, error: statsError } = await supabase.rpc('fn_purchase_order_statistics', {
        p_tenant_id: DEFAULT_TENANT_ID
      });

      if (statsError) throw statsError;

      // Buscar dados adicionais diretamente do banco
      const { data: ordersData, error: ordersError } = await supabase
        .from('purchase_orders')
        .select(`
          *,
          purchase_order_items (
            quantity,
            unit_price
          )
        `)
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .gte('order_date', startDate || new Date(Date.now() - 365 * 24 * 60 * 60 * 1000).toISOString().split('T')[0])
        .lte('order_date', endDate || new Date().toISOString().split('T')[0]);

      if (ordersError) throw ordersError;

      // Buscar evolução de preços
      const priceEvolutionData = await fetchPriceEvolution(startDate, endDate);

      // Calcular estatísticas adicionais
      const totalItems = ordersData?.reduce((sum, order) => {
        return sum + (order.purchase_order_items?.reduce((itemSum, item) => itemSum + item.quantity, 0) || 0);
      }, 0) || 0;

      // Calcular peças mais compradas
      const partsData = await supabase
        .from('purchase_order_items')
        .select(`
          quantity,
          unit_price,
          parts!inner(name),
          purchase_orders!inner(tenant_id, order_date)
        `)
        .eq('purchase_orders.tenant_id', DEFAULT_TENANT_ID)
        .gte('purchase_orders.order_date', startDate || new Date(Date.now() - 365 * 24 * 60 * 60 * 1000).toISOString().split('T')[0])
        .lte('purchase_orders.order_date', endDate || new Date().toISOString().split('T')[0]);

      const mostPurchasedParts = partsData.data?.reduce((acc: any, item: any) => {
        const partName = item.parts.name;
        if (!acc[partName]) {
          acc[partName] = { part_name: partName, quantity: 0, total_value: 0 };
        }
        acc[partName].quantity += item.quantity;
        acc[partName].total_value += item.quantity * item.unit_price;
        return acc;
      }, {}) || {};

      // Calcular gastos mensais
      const monthlySpending = ordersData?.reduce((acc: any, order: any) => {
        const month = new Date(order.order_date).toISOString().slice(0, 7);
        if (!acc[month]) {
          acc[month] = { month, total_amount: 0, orders_count: 0 };
        }
        acc[month].total_amount += order.total_amount;
        acc[month].orders_count += 1;
        return acc;
      }, {}) || {};

      if (statsData && statsData.length > 0) {
        const stats = statsData[0];
        const statistics: PurchaseStatistics = {
          total_orders: stats.total_orders || 0,
          total_amount: stats.total_amount || 0,
          total_items: totalItems,
          average_order_value: stats.avg_order_amount || 0,
          most_purchased_parts: Object.values(mostPurchasedParts).sort((a: any, b: any) => b.quantity - a.quantity).slice(0, 10),
          monthly_spending: Object.values(monthlySpending).sort((a: any, b: any) => a.month.localeCompare(b.month)),
          price_evolution: priceEvolutionData || []
        };

        setStatistics(statistics);
      } else {
        // Fallback para quando não há dados
        const statistics: PurchaseStatistics = {
          total_orders: 0,
          total_amount: 0,
          total_items: 0,
          average_order_value: 0,
          most_purchased_parts: [],
          monthly_spending: [],
          price_evolution: priceEvolutionData || []
        };

        setStatistics(statistics);
      }
    } catch (err) {
      console.error('Erro ao carregar estatísticas de compras:', err);
      setError(err instanceof Error ? err.message : 'Erro ao carregar estatísticas de compras');
      
      // Fallback com dados vazios
      const statistics: PurchaseStatistics = {
        total_orders: 0,
        total_amount: 0,
        total_items: 0,
        average_order_value: 0,
        most_purchased_parts: [],
        monthly_spending: [],
        price_evolution: []
      };

      setStatistics(statistics);
    } finally {
      setLoading(false);
    }
  };

  const getPartPriceHistory = async (partName: string, startDate?: string, endDate?: string) => {
    try {
      const { data, error } = await supabase
        .from('purchase_order_items')
        .select(`
          unit_price,
          quantity,
          total_price,
          purchase_orders (order_date),
          parts (name)
        `)
        .eq('parts.name', partName)
        .gte('purchase_orders.order_date', startDate || new Date(Date.now() - 365 * 24 * 60 * 60 * 1000).toISOString().split('T')[0])
        .lte('purchase_orders.order_date', endDate || new Date().toISOString().split('T')[0])
        .order('purchase_orders.order_date', { ascending: true });

      if (error) throw error;
      return data || [];
    } catch (err) {
      console.error('Error fetching part price history:', err);
      return [];
    }
  };

  const getTopExpensiveParts = async (limit = 10) => {
    try {
      const { data, error } = await supabase
        .from('purchase_order_items')
        .select(`
          unit_price,
          quantity,
          total_price,
          parts (name)
        `)
        .order('unit_price', { ascending: false })
        .limit(limit);

      if (error) throw error;
      return data || [];
    } catch (err) {
      console.error('Error fetching top expensive parts:', err);
      return [];
    }
  };

  const getSupplierStatistics = async () => {
    try {
      const { data, error } = await supabase
        .from('purchase_orders')
        .select(`
          supplier_id,
          total_amount,
          order_date,
          suppliers (name)
        `)
        .eq('tenant_id', DEFAULT_TENANT_ID);

      if (error) throw error;

      // Agrupar por fornecedor
      const supplierStats = data?.reduce((acc, order) => {
        const supplierName = (order.suppliers as { name?: string })?.name || 'Desconhecido';
        if (!acc[supplierName]) {
          acc[supplierName] = { total_amount: 0, orders_count: 0 };
        }
        acc[supplierName].total_amount += order.total_amount || 0;
        acc[supplierName].orders_count += 1;
        return acc;
      }, {} as Record<string, { total_amount: number; orders_count: number }>) || {};

      return Object.entries(supplierStats)
        .map(([supplier_name, stats]) => ({
          supplier_name,
          total_amount: stats.total_amount,
          orders_count: stats.orders_count,
          average_order_value: stats.orders_count > 0 ? stats.total_amount / stats.orders_count : 0
        }))
        .sort((a, b) => b.total_amount - a.total_amount);
    } catch (err) {
      console.error('Error fetching supplier statistics:', err);
      return [];
    }
  };

  useEffect(() => {
    fetchPurchaseStatistics();
  }, []);

  return {
    statistics,
    priceEvolution,
    loading,
    error,
    fetchPurchaseStatistics,
    fetchPriceEvolution,
    getPartPriceHistory,
    getTopExpensiveParts,
    getSupplierStatistics,
    refetch: fetchPurchaseStatistics
  };
}; 