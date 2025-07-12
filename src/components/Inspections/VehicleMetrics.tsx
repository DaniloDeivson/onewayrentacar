import React from 'react';
import { Gauge, Fuel, AlertTriangle } from 'lucide-react';
import toast from 'react-hot-toast';

interface VehicleMetricsProps {
  mileage: string | number;
  fuelLevel: string | number;
  dashboardWarningLight?: boolean;
  onChange: (e: React.ChangeEvent<HTMLInputElement>) => void;
  onCheckboxChange?: (name: string, checked: boolean) => void;
  currentVehicleMileage?: number; // Quilometragem atual do veículo
  originalMileage?: number; // Quilometragem original da inspeção (para edição)
}

export const VehicleMetrics: React.FC<VehicleMetricsProps> = ({
  mileage,
  fuelLevel,
  dashboardWarningLight = false,
  onChange,
  onCheckboxChange,
  currentVehicleMileage,
  originalMileage
}) => {
  const handleCheckboxChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (onCheckboxChange) {
      onCheckboxChange('dashboard_warning_light', e.target.checked);
    }
  };

  const handleMileageChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newMileage = parseInt(e.target.value) || 0;
    
    // Calcular tolerância (10% da quilometragem atual, mínimo 1000 km)
    const tolerance = Math.max((currentVehicleMileage || 0) * 0.1, 1000);
    
    // Se estamos editando uma inspeção existente, validar que o novo valor não seja significativamente menor
    if (originalMileage !== undefined && newMileage < (originalMileage - tolerance)) {
      toast.error(`A quilometragem não pode ser diminuída significativamente. Valor original: ${originalMileage.toLocaleString('pt-BR')} km, Tolerância: ${tolerance.toLocaleString('pt-BR')} km. A quilometragem só pode ser corrigida dentro de uma margem razoável.`);
      return;
    }
    
    // Se não estamos editando, validar que não seja significativamente menor que a quilometragem atual do veículo
    if (currentVehicleMileage && newMileage < (currentVehicleMileage - tolerance)) {
      toast.error(`A quilometragem não pode ser significativamente menor que ${currentVehicleMileage.toLocaleString('pt-BR')} km. Tolerância: ${tolerance.toLocaleString('pt-BR')} km. A quilometragem só pode ser corrigida dentro de uma margem razoável.`);
      return;
    }
    
    // Se passou nas validações, permitir a mudança
    onChange(e);
  };

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            <Gauge className="h-4 w-4 inline mr-1" />
            Quilometragem Atual
          </label>
          <input
            type="number"
            name="mileage"
            value={mileage}
            onChange={handleMileageChange}
            className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
            placeholder={currentVehicleMileage ? `Km atual: ${currentVehicleMileage.toLocaleString('pt-BR')}` : "Digite a quilometragem atual"}
            min={originalMileage || currentVehicleMileage || 0}
          />
          {currentVehicleMileage && (
            <p className="text-xs text-secondary-500 mt-1">
              Quilometragem atual do veículo: {currentVehicleMileage.toLocaleString('pt-BR')} km
            </p>
          )}
          {originalMileage && (
            <p className="text-xs text-warning-600 mt-1">
              ⚠️ Editando inspeção - Valor original: {originalMileage.toLocaleString('pt-BR')} km (correções permitidas dentro de margem razoável)
            </p>
          )}
        </div>

        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            <Fuel className="h-4 w-4 inline mr-1" />
            Nível de Combustível (%)
          </label>
          <input
            type="number"
            name="fuel_level"
            value={fuelLevel}
            onChange={onChange}
            min="0"
            max="100"
            className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
            placeholder="0-100%"
          />
        </div>
      </div>

      <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
        <div className="flex items-center space-x-3">
          <div className="flex-shrink-0">
            <AlertTriangle className="h-5 w-5 text-yellow-600" />
          </div>
          <div className="flex-1">
            <label className="flex items-center space-x-2 cursor-pointer">
              <input
                type="checkbox"
                checked={dashboardWarningLight}
                onChange={handleCheckboxChange}
                className="w-4 h-4 text-yellow-600 border-yellow-300 rounded focus:ring-yellow-500 focus:ring-2"
              />
              <span className="text-sm font-medium text-yellow-800">
                Luz no painel acesa?
              </span>
            </label>
            <p className="text-xs text-yellow-700 mt-1">
              Marque se houver luz de aviso no painel (injeção, combustível baixo, motor, etc.)
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};