import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../hooks/useAuth';
import { useEmployees } from '../hooks/useEmployees';
import { useApproveFuelRecord } from '../hooks/useApproveFuelRecord';
import { useVehicles } from '../hooks/useVehicles';
import { useAllFuelRecords } from '../hooks/usePendingFuelRecords';

import { Card, CardHeader, CardContent } from '../components/UI/Card';
import { Button } from '../components/UI/Button';
import { Badge } from '../components/UI/Badge';
import { Loader2, Car, Trash2, Wrench, Fuel, LogIn } from 'lucide-react';
import toast from 'react-hot-toast';
import VehicleAssignmentSection from '../components/Driver/VehicleAssignmentSection';

interface FuelRecord {
  id: string;
  tenant_id: string;
  vehicle_id: string;
  contract_id: string | null;
  guest_id: string | null;
  driver_employee_id: string | null;
  driver_name: string;
  fuel_amount: number;
  unit_price: number;
  total_cost: number;
  mileage: number | null;
  fuel_station: string | null;
  receipt_number: string | null;
  receipt_photo_url: string | null;
  dashboard_photo_url: string | null;
  notes: string | null;
  recorded_at: string;
  status: 'Pendente' | 'Aprovado' | 'Rejeitado' | 'pending' | 'approved' | 'rejected';
  approved_by_employee_id: string | null;
  approved_at: string | null;
  cost_id: string | null;
  created_at: string;
  updated_at: string;
  vehicles?: {
    plate: string;
    model: string;
    year: number;
    status: string;
    mileage: number | null;
  };
}

interface AvailableVehicle {
  id: string;
  plate: string;
  model: string;
  year: number;
  type: string;
  status: string;
}

interface Vehicle {
  id: string;
  tenant_id: string;
  plate: string;
  model: string;
  year: number;
  type: 'Furgão' | 'Van';
  color: string | null;
  fuel: 'Diesel' | 'Gasolina' | 'Elétrico' | null;
  category: string;
  chassis: string | null;
  renavam: string | null;
  cargo_capacity: number | null;
  location: string | null;
  acquisition_date: string | null;
  acquisition_value: number | null;
  mileage: number | null;
  initial_mileage: number | null;
  tank_capacity: number | null;
  status: 'Disponível' | 'Em Uso' | 'Manutenção' | 'Inativo';
  maintenance_status: 'Available' | 'In_Maintenance' | 'Reserved' | 'Rented';
  created_at: string;
  updated_at: string;
}

interface DriverVehicle {
  id: string;
  driver_id: string;
  vehicle_id: string;
  assigned_at: string;
  active: boolean;
}

interface MultiFormData {
  value?: string;
  date?: string;
  mileage?: string;
  receipt?: File;
  notes?: string;
}

