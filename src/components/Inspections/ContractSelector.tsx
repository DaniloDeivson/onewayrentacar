import React from 'react';
import { FileText, User, Calendar, DollarSign } from 'lucide-react';

interface Contract {
  id: string;
  contract_number?: string;
  customers?: { name: string };
  daily_rate?: number;
  start_date: string;
  end_date: string;
}

interface ContractSelectorProps {
  availableContracts: Contract[];
  activeContract: Contract | null;
}

export const ContractSelector: React.FC<ContractSelectorProps> = ({
  availableContracts,
  activeContract,
}) => {
  if (availableContracts.length === 0) {
    return (
      <div className="bg-secondary-50 p-4 rounded-lg border border-secondary-200">
        <div className="flex items-start">
          <FileText className="h-5 w-5 text-secondary-500 mr-2 mt-0.5" />
          <div>
            <h4 className="font-medium text-secondary-700">Nenhum Contrato Ativo</h4>
            <p className="text-sm text-secondary-600 mt-1">
              Não foi encontrado nenhum contrato ativo para este veículo.
            </p>
            <p className="text-xs text-secondary-500 mt-2">
              A inspeção será registrada sem vinculação a contrato.
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-success-50 p-4 rounded-lg border border-success-200">
      <div className="flex items-start">
        <FileText className="h-5 w-5 text-success-600 mr-2 mt-0.5" />
        <div className="flex-1">
          <h4 className="font-medium text-success-800 mb-3">Contrato Ativo Encontrado</h4>
          
          {activeContract && (
            <div className="bg-white p-3 rounded-lg border border-success-200 mb-3">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                <div className="flex items-center">
                  <User className="h-4 w-4 text-success-600 mr-2" />
                  <div>
                    <span className="text-success-700 font-medium">Cliente:</span>
                    <p className="text-success-800">{activeContract.customers?.name}</p>
                  </div>
                </div>
                
                <div className="flex items-center">
                  <DollarSign className="h-4 w-4 text-success-600 mr-2" />
                  <div>
                    <span className="text-success-700 font-medium">Valor Diário:</span>
                    <p className="text-success-800">R$ {activeContract.daily_rate?.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}</p>
                  </div>
                </div>
                
                <div className="flex items-center">
                  <Calendar className="h-4 w-4 text-success-600 mr-2" />
                  <div>
                    <span className="text-success-700 font-medium">Início:</span>
                    <p className="text-success-800">{new Date(activeContract.start_date).toLocaleDateString('pt-BR')}</p>
                  </div>
                </div>
                
                <div className="flex items-center">
                  <Calendar className="h-4 w-4 text-success-600 mr-2" />
                  <div>
                    <span className="text-success-700 font-medium">Fim:</span>
                    <p className="text-success-800">{new Date(activeContract.end_date).toLocaleDateString('pt-BR')}</p>
                  </div>
                </div>
              </div>
            </div>
          )}
          
          <div>
            <label className="block text-sm font-medium text-success-800 mb-2">
              Contrato Selecionado:
            </label>
            <input
              type="text"
              readOnly
              value={activeContract ? `${activeContract.customers?.name} - ${new Date(activeContract.start_date).toLocaleDateString('pt-BR')} a ${new Date(activeContract.end_date).toLocaleDateString('pt-BR')}` : 'Nenhum (sem contrato)'}
              className="w-full border border-success-300 rounded-lg px-3 py-2 bg-gray-100 text-gray-700 cursor-not-allowed"
            />
            <p className="text-xs text-success-700 mt-1">
              ✓ Contrato automaticamente selecionado com base no veículo
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};