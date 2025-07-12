import React from 'react';
import { Car } from 'lucide-react';

interface VehicleInfoProps {
  vehicle: {
    plate: string;
    model: string;
    year?: number;
  } | null;
}

export const VehicleInfo: React.FC<VehicleInfoProps> = ({ vehicle }) => {
  if (!vehicle) return null;

  return (
    <div className="bg-primary-50 p-4 rounded-lg border border-primary-200">
      <div className="flex items-center space-x-3">
        <div className="h-10 w-10 bg-primary-100 rounded-lg flex items-center justify-center">
          <Car className="h-5 w-5 text-primary-600" />
        </div>
        <div>
          <h3 className="font-semibold text-primary-900">{vehicle.plate}</h3>
          <p className="text-sm text-primary-700">{vehicle.model} {vehicle.year && `(${vehicle.year})`}</p>
        </div>
      </div>
    </div>
  );
};