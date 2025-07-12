import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

export function useCustomerAccountStatus(customerId?: string) {
  const [hasAccount, setHasAccount] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!customerId) {
      setHasAccount(false);
      return;
    }
    
    setLoading(true);
    
    // Primeiro, buscar o email do cliente
    supabase
      .from('customers')
      .select('email')
      .eq('id', customerId)
      .single()
      .then(({ data: customerData, error: customerError }) => {
        if (customerError || !customerData?.email) {
          setHasAccount(false);
          setLoading(false);
          return;
        }

        // Depois, verificar se existe um funcionário com esse email
        supabase
          .from('employees')
          .select('id')
          .eq('contact_info->>email', customerData.email)
          .eq('active', true)
          .limit(1)
          .then(({ data: employeeData, error: employeeError }) => {
            setHasAccount(!!employeeData && employeeData.length > 0);
            setLoading(false);
          })
          .catch(() => {
            setHasAccount(false);
            setLoading(false);
          });
      })
      .catch(() => {
        setHasAccount(false);
        setLoading(false);
      });
  }, [customerId]);

  return { hasAccount, loading };
} 