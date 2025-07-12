import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { Database } from '../types/database';

type Contract = Database['public']['Tables']['contracts']['Row'];

export function useRecurringContracts() {
  const [contracts, setContracts] = useState<Contract[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchContracts = async () => {
    setLoading(true);
    setError(null);
    const { data, error } = await supabase
      .from('contracts')
      .select('*')
      .eq('is_recurring', true)
      .order('created_at', { ascending: false });
    if (error) setError(error.message);
    setContracts((data as Contract[]) || []);
    setLoading(false);
  };

  useEffect(() => {
    fetchContracts();
    const channel = supabase.channel('realtime:contracts_recurring')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'contracts', filter: 'is_recurring=eq.true' },
        () => fetchContracts()
      )
      .subscribe();
    return () => { channel.unsubscribe(); };
  }, []);

  return { contracts, loading, error };
} 