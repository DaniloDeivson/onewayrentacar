import React, { createContext, useContext, useReducer, useCallback, useMemo } from 'react';

interface CacheItem {
  data: unknown;
  timestamp: number;
  ttl: number;
}

interface CacheState {
  [key: string]: CacheItem;
}

type CacheAction = 
  | { type: 'SET'; key: string; data: unknown; ttl?: number }
  | { type: 'GET'; key: string }
  | { type: 'DELETE'; key: string }
  | { type: 'CLEAR' }
  | { type: 'CLEANUP' };

interface CacheContextType {
  get: <T = unknown>(key: string) => T | null;
  set: <T = unknown>(key: string, data: T, ttl?: number) => void;
  delete: (key: string) => void;
  clear: () => void;
  has: (key: string) => boolean;
  isExpired: (key: string) => boolean;
}

const CacheContext = createContext<CacheContextType | undefined>(undefined);

const DEFAULT_TTL = 5 * 60 * 1000; // 5 minutos

function cacheReducer(state: CacheState, action: CacheAction): CacheState {
  switch (action.type) {
    case 'SET':
      return {
        ...state,
        [action.key]: {
          data: action.data,
          timestamp: Date.now(),
          ttl: action.ttl || DEFAULT_TTL
        }
      };
    
    case 'DELETE': {
      const newState = { ...state };
      delete newState[action.key];
      return newState;
    }
    
    case 'CLEAR':
      return {};
    
    case 'CLEANUP': {
      const now = Date.now();
      const newState = { ...state };
      let hasChanges = false;
      
      Object.keys(newState).forEach(key => {
        const item = newState[key];
        if (now - item.timestamp > item.ttl) {
          delete newState[key];
          hasChanges = true;
        }
      });
      
      return hasChanges ? newState : state;
    }
    
    default:
      return state;
  }
}

export function CacheProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(cacheReducer, {});

  // Função para verificar se um item expirou
  const isExpired = useCallback((key: string): boolean => {
    const item = state[key];
    if (!item) return true;
    
    const now = Date.now();
    return now - item.timestamp > item.ttl;
  }, [state]);

  // Função para obter dados do cache
  const get = useCallback(<T = unknown>(key: string): T | null => {
    const item = state[key];
    if (!item || isExpired(key)) {
      return null;
    }
    return item.data as T;
  }, [state, isExpired]);

  // Função para definir dados no cache
  const set = useCallback(<T = unknown>(key: string, data: T, ttl?: number) => {
    dispatch({ type: 'SET', key, data, ttl });
  }, []);

  // Função para deletar dados do cache
  const deleteItem = useCallback((key: string) => {
    dispatch({ type: 'DELETE', key });
  }, []);

  // Função para limpar todo o cache
  const clear = useCallback(() => {
    dispatch({ type: 'CLEAR' });
  }, []);

  // Função para verificar se um item existe no cache
  const has = useCallback((key: string): boolean => {
    return !isExpired(key);
  }, [isExpired]);

  // Limpeza automática do cache a cada 5 minutos
  React.useEffect(() => {
    const interval = setInterval(() => {
      dispatch({ type: 'CLEANUP' });
    }, 5 * 60 * 1000); // 5 minutos

    return () => clearInterval(interval);
  }, []);

  // Memoizar o contexto para evitar re-renders desnecessários
  const contextValue = useMemo(() => ({
    get,
    set,
    delete: deleteItem,
    clear,
    has,
    isExpired
  }), [get, set, deleteItem, clear, has, isExpired]);

  return (
    <CacheContext.Provider value={contextValue}>
      {children}
    </CacheContext.Provider>
  );
}

export function useCache() {
  const context = useContext(CacheContext);
  if (context === undefined) {
    throw new Error('useCache must be used within a CacheProvider');
  }
  return context;
} 