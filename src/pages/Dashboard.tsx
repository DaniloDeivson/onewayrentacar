import React, { useEffect } from 'react';
import { Card, CardHeader, CardContent } from '../components/UI/Card';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend } from 'recharts';
import { Car, DollarSign, Wrench, Users, TrendingUp, AlertCircle } from 'lucide-react';
import { useVehicles } from '../hooks/useVehicles';
import { useCosts } from '../hooks/useCosts';
import { useServiceNotes } from '../hooks/useServiceNotes';
import { useAuth } from '../hooks/useAuth';

const vehicleStatusData = [
  { name: 'Disponível', value: 0, color: '#22c55e' },
  { name: 'Em Uso', value: 0, color: '#3b82f6' },
  { name: 'Manutenção', value: 0, color: '#f59e0b' },
  { name: 'Inativo', value: 0, color: '#ef4444' },
];

const StatCard: React.FC<{
  title: string;
  value: string;
  subtitle: string;
  icon: React.ReactNode;
  trend?: string;
  trendColor?: string;
}> = ({ title, value, subtitle, icon, trend, trendColor = 'text-success-600' }) => (
  <Card>
    <CardContent>
      <div className="flex items-center justify-between">
        <div>
          <p className="text-secondary-600 text-sm font-medium">{title}</p>
          <p className="text-2xl font-bold text-secondary-900">{value}</p>
          <p className="text-secondary-500 text-sm">{subtitle}</p>
          {trend && (
            <div className={`flex items-center mt-2 ${trendColor}`}>
              <TrendingUp className="h-4 w-4 mr-1" />
              <span className="text-sm font-medium">{trend}</span>
            </div>
          )}
        </div>
        <div className="h-12 w-12 bg-primary-100 rounded-lg flex items-center justify-center">
          {icon}
        </div>
      </div>
    </CardContent>
  </Card>
);

