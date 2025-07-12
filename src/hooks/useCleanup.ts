import { useState } from 'react';
import { supabase, DEFAULT_TENANT_ID } from '../lib/supabase';
import toast from 'react-hot-toast';

export const useCleanup = () => {
  const [loading, setLoading] = useState(false);
  const [results, setResults] = useState<Record<string, number>>({});

  // Function to clean up all data for production
  const cleanupAllData = async () => {
    setLoading(true);
    const results: Record<string, number> = {};
    
    try {
      // Clean up in a specific order to avoid foreign key constraints
      
      // 1. First, clean up tables with no dependencies
      results.damage_notifications = await cleanupTable('damage_notifications');
      results.stock_movements = await cleanupTable('stock_movements');
      results.service_order_parts = await cleanupTable('service_order_parts');
      results.inspection_items = await cleanupTable('inspection_items');
      results.maintenance_checkins = await cleanupTable('maintenance_checkins');
      results.purchase_order_items = await cleanupTable('purchase_order_items');
      results.accounts_payable = await cleanupTable('accounts_payable');
      results.salaries = await cleanupTable('salaries');
      
      // 2. Then clean up tables with dependencies on the above
      results.costs = await cleanupTable('costs');
      results.fines = await cleanupTable('fines');
      results.inspections = await cleanupTable('inspections');
      results.service_notes = await cleanupTable('service_notes');
      results.purchase_orders = await cleanupTable('purchase_orders');
      
      // 3. Finally clean up core tables
      results.contracts = await cleanupTable('contracts');
      results.vehicles = await cleanupTable('vehicles');
      results.customers = await cleanupTable('customers');
      results.parts = await cleanupTable('parts');
      results.suppliers = await cleanupTable('suppliers');
      results.drivers = await cleanupTable('drivers');
      
      // Keep employees and tenants intact
      
      toast.success('Limpeza de dados concluída com sucesso!');
      setResults(results);
    } catch (error) {
      console.error('Error cleaning up data:', error);
      toast.error('Erro ao limpar dados: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
    } finally {
      setLoading(false);
    }
    
    return results;
  };
  
  // Function to clean up a specific table
  const cleanupTable = async (tableName: string): Promise<number> => {
    try {
      const { error, count } = await supabase
        .from(tableName)
        .delete()
        .eq('tenant_id', DEFAULT_TENANT_ID)
        .select('count');
      
      if (error) throw error;
      
      return count || 0;
    } catch (error) {
      return 0;
    }
  };
  
  // Function to insert sample data for demo
  const insertSampleData = async () => {
    setLoading(true);
    try {
      // Insert sample vehicles
      await supabase.from('vehicles').insert([
        {
          tenant_id: DEFAULT_TENANT_ID,
          plate: 'ABC1234',
          model: 'Fiat Ducato',
          year: 2022,
          type: 'Furgão',
          color: 'Branco',
          fuel: 'Diesel',
          category: 'Carga',
          status: 'Disponível'
        },
        {
          tenant_id: DEFAULT_TENANT_ID,
          plate: 'DEF5678',
          model: 'Mercedes Sprinter',
          year: 2021,
          type: 'Van',
          color: 'Prata',
          fuel: 'Diesel',
          category: 'Passageiros',
          status: 'Disponível'
        }
      ]);
      
      // Insert sample customers
      await supabase.from('customers').insert([
        {
          tenant_id: DEFAULT_TENANT_ID,
          name: 'Empresa Exemplo Ltda',
          document: '12.345.678/0001-90',
          email: 'contato@empresa.com',
          phone: '(11) 99999-9999'
        },
        {
          tenant_id: DEFAULT_TENANT_ID,
          name: 'Transportes Rápidos S.A.',
          document: '98.765.432/0001-10',
          email: 'contato@transportes.com',
          phone: '(11) 88888-8888'
        }
      ]);
      
      toast.success('Dados de exemplo inseridos com sucesso!');
    } catch (error) {
      console.error('Error inserting sample data:', error);
      toast.error('Erro ao inserir dados de exemplo: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
    } finally {
      setLoading(false);
    }
  };
  
  return {
    loading,
    results,
    cleanupAllData,
    cleanupTable,
    insertSampleData
  };
};