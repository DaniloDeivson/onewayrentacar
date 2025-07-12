import React, { useState } from 'react';
import { Button } from '../UI/Button';
import { Badge } from '../UI/Badge';
import { Clock, User, FileText, FileSignature as Signature, CheckCircle, AlertTriangle, Loader2, X } from 'lucide-react';
import toast from 'react-hot-toast';

interface CheckInOutModalProps {
  isOpen: boolean;
  onClose: () => void;
  serviceNote: {
    id: string;
    vehicles?: { plate: string; model: string };
    maintenance_type: string;
    priority: string;
    description: string;
    start_date: string;
    vehicle_id: string;
  };
  activeCheckin?: {
    id: string;
    mechanic_id: string;
    mechanic_name: string;
    checkin_at: string;
    notes: string;
    signature_url: string;
  };
  mechanics: Array<{ id: string; name: string }>;
  onCheckIn: (data: { mechanic_id: string; notes?: string }) => Promise<void>;
  onCheckOut: (checkinId: string, notes?: string, signatureUrl?: string, mileage?: number, fuelLevel?: number) => Promise<void>;
  onUploadSignature: (blob: Blob) => Promise<string>;
}

export const CheckInOutModal: React.FC<CheckInOutModalProps> = ({
  isOpen,
  onClose,
  serviceNote,
  activeCheckin,
  mechanics,
  onCheckIn,
  onCheckOut,
  onUploadSignature
}) => {
  const [loading, setLoading] = useState(false);
  const [isCheckingOut, setIsCheckingOut] = useState(false);
  const [formData, setFormData] = useState({
    mechanic_id: activeCheckin?.mechanic_id || '',
    notes: activeCheckin?.notes || '',
    mileage: '',
    fuel_level: ''
  });
  const [signatureUrl, setSignatureUrl] = useState(activeCheckin?.signature_url || '');
  const [signatureFile, setSignatureFile] = useState<File | null>(null);

  if (!isOpen) return null;

  const isCheckIn = !activeCheckin;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    
    try {
      if (isCheckIn) {
        await onCheckIn({
          mechanic_id: formData.mechanic_id,
          notes: formData.notes || undefined
        });
        toast.success('Check-in realizado com sucesso!');
      } else {
        // If we have a signature file, upload it first
        let finalSignatureUrl = signatureUrl;
        if (signatureFile) {
          try {
            finalSignatureUrl = await onUploadSignature(signatureFile);
          } catch (error) {
            console.error('Error uploading signature:', error);
            toast.error('Erro ao enviar assinatura, mas continuando com o check-out');
          }
        }
        
        await onCheckOut(
          activeCheckin.id,
          formData.notes || undefined,
          finalSignatureUrl || undefined,
          parseFloat(formData.mileage) || undefined,
          parseFloat(formData.fuel_level) || undefined
        );
        toast.success('Check-out realizado com sucesso!');
      }
      onClose();
    } catch (error) {
      console.error('Error processing check-in/out:', error);
      toast.error('Erro ao processar operação: ' + (error instanceof Error ? error.message : 'Erro desconhecido'));
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSignatureUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    
    setSignatureFile(file);
    
    // Create a preview URL
    const previewUrl = URL.createObjectURL(file);
    setSignatureUrl(previewUrl);
  };

  const formatDuration = (startTime: string) => {
    const start = new Date(startTime);
    const now = new Date();
    const diffMs = now.getTime() - start.getTime();
    const hours = Math.floor(diffMs / (1000 * 60 * 60));
    const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
    return `${hours}h ${minutes}m`;
  };

  const getPriorityBadge = (priority: string) => {
    const variants = {
      'Baixa': 'secondary',
      'Média': 'warning',
      'Alta': 'error'
    } as const;

    return <Badge variant={variants[priority as keyof typeof variants] || 'secondary'}>{priority}</Badge>;
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <h2 className="text-lg lg:text-xl font-semibold text-secondary-900 flex items-center">
            {isCheckIn ? (
              <>
                <CheckCircle className="h-5 w-5 mr-2 text-success-600" />
                Check-In de Manutenção
              </>
            ) : (
              <>
                <Clock className="h-5 w-5 mr-2 text-warning-600" />
                Check-Out de Manutenção
              </>
            )}
          </h2>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            <X className="h-6 w-6" />
          </button>
        </div>

        {/* Service Note Info */}
        <div className="bg-secondary-50 p-4 rounded-lg mb-6">
          <h3 className="font-semibold text-secondary-900 mb-3">Informações da Ordem de Serviço</h3>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <div>
              <p className="text-sm text-secondary-600">Veículo</p>
              <p className="font-medium">{serviceNote.vehicles?.plate} - {serviceNote.vehicles?.model}</p>
            </div>
            <div>
              <p className="text-sm text-secondary-600">Tipo de Manutenção</p>
              <p className="font-medium">{serviceNote.maintenance_type}</p>
            </div>
            <div>
              <p className="text-sm text-secondary-600">Prioridade</p>
              <div className="mt-1">{getPriorityBadge(serviceNote.priority)}</div>
            </div>
            <div>
              <p className="text-sm text-secondary-600">Data de Início</p>
              <p className="font-medium">{new Date(serviceNote.start_date).toLocaleDateString('pt-BR')}</p>
            </div>
          </div>
          <div className="mt-4">
            <p className="text-sm text-secondary-600">Descrição</p>
            <p className="font-medium">{serviceNote.description}</p>
          </div>
        </div>

        {/* Active Check-in Info (for check-out) */}
        {activeCheckin && (
          <div className="bg-warning-50 border border-warning-200 p-4 rounded-lg mb-6">
            <h4 className="font-semibold text-warning-800 mb-3 flex items-center">
              <AlertTriangle className="h-4 w-4 mr-2" />
              Manutenção em Andamento
            </h4>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 text-sm">
              <div>
                <p className="text-warning-600">Mecânico Responsável:</p>
                <p className="font-medium text-warning-800">{activeCheckin.mechanic_name}</p>
              </div>
              <div>
                <p className="text-warning-600">Início:</p>
                <p className="font-medium text-warning-800">
                  {new Date(activeCheckin.checkin_at).toLocaleString('pt-BR')}
                </p>
              </div>
              <div>
                <p className="text-warning-600">Duração:</p>
                <p className="font-medium text-warning-800">{formatDuration(activeCheckin.checkin_at)}</p>
              </div>
              {activeCheckin.notes && (
                <div className="lg:col-span-2">
                  <p className="text-warning-600">Observações do Check-In:</p>
                  <p className="font-medium text-warning-800">{activeCheckin.notes}</p>
                </div>
              )}
            </div>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4 lg:space-y-6">
          {/* Mechanic Selection (only for check-in) */}
          {isCheckIn && (
            <div>
              <label className="block text-sm font-medium text-secondary-700 mb-2">
                <User className="h-4 w-4 inline mr-1" />
                Mecânico Responsável *
              </label>
              <select
                name="mechanic_id"
                value={formData.mechanic_id}
                onChange={handleChange}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                required
              >
                <option value="">Selecione um mecânico</option>
                {mechanics.map(mechanic => (
                  <option key={mechanic.id} value={mechanic.id}>
                    {mechanic.name} {mechanic.employee_code && `(${mechanic.employee_code})`}
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* Notes */}
          <div>
            <label className="block text-sm font-medium text-secondary-700 mb-2">
              <FileText className="h-4 w-4 inline mr-1" />
              {isCheckIn ? 'Observações do Check-In' : 'Observações do Check-Out'}
            </label>
            <textarea
              name="notes"
              value={formData.notes}
              onChange={handleChange}
              rows={3}
              className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder={
                isCheckIn 
                  ? "Observações sobre o início da manutenção..."
                  : "Observações sobre a conclusão da manutenção, trabalhos realizados, etc..."
              }
            />
          </div>

          {/* Signature Upload (for check-out) */}
          {!isCheckIn && (
            <div>
              <label className="block text-sm font-medium text-secondary-700 mb-2">
                <Signature className="h-4 w-4 inline mr-1" />
                Assinatura Digital
              </label>
              <input
                type="file"
                accept="image/*"
                onChange={handleSignatureUpload}
                className="w-full border border-secondary-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500"
                disabled={loading}
              />
              {signatureUrl && (
                <div className="mt-2">
                  <img 
                    src={signatureUrl} 
                    alt="Assinatura" 
                    className="w-full max-w-xs h-24 object-contain border rounded"
                  />
                </div>
              )}
              <p className="text-xs text-secondary-500 mt-1">
                Faça upload de uma imagem da assinatura para confirmar a conclusão da manutenção
              </p>
            </div>
          )}

          {/* Status Update Info */}
          <div className="bg-info-50 border border-info-200 rounded-lg p-4">
            <div className="flex items-start">
              <AlertTriangle className="h-5 w-5 text-info-600 mr-2 mt-0.5" />
              <div>
                <p className="text-sm font-medium text-info-800">
                  {isCheckIn ? 'Atualização Automática de Status' : 'Finalização da Manutenção'}
                </p>
                <p className="text-xs text-info-700 mt-1">
                  {isCheckIn 
                    ? 'Ao fazer check-in, o status do veículo será automaticamente alterado para "Manutenção".'
                    : 'Ao fazer check-out, o status do veículo será automaticamente alterado para "Disponível".'
                  }
                </p>
              </div>
            </div>
          </div>

          <div className="flex flex-col sm:flex-row justify-end space-y-3 sm:space-y-0 sm:space-x-4 pt-4 lg:pt-6 border-t">
            <Button variant="secondary" onClick={onClose} disabled={loading} className="w-full sm:w-auto">
              Cancelar
            </Button>
            <Button 
              type="submit" 
              disabled={loading} 
              variant={isCheckIn ? "success" : "warning"}
              className="w-full sm:w-auto"
            >
              {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
              {isCheckIn ? (
                <>
                  <CheckCircle className="h-4 w-4 mr-2" />
                  Fazer Check-In
                </>
              ) : (
                <>
                  <Clock className="h-4 w-4 mr-2" />
                  Fazer Check-Out
                </>
              )}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
};