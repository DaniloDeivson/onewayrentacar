import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { Button } from './Button';
import { Card, CardHeader, CardContent } from './Card';
import { AlertTriangle, Car, FileText, Fuel, AlertCircle, CheckCircle, XCircle } from 'lucide-react';
import toast from 'react-hot-toast';

interface VehicleDeletionModalProps {
  vehicleId: string;
  vehiclePlate: string;
  vehicleModel: string;
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
}

interface ImpactAnalysis {
  vehicle_exists: boolean;
  vehicle_plate: string;
  vehicle_model: string;
  has_active_contract: boolean;
  contract_info: {
    contract_id: string;
    contract_number: string;
    customer_name: string;
    start_date: string;
    end_date: string;
    status: string;
  } | null;
  impact_summary: {
    active_driver_assignments: number;
    total_inspections: number;
    total_fuel_records: number;
    total_fines: number;
  };
  warning_message: string;
}

export const VehicleDeletionModal: React.FC<VehicleDeletionModalProps> = ({
  vehicleId,
  vehiclePlate,
  vehicleModel,
  isOpen,
  onClose,
  onConfirm
}) => {
  const [impact, setImpact] = useState<ImpactAnalysis | null>(null);
  const [loading, setLoading] = useState(false);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    if (isOpen && vehicleId) {
      fetchImpactAnalysis();
    }
  }, [isOpen, vehicleId]);

  const fetchImpactAnalysis = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase.rpc('fn_get_vehicle_deletion_impact', {
        p_vehicle_id: vehicleId
      });

      if (error) throw error;
      setImpact(data);
    } catch (err) {
      console.error('Erro ao analisar impacto:', err);
      toast.error('Erro ao analisar impacto da exclusão');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async () => {
    try {
      setDeleting(true);
      const { data, error } = await supabase.rpc('fn_safe_delete_vehicle', {
        p_vehicle_id: vehicleId
      });

      if (error) throw error;

      if (data.success) {
        toast.success(data.message);
        onConfirm();
        onClose();
      } else {
        toast.error(data.message);
      }
    } catch (err) {
      console.error('Erro ao excluir veículo:', err);
      toast.error('Erro ao excluir veículo');
    } finally {
      setDeleting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-6 w-full max-w-2xl mx-4 shadow-lg max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-semibold flex items-center">
            <AlertTriangle className="h-5 w-5 mr-2 text-warning-600" />
            Confirmar Exclusão de Veículo
          </h3>
          <Button
            variant="secondary"
            size="sm"
            onClick={onClose}
            disabled={deleting}
          >
            <XCircle className="h-4 w-4" />
          </Button>
        </div>

        {loading ? (
          <div className="flex items-center justify-center h-32">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
          </div>
        ) : impact ? (
          <div className="space-y-4">
            {/* Vehicle Info */}
            <Card>
              <CardHeader className="pb-2">
                <div className="flex items-center">
                  <Car className="h-4 w-4 mr-2 text-primary-600" />
                  <span className="font-medium">Veículo a ser excluído</span>
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-sm">
                  <p><strong>Placa:</strong> {impact.vehicle_plate}</p>
                  <p><strong>Modelo:</strong> {impact.vehicle_model}</p>
                </div>
              </CardContent>
            </Card>

            {/* Contract Warning */}
            {impact.has_active_contract && impact.contract_info && (
              <Card className="border-warning-200 bg-warning-50">
                <CardHeader className="pb-2">
                  <div className="flex items-center">
                    <AlertCircle className="h-4 w-4 mr-2 text-warning-600" />
                    <span className="font-medium text-warning-800">Contrato Ativo Detectado</span>
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="text-sm text-warning-700 space-y-1">
                    <p><strong>Contrato:</strong> {impact.contract_info.contract_number}</p>
                    <p><strong>Cliente:</strong> {impact.contract_info.customer_name}</p>
                    <p><strong>Período:</strong> {new Date(impact.contract_info.start_date).toLocaleDateString()} a {new Date(impact.contract_info.end_date).toLocaleDateString()}</p>
                    <p className="font-semibold mt-2">
                      ⚠️ Este contrato será automaticamente desativado!
                    </p>
                  </div>
                </CardContent>
              </Card>
            )}

            {/* Impact Summary */}
            <Card>
              <CardHeader className="pb-2">
                <div className="flex items-center">
                  <FileText className="h-4 w-4 mr-2 text-secondary-600" />
                  <span className="font-medium">Resumo do Impacto</span>
                </div>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div className="flex items-center">
                    <Car className="h-4 w-4 mr-2 text-primary-600" />
                    <span>Atribuições ativas: <strong>{impact.impact_summary.active_driver_assignments}</strong></span>
                  </div>
                  <div className="flex items-center">
                    <FileText className="h-4 w-4 mr-2 text-info-600" />
                    <span>Inspeções: <strong>{impact.impact_summary.total_inspections}</strong></span>
                  </div>
                  <div className="flex items-center">
                    <Fuel className="h-4 w-4 mr-2 text-success-600" />
                    <span>Registros de combustível: <strong>{impact.impact_summary.total_fuel_records}</strong></span>
                  </div>
                  <div className="flex items-center">
                    <AlertCircle className="h-4 w-4 mr-2 text-warning-600" />
                    <span>Multas: <strong>{impact.impact_summary.total_fines}</strong></span>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Warning Message */}
            <div className="p-4 bg-warning-50 border border-warning-200 rounded-lg">
              <div className="flex items-start">
                <AlertTriangle className="h-5 w-5 mr-2 text-warning-600 mt-0.5" />
                <div className="text-sm text-warning-700">
                  <p className="font-medium mb-1">Atenção:</p>
                  <p>{impact.warning_message}</p>
                  <p className="mt-2 font-medium">
                    Esta ação não pode ser desfeita. Todos os dados relacionados ao veículo serão perdidos.
                  </p>
                </div>
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex justify-end gap-3 pt-4">
              <Button
                variant="secondary"
                onClick={onClose}
                disabled={deleting}
              >
                Cancelar
              </Button>
              <Button
                variant="error"
                onClick={handleDelete}
                disabled={deleting}
                className="flex items-center"
              >
                {deleting ? (
                  <>
                    <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                    Excluindo...
                  </>
                ) : (
                  <>
                    <XCircle className="h-4 w-4 mr-2" />
                    Confirmar Exclusão
                  </>
                )}
              </Button>
            </div>
          </div>
        ) : (
          <div className="text-center py-8 text-secondary-600">
            <AlertCircle className="h-8 w-8 mx-auto mb-2" />
            Erro ao carregar análise de impacto
          </div>
        )}
      </div>
    </div>
  );
}; 