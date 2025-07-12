import React from 'react';

interface InspectorSelectorProps {
  employeeId: string;
  inspectedBy: string;
  patioInspectors: any[];
  onChange: (e: React.ChangeEvent<HTMLSelectElement>) => void;
}

export const InspectorSelector: React.FC<InspectorSelectorProps> = ({
  employeeId,
  inspectedBy,
  patioInspectors,
  onChange
}) => {
  return (
    <div>
      <label className="block text-sm font-medium text-secondary-700 mb-2">
        Responsável pela Inspeção *
      </label>
      <select
        name="employee_id"
        value={employeeId}
        onChange={onChange}
        className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
        required
      >
        <option value="">Selecione um responsável</option>
        {patioInspectors.map(inspector => (
          <option key={inspector.id} value={inspector.id}>
            {inspector.name} {inspector.employee_code && `(${inspector.employee_code})`}
          </option>
        ))}
      </select>
      <input
        type="hidden"
        name="inspected_by"
        value={inspectedBy}
      />
      {patioInspectors.length === 0 && (
        <p className="text-xs text-error-600 mt-1">
          Nenhum inspetor cadastrado. Adicione inspetores no painel de funcionários.
        </p>
      )}
    </div>
  );
};