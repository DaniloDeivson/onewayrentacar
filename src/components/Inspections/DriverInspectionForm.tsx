import React, { useState } from 'react';
import { useDriverVehicles } from '../../hooks/useDriverVehicles';
import { useDriverInspections } from '../../hooks/useDriverInspections';
import { Button } from '../UI/Button';

interface DriverInspectionFormProps {
  onSuccess?: () => void;
}

export const DriverInspectionForm: React.FC<DriverInspectionFormProps> = ({
  onSuccess
}) => {
  const { vehicles, loading: loadingVehicles } = useDriverVehicles();
  const { createInspection, loading: submitting, error } = useDriverInspections();

  const [selectedVehicle, setSelectedVehicle] = useState('');
  const [mileage, setMileage] = useState('');
  const [items, setItems] = useState([
    { location: '', condition: 'ok', notes: '', images: [] }
  ]);
  const [notes, setNotes] = useState('');

  const handleAddItem = () => {
    setItems([...items, { location: '', condition: 'ok', notes: '', images: [] }]);
  };

  const handleItemChange = (index: number, field: keyof typeof items[0], value: string) => {
    const newItems = [...items];
    newItems[index] = { ...newItems[index], [field]: value };
    setItems(newItems);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedVehicle || !mileage) return;

    const result = await createInspection({
      vehicle_id: selectedVehicle,
      inspection_type: 'driver',
      items: items.filter(item => item.location.trim()),
      notes,
      mileage: Number(mileage)
    });

    if (result) {
      onSuccess?.();
      // Limpar formulário
      setSelectedVehicle('');
      setMileage('');
      setItems([{ location: '', condition: 'ok', notes: '', images: [] }]);
      setNotes('');
    }
  };

  if (loadingVehicles) {
    return <div>Carregando veículos...</div>;
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {error && (
        <div className="bg-red-50 text-red-600 p-3 rounded">
          {error}
        </div>
      )}

      <div>
        <label className="block text-sm font-medium text-gray-700">
          Veículo
        </label>
        <select
          value={selectedVehicle}
          onChange={(e) => setSelectedVehicle(e.target.value)}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          required
        >
          <option value="">Selecione um veículo</option>
          {vehicles.map((vehicle) => (
            <option key={vehicle.id} value={vehicle.id}>
              {vehicle.plate} - {vehicle.model}
            </option>
          ))}
        </select>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">
          Quilometragem
        </label>
        <input
          type="number"
          value={mileage}
          onChange={(e) => setMileage(e.target.value)}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          required
        />
      </div>

      <div className="space-y-4">
        <div className="flex justify-between items-center">
          <h3 className="text-lg font-medium">Itens da Inspeção</h3>
          <Button
            type="button"
            onClick={handleAddItem}
            variant="secondary"
            size="sm"
          >
            Adicionar Item
          </Button>
        </div>

        {items.map((item, index) => (
          <div key={index} className="border p-4 rounded space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700">
                Localização
              </label>
              <input
                type="text"
                value={item.location}
                onChange={(e) => handleItemChange(index, 'location', e.target.value)}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Condição
              </label>
              <select
                value={item.condition}
                onChange={(e) => handleItemChange(index, 'condition', e.target.value)}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              >
                <option value="ok">OK</option>
                <option value="damaged">Danificado</option>
                <option value="needs_attention">Requer Atenção</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Observações
              </label>
              <textarea
                value={item.notes}
                onChange={(e) => handleItemChange(index, 'notes', e.target.value)}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                rows={2}
              />
            </div>
          </div>
        ))}
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">
          Observações Gerais
        </label>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          rows={3}
        />
      </div>

      <div className="flex justify-end">
        <Button
          type="submit"
          variant="primary"
          disabled={submitting}
        >
          {submitting ? 'Salvando...' : 'Salvar Inspeção'}
        </Button>
      </div>
    </form>
  );
}; 