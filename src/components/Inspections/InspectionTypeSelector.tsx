import React from 'react';

interface InspectionTypeSelectorProps {
  value: string;
  onChange: (e: React.ChangeEvent<HTMLSelectElement>) => void;
}

export const InspectionTypeSelector: React.FC<InspectionTypeSelectorProps> = ({
  value,
  onChange
}) => {
  return (
    <div>
      <label className="block text-sm font-medium text-secondary-700 mb-2">
        Tipo de Inspeção *
      </label>
      <select
        name="inspection_type"
        value={value}
        onChange={onChange}
        className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
        required
      >
        <option value="CheckIn">Check-In (Entrada/Retorno)</option>
        <option value="CheckOut">Check-Out (Saída/Locação)</option>
      </select>
    </div>
  );
};