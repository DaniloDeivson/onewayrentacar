import React, { useState, useEffect } from 'react';
import { Button } from '../UI/Button';
import { Calendar, Loader2, Package, ShoppingCart, Gauge, AlertTriangle } from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';
import { PartCartItem, useServiceOrderParts, ServiceOrderPart } from '../../hooks/useServiceOrderParts';
import { supabase } from '../../lib/supabase';
import toast from 'react-hot-toast';


interface ServiceNoteFormProps {
  onSubmit: (data: any, partsCart?: PartCartItem[]) => Promise<void>;
  onCancel: () => void;
  serviceNote?: any;
  vehicles: any[];
  maintenanceTypes: any[];
  mechanics: any[];
  onOpenPartsCart: () => void;
  partsCount: number;
  partsCart?: PartCartItem[];
}

export const ServiceNoteForm: React.FC<ServiceNoteFormProps> = ({
  onSubmit,
  onCancel,
  serviceNote,
  vehicles,
  maintenanceTypes,
  mechanics,
  onOpenPartsCart,
  partsCount,
  partsCart = []
}) => {
  const { user, hasPermission, isAdmin } = useAuth();
  const [loading, setLoading] = useState(false);
  const [currentVehicleMileage, setCurrentVehicleMileage] = useState<number>(0);
  const [formData, setFormData] = useState({
    vehicle_id: serviceNote?.vehicle_id || '',
    maintenance_type: serviceNote?.maintenance_type || '',
    start_date: serviceNote?.start_date || new Date().toISOString().split('T')[0],
    end_date: serviceNote?.end_date || '',
    mechanic: serviceNote?.mechanic || '',
    employee_id: serviceNote?.employee_id || '',
    priority: serviceNote?.priority || 'Média',
    mileage: serviceNote?.mileage || 0,
    description: serviceNote?.description || '',
    observations: serviceNote?.observations || '',
    status: serviceNote?.status || 'Aberta'
  });
  
  // Hook para buscar peças já utilizadas (quando editando uma ordem existente)
  const { serviceOrderParts } = useServiceOrderParts(serviceNote?.id);

  // Função auxiliar para formatar valores monetários de forma segura
  const formatCurrency = (value: number | undefined | null): string => {
    const numValue = Number(value) || 0;
    return numValue.toLocaleString('pt-BR', { minimumFractionDigits: 2 });
  };

  // Função auxiliar para obter valor seguro de quantidade
  const getSafeQuantity = (part: any): number => {
    return Number((part as any).quantity_to_use || (part as any).quantity_used || 0);
  };

  // Função auxiliar para obter valor seguro de custo unitário
  const getSafeUnitCost = (part: any): number => {
    return Number((part as any).unit_cost || (part as any).unit_cost_at_time || 0);
  };

  // Função auxiliar para obter valor seguro de custo total
  const getSafeTotalCost = (part: any): number => {
    const totalCost = (part as any).total_cost;
    if (totalCost !== undefined && totalCost !== null) {
      return Number(totalCost);
    }
    const quantity = getSafeQuantity(part);
    const unitCost = getSafeUnitCost(part);
    return quantity * unitCost;
  };

  // Filter mechanics to only show employees with Mechanic role
  const mechanicEmployees = mechanics.filter(emp => emp.role === 'Mechanic' && emp.active);
  
  // Auto-fill employee_id with current user if they have maintenance permission
  useEffect(() => {
    if (!serviceNote && hasPermission('maintenance') && user && !formData.employee_id) {
      // Check if current user is a mechanic
      const isMechanic = mechanicEmployees.some(emp => emp.id === user.id);
      if (isMechanic || isAdmin) {
        setFormData(prev => ({ ...prev, employee_id: user.id }));
      }
    }
  }, [serviceNote, user, hasPermission, mechanicEmployees, formData.employee_id, isAdmin]);

  // Update mechanic name when employee_id changes
  useEffect(() => {
    if (formData.employee_id) {
      const selectedMechanic = mechanics.find(m => m.id === formData.employee_id);
      if (selectedMechanic) {
        setFormData(prev => ({ ...prev, mechanic: selectedMechanic.name }));
      }
    }
  }, [formData.employee_id, mechanics]);

  // Buscar quilometragem atual do veículo quando o veículo é selecionado
  useEffect(() => {
    const fetchVehicleMileage = async () => {
      if (formData.vehicle_id) {
        try {
          const { data, error } = await supabase
            .from('vehicles')
            .select('mileage, total_mileage')
            .eq('id', formData.vehicle_id)
            .single();

          if (!error && data) {
            // Usar total_mileage se disponível, senão usar mileage
            const mileage = data.total_mileage || data.mileage || 0;
            setCurrentVehicleMileage(mileage);
            
            // Se não há quilometragem definida na ordem, usar a atual do veículo
            if (!serviceNote && !formData.mileage) {
              setFormData(prev => ({ ...prev, mileage: mileage }));
            }
          }
        } catch (error) {
          console.error('Erro ao buscar quilometragem do veículo:', error);
        }
      } else {
        setCurrentVehicleMileage(0);
      }
    };

    fetchVehicleMileage();
  }, [formData.vehicle_id, serviceNote, formData.mileage]);

  // Monitorar mudanças no partsCart
  useEffect(() => {
    console.log('ServiceNoteForm - partsCart changed:', partsCart);
    console.log('ServiceNoteForm - partsCart length:', partsCart.length);
  }, [partsCart]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    console.log('ServiceNoteForm handleSubmit called');
    console.log('Form data:', formData);
    console.log('Parts cart:', partsCart);
    console.log('Service note:', serviceNote);
    
    // Client-side validation
    if (!formData.vehicle_id) {
      toast.error('Por favor, selecione um veículo antes de salvar a ordem de serviço.');
      return;
    }
    
    if (!formData.maintenance_type) {
      toast.error('Por favor, selecione um tipo de manutenção.');
      return;
    }
    
    if (!formData.description) {
      toast.error('Por favor, forneça uma descrição para a ordem de serviço.');
      return;
    }
    
    if (!formData.mechanic) {
      toast.error('Por favor, informe o nome do mecânico responsável.');
      return;
    }

    // Validação de quilometragem
    if (formData.mileage && currentVehicleMileage > 0) {
      const tolerance = Math.max(currentVehicleMileage * 0.1, 1000); // 10% ou mínimo 1000 km
      
      if (formData.mileage < (currentVehicleMileage - tolerance)) {
        toast.error(`A quilometragem não pode ser significativamente menor que ${currentVehicleMileage.toLocaleString('pt-BR')} km. Tolerância: ${tolerance.toLocaleString('pt-BR')} km.`);
        return;
      }
    }
    
    setLoading(true);
    try {
      const processedData = {
        ...formData,
        mileage: formData.mileage ? parseInt(formData.mileage.toString()) : null,
        end_date: formData.end_date === '' ? null : formData.end_date,
        observations: formData.observations === '' ? null : formData.observations
      };
      
      console.log('Processed data:', processedData);
      console.log('Parts cart to save:', partsCart);
      
      // Chama a função onSubmit passada como prop, que será tratada pelo componente pai
      await onSubmit(processedData, partsCart);
      
      console.log('Service note saved successfully');
    } catch (error) {
      console.error('Error saving service note:', error);
      toast.error('Erro ao salvar ordem de serviço. Verifique se todos os campos obrigatórios estão preenchidos.');
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: name === 'mileage' ? Number(value) || 0 : value
    }));
  };

  const handleMechanicChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const employeeId = e.target.value;
    const selectedMechanic = mechanics.find(m => m.id === employeeId);
    
    setFormData(prev => ({
      ...prev,
      employee_id: employeeId,
      mechanic: selectedMechanic ? selectedMechanic.name : ''
    }));
  };

  // Exibir peças do carrinho local se for nova ordem, ou do banco se for edição
  const displayedParts: (PartCartItem | ServiceOrderPart)[] =
    partsCart && partsCart.length > 0
      ? partsCart
      : (serviceOrderParts || []);
  
  console.log('ServiceNoteForm - displayedParts:', displayedParts);
  console.log('ServiceNoteForm - partsCart:', partsCart);
  console.log('ServiceNoteForm - serviceNote:', serviceNote);
  console.log('ServiceNoteForm - serviceOrderParts:', serviceOrderParts);
  console.log('ServiceNoteForm - displayedParts.length:', displayedParts.length);
  console.log('ServiceNoteForm - partsCount:', partsCount);

  return (
    <form onSubmit={handleSubmit} className="space-y-4 lg:space-y-6">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            Veículo *
          </label>
          <div className="mb-2 p-2 bg-info-50 border border-info-200 rounded text-xs text-info-700">
            <AlertTriangle className="h-3 w-3 inline mr-1" />
            Veículos com status "No Patio" ou "Disponível" podem receber ordens de serviço
          </div>
          <select
            name="vehicle_id"
            value={formData.vehicle_id}
            onChange={handleChange}
            className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
            required
          >
            <option value="">Selecione um veículo</option>
            {vehicles.map(vehicle => (
              <option key={vehicle.id} value={vehicle.id}>
                {vehicle.plate} - {vehicle.model}
              </option>
            ))}
          </select>
          {vehicles.length === 0 && (
            <p className="text-xs text-error-600 mt-1">
              Nenhum veículo disponível para seleção
            </p>
          )}
        </div>

        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            Tipo de Manutenção *
          </label>
          <select
            name="maintenance_type"
            value={formData.maintenance_type}
            onChange={handleChange}
            className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
            required
          >
            <option value="">Selecione o tipo</option>
            {[...new Map(maintenanceTypes.map(type => [type.name, type])).values()].map(type => (
              <option key={type.id} value={type.name}>
                {type.name}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            Data de Início *
          </label>
          <div className="relative">
            <Calendar className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
            <input
              type="date"
              name="start_date"
              value={formData.start_date}
              onChange={handleChange}
              className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              required
            />
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            Data de Conclusão
          </label>
          <div className="relative">
            <Calendar className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
            <input
              type="date"
              name="end_date"
              value={formData.end_date}
              onChange={handleChange}
              className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              min={formData.start_date}
            />
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            Mecânico Responsável *
          </label>
          <select
            value={formData.employee_id}
            onChange={handleMechanicChange}
            className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
            required
          >
            <option value="">Selecione um mecânico</option>
            {mechanicEmployees.map(mechanic => (
              <option key={mechanic.id} value={mechanic.id}>
                {mechanic.name} {mechanic.employee_code && `(${mechanic.employee_code})`}
              </option>
            ))}
          </select>
          {mechanicEmployees.length === 0 && (
            <p className="text-xs text-error-600 mt-1">
              Nenhum mecânico cadastrado. Adicione mecânicos no painel de funcionários.
            </p>
          )}
        </div>

        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            Prioridade *
          </label>
          <select
            name="priority"
            value={formData.priority}
            onChange={handleChange}
            className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
            required
          >
            <option value="Baixa">Baixa</option>
            <option value="Média">Média</option>
            <option value="Alta">Alta</option>
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            Quilometragem
          </label>
          <div className="relative">
            <Gauge className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-secondary-400" />
            <input
              type="number"
              name="mileage"
              value={formData.mileage}
              onChange={handleChange}
              className="w-full pl-10 pr-4 py-2 border border-secondary-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              min="0"
              placeholder="0"
            />
          </div>
          {currentVehicleMileage > 0 && (
            <p className="text-xs text-secondary-500 mt-1">
              Quilometragem atual do veículo: {currentVehicleMileage.toLocaleString('pt-BR')} km
            </p>
          )}
        </div>

        <div>
          <label className="block text-sm font-medium text-secondary-700 mb-2">
            Status *
          </label>
          <select
            name="status"
            value={formData.status}
            onChange={handleChange}
            className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
            required
          >
            <option value="Aberta">Aberta</option>
            <option value="Em Andamento">Em Andamento</option>
            <option value="Concluída">Concluída</option>
          </select>
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium text-secondary-700 mb-2">
          Descrição *
        </label>
        <textarea
          name="description"
          value={formData.description}
          onChange={handleChange}
          rows={3}
          className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
          placeholder="Descreva o serviço a ser realizado..."
          required
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-secondary-700 mb-2">
          Observações
        </label>
        <textarea
          name="observations"
          value={formData.observations}
          onChange={handleChange}
          rows={3}
          className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
          placeholder="Observações adicionais..."
        />
      </div>

      {/* Parts Section */}
      <div className="border-t pt-4 lg:pt-6">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-4">
          <h3 className="text-lg font-semibold text-secondary-900 flex items-center">
            <Package className="h-5 w-5 mr-2" />
            Peças Utilizadas ({serviceNote ? serviceOrderParts.length : partsCount})
          </h3>
          <Button
            type="button"
            variant="secondary"
            size="sm"
            onClick={onOpenPartsCart}
          >
            <ShoppingCart className="h-4 w-4 mr-2" />
            {serviceNote ? 'Adicionar Peças' : 'Adicionar Peças'}
          </Button>
        </div>

        {/* Peças já utilizadas (ordem existente ou carrinho local) */}
        {displayedParts.length > 0 && (
          <div className="mb-4">
            <h4 className="text-sm font-medium text-secondary-700 mb-2">Peças já utilizadas</h4>
            <div className="bg-info-50 border border-info-200 rounded-lg p-3 mb-3">
              <div className="flex items-start">
                <Package className="h-4 w-4 text-info-600 mr-2 mt-0.5" />
                <div>
                  <p className="text-xs font-medium text-info-800">
                    Integração com Estoque
                  </p>
                  <p className="text-xs text-info-700 mt-1">
                    As peças serão automaticamente deduzidas do estoque e um custo será gerado para cada peça utilizada.
                  </p>
                </div>
              </div>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full mt-2 border rounded">
                <thead>
                  <tr>
                    <th className="py-2 px-3 text-xs font-semibold text-secondary-700">SKU</th>
                    <th className="py-2 px-3 text-xs font-semibold text-secondary-700">Nome</th>
                    <th className="py-2 px-3 text-xs font-semibold text-secondary-700">Quantidade</th>
                    <th className="py-2 px-3 text-xs font-semibold text-secondary-700">Valor Unitário</th>
                    <th className="py-2 px-3 text-xs font-semibold text-secondary-700">Valor Total</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-secondary-200">
                  {displayedParts.map((part, idx) => (
                    <tr key={`${(part as any).part_id || (part as any).id || 'part'}-${idx}`} className="hover:bg-secondary-50">
                      <td className="py-2 px-3 text-xs font-medium text-secondary-900">
                        {(part as any).sku || (part as any).parts?.sku || 'N/A'}
                      </td>
                      <td className="py-2 px-3 text-xs text-secondary-700">
                        {(part as any).name || (part as any).parts?.name || 'Peça não encontrada'}
                      </td>
                      <td className="py-2 px-3 text-xs text-secondary-700">
                        {getSafeQuantity(part)}
                      </td>
                      <td className="py-2 px-3 text-xs text-secondary-700">
                        R$ {formatCurrency(getSafeUnitCost(part))}
                      </td>
                      <td className="py-2 px-3 text-xs font-medium text-secondary-900">
                        R$ {formatCurrency(getSafeTotalCost(part))}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}



        {/* Quando não há peças */}
        {((serviceNote && serviceOrderParts.length === 0) || (!serviceNote && partsCount === 0)) && (
          <div className="text-center py-6 text-secondary-500">
            <Package className="h-8 w-8 mx-auto mb-2" />
            <p>Nenhuma peça adicionada ainda</p>
            <p className="text-sm mt-1">Use o botão acima para adicionar peças à manutenção</p>
          </div>
        )}
      </div>

      <div className="flex flex-col sm:flex-row justify-end space-y-3 sm:space-y-0 sm:space-x-4 pt-4 lg:pt-6 border-t">
        <Button variant="secondary" onClick={onCancel} disabled={loading} className="w-full sm:w-auto">
          Cancelar
        </Button>
        <Button type="submit" disabled={loading} className="w-full sm:w-auto">
          {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
          {serviceNote ? 'Salvar Alterações' : 'Criar Ordem de Serviço'}
        </Button>
      </div>
    </form>
  );
};

export default ServiceNoteForm;