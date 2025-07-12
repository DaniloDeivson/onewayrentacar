import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { Database } from '../types/database';
import { useCache } from '../context/CacheContext';

type Employee = Database['public']['Tables']['employees']['Row'];

export function useEmployees() {
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { get, set, has, delete: deleteCache } = useCache();

  const fetchEmployees = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);

      // Verificar cache primeiro
      const cacheKey = 'employees';
      if (has(cacheKey)) {
        const cachedData = get<Employee[]>(cacheKey);
        if (cachedData) {
          console.log('📦 Usando funcionários do cache');
          setEmployees(cachedData);
          setLoading(false);
          return;
        }
      }

      // Buscar via função RPC que contorna problemas de RLS
      const { data, error } = await supabase.rpc('list_employees_for_admin');
      if (error) throw error;

      set(cacheKey, data, 5 * 60 * 1000); // 5 minutos
      setEmployees(data);
    } catch (err) {
      console.error('Erro ao buscar funcionários:', err);
      setError(err instanceof Error ? err.message : 'Erro ao buscar funcionários');
    } finally {
      setLoading(false);
    }
  }, [get, set, has]);

  const createEmployee = useCallback(async (employeeData: Partial<Employee>) => {
    try {
      const { data, error } = await supabase
        .from('employees')
        .insert([employeeData])
        .select()
        .single();

      if (error) throw error;

      // Limpar cache e atualizar lista local
      deleteCache('employees');
      setEmployees(prev => [data, ...prev]);
      return data;
    } catch (err) {
      console.error('Erro ao criar funcionário:', err);
      throw err;
    }
  }, [deleteCache]);

  const updateEmployee = useCallback(async (id: string, updates: Partial<Employee>) => {
    try {
      console.log('Atualizando funcionário:', id, updates);
      
      // Tentar atualização com retorno dos dados
      const { data, error } = await supabase
        .from('employees')
        .update(updates)
        .eq('id', id)
        .select()
        .maybeSingle();

      if (error) {
        console.error('Erro do Supabase ao atualizar:', error);
        
        // Se falhou com select, tentar sem select
        const { error: updateError } = await supabase
          .from('employees')
          .update(updates)
          .eq('id', id);

        if (updateError) {
          console.error('Erro ao atualizar sem select:', updateError);
          throw updateError;
        } else {
          console.log('Atualização realizada sem retorno de dados');
        }
      } else {
        console.log('Funcionário atualizado com sucesso:', data);
      }

      // Limpar cache e atualizar lista local
      deleteCache('employees');
      setEmployees(prev => prev.map(employee => 
        employee.id === id ? { ...employee, ...updates } : employee
      ));
      
      return data || { id, ...updates };
    } catch (err) {
      console.error('Erro ao atualizar funcionário:', err);
      throw err;
    }
  }, [deleteCache]);

  const deleteEmployee = useCallback(async (id: string) => {
    try {
      console.log('Excluindo funcionário:', id);
      
      // Verificar se o funcionário existe antes de tentar excluir (opcional)
      try {
        const { data: employeeData, error: fetchError } = await supabase
          .from('employees')
          .select('id')
          .eq('id', id)
          .maybeSingle();
        
        if (fetchError && fetchError.code !== 'PGRST116') {
          console.error('Erro ao buscar funcionário:', fetchError);
          throw fetchError;
        }
        
        if (!employeeData) {
          console.log('Funcionário não encontrado, mas prosseguindo com exclusão');
        }
      } catch (fetchErr) {
        console.error('Erro ao verificar funcionário:', fetchErr);
        // Continue com a exclusão mesmo se não conseguir buscar
      }
      
      // Excluir do banco
      const { error: deleteError } = await supabase
        .from('employees')
        .delete()
        .eq('id', id);
        
      if (deleteError) {
        console.error('Erro ao fazer DELETE:', deleteError);
        throw deleteError;
      } else {
        console.log('DELETE realizado com sucesso');
      }
      
      // Limpar cache e atualizar lista local
      deleteCache('employees');
      setEmployees(prev => prev.filter(employee => employee.id !== id));
      console.log('Funcionário excluído com sucesso da lista local');
      
    } catch (err) {
      console.error('Erro ao excluir funcionário:', err);
      throw err;
    }
  }, [deleteCache]);

  useEffect(() => {
    fetchEmployees();
  }, [fetchEmployees]);

  return {
    employees,
    loading,
    error,
    refetch: fetchEmployees,
    createEmployee,
    updateEmployee,
    deleteEmployee
  };
}