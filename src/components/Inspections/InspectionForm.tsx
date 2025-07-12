import React, { useState, useEffect } from 'react';
import { Button } from '../UI/Button';
import { Loader2, Camera, Upload, X } from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';
import { useContracts } from '../../hooks/useContracts';
import { useInspections, getInspectors } from '../../hooks/useInspections';
import { useVehicleMileage } from '../../hooks/useVehicleMileage';
import toast from 'react-hot-toast';
import { getEmployeeNameById } from '../../utils/getEmployeeName';
import { Contract, Employee } from '../../types';
import { supabase } from '../../lib/supabase';

// Import sub-components
import { VehicleInfo } from './VehicleInfo';
import { InspectionTypeSelector } from './InspectionTypeSelector';
import { ContractSelector } from './ContractSelector';
import { VehicleMetrics } from './VehicleMetrics';
import { DamageCartSummary } from './DamageCartSummary';

interface InspectionFormProps {
  onSubmit: (data: InspectionFormData) => Promise<void>;
  onCancel: () => void;
  inspection?: Partial<InspectionFormData>;
  selectedVehicle?: { id: string; total_mileage?: number; mileage?: number };
  employees: Employee[];
  onOpenDamageCart: () => void;
  damageCount: number;
  damageCart?: DamageItem[];
  locationOptions?: string[];
  onUpdateDamageCart?: (damages: DamageItem[]) => void;
  onRemoveDamage?: (damageId: string) => void;
}

// Definir tipo local para DamageItem se não existir no types
interface DamageItem {
  id: string;
  location: string;
  description: string;
  damage_type: string;
  severity: string;
  photo_url?: string;
  requires_repair: boolean;
}

// Definir tipo local para InspectionFormData
export interface InspectionFormData {
  vehicle_id: string;
  inspection_type: string;
  employee_id: string;
  inspected_by: string;
  notes: string | null;
  signature_url: string | null;
  mileage: number | null;
  fuel_level: number | null;
  contract_id: string | null;
  customer_id?: string | null;
  location: string | null;
  dashboard_warning_light: boolean;
  dashboard_photo_url: string;
  inspected_at?: string;
  created_by_employee_id?: string;
  created_by_name?: string;
}

