import { useState, useEffect } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';

export interface PurchaseOrder {
  id: string;
  tenant_id: string;
  supplier_id: string;
  order_number: string;
  order_date: string;
  total_amount: number;
  status: 'Pending' | 'Received' | 'Cancelled' | 'Aprovada';
  created_by_employee_id: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
  // From view
  supplier_name?: string;
  supplier_document?: string;
  created_by_name?: string;
  created_by_role?: string;
  item_count?: number;
}

export interface PurchaseOrderInsert {
  supplier_id: string;
  order_number?: string;
  order_date: string;
  total_amount: number;
  status: 'Pending' | 'Received' | 'Cancelled' | 'Aprovada';
  created_by_employee_id: string | null;
  notes?: string | null;
}

export interface PurchaseOrderUpdate {
  supplier_id?: string;
  order_date?: string;
  total_amount?: number;
  status?: 'Pending' | 'Received' | 'Cancelled' | 'Aprovada';
  notes?: string | null;
  created_by_employee_id?: string | null;
}

export interface PurchaseOrderItem {
  id: string;
  purchase_order_id: string;
  part_id: string | null;
  description: string;
  quantity: number;
  unit_price: number;
  line_total: number;
  created_at: string;
  // From view
  part_name?: string;
  part_sku?: string;
}

export interface PurchaseOrderItemInsert {
  purchase_order_id: string;
  part_id?: string | null;
  description: string;
  quantity: number;
  unit_price: number;
}

export interface PurchaseOrderStatistics {
  total_orders: number;
  pending_orders: number;
  received_orders: number;
  cancelled_orders: number;
  total_amount: number;
  pending_amount: number;
  avg_order_amount: number;
  most_ordered_part: string | null;
  top_supplier: string | null;
}

