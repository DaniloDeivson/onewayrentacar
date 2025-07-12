// Authentication configuration
export const AUTH_CONFIG = {
  // Session management
  SESSION_CHECK_INTERVAL: 30000, // 30 seconds
  SESSION_TIMEOUT: 7 * 24 * 60 * 60 * 1000, // 7 days for persistent sessions
  
  // Navigation
  REDIRECT_DELAY: 100, // milliseconds
  DEBOUNCE_DELAY: 1000, // milliseconds
  
  // Local storage keys
  STORAGE_KEYS: {
    LAST_LOGIN: 'lastLogin',
    USER_PREFERENCES: 'userPreferences',
    REDIRECT_PATH: 'redirectPath',
    REMEMBER_ME: 'rememberMe',
    SESSION_PERSISTENT: 'sessionPersistent'
  },
  
  // Default routes
  ROUTES: {
    LOGIN: '/login',
    DASHBOARD: '/',
    UNAUTHORIZED: '/unauthorized'
  }
};

// Helper functions
export const isSessionValid = (): boolean => {
  const lastLogin = localStorage.getItem(AUTH_CONFIG.STORAGE_KEYS.LAST_LOGIN);
  const rememberMe = localStorage.getItem(AUTH_CONFIG.STORAGE_KEYS.REMEMBER_ME);
  
  if (!lastLogin) return false;
  
  const loginTime = new Date(lastLogin).getTime();
  const now = Date.now();
  
  // If user chose "remember me", extend session timeout
  const timeout = rememberMe === 'true' ? AUTH_CONFIG.SESSION_TIMEOUT : 24 * 60 * 60 * 1000; // 24 hours default
  
  return (now - loginTime) < timeout;
};

export const saveLastLogin = (rememberMe: boolean = false): void => {
  localStorage.setItem(AUTH_CONFIG.STORAGE_KEYS.LAST_LOGIN, new Date().toISOString());
  localStorage.setItem(AUTH_CONFIG.STORAGE_KEYS.REMEMBER_ME, rememberMe.toString());
  localStorage.setItem(AUTH_CONFIG.STORAGE_KEYS.SESSION_PERSISTENT, 'true');
};

export const clearSession = (): void => {
  localStorage.removeItem(AUTH_CONFIG.STORAGE_KEYS.LAST_LOGIN);
  localStorage.removeItem(AUTH_CONFIG.STORAGE_KEYS.USER_PREFERENCES);
  localStorage.removeItem(AUTH_CONFIG.STORAGE_KEYS.REDIRECT_PATH);
  localStorage.removeItem(AUTH_CONFIG.STORAGE_KEYS.REMEMBER_ME);
  localStorage.removeItem(AUTH_CONFIG.STORAGE_KEYS.SESSION_PERSISTENT);
};

export const shouldRememberUser = (): boolean => {
  return localStorage.getItem(AUTH_CONFIG.STORAGE_KEYS.REMEMBER_ME) === 'true';
};

export const isSessionPersistent = (): boolean => {
  return localStorage.getItem(AUTH_CONFIG.STORAGE_KEYS.SESSION_PERSISTENT) === 'true';
};

export const getLastLoginTime = (): Date | null => {
  const lastLogin = localStorage.getItem(AUTH_CONFIG.STORAGE_KEYS.LAST_LOGIN);
  return lastLogin ? new Date(lastLogin) : null;
};

export const getSessionAge = (): number => {
  const lastLogin = getLastLoginTime();
  if (!lastLogin) return 0;
  
  return Date.now() - lastLogin.getTime();
};

export const formatSessionAge = (): string => {
  const age = getSessionAge();
  if (age === 0) return 'Nunca';
  
  const minutes = Math.floor(age / (1000 * 60));
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  
  if (days > 0) return `${days} dias atrás`;
  if (hours > 0) return `${hours} horas atrás`;
  if (minutes > 0) return `${minutes} minutos atrás`;
  return 'Agora mesmo';
}; 