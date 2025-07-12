import React, { useEffect, useState } from 'react';
import { Loader2, AlertCircle, RefreshCw } from 'lucide-react';

interface SessionLoaderProps {
  loading: boolean;
  error: string | null;
  onRetry?: () => void;
}

export const SessionLoader: React.FC<SessionLoaderProps> = ({ loading, error, onRetry }) => {
  const [showRetry, setShowRetry] = useState(false);
  const [loadingTime, setLoadingTime] = useState(0);

  useEffect(() => {
    let timer: NodeJS.Timeout;
    
    if (loading) {
      setLoadingTime(0);
      setShowRetry(false);
      
      // Show retry button after 10 seconds of loading (longer for login)
      timer = setTimeout(() => {
        setShowRetry(true);
      }, 10000);

      // Track loading time
      const timeTracker = setInterval(() => {
        setLoadingTime(prev => prev + 1);
      }, 1000);

      return () => {
        clearTimeout(timer);
        clearInterval(timeTracker);
      };
    } else {
      setShowRetry(false);
      setLoadingTime(0);
    }

    return () => {
      if (timer) clearTimeout(timer);
    };
  }, [loading]);

  if (!loading && !error) {
    return null;
  }

  const getLoadingMessage = () => {
    if (loadingTime < 3) return 'Verificando autenticação...';
    if (loadingTime < 6) return 'Carregando dados do usuário...';
    if (loadingTime < 10) return 'Conectando com o servidor...';
    return 'Isso está demorando mais que o esperado...';
  };

  return (
    <div className="fixed inset-0 bg-secondary-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-lg p-8 max-w-md w-full mx-4">
        <div className="text-center">
          {/* Logo */}
          <div className="mb-6">
            <div className="flex items-center justify-center mb-2">
              <div className="w-12 h-12 bg-primary-600 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-xl">OW</span>
              </div>
            </div>
            <h2 className="text-xl font-bold text-gray-900">OneWay Rent A Car</h2>
          </div>

          {/* Loading State */}
          {loading && !error && (
            <div className="mb-6">
              <Loader2 className="h-8 w-8 animate-spin text-primary-600 mx-auto mb-4" />
              <p className="text-gray-600 mb-2">{getLoadingMessage()}</p>
              <p className="text-sm text-gray-500">
                {loadingTime > 0 && `${loadingTime}s`}
              </p>
              
              {showRetry && (
                <div className="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
                  <p className="text-sm text-yellow-800 mb-2">
                    A autenticação está demorando mais que o esperado.
                  </p>
                  <p className="text-xs text-yellow-600 mb-3">
                    Verifique sua conexão ou tente novamente.
                  </p>
                  {onRetry && (
                    <button
                      onClick={onRetry}
                      className="flex items-center justify-center w-full px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors text-sm"
                    >
                      <RefreshCw className="h-4 w-4 mr-2" />
                      Tentar Novamente
                    </button>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Error State */}
          {error && (
            <div className="mb-6">
              <AlertCircle className="h-8 w-8 text-red-500 mx-auto mb-4" />
              <p className="text-red-600 mb-2">Erro na autenticação</p>
              <p className="text-sm text-gray-600 mb-4">{error}</p>
              
              {onRetry && (
                <button
                  onClick={onRetry}
                  className="flex items-center justify-center w-full px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
                >
                  <RefreshCw className="h-4 w-4 mr-2" />
                  Tentar Novamente
                </button>
              )}
            </div>
          )}

          {/* Additional Info */}
          <div className="text-xs text-gray-500 border-t pt-4">
            <p>Se o problema persistir, verifique sua conexão com a internet ou contate o suporte.</p>
          </div>
        </div>
      </div>
    </div>
  );
}; 