export const usePurchaseOrders = () => {
  const [orders, setOrders] = useState<PurchaseOrder[]>([]);
  const [stats, setStats] = useState<PurchaseOrderStatistics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchPurchaseOrders = async () => {
    try {
      setLoading(true);
      
      // Try to use the detailed view first
      const { data, error } = await supabase
        .from('vw_purchase_orders_detailed')
        .select('*')
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .order('created_at', { ascending: false });

      // If view doesn't exist, query directly
      if (error || !data) {
        const { data: directData, error: directError } = await supabase
          .from('purchase_orders')
          .select(`
            *,
            suppliers (
              name,
              document
            ),
            employees (
              name,
              role
            )
          `)
          .eq('tenant_id', DEFAULT_TENANT_ID)
          .order('created_at', { ascending: false });

        if (directError) throw directError;
        
        // Transform data to match view structure
        const transformedData = directData?.map(po => ({
          ...po,
          supplier_name: po.suppliers?.name,
          supplier_document: po.suppliers?.document,
          created_by_name: po.employees?.name,
          created_by_role: po.employees?.role,
          item_count: 0 // We'll need a separate query to get this
        })) || [];

        setOrders(transformedData);
      } else {
        setOrders(data || []);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
      setOrders([]); // Ensure we always have an array
    } finally {
      setLoading(false);
    }
  };

  const fetchStatistics = async () => {
    try {
      // fn_purchase_order_statistics only accepts p_tenant_id
      const { data, error } = await supabase
        .rpc('fn_purchase_order_statistics', { 
          p_tenant_id: DEFAULT_TENANT_ID 
        });

      if (error) throw error;
      if (data && data.length > 0) {
        setStats(data[0]);
      } else {
        // Set default statistics if no data
        setStats({
          total_orders: 0,
          pending_orders: 0,
          received_orders: 0,
          cancelled_orders: 0,
          total_amount: 0,
          pending_amount: 0,
          avg_order_amount: 0,
          most_ordered_part: null,
          top_supplier: null
        });
      }
    } catch (err) {
      console.error('Error fetching purchase order statistics:', err);
      // Set default statistics on error
      setStats({
        total_orders: 0,
        pending_orders: 0,
        received_orders: 0,
        cancelled_orders: 0,
        total_amount: 0,
        pending_amount: 0,
        avg_order_amount: 0,
        most_ordered_part: null,
        top_supplier: null
      });
    }
  };

  const fetchPurchaseOrderItems = async (purchaseOrderId: string): Promise<PurchaseOrderItem[]> => {
    try {
      // Try to use the detailed view first
      const { data, error } = await supabase
        .from('vw_purchase_order_items_detailed')
        .select('*')
        .eq('purchase_order_id', purchaseOrderId)
        .order('created_at', { ascending: true });

      // If view doesn't exist, query directly
      if (error || !data) {
        const { data: directData, error: directError } = await supabase
          .from('purchase_order_items')
          .select(`
            *,
            parts (
              name,
              sku
            )
          `)
          .eq('purchase_order_id', purchaseOrderId)
          .order('created_at', { ascending: true });

        if (directError) throw directError;
        
        // Transform data to match view structure
        const transformedData = directData?.map(item => ({
          ...item,
          part_name: item.parts?.name,
          part_sku: item.parts?.sku
        })) || [];

        return transformedData;
      }

      return data || [];
    } catch (err) {
      console.error('Error fetching purchase order items:', err);
      return [];
    }
  };

  const createPurchaseOrder = async (orderData: PurchaseOrderInsert, items: PurchaseOrderItemInsert[]) => {
    try {
      // Validate order data before insertion
      if (!orderData.supplier_id) {
        throw new Error('Supplier ID is required');
      }
      
      if (!orderData.order_date) {
        throw new Error('Order date is required');
      }
      
      if (orderData.total_amount < 0) {
        throw new Error('Total amount must be non-negative');
      }
      
      // Ensure status is valid
      const validStatuses = ['Pending', 'Received', 'Cancelled', 'Aprovada'];
      if (!validStatuses.includes(orderData.status)) {
        throw new Error(`Invalid status: ${orderData.status}. Valid statuses are: ${validStatuses.join(', ')}`);
      }

      // Start a transaction
      const { data: order, error: orderError } = await supabase
        .from('purchase_orders')
        .insert([{ ...orderData, tenant_id: DEFAULT_TENANT_ID }])
        .select()
        .single();

      if (orderError) {
        console.error('Purchase order creation error:', orderError);
        
        // Provide more specific error messages
        if (orderError.code === '23505') {
          throw new Error('Order number already exists. Please use a different number or leave it empty for auto-generation.');
        } else if (orderError.code === '23514') {
          throw new Error('Invalid data provided. Please check all required fields and constraints.');
        } else if (orderError.code === '409') {
          throw new Error('Conflict detected. This might be due to duplicate order number or invalid status.');
        } else {
          throw new Error(`Database error: ${orderError.message}`);
        }
      }

      // Insert items
      if (items.length > 0) {
        const itemsWithOrderId = items.map(item => ({
          ...item,
          purchase_order_id: order.id
        }));

        const { error: itemsError } = await supabase
          .from('purchase_order_items')
          .insert(itemsWithOrderId);

        if (itemsError) {
          console.error('Purchase order items creation error:', itemsError);
          throw new Error(`Failed to create order items: ${itemsError.message}`);
        }
      }

      // Refresh the list
      await fetchPurchaseOrders();
      await fetchStatistics();
      
      return order;
    } catch (err) {
      console.error('Create purchase order error:', err);
      throw new Error(err instanceof Error ? err.message : 'Failed to create purchase order');
    }
  };

  const updatePurchaseOrder = async (id: string, updates: PurchaseOrderUpdate) => {
    try {
      const { data, error } = await supabase
        .from('purchase_orders')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      
      // Refresh the list
      await fetchPurchaseOrders();
      await fetchStatistics();
      
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to update purchase order');
    }
  };

  const deletePurchaseOrder = async (id: string) => {
    try {
      const { error } = await supabase
        .from('purchase_orders')
        .delete()
        .eq('id', id);

      if (error) throw error;
      
      // Refresh the list
      await fetchPurchaseOrders();
      await fetchStatistics();
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to delete purchase order');
    }
  };

  const addPurchaseOrderItem = async (item: PurchaseOrderItemInsert) => {
    try {
      const { data, error } = await supabase
        .from('purchase_order_items')
        .insert([item])
        .select()
        .single();

      if (error) throw error;
      
      // Update the total amount in the purchase order
      const { data: items } = await supabase
        .from('purchase_order_items')
        .select('line_total')
        .eq('purchase_order_id', item.purchase_order_id);
      
      const totalAmount = items?.reduce((sum, item) => sum + item.line_total, 0) || 0;
      
      await updatePurchaseOrder(item.purchase_order_id, { total_amount: totalAmount });
      
      return data;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to add purchase order item');
    }
  };

  const deletePurchaseOrderItem = async (id: string, purchaseOrderId: string) => {
    try {
      const { error } = await supabase
        .from('purchase_order_items')
        .delete()
        .eq('id', id);

      if (error) throw error;
      
      // Update the total amount in the purchase order
      const { data: items } = await supabase
        .from('purchase_order_items')
        .select('line_total')
        .eq('purchase_order_id', purchaseOrderId);
      
      const totalAmount = items?.reduce((sum, item) => sum + item.line_total, 0) || 0;
      
      await updatePurchaseOrder(purchaseOrderId, { total_amount: totalAmount });
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to delete purchase order item');
    }
  };

  useEffect(() => {
    fetchPurchaseOrders();
    fetchStatistics();
  }, []);

  return {
    orders,
    stats,
    loading,
    error,
    createPurchaseOrder,
    updatePurchaseOrder,
    deletePurchaseOrder,
    fetchPurchaseOrderItems,
    addPurchaseOrderItem,
    deletePurchaseOrderItem,
    refetch: fetchPurchaseOrders,
    refetchStatistics: fetchStatistics
  };
};