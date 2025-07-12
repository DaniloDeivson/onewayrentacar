import React from 'react';
import { Card, CardContent } from '../UI/Card';
import { DollarSign, Calendar, AlertTriangle, TrendingUp, UserCheck } from 'lucide-react';

interface FinancialSummaryProps {
  summary: {
    total_pending: number;
    total_paid: number;
    total_overdue: number;
    overdue_count: number;
    upcoming_payments: number;
    upcoming_count: number;
    salary_total: number;
    recurring_total: number;
  } | null;
}

export const FinancialSummary: React.FC<FinancialSummaryProps> = ({ summary }) => {
  if (!summary) return null;

  // Format currency
  const formatCurrency = (value: number) => {
    return value.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
  };

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4 mb-6">
      <Card>
        <CardContent className="p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-secondary-600 text-xs lg:text-sm font-medium">Total a Pagar</p>
              <p className="text-xl lg:text-2xl font-bold text-secondary-900">
                {formatCurrency(summary.total_pending)}
              </p>
              <p className="text-xs text-secondary-500 mt-1">Contas pendentes</p>
            </div>
            <div className="h-12 w-12 bg-primary-100 rounded-lg flex items-center justify-center">
              <DollarSign className="h-6 w-6 text-primary-600" />
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-secondary-600 text-xs lg:text-sm font-medium">Vencendo em 7 dias</p>
              <p className="text-xl lg:text-2xl font-bold text-secondary-900">
                {formatCurrency(summary.upcoming_payments)}
              </p>
              <p className="text-xs text-secondary-500 mt-1">{summary.upcoming_count} contas</p>
            </div>
            <div className="h-12 w-12 bg-warning-100 rounded-lg flex items-center justify-center">
              <Calendar className="h-6 w-6 text-warning-600" />
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-secondary-600 text-xs lg:text-sm font-medium">Contas Vencidas</p>
              <p className="text-xl lg:text-2xl font-bold text-error-600">
                {formatCurrency(summary.total_overdue)}
              </p>
              <p className="text-xs text-error-500 mt-1">{summary.overdue_count} contas em atraso</p>
            </div>
            <div className="h-12 w-12 bg-error-100 rounded-lg flex items-center justify-center">
              <AlertTriangle className="h-6 w-6 text-error-600" />
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-secondary-600 text-xs lg:text-sm font-medium">Total Pago</p>
              <p className="text-xl lg:text-2xl font-bold text-success-600">
                {formatCurrency(summary.total_paid)}
              </p>
              <p className="text-xs text-success-500 mt-1">Contas quitadas</p>
            </div>
            <div className="h-12 w-12 bg-success-100 rounded-lg flex items-center justify-center">
              <TrendingUp className="h-6 w-6 text-success-600" />
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-secondary-600 text-xs lg:text-sm font-medium">Salários</p>
              <p className="text-xl lg:text-2xl font-bold text-blue-600">
                {formatCurrency(summary.salary_total)}
              </p>
              <p className="text-xs text-blue-500 mt-1">Total de salários</p>
            </div>
            <div className="h-12 w-12 bg-blue-100 rounded-lg flex items-center justify-center">
              <UserCheck className="h-6 w-6 text-blue-600" />
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default FinancialSummary;