import React from 'react';
import { Card, CardContent } from '../UI/Card';
import { Badge } from '../UI/Badge';
import { Button } from '../UI/Button';
import { Clock, CheckCircle, User, Calendar, AlertTriangle, LogIn, LogOut } from 'lucide-react';

interface CheckInStatusCardProps {
  serviceNote: any;
  activeCheckin?: any;
  onCheckIn: () => void;
  onCheckOut: () => void;
  className?: string;
}

export const CheckInStatusCard: React.FC<CheckInStatusCardProps> = ({
  serviceNote,
  activeCheckin,
  onCheckIn,
  onCheckOut,
  className = ''
}) => {
  const formatDuration = (startTime: string) => {
    const start = new Date(startTime);
    const now = new Date();
    const diffMs = now.getTime() - start.getTime();
    const hours = Math.floor(diffMs / (1000 * 60 * 60));
    const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
    return `${hours}h ${minutes}m`;
  };

  const isOverdue = activeCheckin && 
    new Date(activeCheckin.checkin_at).getTime() < Date.now() - (24 * 60 * 60 * 1000);

  return (
    <Card className={`${className} ${activeCheckin ? 'border-warning-200 bg-warning-50' : 'border-secondary-200'}`}>
      <CardContent className="p-4">
        <div className="flex items-center justify-between mb-3">
          <h4 className="font-semibold text-secondary-900 flex items-center">
            {activeCheckin ? (
              <>
                <Clock className="h-4 w-4 mr-2 text-warning-600" />
                Manutenção em Andamento
              </>
            ) : (
              <>
                <CheckCircle className="h-4 w-4 mr-2 text-secondary-600" />
                Aguardando Check-In
              </>
            )}
          </h4>
          {activeCheckin ? (
            <Badge variant="warning">Em Andamento</Badge>
          ) : (
            <Badge variant="secondary">Pendente</Badge>
          )}
        </div>

        {activeCheckin ? (
          <div className="space-y-3">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-3 text-sm">
              <div>
                <p className="text-secondary-600 flex items-center">
                  <User className="h-3 w-3 mr-1" />
                  Mecânico:
                </p>
                <p className="font-medium">{activeCheckin.mechanic_name}</p>
              </div>
              <div>
                <p className="text-secondary-600 flex items-center">
                  <Calendar className="h-3 w-3 mr-1" />
                  Início:
                </p>
                <p className="font-medium">
                  {new Date(activeCheckin.checkin_at).toLocaleString('pt-BR')}
                </p>
              </div>
              <div>
                <p className="text-secondary-600 flex items-center">
                  <Clock className="h-3 w-3 mr-1" />
                  Duração:
                </p>
                <p className="font-medium">{formatDuration(activeCheckin.checkin_at)}</p>
              </div>
              {activeCheckin.notes && (
                <div className="lg:col-span-2">
                  <p className="text-secondary-600">Observações:</p>
                  <p className="font-medium text-sm">{activeCheckin.notes}</p>
                </div>
              )}
            </div>

            {isOverdue && (
              <div className="bg-error-50 border border-error-200 rounded p-2">
                <div className="flex items-center text-error-700">
                  <AlertTriangle className="h-4 w-4 mr-2" />
                  <span className="text-sm font-medium">Manutenção em atraso (mais de 24h)</span>
                </div>
              </div>
            )}

            <Button 
              onClick={onCheckOut}
              variant="warning"
              size="sm"
              className="w-full"
            >
              <LogOut className="h-4 w-4 mr-2" />
              Fazer Check-Out
            </Button>
          </div>
        ) : (
          <div className="space-y-3">
            <p className="text-sm text-secondary-600">
              Esta ordem de serviço está aguardando o check-in do mecânico para iniciar a manutenção.
            </p>
            
            <div className="bg-info-50 border border-info-200 rounded p-3">
              <p className="text-xs text-info-700">
                <strong>Status do veículo:</strong> Será automaticamente alterado para "Manutenção" após o check-in.
              </p>
            </div>

            <Button 
              onClick={onCheckIn}
              variant="success"
              size="sm"
              className="w-full"
            >
              <LogIn className="h-4 w-4 mr-2" />
              Fazer Check-In
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  );
};