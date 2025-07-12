import React, { useState } from 'react';
import { Card, CardHeader, CardContent } from '../UI/Card';
import { Button } from '../UI/Button';
import { Car, Trash2, Eye, Calendar, Gauge, MapPin } from 'lucide-react';
import { Database } from '../../types/database';

type Vehicle = Database['public']['Tables']['vehicles']['Row'];
type DriverVehicle = Database['public']['Tables']['driver_vehicles']['Row'];

interface VehicleCardProps {
  vehicle: Vehicle;
  assignment: DriverVehicle;
  onRemove: (driverVehicleId: string) => void;
}

export const VehicleCard: React.FC<VehicleCardProps> = ({ 
  vehicle, 
  assignment, 
  onRemove 
}) => {
  const [showDetails, setShowDetails] = useState(false);

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Disponível':
        return 'bg-green-100 text-green-800';
      case 'Em Uso':
        return 'bg-blue-100 text-blue-800';
      case 'Manutenção':
        return 'bg-yellow-100 text-yellow-800';
      case 'Indisponível':
        return 'bg-red-100 text-red-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  return (
    <Card className="border border-gray-200 hover:shadow-md transition-shadow">
      <CardHeader className="pb-2">
        <div className="flex justify-between items-start">
          <div className="flex items-center gap-2">
            <Car className="h-5 w-5 text-primary-600" />
            <div>
              <h3 className="font-semibold text-lg">{vehicle.plate}</h3>
              <p className="text-sm text-gray-600">{vehicle.model} ({vehicle.year})</p>
            </div>
          </div>
          <div className="flex gap-1">
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setShowDetails(!showDetails)}
              className="text-gray-600 hover:text-gray-800"
            >
              <Eye className="h-4 w-4" />
            </Button>
            <Button
              variant="error"
              size="sm"
              onClick={() => onRemove(assignment.id)}
              className="text-red-600 hover:text-red-700"
            >
              <Trash2 className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </CardHeader>
      
      <CardContent className="pt-0">
        <div className="space-y-3">
          {/* Informações básicas sempre visíveis */}
          <div className="grid grid-cols-2 gap-2 text-sm">
            <div className="flex items-center gap-1">
              <span className="text-gray-600">Tipo:</span>
              <span className="font-medium">{vehicle.type}</span>
            </div>
            <div className="flex items-center gap-1">
              <span className="text-gray-600">Status:</span>
              <span className={`px-2 py-1 rounded text-xs font-medium ${getStatusColor(vehicle.status)}`}>
                {vehicle.status}
              </span>
            </div>
          </div>

          {/* Data de atribuição */}
          <div className="flex items-center gap-1 text-sm text-gray-600">
            <Calendar className="h-4 w-4" />
            <span>Atribuído em: {new Date(assignment.assigned_at).toLocaleDateString('pt-BR')}</span>
          </div>

          {/* Detalhes expandidos */}
          {showDetails && (
            <div className="border-t pt-3 space-y-2">
              <h4 className="font-medium text-sm text-gray-700">Detalhes do Veículo</h4>
              
              <div className="grid grid-cols-1 gap-2 text-sm">
                {vehicle.color && (
                  <div className="flex justify-between">
                    <span className="text-gray-600">Cor:</span>
                    <span>{vehicle.color}</span>
                  </div>
                )}
                
                {vehicle.chassis && (
                  <div className="flex justify-between">
                    <span className="text-gray-600">Chassi:</span>
                    <span className="font-mono text-xs">{vehicle.chassis}</span>
                  </div>
                )}
                
                {vehicle.fuel && (
                  <div className="flex justify-between">
                    <span className="text-gray-600">Combustível:</span>
                    <span>{vehicle.fuel}</span>
                  </div>
                )}
                
                {vehicle.mileage && (
                  <div className="flex items-center gap-1">
                    <Gauge className="h-4 w-4 text-gray-600" />
                    <span className="text-gray-600">Quilometragem atual:</span>
                    <span className="font-medium">{vehicle.mileage.toLocaleString('pt-BR')} km</span>
                  </div>
                )}
                
                {vehicle.location && (
                  <div className="flex items-center gap-1">
                    <MapPin className="h-4 w-4 text-gray-600" />
                    <span className="text-gray-600">Localização:</span>
                    <span>{vehicle.location}</span>
                  </div>
                )}
              </div>


            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}; 