export const Dashboard: React.FC = () => {
  const { user } = useAuth();
  const { vehicles } = useVehicles();
  const { costs } = useCosts();
  const { serviceNotes } = useServiceNotes();

  useEffect(() => {
    console.log('📊 Dashboard loaded successfully');
    console.log('👤 User data:', user);
    console.log('🔐 User permissions:', user?.permissions);
  }, [user]);

  // Verificar se o usuário tem permissão para dashboard
  const hasDashboardPermission = user?.role === 'Admin' || user?.permissions?.dashboard;

  if (!hasDashboardPermission) {
    console.log('❌ Usuário sem permissão para dashboard');
    return (
      <div className="flex flex-col items-center justify-center h-[60vh]">
        <AlertCircle className="h-16 w-16 text-error-500 mb-4" />
        <h2 className="text-2xl font-bold text-secondary-900 mb-2">Acesso Restrito</h2>
        <p className="text-secondary-600 text-center">
          Você não tem permissão para acessar o dashboard.
          <br />
          Entre em contato com um administrador.
        </p>
        <div className="mt-4 text-sm text-gray-500">
          <p>Role: {user?.role}</p>
          <p>Permissions: {JSON.stringify(user?.permissions)}</p>
        </div>
      </div>
    );
  }

  // Calculate statistics based on permissions
  const totalCosts = user?.permissions?.costs 
    ? costs.reduce((sum, cost) => sum + cost.amount, 0)
    : 0;

  const pendingMaintenance = user?.permissions?.maintenance
    ? serviceNotes.filter(note => note.status !== 'Concluída').length
    : 0;

  // Calculate vehicle status distribution if has fleet permission
  const statusCounts = user?.permissions?.fleet
    ? vehicles.reduce((acc, vehicle) => {
        // Para drivers, contar apenas veículos ativos
        if (user?.role === 'Driver' && vehicle.status === 'Inativo') {
          return acc;
        }
        acc[vehicle.status] = (acc[vehicle.status] || 0) + 1;
        return acc;
      }, {} as Record<string, number>)
    : {};

  const chartData = vehicleStatusData.map(item => ({
    ...item,
    value: statusCounts[item.name] || 0
  }));

  // Recent costs for chart (only if has costs permission)
  const recentCosts = user?.permissions?.costs
    ? costs
        .sort((a, b) => new Date(b.cost_date).getTime() - new Date(a.cost_date).getTime())
        .slice(0, 6)
        .reverse()
    : [];

  const costChartData = recentCosts.map(cost => ({
    date: new Date(cost.cost_date).toLocaleDateString('pt-BR', { month: 'short', day: 'numeric' }),
    amount: cost.amount
  }));

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-secondary-900">Dashboard</h1>
        <p className="text-secondary-600 mt-2">Visão geral da sua operação</p>
        {user && (
          <p className="text-sm text-gray-500 mt-1">
            Logado como: <span className="font-medium">{user.name}</span> ({user.role})
          </p>
        )}
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {user?.permissions?.fleet && (
          <StatCard
            title="Total de Veículos"
            value={
              user?.role === 'Driver' 
                ? vehicles.filter(v => v.status !== 'Inativo').length.toString()
                : vehicles.length.toString()
            }
            subtitle={user?.role === 'Driver' ? 'Meus veículos ativos' : 'Frota ativa'}
            icon={<Car className="h-6 w-6 text-primary-600" />}
          />
        )}
        
        {user?.permissions?.costs && (
          <StatCard
            title="Custos Totais"
            value={`R$ ${totalCosts.toLocaleString('pt-BR')}`}
            subtitle="Acumulado"
            icon={<DollarSign className="h-6 w-6 text-error-600" />}
          />
        )}

        {user?.permissions?.maintenance && (
          <>
            <StatCard
              title="Ordens de Serviço"
              value={serviceNotes.length.toString()}
              subtitle="Total registradas"
              icon={<Users className="h-6 w-6 text-primary-600" />}
            />
            <StatCard
              title="Manutenções Pendentes"
              value={pendingMaintenance.toString()}
              subtitle="Necessitam atenção"
              icon={<Wrench className="h-6 w-6 text-warning-600" />}
            />
          </>
        )}
      </div>

      {/* Charts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Costs Chart */}
        {user?.permissions?.costs && (
          <Card>
            <CardHeader>
              <h3 className="text-lg font-semibold text-secondary-900">Custos Recentes</h3>
              <p className="text-secondary-600 text-sm">Últimos lançamentos</p>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={costChartData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" />
                  <YAxis />
                  <Tooltip 
                    formatter={(value: number) => [`R$ ${value.toLocaleString('pt-BR')}`, 'Valor']}
                  />
                  <Bar dataKey="amount" fill="#ef4444" />
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        )}

        {/* Vehicle Status Chart */}
        {user?.permissions?.fleet && (
          <Card>
            <CardHeader>
              <h3 className="text-lg font-semibold text-secondary-900">Status da Frota</h3>
              <p className="text-secondary-600 text-sm">Distribuição atual</p>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={300}>
                <PieChart>
                  <Pie
                    data={chartData}
                    cx="50%"
                    cy="50%"
                    outerRadius={100}
                    dataKey="value"
                    label={false}
                  >
                    {chartData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip />
                  <Legend layout="vertical" align="right" verticalAlign="middle" />
                </PieChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        )}
      </div>

      {/* Recent Activity */}
      {(user?.permissions?.costs || user?.permissions?.maintenance) && (
        <Card>
          <CardHeader>
            <h3 className="text-lg font-semibold text-secondary-900">Atividades Recentes</h3>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {user?.permissions?.costs && costs.slice(0, 3).map((cost) => (
                <div key={cost.id} className="flex items-center space-x-4 p-4 bg-secondary-50 rounded-lg">
                  <div className="h-8 w-8 bg-error-100 rounded-full flex items-center justify-center">
                    <DollarSign className="h-4 w-4 text-error-600" />
                  </div>
                  <div className="flex-1">
                    <p className="text-sm font-medium text-secondary-900">Novo custo registrado</p>
                    <p className="text-xs text-secondary-600">{cost.description} - R$ {cost.amount.toLocaleString('pt-BR')}</p>
                  </div>
                  <span className="text-xs text-secondary-500">
                    {new Date(cost.created_at).toLocaleDateString('pt-BR')}
                  </span>
                </div>
              ))}

              {user?.permissions?.maintenance && serviceNotes.slice(0, 2).map((note) => (
                <div key={note.id} className="flex items-center space-x-4 p-4 bg-secondary-50 rounded-lg">
                  <div className="h-8 w-8 bg-warning-100 rounded-full flex items-center justify-center">
                    <Wrench className="h-4 w-4 text-warning-600" />
                  </div>
                  <div className="flex-1">
                    <p className="text-sm font-medium text-secondary-900">Nova ordem de serviço</p>
                    <p className="text-xs text-secondary-600">{note.description}</p>
                  </div>
                  <span className="text-xs text-secondary-500">
                    {new Date(note.created_at).toLocaleDateString('pt-BR')}
                  </span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
};