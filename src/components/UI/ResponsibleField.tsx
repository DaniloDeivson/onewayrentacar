import React from 'react';
import { useAuth } from '../../hooks/useAuth';
import { User } from 'lucide-react';
import { Employee } from '../../types';

interface ResponsibleFieldProps {
  value?: string;
  onChange?: (value: string) => void;
  required?: boolean;
  label?: string;
  className?: string;
  employeeOptions?: Employee[];
  autoFill?: boolean;
}

export const ResponsibleField: React.FC<ResponsibleFieldProps> = ({
  value,
  onChange,
  required = false,
  label = "Responsável",
  className = "",
  employeeOptions = [],
  autoFill = true
}) => {
  const { user } = useAuth();
  
  // Auto-fill with current user if enabled and no value is set
  React.useEffect(() => {
    if (autoFill && !value && user && onChange) {
      onChange(user.id);
    }
  }, [autoFill, value, user, onChange]);

  // Find the current user in the options
  const currentUserOption = employeeOptions.find(emp => emp.id === user?.id);
  const selectedEmployee = employeeOptions.find(emp => emp.id === value);
  
  return (
    <div className={className}>
      <label className="block text-sm font-medium text-secondary-700 mb-2">
        {label} {required && '*'}
      </label>
      <div className="relative">
        {autoFill && currentUserOption ? (
          <div className="w-full px-3 py-2 border border-secondary-300 bg-secondary-50 rounded-lg text-secondary-700 flex items-center">
            <User className="h-4 w-4 text-secondary-400 mr-2" />
            <span>{currentUserOption.name} (Você)</span>
          </div>
        ) : (
          <select
            value={value || ''}
            onChange={(e) => onChange && onChange(e.target.value)}
            className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
            required={required}
          >
            <option value="">Selecione um responsável</option>
            {employeeOptions.map(employee => (
              <option 
                key={employee.id} 
                value={employee.id}
                disabled={autoFill && employee.id !== user?.id}
              >
                {employee.name} {employee.id === user?.id ? '(Você)' : ''}
              </option>
            ))}
          </select>
        )}
        {/* Campo hidden para enviar o nome do responsável */}
        <input type="hidden" name="created_by_name" value={selectedEmployee ? selectedEmployee.name : ''} />
      </div>
      {autoFill && (
        <p className="text-xs text-secondary-500 mt-1">
          Campo preenchido automaticamente com seu usuário
        </p>
      )}
    </div>
  );
};

export default ResponsibleField;