export const InspectionForm: React.FC<InspectionFormProps> = ({
  onSubmit,
  onCancel,
  inspection,
  selectedVehicle,
  employees,
  onOpenDamageCart,
  damageCount,
  damageCart = [],
  locationOptions,
  onUpdateDamageCart,
  onRemoveDamage
}) => {
  const { user, hasPermission } = useAuth();
  const { contracts } = useContracts();
  const { uploadPhoto } = useInspections();
  const { updateVehicleMileage } = useVehicleMileage();
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    vehicle_id: inspection?.vehicle_id || selectedVehicle?.id || '',
    inspection_type: inspection?.inspection_type || 'CheckIn',
    employee_id: inspection?.employee_id || '',
    inspected_by: inspection?.inspected_by || '',
    notes: inspection?.notes || '',
    signature_url: inspection?.signature_url || '',
    mileage: inspection?.mileage || (selectedVehicle?.total_mileage || selectedVehicle?.mileage || ''),
    fuel_level: inspection?.fuel_level ? Math.round(inspection.fuel_level * 100) : '',
    contract_id: inspection?.contract_id || '',
    location: inspection?.location || '',
    dashboard_warning_light: inspection?.dashboard_warning_light || false,
    dashboard_photo_url: inspection?.dashboard_photo_url || ''
  });
  const [uploadingDashboardPhoto, setUploadingDashboardPhoto] = useState(false);
  const [activeContract, setActiveContract] = useState<Contract | null>(null);
  const [availableContracts, setAvailableContracts] = useState<Contract[]>([]);
  const [selectedDashboardPhoto, setSelectedDashboardPhoto] = useState<File | null>(null);
  const [inspectors, setInspectors] = useState<Employee[]>([]);

  // Filter employees to only show PatioInspector role
  const patioInspectors = employees.filter(emp => emp.role === 'PatioInspector' && emp.active);
  
  // Auto-fill inspector_id with current user if they have inspections permission
  useEffect(() => {
    if (!inspection && hasPermission('inspections') && user && !formData.employee_id) {
      // Check if current user is a patio inspector
      const isInspector = patioInspectors.some(emp => emp.id === user.id);
      if (isInspector) {
        setFormData(prev => ({ ...prev, employee_id: user.id }));
      }
    }
  }, [inspection, user, hasPermission, patioInspectors, formData.employee_id]);

  // Update inspected_by when employee_id changes
  useEffect(() => {
    if (formData.employee_id) {
      const selectedInspector = employees.find(e => e.id === formData.employee_id);
      if (selectedInspector) {
        setFormData(prev => ({ ...prev, inspected_by: selectedInspector.name }));
      }
    }
  }, [formData.employee_id, employees]);

  // Fetch contracts when component mounts or vehicle changes
  useEffect(() => {
    if (formData.vehicle_id) {
      // Find active contracts for this vehicle
      const vehicleContracts = contracts.filter(contract => 
        contract.vehicle_id === formData.vehicle_id && 
        contract.status === 'Ativo'
      );
      
      setAvailableContracts(vehicleContracts);
      
      // Auto-set active contract if found
      if (vehicleContracts.length > 0) {
        const currentContract = vehicleContracts[0];
        setActiveContract(currentContract);
        
        // Auto-set contract_id if not already set
        if (!formData.contract_id) {
          setFormData(prev => ({ ...prev, contract_id: currentContract.id }));
        }
      } else {
        setActiveContract(null);
        setFormData(prev => ({ ...prev, contract_id: null }));
      }
    }
  }, [formData.vehicle_id, contracts]);

  useEffect(() => {
    getInspectors().then(setInspectors).catch(() => setInspectors([]));
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // Client-side validation
    if (!formData.vehicle_id) {
      toast.error('Por favor, selecione um veículo antes de salvar a inspeção.');
      return;
    }
    
    if (!formData.employee_id) {
      toast.error('Por favor, selecione um responsável pela inspeção.');
      return;
    }
    
    if (!formData.inspected_by) {
      toast.error('Por favor, informe o nome do inspetor responsável.');
      return;
    }
    
    setLoading(true);
    try {
      // Convert fuel_level to a number between 0 and 1
      const processedData: InspectionFormData = {
        ...formData,
        mileage: formData.mileage ? parseInt(formData.mileage.toString()) : null,
        fuel_level: formData.fuel_level ? parseFloat(formData.fuel_level.toString()) / 100 : null,
        notes: !formData.notes ? null : formData.notes,
        signature_url: !formData.signature_url ? null : formData.signature_url,
        contract_id: !formData.contract_id ? null : formData.contract_id,
        location: !formData.location ? null : formData.location
      };

      if (!inspection) {
        processedData.inspected_at = new Date().toISOString();
      }

      const validFields: (keyof InspectionFormData)[] = [
        'vehicle_id', 'inspection_type', 'employee_id', 'inspected_by', 
        'notes', 'signature_url', 'mileage', 'fuel_level', 'contract_id', 
        'location', 'dashboard_warning_light', 'dashboard_photo_url', 'inspected_at'
      ];
      const sanitizedData: Partial<InspectionFormData> = {};
      for (const field of validFields) {
        if (processedData[field] !== undefined) {
          sanitizedData[field] = processedData[field];
        }
      }

      // Buscar nome do usuário logado para created_by_name
      const currentUserName = user?.name || 'Usuário do Sistema';
      
      // Buscar customer_id baseado no usuário logado
      let customerId = null;
      try {
        // Obter email do usuário logado via auth
        const { data: { user: authUser } } = await supabase.auth.getUser();
        if (authUser?.email) {
          const { data: customerData } = await supabase
            .from('customers')
            .select('id')
            .eq('email', authUser.email)
            .eq('tenant_id', '00000000-0000-0000-0000-000000000001')
            .eq('active', true)
            .single();
          
          if (customerData) {
            customerId = customerData.id;
          }
        }
      } catch (error) {
        console.log('Usuário logado não é um cliente ou erro ao buscar:', error);
      }
      
      await onSubmit({
        ...sanitizedData,
        created_by_employee_id: user?.id || formData.employee_id,
        created_by_name: currentUserName,
        customer_id: customerId,
      });
      
      // Atualizar a quilometragem do veículo se houver quilometragem na inspeção
      if (sanitizedData.mileage && sanitizedData.vehicle_id) {
        try {
          await updateVehicleMileage(sanitizedData.vehicle_id, sanitizedData.mileage);
        } catch (mileageError) {
          console.error('Erro ao atualizar quilometragem do veículo:', mileageError);
          // Não falhar o envio do formulário se a atualização da quilometragem falhar
        }
      }
      
      onCancel();
    } catch (error) {
      console.error('Error saving inspection:', error);
      toast.error('Erro ao salvar inspeção. Verifique se todos os campos obrigatórios estão preenchidos.');
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleEmployeeChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const employeeId = e.target.value;
    const selectedEmployee = employees.find(emp => emp.id === employeeId);
    setFormData(prev => ({
      ...prev,
      employee_id: employeeId,
      inspected_by: selectedEmployee ? selectedEmployee.name : '',
      created_by_name: selectedEmployee ? selectedEmployee.name : ''
    }));
  };

  const handleCheckboxChange = (name: string, checked: boolean) => {
    setFormData(prev => ({ ...prev, [name]: checked }));
  };

  const handleDashboardPhotoFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0] || null;
    console.log('handleDashboardPhotoFileChange chamado:', {
      file: file ? {
        name: file.name,
        type: file.type,
        size: file.size,
        lastModified: file.lastModified
      } : null,
      filesLength: e.target.files?.length
    });
    setSelectedDashboardPhoto(file);
  };

  const handleDashboardPhotoUploadClick = async () => {
    console.log('handleDashboardPhotoUploadClick chamado:', {
      selectedDashboardPhoto: selectedDashboardPhoto ? {
        name: selectedDashboardPhoto.name,
        type: selectedDashboardPhoto.type,
        size: selectedDashboardPhoto.size
      } : null
    });
    
    if (!selectedDashboardPhoto) return;
    setUploadingDashboardPhoto(true);
    try {
      const photoUrl = await uploadPhoto(selectedDashboardPhoto);
      setFormData(prev => ({ ...prev, dashboard_photo_url: photoUrl }));
      setSelectedDashboardPhoto(null);
      toast.success('Foto do painel enviada com sucesso!');
    } catch (error) {
      console.error('Error uploading dashboard photo:', error);
      toast.error('Erro ao enviar foto do painel');
    } finally {
      setUploadingDashboardPhoto(false);
    }
  };

  const removeDashboardPhoto = () => {
    setFormData(prev => ({ ...prev, dashboard_photo_url: '' }));
    toast.success('Foto do painel removida');
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4 lg:space-y-6">
      {/* Vehicle Info */}
      <VehicleInfo vehicle={selectedVehicle} />

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Inspection Type */}
        <InspectionTypeSelector 
          value={formData.inspection_type} 
          onChange={handleChange} 
        />

        {/* Inspector */}
        <select
          id="employee_id"
          name="employee_id"
          required
          value={formData.employee_id || ''}
          onChange={handleEmployeeChange}
          className="w-full px-3 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
        >
          <option value="">Selecione um responsável</option>
          {inspectors.map((insp) => (
            <option key={insp.id} value={insp.id}>{insp.name}</option>
          ))}
        </select>
      </div>

      {/* Contract Selector */}
      <ContractSelector 
        availableContracts={availableContracts}
        activeContract={activeContract}
      />

      {activeContract ? (
        <span>Contrato: {activeContract.contract_number}</span>
      ) : (
        <span className="text-warning-600 font-semibold">Sem Contrato</span>
      )}

      {/* Vehicle Metrics */}
      <VehicleMetrics 
        mileage={formData.mileage}
        fuelLevel={formData.fuel_level}
        dashboardWarningLight={formData.dashboard_warning_light}
        onChange={handleChange}
        onCheckboxChange={handleCheckboxChange}
        currentVehicleMileage={selectedVehicle?.total_mileage || selectedVehicle?.mileage}
        originalMileage={inspection?.mileage}
      />

      {/* Dashboard Photo Upload - Show when dashboard warning light is checked */}
      {formData.dashboard_warning_light && (
        <div className="bg-orange-50 border border-orange-200 rounded-lg p-4">
          <h4 className="font-semibold text-orange-900 mb-3 flex items-center">
            <Camera className="h-5 w-5 mr-2" />
            Foto do Painel (Luz de Aviso)
          </h4>
          <p className="text-sm text-orange-800 mb-4">
            Como há luz de aviso no painel, é recomendado tirar uma foto para documentar o problema.
          </p>
          <div className="flex flex-col items-center space-y-2 sm:flex-row sm:items-start sm:space-x-4 sm:space-y-0">
            {formData.dashboard_photo_url ? (
              <div className="relative mb-2 sm:mb-0">
                <img 
                  src={formData.dashboard_photo_url} 
                  alt="Foto do painel" 
                  className="w-32 h-24 object-cover rounded border"
                />
                <button
                  type="button"
                  onClick={removeDashboardPhoto}
                  className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center text-sm hover:bg-red-600"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
            ) : (
              <div className="w-32 h-24 border-2 border-dashed border-orange-300 rounded flex items-center justify-center mb-2 sm:mb-0">
                <Camera className="h-8 w-8 text-orange-400" />
              </div>
            )}
            <div className="flex flex-col items-center">
              <input
                type="file"
                accept="image/*"
                onChange={handleDashboardPhotoFileChange}
                className="mb-2"
                disabled={uploadingDashboardPhoto}
              />
              <Button
                type="button"
                variant="secondary"
                disabled={uploadingDashboardPhoto || !selectedDashboardPhoto}
                className="flex items-center"
                onClick={handleDashboardPhotoUploadClick}
              >
                {uploadingDashboardPhoto ? (
                  <>
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                    Enviando...
                  </>
                ) : (
                  <>
                    <Upload className="h-4 w-4 mr-2" />
                    {formData.dashboard_photo_url ? 'Alterar Foto' : 'Enviar Foto'}
                  </>
                )}
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* Notes */}
      <div>
        <label className="block text-sm font-medium text-secondary-700 mb-2">
          Observações Gerais
        </label>
        <textarea
          name="notes"
          value={formData.notes}
          onChange={handleChange}
          rows={3}
          className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
          placeholder="Observações gerais sobre a inspeção..."
        />
      </div>

      {/* Location field */}
      <div>
        <label className="block text-sm font-medium text-secondary-700 mb-2">Localização</label>
        <input
          name="location"
          value={formData.location}
          onChange={handleChange}
          list="location-suggestions"
          className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
          placeholder="Ex: Pátio A, Oficina, Externo..."
          autoComplete="off"
        />
        <datalist id="location-suggestions">
          {locationOptions?.map(option => (
            <option key={option} value={option} />
          ))}
        </datalist>
      </div>

      {/* Damage Cart Section */}
      <DamageCartSummary 
        damageCount={damageCount}
        inspectionType={formData.inspection_type}
        contractId={formData.contract_id}
        onOpenDamageCart={onOpenDamageCart}
        damageCart={damageCart}
        onUpdateCart={onUpdateDamageCart}
        onRemoveDamage={onRemoveDamage}
      />

      <div className="flex flex-col sm:flex-row justify-end space-y-3 sm:space-y-0 sm:space-x-4 pt-4 lg:pt-6 border-t">
        <Button variant="secondary" onClick={onCancel} disabled={loading} className="w-full sm:w-auto">
          Cancelar
        </Button>
        <Button type="submit" disabled={loading || !formData.employee_id} className="w-full sm:w-auto">
          {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
          {inspection ? 'Salvar Alterações' : 'Criar Inspeção'}
        </Button>
      </div>
    </form>
  );
};

export default InspectionForm;