export const DriverRecords: React.FC = () => {
  const { user, isAdmin } = useAuth();

  // Funções auxiliares para status
  const isPendingStatus = (status: string) => status === 'Pendente' || status === 'pending';
  const isApprovedStatus = (status: string) => status === 'Aprovado' || status === 'approved';

  const getStatusDisplay = (status: string) => {
    if (status === 'pending') return 'Pendente';
    if (status === 'approved') return 'Aprovado';
    if (status === 'rejected') return 'Rejeitado';
    return status;
  };
  const { employees } = useEmployees();
  const [driverVehicles, setDriverVehicles] = useState<Vehicle[]>([]);
  const [driverVehicleAssignments, setDriverVehicleAssignments] = useState<DriverVehicle[]>([]);
  const [vehiclesLoading, setVehiclesLoading] = useState(true);
  
  const [records, setRecords] = useState<FuelRecord[]>([]);
  const [availableVehicles, setAvailableVehicles] = useState<AvailableVehicle[]>([]);
  const [showVehicleModal, setShowVehicleModal] = useState(false);
  const [showFuelModal, setShowFuelModal] = useState(false);
  const [modalAction, setModalAction] = useState<'fuel' | 'checkin' | 'checkout'>('fuel');
  const [selectedVehicleIds, setSelectedVehicleIds] = useState<string[]>([]);
  const [multiForm, setMultiForm] = useState<Record<string, MultiFormData>>({});
  const [submitting, setSubmitting] = useState(false);

  // Novo estado para admin selecionar motorista e veículos
  const [selectedDriverId, setSelectedDriverId] = useState<string>('');
  const [adminSelectedVehicleIds, setAdminSelectedVehicleIds] = useState<string[]>([]);

  const [lastMileage, setLastMileage] = useState<Record<string, number>>({});

  const { records: allFuelRecords, loading: loadingPending, refetch: refetchFuelRecords } = useAllFuelRecords();
  const { approve, reject, loading: loadingApprove } = useApproveFuelRecord();
  const { vehicles } = useVehicles();

  const [adminSearch, setAdminSearch] = useState('');
  const [adminStatusFilter, setAdminStatusFilter] = useState('');

  const [vehicleSearch, setVehicleSearch] = useState('');
  const [assigning, setAssigning] = useState<string | null>(null);
  const [selectedDriverToAssign, setSelectedDriverToAssign] = useState<string>('');

  const fetchRecords = async () => {
    console.log('Fetching records for user:', user?.id);
    
    // Buscar registros onde o usuário é o motorista (driver_employee_id ou driver_id)
    const { data, error } = await supabase
      .from('fuel_records')
      .select(`
        *,
        vehicles (
          plate,
          model,
          year,
          status,
          mileage
        )
      `)
      .or(`driver_employee_id.eq.${user?.id},driver_id.eq.${user?.id}`)
      .order('recorded_at', { ascending: false });
      
    if (error) {
      console.error('Error fetching records:', error);
    } else {
      console.log('Records fetched:', data?.length || 0);
      setRecords(data || []);
    }
  };

  const fetchDriverVehicles = async () => {
    if (!user?.id) return;

    try {
      setVehiclesLoading(true);
      
      // Buscar veículos atribuídos ao motorista
      const { data: driverVehiclesData, error: driverError } = await supabase
        .from('driver_vehicles')
        .select('*')
        .eq('driver_id', user.id)
        .eq('active', true);

      if (driverError) throw driverError;

      // Buscar detalhes dos veículos existentes
      const vehicleIds = (driverVehiclesData || []).map(dv => dv.vehicle_id);
      let vehiclesData: Vehicle[] = [];
      if (vehicleIds.length > 0) {
        const { data: vehiclesFetched, error: vehiclesError } = await supabase
          .from('vehicles')
          .select('*')
          .in('id', vehicleIds);
        if (vehiclesError) throw vehiclesError;
        vehiclesData = vehiclesFetched || [];
      }

      // Filtrar associações órfãs (sem veículo correspondente)
      const validAssignments = (driverVehiclesData || []).filter(dv => vehiclesData.some(v => v.id === dv.vehicle_id));
      setDriverVehicleAssignments(validAssignments);
      setDriverVehicles(vehiclesData);

      // Remover associações órfãs do banco
      const orphanAssignments = (driverVehiclesData || []).filter(dv => !vehiclesData.some(v => v.id === dv.vehicle_id));
      for (const orphan of orphanAssignments) {
        await supabase.from('driver_vehicles').delete().eq('id', orphan.id);
      }
    } catch (err) {
      console.error('Erro ao buscar veículos do motorista:', err);
      toast.error('Erro ao buscar veículos');
    } finally {
      setVehiclesLoading(false);
    }
  };

  const fetchAvailableVehicles = async () => {
    try {
      const { data, error } = await supabase
        .from('vehicles')
        .select('id, plate, model, year, type, status')
        .eq('status', 'Disponível')
        .order('plate');

      if (error) throw error;
      
      // Filtrar veículos que já estão atribuídos ao motorista
      const assignedVehicleIds = driverVehicleAssignments.map(dv => dv.vehicle_id);
      const available = data?.filter(v => !assignedVehicleIds.includes(v.id)) || [];
      setAvailableVehicles(available);
    } catch (error) {
      console.error('Erro ao buscar veículos disponíveis:', error);
      toast.error('Erro ao buscar veículos disponíveis');
    }
  };

  useEffect(() => {
    if (user?.id) {
      fetchRecords();
      fetchDriverVehicles();
      fetchAvailableVehicles();
    }
    // eslint-disable-next-line
  }, [user?.id]);

  // Função para lidar com campos de cada veículo
  const handleMultiFormChange = (vehicleId: string, field: keyof MultiFormData, value: string | File | undefined) => {
    setMultiForm(prev => ({
      ...prev,
      [vehicleId]: {
        ...prev[vehicleId],
        [field]: value,
      },
    }));
  };

  // Função para buscar a última quilometragem de cada veículo selecionado
  const fetchLastMileage = async (vehicleIds: string[]) => {
    if (!vehicleIds.length) return;
    const mileageMap: Record<string, number> = {};
    for (const vehicleId of vehicleIds) {
      // Busca o último registro de abastecimento para o veículo
      const { data, error } = await supabase
        .from('fuel_records')
        .select('mileage')
        .eq('vehicle_id', vehicleId)
        .order('recorded_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (!error && data && typeof data.mileage === 'number') {
        mileageMap[vehicleId] = data.mileage;
      } else {
        // Se não houver registro, pega a km inicial do veículo (só Vehicle tem mileage)
        const v = driverVehicles.find(v => v.id === vehicleId);
        if (v && typeof v.mileage === 'number') {
          mileageMap[vehicleId] = v.mileage;
        } else {
          mileageMap[vehicleId] = 0;
        }
      }
    }
    setLastMileage(mileageMap);
  };

  // Buscar última km sempre que abrir o modal ou mudar seleção de veículos
  useEffect(() => {
    if (showFuelModal) {
      const ids = isAdmin ? adminSelectedVehicleIds : selectedVehicleIds;
      fetchLastMileage(ids);
    }
    // eslint-disable-next-line
  }, [showFuelModal, selectedVehicleIds, adminSelectedVehicleIds]);

  const handleMultiSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if ((isAdmin && adminSelectedVehicleIds.length === 0) || (!isAdmin && selectedVehicleIds.length === 0)) {
      toast.error('Selecione pelo menos um veículo!');
      return;
    }
    if (!user?.id) {
      toast.error('Usuário não autenticado!');
      return;
    }
    if (isAdmin && !selectedDriverId) {
      toast.error('Selecione o motorista!');
      return;
    }
    setSubmitting(true);
    try {
      const vehicleIds = isAdmin ? adminSelectedVehicleIds : selectedVehicleIds;
      const driverIdToUse = isAdmin ? selectedDriverId : user.id;
      for (const vehicleId of vehicleIds) {
        const data = multiForm[vehicleId];
        if (!data) continue;
        // Validação de quilometragem
        const last = lastMileage[vehicleId] || 0;
        if (Number(data.mileage) < last) {
          toast.error(`A quilometragem informada (${data.mileage}) não pode ser menor que a última registrada (${last}).`);
          continue;
        }
        // Para admin, não precisa checar atribuição do veículo
        if (!isAdmin) {
          const isAllowed = driverVehicles.some(v => v.id === vehicleId);
          if (!isAllowed) {
            toast.error(`Você não tem permissão para abastecer o veículo ${vehicleId}`);
            continue;
          }
        }
        if (modalAction === 'fuel') {
          // Upload do comprovante (obrigatório)
          let receiptUrl = '';
          if (!data.receipt) {
            toast.error('Comprovante de abastecimento é obrigatório.');
            return;
          }
          
          try {
            const fileExt = data.receipt.name.split('.').pop();
            const fileName = `${driverIdToUse}_${vehicleId}_${Date.now()}.${fileExt}`;
            
            // Verificar se o bucket existe e se temos permissão
            const { error: bucketError } = await supabase.storage
              .from('photos')
              .list('', { limit: 1 });
            
            if (bucketError) {
              console.error('Erro ao acessar bucket photos:', bucketError);
              toast.error('Erro: Não foi possível acessar o sistema de upload. Tente novamente.');
              return;
            }
            
            const { data: uploadData, error: uploadError } = await supabase.storage
              .from('photos')
              .upload(`fuel-receipts/${fileName}`, data.receipt);
            if (uploadError) {
              console.error('Erro no upload do comprovante:', uploadError);
              toast.error('Erro: Não foi possível fazer upload do comprovante. Tente novamente.');
              return;
            }
            receiptUrl = uploadData?.path ? supabase.storage.from('photos').getPublicUrl(uploadData.path).data.publicUrl : '';
          } catch (uploadError) {
            console.error('Erro inesperado no upload:', uploadError);
            toast.error('Erro inesperado no upload do comprovante. Tente novamente.');
            return;
          }
          // Salvar registro de abastecimento com nova estrutura
          const { error: insertError } = await supabase.from('fuel_records').insert([{
            driver_employee_id: driverIdToUse,
            vehicle_id: vehicleId,
            value: Number(data.value),
            total_cost: Number(data.value),
            fuel_amount: 0, // Será atualizado quando tivermos mais detalhes
            unit_price: 0, // Será atualizado quando tivermos mais detalhes
            driver_name: user.name,
            recorded_at: data.date,
            date: data.date,
            mileage: Number(data.mileage),
            receipt_photo_url: receiptUrl,
            fuel_station: 'Posto não informado',
            status: 'Pendente',
            tenant_id: user.tenant_id || '00000000-0000-0000-0000-000000000001',
            notes: `Registro de abastecimento via app. Quilometragem: ${data.mileage}. Comprovante: ${receiptUrl}`,
          }]);
          if (insertError) throw insertError;
        } else {
          // Check-in ou Check-out
          await supabase.from('inspections').insert([{
            vehicle_id: vehicleId,
            inspection_type: modalAction === 'checkin' ? 'CheckIn' : 'CheckOut',
            inspected_by: user.name,
            inspected_at: data.date,
            mileage: Number(data.mileage),
            notes: data.notes || '',
            tenant_id: user.tenant_id || '00000000-0000-0000-0000-000000000001',
          }]);
        }
      }
      if (modalAction === 'fuel') {
        toast.success('Abastecimento(s) salvo(s) com sucesso!');
        fetchRecords();
      } else if (modalAction === 'checkin') {
        toast.success('Check-in(s) salvo(s) com sucesso!');
      } else {
        toast.success('Check-out(s) salvo(s) com sucesso!');
      }
      setShowFuelModal(false);
      setSelectedVehicleIds([]);
      setAdminSelectedVehicleIds([]);
      setSelectedDriverId('');
    } catch (error) {
      console.error('Erro ao salvar registros:', error);
      toast.error('Erro ao salvar registros!');
    } finally {
      setSubmitting(false);
    }
  };

  const addDriverVehicle = async (vehicleId: string, driverIdOverride?: string) => {
    const driverId = driverIdOverride || user?.id;
    if (!driverId) return;

    try {
      // 1. Verificar se já existe (mesmo inativo)
      const { data: existing, error: fetchError } = await supabase
        .from('driver_vehicles')
        .select('*')
        .eq('driver_id', driverId)
        .eq('vehicle_id', vehicleId)
        .maybeSingle();

      if (fetchError) throw fetchError;

      if (existing) {
        if (!existing.active) {
          // Já existe, mas está inativo: reativar
          const { data, error } = await supabase
            .from('driver_vehicles')
            .update({ active: true, removed_at: null, assigned_at: new Date().toISOString() })
            .eq('id', existing.id)
            .select()
            .single();
          if (error) throw error;
          setDriverVehicleAssignments(prev => [...prev, data]);
          await fetchDriverVehicles();
          return data;
        } else {
          // Já existe e está ativo
          throw new Error('Este veículo já está atribuído a este motorista.');
        }
      } else {
        // Não existe: inserir normalmente
        const { data, error } = await supabase
          .from('driver_vehicles')
          .insert({
            driver_id: driverId,
            vehicle_id: vehicleId,
            active: true,
            assigned_at: new Date().toISOString()
          })
          .select()
          .single();
        if (error) throw error;
        setDriverVehicleAssignments(prev => [...prev, data]);
        await fetchDriverVehicles();
        return data;
      }
    } catch (err) {
      console.error('Erro ao adicionar veículo ao motorista:', err);
      throw err;
    }
  };

  const removeDriverVehicle = async (driverVehicleId: string) => {
    try {
      const { error } = await supabase
        .from('driver_vehicles')
        .update({ active: false, removed_at: new Date().toISOString() })
        .eq('id', driverVehicleId);

      if (error) throw error;

      // Atualizar a lista local
      setDriverVehicleAssignments(prev => 
        prev.filter(dv => dv.id !== driverVehicleId)
      );

      // Recarregar veículos
      await fetchDriverVehicles();

      return true;
    } catch (err) {
      console.error('Erro ao remover veículo do motorista:', err);
      throw err;
    }
  };

  const handleRemoveVehicle = async (driverVehicleId: string) => {
    if (window.confirm('Tem certeza que deseja remover este veículo?')) {
      try {
        await removeDriverVehicle(driverVehicleId);
        toast.success('Veículo removido com sucesso!');
        await fetchAvailableVehicles();
      } catch (error) {
        console.error('Erro ao remover veículo:', error);
        toast.error('Erro ao remover veículo');
      }
    }
  };

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Meus Registros e Frota</h1>
      
      {/* Seção de Veículos Atribuídos - Estilo Fleet */}
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div>
            <h2 className="text-2xl lg:text-3xl font-bold text-secondary-900">Minha Frota</h2>
            <p className="text-secondary-600 mt-1 lg:mt-2">
              Gerencie seus veículos atribuídos e registre check-ins/check-outs
            </p>
          </div>
          <div className="flex gap-2">
            <Button
              onClick={() => {
                setModalAction('fuel');
                setShowFuelModal(true);
              }}
              size="sm"
              className="w-full sm:w-auto bg-success-600 hover:bg-success-700 flex items-center"
            >
              <Fuel className="h-4 w-4 mr-2" />
              Adicionar Combustível
            </Button>
            <Button
              onClick={() => {
                setModalAction('checkin');
                setShowFuelModal(true);
              }}
              size="sm"
              className="w-full sm:w-auto bg-warning-600 hover:bg-warning-700 flex items-center"
            >
              <LogIn className="h-4 w-4 mr-2" />
              Check-in / Check-out
            </Button>
            {isAdmin && (
              <Button
                onClick={() => setShowVehicleModal(true)}
                size="sm"
                className="w-full sm:w-auto bg-primary-600 hover:bg-primary-700"
              >
                Adicionar Veículo
              </Button>
            )}
          </div>
        </div>

        {/* Statistics Cards for Driver */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Meus Veículos</p>
                  <p className="text-xl lg:text-2xl font-bold text-secondary-900">
                    {driverVehicles.filter(v => v.status !== 'Inativo').length}
                  </p>
                </div>
                <div className="h-8 w-8 lg:h-12 lg:w-12 bg-primary-100 rounded-lg flex items-center justify-center">
                  <Car className="h-4 w-4 lg:h-6 lg:w-6 text-primary-600" />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Disponíveis</p>
                  <p className="text-xl lg:text-2xl font-bold text-success-600">
                    {driverVehicles.filter(v => v.status === 'Disponível').length}
                  </p>
                </div>
                <div className="h-8 w-8 lg:h-12 lg:w-12 bg-success-100 rounded-lg flex items-center justify-center">
                  <Car className="h-4 w-4 lg:h-6 lg:w-6 text-success-600" />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Em Uso</p>
                  <p className="text-xl lg:text-2xl font-bold text-info-600">
                    {driverVehicles.filter(v => v.status === 'Em Uso').length}
                  </p>
                </div>
                <div className="h-8 w-8 lg:h-12 lg:w-12 bg-info-100 rounded-lg flex items-center justify-center">
                  <Car className="h-4 w-4 lg:h-6 lg:w-6 text-info-600" />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-secondary-600 text-xs lg:text-sm font-medium">Manutenção</p>
                  <p className="text-xl lg:text-2xl font-bold text-warning-600">
                    {driverVehicles.filter(v => v.status === 'Manutenção').length}
                  </p>
                </div>
                <div className="h-8 w-8 lg:h-12 lg:w-12 bg-warning-100 rounded-lg flex items-center justify-center">
                  <Wrench className="h-4 w-4 lg:h-6 lg:w-6 text-warning-600" />
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Vehicle Assignment Section - Only for Admin */}
        {isAdmin && <VehicleAssignmentSection />}

        {/* Vehicles Grid */}
        {vehiclesLoading ? (
          <div className="flex items-center justify-center h-64">
            <Loader2 className="h-8 w-8 animate-spin text-primary-600" />
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {driverVehicles.filter(v => v.status !== 'Inativo').map(vehicle => {
              const assignment = driverVehicleAssignments.find(dv => dv.vehicle_id === vehicle.id);
              if (!assignment) return null;
              
              return (
                <Card key={vehicle.id} className="relative group border border-secondary-200 rounded-xl shadow-sm hover:shadow-md transition-all bg-white flex flex-col justify-between min-h-[220px]">
                  <CardHeader className="pb-2 flex flex-row items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="h-10 w-10 bg-primary-100 rounded-lg flex items-center justify-center">
                          <Car className="h-5 w-5 text-primary-600" />
                        </div>
                        <div>
                        <h3 className="font-bold text-lg text-secondary-900 leading-tight">{vehicle.plate}</h3>
                        <p className="text-xs text-secondary-600">{vehicle.model} ({vehicle.year})</p>
                        </div>
                      <Badge className="ml-2" variant={vehicle.status === 'Disponível' ? 'success' : vehicle.status === 'Em Uso' ? 'info' : vehicle.status === 'Manutenção' ? 'warning' : 'secondary'}>{vehicle.status}</Badge>
                      </div>
                        {isAdmin && (
                          <Button
                            variant="error"
                        size="sm"
                        className="opacity-0 group-hover:opacity-100 transition-opacity absolute top-2 right-2 z-10"
                            onClick={() => handleRemoveVehicle(assignment.id)}
                        aria-label="Remover veículo"
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        )}
                  </CardHeader>
                  <CardContent className="flex-1 flex flex-col justify-between">
                    <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-xs text-secondary-700 mb-4">
                      <span className="font-medium">Tipo:</span><span className="font-bold">{vehicle.type}</span>
                      <span className="font-medium">Combustível:</span><span className="font-bold">{vehicle.fuel}</span>
                      <span className="font-medium">Quilometragem:</span><span className="font-bold">{vehicle.mileage?.toLocaleString('pt-BR')} km</span>
                      {vehicle.location && (<><span className="font-medium">Localização:</span><span className="font-bold">{vehicle.location}</span></>)}
                      <span className="font-medium">Categoria:</span><span className="font-bold">{vehicle.category === 'Driver Registered' ? 'Registrado pelo Motorista' : vehicle.category}</span>
                      <span className="font-medium">Atribuído em:</span><span className="font-bold">{new Date(assignment.assigned_at).toLocaleDateString('pt-BR')}</span>
                      </div>
                    <div className="grid grid-cols-2 gap-2 mt-auto">
                      <Button
                        size="sm"
                        variant="success"
                        className="w-full"
                        onClick={async () => {
                          if (!user) { toast.error('Usuário não autenticado!'); return; }
                          await supabase.from('inspections').insert([{
                            vehicle_id: vehicle.id,
                            inspection_type: 'CheckIn',
                            inspected_by: user.name,
                            inspected_at: new Date().toISOString(),
                            mileage: vehicle.mileage || 0,
                            notes: '',
                            tenant_id: user.tenant_id || '00000000-0000-0000-0000-000000000001',
                          }]);
                          setDriverVehicles(prev => prev.map(v => v.id === vehicle.id ? { ...v, status: 'Disponível' } : v));
                          toast.success('Check-in realizado!');
                        }}
                      >Check-in</Button>
                      <Button
                        size="sm"
                        variant="warning"
                        className="w-full"
                        onClick={async () => {
                          if (!user) { toast.error('Usuário não autenticado!'); return; }
                          await supabase.from('inspections').insert([{
                            vehicle_id: vehicle.id,
                            inspection_type: 'CheckOut',
                            inspected_by: user.name,
                            inspected_at: new Date().toISOString(),
                            mileage: vehicle.mileage || 0,
                            notes: '',
                            tenant_id: user.tenant_id || '00000000-0000-0000-0000-000000000001',
                          }]);
                          setDriverVehicles(prev => prev.map(v => v.id === vehicle.id ? { ...v, status: 'Em Uso' } : v));
                          toast.success('Check-out realizado!');
                        }}
                      >Check-out</Button>
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        )}

        {/* Empty State */}
        {!vehiclesLoading && driverVehicles.filter(v => v.status !== 'Inativo').length === 0 && (
          <Card>
            <CardContent className="p-8 text-center">
              <Car className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-secondary-900 mb-2">Nenhum veículo atribuído</h3>
              <p className="text-secondary-600 mb-4">
                {isAdmin 
                  ? 'Você ainda não possui veículos atribuídos. Clique em "Adicionar Veículo" para atribuir veículos aos motoristas.'
                  : 'Você ainda não possui veículos atribuídos. Entre em contato com o administrador para solicitar a atribuição de veículos.'
                }
              </p>
            </CardContent>
          </Card>
        )}
      </div>

      {/* Modal para Adicionar Veículo */}
      {showVehicleModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-3xl mx-4">
            <h3 className="text-lg font-semibold mb-4">Catálogo de Veículos e Atribuições</h3>
            <div className="flex gap-2 mb-3">
              <input
                type="text"
                placeholder="Buscar por placa ou modelo..."
                value={vehicleSearch}
                onChange={e => setVehicleSearch(e.target.value)}
                className="border border-secondary-300 rounded-lg px-3 py-2 flex-1"
              />
            </div>
            <div className="overflow-x-auto">
              <table className="min-w-full border text-sm">
                <thead>
                  <tr className="bg-secondary-100">
                    <th className="px-3 py-2 text-left">Placa</th>
                    <th className="px-3 py-2 text-left">Modelo</th>
                    <th className="px-3 py-2 text-left">Status</th>
                    <th className="px-3 py-2 text-left">Motoristas Atribuídos</th>
                    <th className="px-3 py-2 text-left">Ações</th>
                  </tr>
                </thead>
                <tbody>
                  {vehicles.filter(vehicle =>
                    !vehicleSearch ||
                    vehicle.plate.toLowerCase().includes(vehicleSearch.toLowerCase()) ||
                    vehicle.model.toLowerCase().includes(vehicleSearch.toLowerCase())
                  ).map(vehicle => {
                    const atribuicoes = driverVehicleAssignments.filter(dv => dv.vehicle_id === vehicle.id && dv.active);
                    return (
                      <tr key={vehicle.id} className="border-b hover:bg-primary-50">
                        <td className="px-3 py-2 font-semibold">{vehicle.plate}</td>
                        <td className="px-3 py-2">{vehicle.model} ({vehicle.year})</td>
                        <td className="px-3 py-2">{vehicle.status}</td>
                        <td className="px-3 py-2">
                          {atribuicoes.length > 0 ? (
                            <ul className="list-disc ml-4">
                              {atribuicoes.map(attr => {
                                const motorista = employees.find(e => e.id === attr.driver_id);
                                return (
                                  <li key={attr.id} className="mb-1 flex items-center gap-2">
                                    <span className="font-medium">{motorista ? motorista.name : 'Motorista desconhecido'}</span>
                                    <span className="text-xs text-secondary-500 ml-2">(desde {new Date(attr.assigned_at).toLocaleDateString()})</span>
                                    <Button size="sm" variant="error" onClick={async () => { await removeDriverVehicle(attr.id); }}>Desatribuir</Button>
                                  </li>
                                );
                              })}
                            </ul>
                          ) : (
                            <span className="text-warning-700 font-semibold">Sem motorista atribuído</span>
                          )}
                        </td>
                        <td className="px-3 py-2">
                          <div className="flex gap-2 items-center">
                            <select
                              value={assigning === vehicle.id ? selectedDriverToAssign : ''}
                              onChange={e => {
                                setAssigning(vehicle.id);
                                setSelectedDriverToAssign(e.target.value);
                              }}
                              className="border border-secondary-300 rounded px-2 py-1"
                            >
                              <option value="">Atribuir motorista...</option>
                              {employees.filter(emp => emp.active && emp.role === 'Driver').map(emp => (
                                <option key={emp.id} value={emp.id}>{emp.name}</option>
                              ))}
                            </select>
                            <Button
                              size="sm"
                              variant="success"
                              disabled={!selectedDriverToAssign || assigning !== vehicle.id}
                              onClick={async () => {
                                setAssigning(vehicle.id);
                                await addDriverVehicle(vehicle.id, selectedDriverToAssign);
                                setSelectedDriverToAssign('');
                                setAssigning(null);
                                await fetchAvailableVehicles();
                                await fetchDriverVehicles();
                              }}
                            >Atribuir</Button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            <div className="flex justify-end gap-2 mt-4">
              <Button variant="secondary" onClick={() => setShowVehicleModal(false)}>Fechar</Button>
            </div>
          </div>
        </div>
      )}

      {/* Modal para Adicionar Abastecimento */}
      {showFuelModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-2xl mx-4 shadow-lg">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold flex items-center">
                {modalAction === 'fuel' && <Fuel className="h-5 w-5 mr-2 text-success-600" />}
                {modalAction === 'checkin' && <Wrench className="h-5 w-5 mr-2 text-info-600" />}
                {modalAction === 'checkout' && <Wrench className="h-5 w-5 mr-2 text-warning-600" />}
                {modalAction === 'fuel' ? 'Adicionar Abastecimento' : modalAction === 'checkin' ? 'Check-In' : 'Check-Out'}
              </h3>
              <div className="flex gap-2">
                <Button size="sm" variant={modalAction === 'fuel' ? 'primary' : 'secondary'} onClick={() => setModalAction('fuel')}>Abastecimento</Button>
                <Button size="sm" variant={modalAction === 'checkin' ? 'primary' : 'secondary'} onClick={() => setModalAction('checkin')}>Check-In</Button>
                <Button size="sm" variant={modalAction === 'checkout' ? 'primary' : 'secondary'} onClick={() => setModalAction('checkout')}>Check-Out</Button>
                <Button size="sm" variant="secondary" onClick={() => setShowFuelModal(false)}>Fechar</Button>
              </div>
            </div>
            <form onSubmit={handleMultiSubmit} className="space-y-4">
              {isAdmin && (
                <div>
                  <label className="block text-sm font-medium mb-2">Selecione o motorista</label>
                  <select
                    value={selectedDriverId}
                    onChange={e => setSelectedDriverId(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    required
                  >
                    <option value="">Selecione...</option>
                    {employees.filter(emp => emp.active && emp.role === 'Driver').map(emp => (
                      <option key={emp.id} value={emp.id}>{emp.name} ({emp.role})</option>
                    ))}
                  </select>
                </div>
              )}
              <div>
                <label className="block text-sm font-medium mb-2">
                  {isAdmin ? 'Selecione um ou mais veículos' : 'Selecione um ou mais veículos atribuídos'}
                </label>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                  {(isAdmin
                    ? availableVehicles // Para admin, todos disponíveis
                    : driverVehicles.filter(v => v.status !== 'Inativo') // Para motoristas, apenas veículos atribuídos e ativos
                  ).map(v => (
                    <label key={v.id} className={`flex items-center border rounded-lg px-3 py-2 cursor-pointer transition ${
                      (isAdmin ? adminSelectedVehicleIds : selectedVehicleIds).includes(v.id)
                        ? 'border-primary-500 bg-primary-50'
                        : 'border-secondary-200'
                    }`}>
                      <input
                        type="checkbox"
                        checked={(isAdmin ? adminSelectedVehicleIds : selectedVehicleIds).includes(v.id)}
                        onChange={() => {
                          if (isAdmin) {
                            setAdminSelectedVehicleIds(prev =>
                              prev.includes(v.id)
                                ? prev.filter(id => id !== v.id)
                                : [...prev, v.id]
                            );
                          } else {
                            setSelectedVehicleIds(prev =>
                              prev.includes(v.id)
                                ? prev.filter(id => id !== v.id)
                                : [...prev, v.id]
                            );
                          }
                        }}
                        className="mr-2 accent-primary-500"
                      />
                      <span className="font-medium">{v.plate} - {v.model} ({v.year})</span>
                    </label>
                  ))}
                </div>
                {!isAdmin && driverVehicles.filter(v => v.status !== 'Inativo').length === 0 && (
                  <div className="mt-2 p-3 bg-warning-50 border border-warning-200 rounded-lg">
                    <p className="text-sm text-warning-700">
                      <strong>Nenhum veículo atribuído:</strong> Você não possui veículos atribuídos para realizar check-ins/check-outs. 
                      Entre em contato com o administrador para solicitar a atribuição de veículos.
                    </p>
                  </div>
                )}
              </div>
              {(isAdmin ? adminSelectedVehicleIds : selectedVehicleIds).length > 0 && (
                <div className="space-y-4">
                  {(isAdmin ? adminSelectedVehicleIds : selectedVehicleIds).map(vehicleId => (
                    <div key={vehicleId} className="border rounded-lg p-4 bg-secondary-50">
                      <div className="font-semibold mb-2">
                        {(isAdmin ? availableVehicles : driverVehicles).find(v => v.id === vehicleId)?.plate} - {(isAdmin ? availableVehicles : driverVehicles).find(v => v.id === vehicleId)?.model} ({(isAdmin ? availableVehicles : driverVehicles).find(v => v.id === vehicleId)?.year})
                      </div>
                      {modalAction === 'fuel' && (
                        <>
                          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                            <div>
                              <label className="block text-sm font-medium">Valor (R$)</label>
                              <input type="number" value={multiForm[vehicleId]?.value || ''} onChange={e => handleMultiFormChange(vehicleId, 'value', e.target.value)} className="input" required min={0.01} step={0.01} />
                            </div>
                            <div>
                              <label className="block text-sm font-medium">Data</label>
                              <input type="date" value={multiForm[vehicleId]?.date || ''} onChange={e => handleMultiFormChange(vehicleId, 'date', e.target.value)} className="input" required />
                            </div>
                            <div>
                              <label className="block text-sm font-medium">Quilometragem</label>
                              <input
                                type="number"
                                value={multiForm[vehicleId]?.mileage || ''}
                                onChange={e => handleMultiFormChange(vehicleId, 'mileage', e.target.value)}
                                className={`input ${multiForm[vehicleId]?.mileage && lastMileage[vehicleId] !== undefined && Number(multiForm[vehicleId]?.mileage) < lastMileage[vehicleId] ? 'border-red-500 bg-red-50' : ''}`}
                                required
                                min={0}
                              />
                              <div className="text-xs mt-1">
                                <span className="font-semibold text-secondary-700">Última registrada: </span>
                                <span className="font-bold text-primary-700">{lastMileage[vehicleId] !== undefined ? `${lastMileage[vehicleId]} km` : '---'}</span>
                                {multiForm[vehicleId]?.mileage && lastMileage[vehicleId] !== undefined && Number(multiForm[vehicleId]?.mileage) < lastMileage[vehicleId] && (
                                  <span className="ml-2 text-red-600 font-semibold animate-pulse">Atenção: valor menor que o último registro!</span>
                                )}
                              </div>
                            </div>
                            <div>
                              <label className="block text-sm font-medium">Comprovante (imagem)</label>
                              <input type="file" accept="image/*" onChange={e => handleMultiFormChange(vehicleId, 'receipt', e.target.files?.[0])} className="input" required />
                            </div>
                          </div>
                        </>
                      )}
                      {(modalAction === 'checkin' || modalAction === 'checkout') && (
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                          <div>
                            <label className="block text-sm font-medium">Data</label>
                            <input type="date" value={multiForm[vehicleId]?.date || ''} onChange={e => handleMultiFormChange(vehicleId, 'date', e.target.value)} className="input" required />
                          </div>
                          <div>
                            <label className="block text-sm font-medium">Quilometragem</label>
                            <input
                              type="number"
                              value={multiForm[vehicleId]?.mileage || ''}
                              onChange={e => handleMultiFormChange(vehicleId, 'mileage', e.target.value)}
                              className={`input ${multiForm[vehicleId]?.mileage && lastMileage[vehicleId] !== undefined && Number(multiForm[vehicleId]?.mileage) < lastMileage[vehicleId] ? 'border-red-500 bg-red-50' : ''}`}
                              required
                              min={0}
                            />
                            <div className="text-xs mt-1">
                              <span className="font-semibold text-secondary-700">Última registrada: </span>
                              <span className="font-bold text-primary-700">{lastMileage[vehicleId] !== undefined ? `${lastMileage[vehicleId]} km` : '---'}</span>
                              {multiForm[vehicleId]?.mileage && lastMileage[vehicleId] !== undefined && Number(multiForm[vehicleId]?.mileage) < lastMileage[vehicleId] && (
                                <span className="ml-2 text-red-600 font-semibold animate-pulse">Atenção: valor menor que o último registro!</span>
                              )}
                            </div>
                          </div>
                          <div className="md:col-span-2">
                            <label className="block text-sm font-medium">Observação</label>
                            <input type="text" value={multiForm[vehicleId]?.notes || ''} onChange={e => handleMultiFormChange(vehicleId, 'notes', e.target.value)} className="input" />
                          </div>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
              <div className="flex justify-end gap-2">
                <Button variant="secondary" type="button" onClick={() => setShowFuelModal(false)}>Cancelar</Button>
                <Button type="submit" disabled={submitting || (isAdmin ? adminSelectedVehicleIds.length === 0 : selectedVehicleIds.length === 0)}>{submitting ? <Loader2 className="animate-spin h-5 w-5" /> : 'Salvar'}</Button>
              </div>
            </form>
          </div>
        </div>
      )}

      {isAdmin ? (
        <div className="space-y-6">
          <h1 className="text-2xl font-bold mb-4">Histórico de Abastecimento da Frota</h1>
          <div className="flex flex-col md:flex-row gap-2 mb-4">
            <input
              type="text"
              placeholder="Buscar por placa, modelo, motorista..."
              value={adminSearch}
              onChange={e => setAdminSearch(e.target.value)}
              className="border border-secondary-300 rounded-lg px-3 py-2 flex-1"
            />
            <select
              value={adminStatusFilter}
              onChange={e => setAdminStatusFilter(e.target.value)}
              className="border border-secondary-300 rounded-lg px-3 py-2 w-48"
            >
              <option value="">Todos Status</option>
              <option value="Pendente">Pendente</option>
              <option value="pending">pending (EN)</option>
              <option value="Aprovado">Aprovado</option>
              <option value="approved">approved (EN)</option>
              <option value="Rejeitado">Rejeitado</option>
              <option value="rejected">rejected (EN)</option>
            </select>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {vehicles.map(vehicle => {
              // Filtrar todos os registros do veículo conforme busca/status
              const registros = allFuelRecords
                .filter(r => r.vehicle_id === vehicle.id)
                .filter(r =>
                  (!adminStatusFilter || 
                    r.status === adminStatusFilter ||
                    (adminStatusFilter === 'Pendente' && r.status === 'pending') ||
                    (adminStatusFilter === 'Aprovado' && r.status === 'approved') ||
                    (adminStatusFilter === 'Rejeitado' && r.status === 'rejected')) &&
                  (
                    !adminSearch ||
                    vehicle.plate.toLowerCase().includes(adminSearch.toLowerCase()) ||
                    vehicle.model.toLowerCase().includes(adminSearch.toLowerCase()) ||
                    (r.driver_name && r.driver_name.toLowerCase().includes(adminSearch.toLowerCase()))
                  )
                )
                .sort((a, b) => new Date(b.recorded_at).getTime() - new Date(a.recorded_at).getTime());
              if (registros.length === 0) return null;
              return (
                <Card key={vehicle.id} className="hover:shadow-lg transition-shadow border-2 border-primary-100 mb-4">
                  <CardHeader>
                    <div className="flex items-center gap-3">
                      <div className="h-10 w-10 bg-primary-100 rounded-lg flex items-center justify-center">
                        <Car className="h-5 w-5 text-primary-600" />
                      </div>
                      <div>
                        <h3 className="font-semibold text-lg text-secondary-900">{vehicle.plate}</h3>
                        <p className="text-sm text-secondary-600">{vehicle.model} ({vehicle.year})</p>
                      </div>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-2">
                      <div className="flex justify-between text-sm">
                        <span className="text-secondary-600">Tipo:</span>
                        <span className="font-medium">{vehicle.type}</span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span className="text-secondary-600">Combustível:</span>
                        <span className="font-medium">{vehicle.fuel}</span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span className="text-secondary-600">Quilometragem:</span>
                        <span className="font-medium">{vehicle.mileage?.toLocaleString('pt-BR')} km</span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span className="text-secondary-600">Status:</span>
                        <span className="font-medium">{vehicle.status}</span>
                      </div>
                    </div>
                    <div className="mt-4">
                      <h4 className="font-semibold mb-2 text-secondary-800">Histórico de Abastecimento</h4>
                      {loadingPending ? (
                        <div className="flex items-center gap-2 text-primary-600 animate-pulse"><Loader2 className="h-5 w-5 animate-spin" />Carregando registros...</div>
                      ) : (
                        <div className="space-y-2">
                          {registros.map(record => (
                            <div key={record.id} className={`border rounded-lg p-2 flex flex-col md:flex-row md:items-center md:justify-between gap-2 ${isPendingStatus(record.status) ? 'bg-yellow-50 border-yellow-300' : 'bg-secondary-50'}`}>
                              <div className="flex flex-col gap-1">
                                <div className="text-sm font-medium">{record.driver_name || 'Motorista desconhecido'}</div>
                                <div className="text-xs text-secondary-600">Data: {new Date(record.recorded_at).toLocaleDateString()} — Valor: R$ {record.total_cost.toFixed(2)}</div>
                                <div className="text-xs text-secondary-600">Quilometragem: {record.mileage} km</div>
                                {record.notes && <div className="text-xs text-secondary-500">Obs: {record.notes}</div>}
                                {record.receipt_photo_url && (
                                  <a href={record.receipt_photo_url} target="_blank" rel="noopener noreferrer" className="mt-1 inline-block">
                                    <img src={record.receipt_photo_url} alt="Comprovante" className="h-16 w-auto rounded shadow border border-secondary-200 hover:scale-105 transition-transform" />
                                    <span className="block text-primary-600 underline text-xs mt-1">Ver comprovante</span>
                                  </a>
                                )}
                              </div>
                              <div className="flex flex-col gap-2 items-end">
                                <span className={`text-xs font-semibold px-2 py-1 rounded ${isPendingStatus(record.status) ? 'bg-yellow-200 text-yellow-800' : isApprovedStatus(record.status) ? 'bg-green-200 text-green-800' : 'bg-red-200 text-red-800'}`}>{getStatusDisplay(record.status)}</span>
                                {isAdmin && isPendingStatus(record.status) && (
                                  <div className="flex gap-1 ml-2">
                                    <Button
                                      size="sm"
                                      variant="success"
                                      disabled={loadingApprove}
                                      onClick={async () => { 
                                        const success = await approve(record.id, user?.id, user?.name);
                                        if (success) {
                                          await refetchFuelRecords();
                                        }
                                      }}
                                      className="text-xs px-2 py-1"
                                    >
                                      Aprovar
                                    </Button>
                                    <Button
                                      size="sm"
                                      variant="error"
                                      disabled={loadingApprove}
                                      onClick={async () => { 
                                        const success = await reject(record.id, user?.id);
                                        if (success) {
                                          await refetchFuelRecords();
                                        }
                                      }}
                                      className="text-xs px-2 py-1"
                                    >
                                      Recusar
                                    </Button>
                                  </div>
                                )}
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        </div>
      ) : (
        <>
          <div className="flex justify-between items-center mt-8 mb-4">
            <h2 className="text-xl font-semibold">
              {isAdmin ? 'Registros de Abastecimento da Frota' : 'Meus Registros de Abastecimento'}
            </h2>
            <Button
              onClick={fetchRecords}
              size="sm"
              variant="secondary"
              className="flex items-center gap-2"
            >
              <span>🔄</span>
              Atualizar
            </Button>
          </div>
          
          {/* Filtros para Admin */}
          {isAdmin && (
            <div className="flex flex-col md:flex-row gap-2 mb-4">
              <input
                type="text"
                placeholder="Buscar por placa, modelo, motorista..."
                value={adminSearch}
                onChange={e => setAdminSearch(e.target.value)}
                className="border border-secondary-300 rounded-lg px-3 py-2 flex-1"
              />
              <select
                value={adminStatusFilter}
                onChange={e => setAdminStatusFilter(e.target.value)}
                className="border border-secondary-300 rounded-lg px-3 py-2 w-48"
              >
                <option value="">Todos Status</option>
                <option value="Pendente">Pendente</option>
                <option value="pending">pending (EN)</option>
                <option value="Aprovado">Aprovado</option>
                <option value="approved">approved (EN)</option>
                <option value="Rejeitado">Rejeitado</option>
                <option value="rejected">rejected (EN)</option>
              </select>
            </div>
          )}
          
          <div className="mb-4 text-sm text-secondary-600">
            Total de registros: {records.length} | User ID: {user?.id}
          </div>
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {(() => {
              // Aplicar filtros se for admin
              let filteredRecords = records;
              if (isAdmin) {
                filteredRecords = records.filter(record => {
                  const vehicle = record.vehicles;
                  const matchesSearch = !adminSearch || 
                    (vehicle?.plate && vehicle.plate.toLowerCase().includes(adminSearch.toLowerCase())) ||
                    (vehicle?.model && vehicle.model.toLowerCase().includes(adminSearch.toLowerCase())) ||
                    (record.driver_name && record.driver_name.toLowerCase().includes(adminSearch.toLowerCase()));
                  
                  const matchesStatus = !adminStatusFilter || 
                    record.status === adminStatusFilter ||
                    (adminStatusFilter === 'Pendente' && record.status === 'pending') ||
                    (adminStatusFilter === 'Aprovado' && record.status === 'approved') ||
                    (adminStatusFilter === 'Rejeitado' && record.status === 'rejected');
                  
                  return matchesSearch && matchesStatus;
                });
              }
              
              if (filteredRecords.length === 0) {
                return (
                  <div className="col-span-full text-center text-secondary-500">
                    {isAdmin ? 'Nenhum registro encontrado com os filtros aplicados.' : 'Nenhum registro encontrado.'}
                    <br />
                    <span className="text-xs">Verifique se você tem registros de abastecimento associados ao seu ID.</span>
                  </div>
                );
              }
              
              return filteredRecords
                .sort((a, b) => new Date(b.recorded_at).getTime() - new Date(a.recorded_at).getTime())
                .map(record => (
                  <Card key={record.id} className="hover:shadow-lg transition-shadow border border-primary-100">
                    <CardHeader>
                      <div className="flex flex-col gap-1">
                        <div className="flex items-center gap-2">
                          <span className="font-semibold text-primary-700">{record.vehicles?.plate || 'Veículo não encontrado'}</span>
                          <Badge variant={record.vehicles?.status === 'Disponível' ? 'success' : record.vehicles?.status === 'Em Uso' ? 'info' : record.vehicles?.status === 'Manutenção' ? 'warning' : 'secondary'}>{record.vehicles?.status}</Badge>
                        </div>
                        <div className="flex items-center gap-2 text-xs text-secondary-600">
                          <span>{new Date(record.recorded_at).toLocaleDateString()}</span>
                          <span>•</span>
                          <span>R$ {record.total_cost.toFixed(2)}</span>
                          <span>•</span>
                          <span>{record.vehicles?.model} ({record.vehicles?.year})</span>
                          {isAdmin && (
                            <>
                              <span>•</span>
                              <span className="font-medium text-primary-600">{record.driver_name}</span>
                            </>
                          )}
                        </div>
                      </div>
                    </CardHeader>
                    <CardContent>
                      <div className="flex flex-col gap-2 text-sm">
                        <div className="flex justify-between">
                          <span className="font-medium">Quilometragem do registro:</span>
                          <span>{record.mileage?.toLocaleString('pt-BR') || 'N/A'} km</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="font-medium">Quilometragem atual do veículo:</span>
                          <span>{record.vehicles?.mileage?.toLocaleString('pt-BR') || 'N/A'} km</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="font-medium">Combustível:</span>
                          <span>{record.fuel_amount}L a R$ {record.unit_price}/L</span>
                        </div>
                        {record.fuel_station && (
                          <div className="flex justify-between">
                            <span className="font-medium">Posto:</span>
                            <span>{record.fuel_station}</span>
                          </div>
                        )}
                        {record.notes && (
                          <div className="mt-2 p-2 bg-gray-50 rounded">
                            <span className="font-medium">Observações:</span> {record.notes}
                          </div>
                        )}
                        {record.receipt_photo_url && (
                          <div className="mt-2">
                            <a href={record.receipt_photo_url} target="_blank" rel="noopener noreferrer" className="text-primary-600 underline text-sm">📷 Ver comprovante</a>
                          </div>
                        )}
                        <div className="flex items-center gap-2 mt-2">
                          <span className={`text-xs font-semibold px-2 py-1 rounded ${isPendingStatus(record.status) ? 'bg-yellow-200 text-yellow-800' : isApprovedStatus(record.status) ? 'bg-green-200 text-green-800' : 'bg-red-200 text-red-800'}`}>{getStatusDisplay(record.status)}</span>
                          {isAdmin && isPendingStatus(record.status) && (
                            <div className="flex gap-1 ml-2">
                              <Button
                                size="sm"
                                variant="success"
                                disabled={loadingApprove}
                                onClick={async () => { 
                                  const success = await approve(record.id, user?.id, user?.name);
                                  if (success) {
                                    await refetchFuelRecords();
                                    await fetchRecords(); // Também recarregar registros locais
                                  }
                                }}
                                className="text-xs px-2 py-1"
                              >
                                Aprovar
                              </Button>
                              <Button
                                size="sm"
                                variant="error"
                                disabled={loadingApprove}
                                onClick={async () => { 
                                  const success = await reject(record.id, user?.id);
                                  if (success) {
                                    await refetchFuelRecords();
                                    await fetchRecords(); // Também recarregar registros locais
                                  }
                                }}
                                className="text-xs px-2 py-1"
                              >
                                Recusar
                              </Button>
                            </div>
                          )}
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                ));
            })()}
          </div>
        </>
      )}


    </div>
  );
};

export default DriverRecords; 