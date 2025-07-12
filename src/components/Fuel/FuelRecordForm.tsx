import React, { useState, useEffect } from 'react';
import { Button } from '../UI/Button';
import { X, MapPin, Gauge, DollarSign, FileText, Camera, Upload } from 'lucide-react';
import { useFuelRecords, FuelRecordInsert, FuelRecord } from '../../hooks/useFuelRecords';
import { useVehicles } from '../../hooks/useVehicles';
import { useAuth } from '../../hooks/useAuth';
import toast from 'react-hot-toast';
import { useEmployees } from '../../hooks/useEmployees';

interface FuelRecordFormProps {
  isOpen: boolean;
  onClose: () => void;
  editingRecord?: FuelRecord;
  guestId?: string;
  vehicleId?: string;
  contractId?: string;
}

export const FuelRecordForm: React.FC<FuelRecordFormProps> = ({
  isOpen,
  onClose,
  editingRecord,
  guestId,
  vehicleId,
  contractId
}) => {
  const { createFuelRecord, updateFuelRecord } = useFuelRecords();
  const { vehicles } = useVehicles();
  const { user } = useAuth();
  const { employees } = useEmployees();
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState<FuelRecordInsert>({
    vehicle_id: editingRecord?.vehicle_id || vehicleId || '',
    contract_id: editingRecord?.contract_id || contractId || null,
    guest_id: editingRecord?.guest_id || guestId || null,
    driver_name: editingRecord?.driver_name || '',
    fuel_amount: editingRecord?.fuel_amount || 0,
    unit_price: editingRecord?.unit_price || 0,
    total_cost: editingRecord?.total_cost || 0,
    mileage: editingRecord?.mileage || null,
    fuel_station: editingRecord?.fuel_station || '',
    receipt_number: editingRecord?.receipt_number || '',
    notes: editingRecord?.notes || ''
  });

  // Calcular custo total automaticamente
  useEffect(() => {
    if (formData.fuel_amount && formData.unit_price) {
      const totalCost = formData.fuel_amount * formData.unit_price;
      setFormData(prev => ({ ...prev, total_cost: totalCost }));
    }
  }, [formData.fuel_amount, formData.unit_price]);

  // Auto-preencher nome do motorista se for um funcionário
  useEffect(() => {
    if (user && !formData.driver_name) {
      setFormData(prev => ({ ...prev, driver_name: user.name || '' }));
    }
  }, [user, formData.driver_name]);

  const motoristas = employees.filter(emp => emp.role === 'Driver' && emp.active);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      // Validar campos obrigatórios
      if (!formData.vehicle_id) {
        toast.error('Selecione um veículo');
        return;
      }
      if (!formData.driver_name) {
        toast.error('Nome do motorista é obrigatório');
        return;
      }
      if (!formData.fuel_amount || formData.fuel_amount <= 0) {
        toast.error('Quantidade de combustível deve ser maior que zero');
        return;
      }
      if (!formData.unit_price || formData.unit_price <= 0) {
        toast.error('Preço por litro deve ser maior que zero');
        return;
      }

      if (editingRecord) {
        await updateFuelRecord(editingRecord.id, formData);
        toast.success('Registro de abastecimento atualizado com sucesso!');
      } else {
        const result = await createFuelRecord(formData);
        console.log('Fuel record created:', result);
        // O custo será criado automaticamente pelo trigger do banco
        toast.success('Registro de abastecimento criado com sucesso! O custo será gerado automaticamente.');
      }
      onClose();
    } catch (error) {
      console.error('Erro ao salvar registro de abastecimento:', error);
      // O erro já é tratado no hook
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = (field: keyof FuelRecordInsert, value: string | number | null) => {
    setFormData(prev => ({
      ...prev,
      [field]: value
    }));
  };

  const handleFileUpload = async (field: string, file: File) => {
    // Implementar upload de arquivo para Supabase Storage
    // Por enquanto, apenas simular o upload
    console.log(`Uploading ${field}:`, file);
    // const url = await uploadToSupabase(file);
    // handleInputChange(field, url);
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-3xl mx-4 max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center p-6 border-b">
          <h2 className="text-xl font-semibold text-gray-800">
            {editingRecord ? 'Editar Abastecimento' : 'Registrar Abastecimento'}
          </h2>
          <Button
            variant="secondary"
            size="sm"
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
          >
            <X size={20} />
          </Button>
        </div>

        <form onSubmit={handleSubmit} className="p-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <MapPin className="inline w-4 h-4 mr-1" />
                Veículo
              </label>
              <select
                value={formData.vehicle_id}
                onChange={(e) => handleInputChange('vehicle_id', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                required
                disabled={!!vehicleId}
              >
                <option value="">Selecione um veículo</option>
                {vehicles.map(vehicle => (
                  <option key={vehicle.id} value={vehicle.id}>
                    {vehicle.plate} - {vehicle.model}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Motorista
              </label>
              <select
                value={formData.driver_name}
                onChange={(e) => handleInputChange('driver_name', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                required
              >
                <option value="">Selecione o motorista</option>
                {motoristas.map(motorista => (
                  <option key={motorista.id} value={motorista.name}>{motorista.name}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <Gauge className="inline w-4 h-4 mr-1" />
                Quantidade de Combustível (Litros)
              </label>
              <input
                type="number"
                step="0.001"
                min="0"
                value={formData.fuel_amount}
                onChange={(e) => handleInputChange('fuel_amount', parseFloat(e.target.value))}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <DollarSign className="inline w-4 h-4 mr-1" />
                Preço por Litro (R$)
              </label>
              <input
                type="number"
                step="0.001"
                min="0"
                value={formData.unit_price}
                onChange={(e) => handleInputChange('unit_price', parseFloat(e.target.value))}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <DollarSign className="inline w-4 h-4 mr-1" />
                Valor Total (R$)
              </label>
              <input
                type="number"
                step="0.01"
                min="0"
                value={formData.total_cost}
                onChange={(e) => handleInputChange('total_cost', parseFloat(e.target.value))}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-gray-50"
                readOnly
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Quilometragem (Km)
              </label>
              <input
                type="number"
                min="0"
                value={formData.mileage || ''}
                onChange={(e) => handleInputChange('mileage', e.target.value ? parseInt(e.target.value) : null)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="Quilometragem atual"
              />
              {/* Exibir o KM atual do veículo selecionado */}
              {formData.vehicle_id && vehicles.length > 0 && (
                <div className="text-xs text-gray-500 mt-1">
                  Última registrada: {(() => {
                    const v = vehicles.find(v => v.id === formData.vehicle_id);
                    return v ? `${v.mileage?.toLocaleString('pt-BR')} km` : '0 km';
                  })()}
                </div>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Posto de Combustível
              </label>
              <input
                type="text"
                value={formData.fuel_station || ''}
                onChange={(e) => handleInputChange('fuel_station', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="Nome do posto"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <FileText className="inline w-4 h-4 mr-1" />
                Número da Nota Fiscal
              </label>
              <input
                type="text"
                value={formData.receipt_number || ''}
                onChange={(e) => handleInputChange('receipt_number', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="Número da nota fiscal"
              />
            </div>

            <div className="md:col-span-2">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Observações
              </label>
              <textarea
                value={formData.notes || ''}
                onChange={(e) => handleInputChange('notes', e.target.value)}
                rows={3}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="Observações sobre o abastecimento"
              />
            </div>
          </div>

          {/* Upload de Fotos */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <Camera className="inline w-4 h-4 mr-1" />
                Foto da Nota Fiscal
              </label>
              <div className="border-2 border-dashed border-gray-300 rounded-lg p-4 text-center">
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      handleFileUpload('receipt_photo_url', file);
                    }
                  }}
                  className="hidden"
                  id="receipt-photo"
                />
                <label htmlFor="receipt-photo" className="cursor-pointer">
                  <Upload className="w-8 h-8 mx-auto text-gray-400 mb-2" />
                  <p className="text-sm text-gray-500">
                    Clique para adicionar foto da nota fiscal
                  </p>
                </label>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <Camera className="inline w-4 h-4 mr-1" />
                Foto do Painel
              </label>
              <div className="border-2 border-dashed border-gray-300 rounded-lg p-4 text-center">
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      handleFileUpload('dashboard_photo_url', file);
                    }
                  }}
                  className="hidden"
                  id="dashboard-photo"
                />
                <label htmlFor="dashboard-photo" className="cursor-pointer">
                  <Upload className="w-8 h-8 mx-auto text-gray-400 mb-2" />
                  <p className="text-sm text-gray-500">
                    Clique para adicionar foto do painel
                  </p>
                </label>
              </div>
            </div>
          </div>

          {/* Informação sobre criação automática de custos */}
          {!editingRecord && (
            <div className="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
              <p className="text-sm text-blue-800">
                <strong>Nota:</strong> Ao salvar este registro, um custo será criado automaticamente 
                e associado ao cliente se houver um contrato ativo para o veículo.
              </p>
            </div>
          )}

          <div className="flex justify-end space-x-3 pt-6 border-t">
            <Button
              type="button"
              variant="secondary"
              onClick={onClose}
              disabled={loading}
            >
              Cancelar
            </Button>
            <Button
              type="submit"
              disabled={loading}
              className="bg-blue-600 hover:bg-blue-700"
            >
              {loading ? 'Salvando...' : editingRecord ? 'Atualizar' : 'Registrar'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}; 