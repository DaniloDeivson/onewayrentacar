import { createClient } from '@supabase/supabase-js';
import type { Database } from '../types/database';
import type { AuthFlowType } from '@supabase/supabase-js';

// Environment variables for Supabase connection
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || '';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || '';
const supabaseServiceRoleKey = import.meta.env.VITE_SUPABASE_SERVICE_ROLE_KEY || '';
const supabasePassword = '3tFlzYbxrAMjrZ3U';

// Validação das variáveis de ambiente
if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

// Singleton class for Supabase client
class SupabaseClient {
  private static instance: ReturnType<typeof createClient<Database>> | null = null;
  private static adminInstance: ReturnType<typeof createClient<Database>> | null = null;

  private constructor() {}

  public static getInstance(): ReturnType<typeof createClient<Database>> {
    if (!SupabaseClient.instance) {
      SupabaseClient.instance = createClient<Database>(
        supabaseUrl,
        supabaseAnonKey,
        {
          auth: {
            storageKey: 'oneway.auth.token',
            autoRefreshToken: true,
            persistSession: true,
            detectSessionInUrl: true,
            flowType: 'pkce' as AuthFlowType,
            storage: window.localStorage
          },
          global: {
            headers: {
              'Accept': 'application/json',
              'X-Supabase-Password': supabasePassword
            }
          },
          db: {
            schema: 'public'
          }
        }
      );
    }
    return SupabaseClient.instance;
  }

  public static getAdminInstance(): ReturnType<typeof createClient<Database>> | null {
    if (!supabaseServiceRoleKey) return null;
    
    if (!SupabaseClient.adminInstance) {
      SupabaseClient.adminInstance = createClient<Database>(
        supabaseUrl,
        supabaseServiceRoleKey,
        {
          auth: {
            autoRefreshToken: false,
            persistSession: false
          },
          global: {
            headers: {
              'Accept': 'application/json',
              'X-Supabase-Password': supabasePassword
            }
          },
          db: {
            schema: 'public'
          }
        }
      );
    }
    return SupabaseClient.adminInstance;
  }
}

// Export singleton instances
export const supabase = SupabaseClient.getInstance();
export const supabaseAdmin = SupabaseClient.getAdminInstance();

// Default tenant ID
export const DEFAULT_TENANT_ID = '00000000-0000-0000-0000-000000000001';

// Helper function to check if Supabase is properly configured
export const isSupabaseConfigured = (): boolean => {
  return !!(supabaseUrl && supabaseAnonKey);
};

// Helper to check if admin operations are available
export const isAdminConfigured = (): boolean => {
  return !!(supabaseServiceRoleKey && supabaseAdmin);
};

// Helper to check current session
export const getCurrentSession = async () => {
  try {
    const { data: { session }, error } = await supabase.auth.getSession();
    if (error) throw error;
    return session;
  } catch (error) {
    console.error('Error getting current session:', error);
    return null;
  }
};