import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { CacheProvider } from './context/CacheContext';
import { DriverProvider } from './context/DriverContext';
import { useAuth } from './hooks/useAuth';
import { Layout } from './components/Layout/Layout';
import { Dashboard } from './pages/Dashboard';
import { Fleet } from './pages/Fleet';
import { Costs } from './pages/Costs';
import { Maintenance } from './pages/Maintenance';
import { Inventory } from './pages/Inventory';
import { Contracts } from './pages/Contracts';
import { Inspections } from './pages/Inspections';
import { Employees } from './pages/Employees';
import { Fines } from './pages/Fines';
import { Suppliers } from './pages/Suppliers';
import { PurchaseOrders } from './pages/PurchaseOrders';
import { Admin } from './pages/Admin';
import { Statistics } from './pages/Statistics';
import { Unauthorized } from './pages/Unauthorized';
import { AuthGuard } from './components/UI/AuthGuard';
import { Finance } from './pages/Finance';
import Notas from './pages/Notas';
import Login from './pages/Login';
import Cobranca from './pages/Cobranca';
import Register from './pages/Register';
import { DriverRecords } from './pages/DriverRecords';
import { Fuel } from './pages/Fuel';
import Customers from './pages/Customers';

// Componente que renderiza o conteúdo baseado no papel do usuário
const AppContent: React.FC = () => {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/register" element={<Register />} />
      <Route path="/" element={<AuthGuard><Layout /></AuthGuard>}>
        <Route index element={
          <AuthGuard>
            <Dashboard />
          </AuthGuard>
        } />
        <Route path="frota" element={
          <AuthGuard>
            <Fleet />
          </AuthGuard>
        } />
        <Route path="custos" element={
          <AuthGuard>
            <Costs />
          </AuthGuard>
        } />
        <Route path="manutencao" element={
          <AuthGuard>
            <Maintenance />
          </AuthGuard>
        } />
        <Route path="estoque" element={
          <AuthGuard>
            <Inventory />
          </AuthGuard>
        } />
        <Route path="contratos" element={
          <AuthGuard>
            <Contracts />
          </AuthGuard>
        } />
        <Route path="inspecoes" element={
          <AuthGuard>
            <Inspections />
          </AuthGuard>
        } />
        <Route path="multas" element={
          <AuthGuard>
            <Fines />
          </AuthGuard>
        } />
        <Route path="fornecedores" element={
          <AuthGuard>
            <Suppliers />
          </AuthGuard>
        } />
        <Route path="compras" element={
          <AuthGuard>
            <PurchaseOrders />
          </AuthGuard>
        } />
        <Route path="estatisticas" element={
          <AuthGuard>
            <Statistics />
          </AuthGuard>
        } />
        <Route path="financeiro" element={
          <AuthGuard>
            <Finance />
          </AuthGuard>
        } />
        <Route path="notas" element={
          <AuthGuard>
            <Notas />
          </AuthGuard>
        } />
        <Route path="cobranca" element={
          <AuthGuard>
            <Cobranca />
          </AuthGuard>
        } />
        <Route path="combustivel" element={
          <AuthGuard>
            <Fuel />
          </AuthGuard>
        } />
        <Route path="admin" element={
          <AuthGuard>
            <Admin />
          </AuthGuard>
        } />
        <Route path="funcionarios" element={
          <AuthGuard>
            <Employees />
          </AuthGuard>
        } />
        <Route path="registros" element={
          <AuthGuard>
            <DriverRecords />
          </AuthGuard>
        } />
        <Route path="clientes" element={
          <AuthGuard>
            <Customers />
          </AuthGuard>
        } />
        <Route path="unauthorized" element={<Unauthorized />} />
      </Route>
      <Route path="*" element={<Navigate to="/login" replace />} />
    </Routes>
  );
};

// Componente que decide se usa DriverProvider baseado no papel do usuário
const AppWithDriverContext: React.FC = () => {
  const { user, loading } = useAuth();
  
  // Se ainda está carregando, mostrar loading
  if (loading) {
    return <div className="flex items-center justify-center min-h-screen">Carregando...</div>;
  }

  // Se é um driver, usar o DriverProvider
  if (user?.role === 'Driver') {
    return (
      <DriverProvider>
        <AppContent />
      </DriverProvider>
    );
  }

  // Para admins e outros papéis, renderizar sem o DriverProvider (acesso total)
  return <AppContent />;
};

function App() {
  return (
    <CacheProvider>
      <Router>
        <AppWithDriverContext />
      </Router>
      
      <Toaster 
        position="top-right"
        toastOptions={{
          duration: 5000,
          style: {
            background: '#fff',
            color: '#1e293b',
            borderRadius: '0.375rem',
            boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
          },
          success: {
            iconTheme: {
              primary: '#16a34a',
              secondary: '#fff',
            },
          },
          error: {
            iconTheme: {
              primary: '#dc2626',
              secondary: '#fff',
            },
          },
        }}
      />
    </CacheProvider>
  );
}

export default App;