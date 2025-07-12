import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { Card, CardHeader, CardContent } from '../UI/Card';
import { Button } from '../UI/Button';
import { Car, UserCheck, AlertCircle, Trash2 } from 'lucide-react';
import toast from 'react-hot-toast';

interface Driver {
  id: string;
  name: string;
  role: string;
}

interface Vehicle {
  id: string;
  plate: string;
  model: string;
}

interface DriverVehicle {
  id: string;
  driver_id: string;
  vehicle_id: string;
  active: boolean;
}

export default function DriverVehicleAssignment() {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [assignments, setAssignments] = useState<DriverVehicle[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedDriver, setSelectedDriver] = useState<string>('');
  const [selectedVehicle, setSelectedVehicle] = useState<string>('');

  // Carregar motoristas
  const loadDrivers = async () => {
    try {
      const { data, error } = await supabase
        .from('employees')
        .select('id, name, role')
        .eq('role', 'Driver')
        .eq('active', true);

      if (error) throw error;
      setDrivers(data || []);
    } catch (error) {
      console.error('Erro ao carregar motoristas:', error);
      toast.error('Erro ao carregar motoristas');
    }
  };

  // Carregar veículos
  const loadVehicles = async () => {
    try {
      const { data, error } = await supabase
        .from('vehicles')
        .select('id, plate, model')
        .eq('status', 'Disponível');

      if (error) throw error;
      setVehicles(data || []);
    } catch (error) {
      console.error('Erro ao carregar veículos:', error);
      toast.error('Erro ao carregar veículos');
    }
  };

  // Carregar associações existentes
  const loadAssignments = async () => {
    try {
      const { data, error } = await supabase
        .from('driver_vehicles')
        .select('*')
        .eq('active', true);

      if (error) throw error;
      setAssignments(data || []);
    } catch (error) {
      console.error('Erro ao carregar associações:', error);
      toast.error('Erro ao carregar associações');
    }
  };

  // Carregar dados iniciais
  useEffect(() => {
    const loadData = async () => {
      setLoading(true);
      await Promise.all([loadDrivers(), loadVehicles(), loadAssignments()]);
      setLoading(false);
    };
    loadData();
  }, []);

  // Associar veículo ao motorista
  const handleAssignment = async () => {
    if (!selectedDriver || !selectedVehicle) {
      toast.error('Selecione um motorista e um veículo');
      return;
    }

    try {
      // Verificar se já existe uma associação (ativa ou inativa)
      const { data: existingAssignment, error: checkError } = await supabase
        .from('driver_vehicles')
        .select('*')
        .eq('driver_id', selectedDriver)
        .eq('vehicle_id', selectedVehicle)
        .maybeSingle();

      if (checkError) throw checkError;

      if (existingAssignment) {
        // Se já existe, verificar se está ativa
        if (existingAssignment.active) {
          toast.error('Esta associação já existe');
          return;
        }
        
        // Se existe mas está inativa, reativar
        const { error } = await supabase
          .from('driver_vehicles')
          .update({ 
            active: true, 
            assigned_at: new Date().toISOString(),
            removed_at: null
          })
          .eq('id', existingAssignment.id);

        if (error) throw error;
      } else {
        // Se não existe, criar nova associação
        const { error } = await supabase
          .from('driver_vehicles')
          .insert({
            driver_id: selectedDriver,
            vehicle_id: selectedVehicle,
            active: true,
            assigned_at: new Date().toISOString()
          });

        if (error) throw error;
      }

      toast.success('Veículo associado com sucesso!');
      await loadAssignments(); // Recarregar associações
      setSelectedDriver('');
      setSelectedVehicle('');
    } catch (error) {
      console.error('Erro ao associar veículo:', error);
      toast.error('Erro ao associar veículo ao motorista');
    }
  };

  // Remover associação
  const handleRemoveAssignment = async (assignmentId: string) => {
    try {
      const { error } = await supabase
        .from('driver_vehicles')
        .update({ 
          active: false,
          removed_at: new Date().toISOString()
        })
        .eq('id', assignmentId);

      if (error) throw error;

      toast.success('Associação removida com sucesso!');
      await loadAssignments(); // Recarregar associações
    } catch (error) {
      console.error('Erro ao remover associação:', error);
      toast.error('Erro ao remover associação');
    }
  };

  if (loading) {
    return (
      <Card>
        <CardContent className="p-4">
          <div className="flex justify-center items-center h-32">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="mb-6">
      <CardHeader className="p-4 lg:p-6">
        <div className="flex items-center">
          <Car className="h-6 w-6 text-primary-600 mr-3" />
          <h3 className="text-lg font-semibold text-secondary-900">
            Associação de Veículos a Motoristas
          </h3>
        </div>
      </CardHeader>

      <CardContent className="p-4 lg:p-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
          {/* Seleção de Motorista */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Motorista
            </label>
            <select
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              value={selectedDriver}
              onChange={(e) => setSelectedDriver(e.target.value)}
            >
              <option value="">Selecione um motorista</option>
              {drivers.map((driver) => (
                <option key={driver.id} value={driver.id}>
                  {driver.name}
                </option>
              ))}
            </select>
          </div>

          {/* Seleção de Veículo */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Veículo
            </label>
            <select
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              value={selectedVehicle}
              onChange={(e) => setSelectedVehicle(e.target.value)}
            >
              <option value="">Selecione um veículo</option>
              {vehicles.map((vehicle) => (
                <option key={vehicle.id} value={vehicle.id}>
                  {vehicle.plate} - {vehicle.model}
                </option>
              ))}
            </select>
          </div>
        </div>

        <Button
          onClick={handleAssignment}
          disabled={!selectedDriver || !selectedVehicle}
          className="w-full md:w-auto"
        >
          <UserCheck className="h-4 w-4 mr-2" />
          Associar Veículo ao Motorista
        </Button>

        {/* Lista de Associações */}
        <div className="mt-6">
          <h4 className="text-md font-medium text-gray-900 mb-3">
            Associações Ativas
          </h4>
          {assignments.length === 0 ? (
            <div className="text-center py-4 text-gray-500">
              <AlertCircle className="h-8 w-8 mx-auto mb-2" />
              Nenhuma associação encontrada
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Motorista
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Veículo
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Ações
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {assignments.map((assignment) => {
                    const driver = drivers.find(d => d.id === assignment.driver_id);
                    const vehicle = vehicles.find(v => v.id === assignment.vehicle_id);
                    
                    return (
                      <tr key={assignment.id}>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {driver?.name || 'Motorista não encontrado'}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {vehicle ? `${vehicle.plate} - ${vehicle.model}` : 'Veículo não encontrado'}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-right">
                          <Button
                            variant="error"
                            size="sm"
                            onClick={() => handleRemoveAssignment(assignment.id)}
                          >
                            <Trash2 className="h-4 w-4 mr-1" />
                            Remover
                          </Button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
} 