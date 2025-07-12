import React, { useState, useRef, useEffect, RefObject } from 'react';
import { Button } from '../UI/Button';
import { Plus, Trash2, Camera, Save, RotateCcw, Upload, X } from 'lucide-react';
import toast from 'react-hot-toast';
import { supabase } from '../../lib/supabase';

interface DamageItem {
  id: string;
  location: string;
  description: string;
  damage_type: 'Arranhão' | 'Amassado' | 'Quebrado' | 'Desgaste' | 'Outro';
  severity: 'Baixa' | 'Média' | 'Alta';
  photo_url?: string;
  requires_repair: boolean;
}

interface DamageCartModalProps {
  isOpen: boolean;
  onClose: () => void;
  damageCart: DamageItem[];
  onUpdateCart: (damages: DamageItem[]) => void;
  onSaveCart: (damages: Omit<DamageItem, 'id'>[]) => void;
  inspectionType: string;
}

const DAMAGE_TYPES = ['Arranhão', 'Amassado', 'Quebrado', 'Desgaste', 'Outro'];
const SEVERITIES = ['Baixa', 'Média', 'Alta'];
const DEFAULT_CAR_LOCATIONS = [
  'Porta dianteira esquerda',
  'Porta dianteira direita',
  'Porta traseira esquerda',
  'Porta traseira direita',
  'Para-choque dianteiro',
  'Para-choque traseiro',
  'Capô',
  'Teto',
  'Porta-malas',
  'Retrovisor esquerdo',
  'Retrovisor direito',
  'Farol esquerdo',
  'Farol direito',
  'Lanterna esquerda',
  'Lanterna direita',
  'Vidro dianteiro',
  'Vidro traseiro',
  'Roda dianteira esquerda',
  'Roda dianteira direita',
  'Roda traseira esquerda',
  'Roda traseira direita',
];

export const DamageCartModal: React.FC<DamageCartModalProps> = ({
  isOpen,
  onClose,
  damageCart,
  onUpdateCart,
  onSaveCart,
  inspectionType,
}) => {
  const [locationOptions, setLocationOptions] = useState<string[]>([]);
  const [uploadingImages, setUploadingImages] = useState<Set<string>>(new Set());
  const [storageStatus, setStorageStatus] = useState<'checking' | 'ready' | 'error'>('checking');
  const tableRef = useRef<HTMLTableElement>(null);

  // Guardar refs para cada input file
  const fileInputRefs = useRef<{ [damageId: string]: RefObject<HTMLInputElement> }>({});

  // Garante que cada linha tem seu ref
  const getFileInputRef = (damageId: string) => {
    if (!fileInputRefs.current[damageId]) {
      fileInputRefs.current[damageId] = React.createRef<HTMLInputElement>();
    }
    return fileInputRefs.current[damageId];
  };

  useEffect(() => {
    if (!isOpen) return;
    
    // Testar conexão com storage
    const testStorage = async () => {
      try {
        const { data, error } = await supabase.storage
          .from('photos')
          .list('', { limit: 1 });
        
        if (error) {
          console.error('Erro ao testar storage:', error);
          setStorageStatus('error');
          toast.error('Erro na conexão com o storage. Execute o SQL de configuração.');
        } else {
          console.log('Storage funcionando:', data);
          setStorageStatus('ready');
        }
      } catch (error) {
        console.error('Erro ao testar storage:', error);
        setStorageStatus('error');
        toast.error('Erro na conexão com o storage. Execute o SQL de configuração.');
      }
    };
    
    // Buscar localizações de damage_locations
    const fetchLocations = async () => {
      const { data, error } = await supabase
        .from('damage_locations')
        .select('name');
      if (!error && data && data.length > 0) {
        setLocationOptions((data as { name: string }[]).map((d) => d.name));
      } else {
        setLocationOptions(DEFAULT_CAR_LOCATIONS);
      }
    };
    
    testStorage();
    fetchLocations();
  }, [isOpen]);

  const uploadPhoto = async (file: File, damageId: string): Promise<string> => {
    try {
      // Validar o arquivo
      if (!file) {
        throw new Error('Nenhum arquivo selecionado');
      }

      if (file.size === 0) {
        throw new Error('Arquivo vazio');
      }

      const maxSize = 10 * 1024 * 1024; // 10MB
      if (file.size > maxSize) {
        throw new Error('Arquivo muito grande. Máximo 10MB');
      }

      const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];
      if (!allowedTypes.includes(file.type)) {
        throw new Error('Tipo de arquivo não permitido. Use JPEG, PNG, WebP ou GIF');
      }

      // Verificar se o storage está funcionando
      if (storageStatus !== 'ready') {
        throw new Error('Storage não está configurado. Execute o SQL de configuração.');
      }

      const fileExt = file.name.split('.').pop()?.toLowerCase() || 'jpg';
      const fileName = `damage-${damageId}-${Date.now()}.${fileExt}`;
      const filePath = `inspection-photos/${fileName}`;

      console.log('Iniciando upload:', { 
        fileName, 
        filePath, 
        size: file.size, 
        type: file.type,
        name: file.name,
        lastModified: file.lastModified
      });

      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('photos')
        .upload(filePath, file, {
          cacheControl: '3600',
          upsert: false,
          contentType: file.type
        });

      if (uploadError) {
        console.error('Erro no upload:', uploadError);
        if (uploadError.message.includes('bucket')) {
          throw new Error('Bucket de fotos não encontrado. Execute o SQL de configuração.');
        } else if (uploadError.message.includes('policy')) {
          throw new Error('Permissões de upload não configuradas. Execute o SQL de configuração.');
        } else {
        throw new Error(`Erro no upload: ${uploadError.message}`);
        }
      }

      console.log('Upload bem-sucedido:', uploadData);

      const { data: { publicUrl } } = supabase.storage
        .from('photos')
        .getPublicUrl(filePath);

      console.log('URL pública gerada:', publicUrl);

      if (!publicUrl) {
        throw new Error('Erro ao gerar URL pública da imagem');
      }

      return publicUrl;
    } catch (err) {
      console.error('Erro completo no upload:', err);
      throw new Error(err instanceof Error ? err.message : 'Falha no upload da foto');
    }
  };

  const handleImageUpload = async (damageId: string, file: File) => {
    console.log('Iniciando handleImageUpload:', { damageId, fileName: file.name, size: file.size });
    
    setUploadingImages(prev => new Set(prev).add(damageId));
    
    try {
      toast.loading('Enviando foto...', { id: `upload-${damageId}` });
      
      const photoUrl = await uploadPhoto(file, damageId);
      
      console.log('Upload concluído, atualizando dano:', { damageId, photoUrl });
      
      updateDamage(damageId, 'photo_url', photoUrl);
      
      toast.success('Foto enviada com sucesso!', { id: `upload-${damageId}` });
      
    } catch (error) {
      console.error('Erro no handleImageUpload:', error);
      
      const errorMessage = error instanceof Error ? error.message : 'Erro desconhecido';
      
      toast.error(`Erro ao enviar foto: ${errorMessage}`, { id: `upload-${damageId}` });
      
      // Limpar qualquer URL inválida
      updateDamage(damageId, 'photo_url', undefined);
      
    } finally {
      setUploadingImages(prev => {
        const newSet = new Set(prev);
        newSet.delete(damageId);
        return newSet;
      });
    }
  };

  const removeImage = async (damageId: string) => {
    const damage = damages.find(d => d.id === damageId);
    
    if (damage?.photo_url) {
      try {
        // Extrair o caminho do arquivo da URL
        const url = new URL(damage.photo_url);
        const pathSegments = url.pathname.split('/');
        const fileName = pathSegments[pathSegments.length - 1];
        const filePath = `inspection-photos/${fileName}`;
        
        console.log('Removendo foto do storage:', { filePath, originalUrl: damage.photo_url });
        
        // Tentar remover do storage (não falha se não conseguir)
        const { error } = await supabase.storage
          .from('photos')
          .remove([filePath]);
        
        if (error) {
          console.warn('Erro ao remover foto do storage:', error);
        }
        
      } catch (error) {
        console.warn('Erro ao processar remoção da foto:', error);
      }
    }
    
    updateDamage(damageId, 'photo_url', undefined);
    toast.success('Foto removida');
  };

  function createEmptyDamage(): DamageItem {
    return {
      id: `damage_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      location: '',
      description: '',
      damage_type: 'Arranhão',
      severity: 'Baixa',
      requires_repair: false,
    };
  }

  if (!isOpen) return null;

  const damages = damageCart.length > 0 ? damageCart : [createEmptyDamage()];

  const addNewRow = () => {
    onUpdateCart([...damages, createEmptyDamage()]);
  };

  const removeRow = (rowId: string) => {
    if (damages.length === 1) {
      onUpdateCart([createEmptyDamage()]);
    } else {
      onUpdateCart(damages.filter(d => d.id !== rowId));
    }
  };

  const updateDamage = (id: string, field: keyof DamageItem, value: string | boolean | undefined) => {
    onUpdateCart(damages.map(damage => 
      damage.id === id 
        ? { ...damage, [field]: value }
        : damage
    ));
  };

  const handleSave = () => {
    // Filtrar apenas danos com localização e descrição preenchidas
    const validDamages = damages.filter(d => 
      d.location.trim() !== '' && d.description.trim() !== ''
    );

    if (validDamages.length === 0) {
      toast.error('Adicione pelo menos um dano com localização e descrição preenchidas');
      return;
    }

    onSaveCart(validDamages.map(damage => ({
      location: damage.location,
      description: damage.description,
      damage_type: damage.damage_type,
      severity: damage.severity,
      photo_url: damage.photo_url,
      requires_repair: damage.requires_repair
    })));
    toast.success(`${validDamages.length} dano(s) registrado(s) com sucesso!`);
    onClose();
  };

  const clearAll = () => {
    onUpdateCart([createEmptyDamage()]);
    toast.success('Lista de danos limpa');
  };

  const getSeverityColor = (severity: string) => {
    const colors = {
      'Baixa': 'bg-green-100 text-green-800',
      'Média': 'bg-yellow-100 text-yellow-800',
      'Alta': 'bg-red-100 text-red-800'
    };
    return colors[severity as keyof typeof colors] || 'bg-gray-100 text-gray-800';
  };

  const validDamagesCount = damages.filter(d => 
    d.location.trim() !== '' && d.description.trim() !== ''
  ).length;

  const handlePhotoUpload = async (e: React.ChangeEvent<HTMLInputElement>, damageId?: string) => {
    const file = e.target.files?.[0];
    console.log('handlePhotoUpload chamado:', { 
      damageId, 
      file: file ? {
        name: file.name,
        type: file.type,
        size: file.size,
        lastModified: file.lastModified
      } : null,
      filesLength: e.target.files?.length
    });
    
    if (!file) {
      console.log('Nenhum arquivo selecionado');
      return;
    }
    
    if (!file.type.startsWith('image/')) {
      console.error('Tipo de arquivo inválido:', file.type);
      alert('Por favor, selecione um arquivo de imagem válido.');
      return;
    }
    
    console.log('Arquivo válido, iniciando upload:', {
      name: file.name,
      type: file.type,
      size: file.size
    });
    
    if (damageId) {
      await handleImageUpload(damageId, file);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-4 lg:p-6 w-full max-w-7xl max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 lg:mb-6">
          <div>
            <h2 className="text-lg lg:text-xl font-semibold text-secondary-900 flex items-center">
              <Camera className="h-5 w-5 mr-2" />
              Registrar Danos - {inspectionType}
            </h2>
            <p className="text-sm text-secondary-600 mt-1">
              Interface tipo Excel - Edite diretamente nas células e faça upload de fotos
            </p>
          </div>
          <button onClick={onClose} className="text-secondary-400 hover:text-secondary-600 p-2">
            ×
          </button>
        </div>

        {/* Estatísticas */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-6">
          <div className="bg-primary-50 p-4 rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-primary-600 font-medium">Danos Válidos</p>
                <p className="text-2xl font-bold text-primary-700">{validDamagesCount}</p>
              </div>
              <Camera className="h-8 w-8 text-primary-600" />
            </div>
          </div>
          
          <div className="bg-secondary-50 p-4 rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-secondary-600 font-medium">Linhas na Tabela</p>
                <p className="text-2xl font-bold text-secondary-700">{damages.length}</p>
              </div>
              <Plus className="h-8 w-8 text-secondary-600" />
            </div>
          </div>

          <div className="bg-green-50 p-4 rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-green-600 font-medium">Fotos Enviadas</p>
                <p className="text-2xl font-bold text-green-700">
                  {damages.filter(d => d.photo_url).length}
                </p>
              </div>
              <Upload className="h-8 w-8 text-green-600" />
            </div>
          </div>
        </div>

        {/* Controles */}
        <div className="flex flex-wrap gap-2 mb-4">
          <Button onClick={addNewRow} variant="secondary" size="sm">
            <Plus className="h-4 w-4 mr-2" />
            Nova Linha
          </Button>
          <Button onClick={clearAll} variant="secondary" size="sm">
            <RotateCcw className="h-4 w-4 mr-2" />
            Limpar Tudo
          </Button>
        </div>

        {/* Tabela Tipo Excel */}
        <div className="border border-secondary-200 rounded-lg overflow-hidden mb-6">
          <div className="overflow-x-auto">
            <table ref={tableRef} className="w-full">
              <thead className="bg-secondary-50">
                <tr>
                  <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600 border-r border-secondary-200">
                    #
                  </th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600 border-r border-secondary-200 min-w-[200px]">
                    Localização *
                  </th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600 border-r border-secondary-200 min-w-[300px]">
                    Descrição do Dano *
                  </th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600 border-r border-secondary-200 min-w-[120px]">
                    Tipo
                  </th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600 border-r border-secondary-200 min-w-[100px]">
                    Severidade
                  </th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600 border-r border-secondary-200 min-w-[150px]">
                    Foto do Dano
                  </th>
                  <th className="text-left py-3 px-4 text-sm font-medium text-secondary-600 min-w-[80px]">
                    Ações
                  </th>
                </tr>
              </thead>
              <tbody>
                {damages.map((damage, index) => (
                  <tr key={damage.id} className="border-t border-secondary-200 hover:bg-secondary-25">
                    <td className="py-2 px-4 text-sm text-secondary-600 border-r border-secondary-200">
                      {index + 1}
                    </td>
                    <td className="py-2 px-2 border-r border-secondary-200">
                      <select
                        value={damage.location}
                        onChange={(e) => updateDamage(damage.id, 'location', e.target.value)}
                        className="w-full border-0 bg-transparent focus:outline-none focus:ring-2 focus:ring-primary-500 rounded px-2 py-1"
                      >
                        <option value="">Selecione...</option>
                        {locationOptions.map((loc) => (
                          <option key={loc} value={loc}>{loc}</option>
                        ))}
                      </select>
                    </td>
                    <td className="py-2 px-2 border-r border-secondary-200">
                      <textarea
                        value={damage.description}
                        onChange={(e) => updateDamage(damage.id, 'description', e.target.value)}
                        rows={2}
                        className="w-full border-0 bg-transparent focus:outline-none focus:ring-2 focus:ring-primary-500 rounded px-2 py-1 resize-none"
                        placeholder="Descreva o dano detalhadamente..."
                      />
                    </td>
                    <td className="py-2 px-2 border-r border-secondary-200">
                      <select
                        value={damage.damage_type}
                        onChange={(e) => updateDamage(damage.id, 'damage_type', e.target.value)}
                        className="w-full border-0 bg-transparent focus:outline-none focus:ring-2 focus:ring-primary-500 rounded px-2 py-1"
                      >
                        {DAMAGE_TYPES.map(type => (
                          <option key={type} value={type}>{type}</option>
                        ))}
                      </select>
                    </td>
                    <td className="py-2 px-2 border-r border-secondary-200">
                      <select
                        value={damage.severity}
                        onChange={(e) => updateDamage(damage.id, 'severity', e.target.value)}
                        className={`w-full border-0 bg-transparent focus:outline-none focus:ring-2 focus:ring-primary-500 rounded px-2 py-1 ${getSeverityColor(damage.severity)}`}
                      >
                        {SEVERITIES.map(severity => (
                          <option key={severity} value={severity}>{severity}</option>
                        ))}
                      </select>
                    </td>
                    <td className="py-2 px-2 border-r border-secondary-200">
                      <div className="flex flex-col items-center space-y-2">
                        {damage.photo_url ? (
                          <div className="relative">
                            <img 
                              src={damage.photo_url} 
                              alt="Foto do dano" 
                              className="w-20 h-20 object-cover rounded border"
                            />
                            <button
                              onClick={() => removeImage(damage.id)}
                              className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs hover:bg-red-600"
                            >
                              <X className="h-3 w-3" />
                            </button>
                          </div>
                        ) : (
                          <div className="w-20 h-20 border-2 border-dashed border-secondary-300 rounded flex items-center justify-center">
                            <Camera className="h-6 w-6 text-secondary-400" />
                          </div>
                        )}
                        <input
                          type="file"
                          accept="image/*"
                          ref={getFileInputRef(damage.id)}
                          style={{ display: 'none' }}
                          onChange={(e) => handlePhotoUpload(e, damage.id)}
                          disabled={uploadingImages.has(damage.id) || storageStatus !== 'ready'}
                        />
                        <Button
                          variant="secondary"
                          size="sm"
                          disabled={uploadingImages.has(damage.id) || storageStatus !== 'ready'}
                          className="text-xs"
                          onClick={() => {
                            const ref = getFileInputRef(damage.id).current;
                            if (ref) ref.click();
                          }}
                        >
                          {uploadingImages.has(damage.id) ? (
                            'Enviando...'
                          ) : storageStatus === 'error' ? (
                            <>
                              <X className="h-3 w-3 mr-1" />
                              Erro
                            </>
                          ) : (
                            <>
                              <Upload className="h-3 w-3 mr-1" />
                              Foto
                            </>
                          )}
                        </Button>
                      </div>
                    </td>
                    <td className="py-2 px-2 text-center">
                      <button
                        onClick={() => removeRow(damage.id)}
                        className="p-1 text-error-400 hover:text-error-600 hover:bg-error-50 rounded"
                        title="Remover linha"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Instruções e Status */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <h4 className="font-semibold text-blue-900 mb-2">💡 Como usar:</h4>
            <ul className="text-sm text-blue-800 space-y-1">
              <li>• Clique diretamente nas células para editar</li>
              <li>• Use Tab para navegar entre células</li>
              <li>• Preencha pelo menos Localização e Descrição para cada dano</li>
              <li>• Faça upload de fotos para cada dano clicando no botão "Foto"</li>
              <li>• Clique em "Nova Linha" para adicionar mais danos</li>
              <li>• O custo total será calculado automaticamente</li>
            </ul>
          </div>
          
                      <div className="bg-green-50 border border-green-200 rounded-lg p-4">
              <div className="flex items-center justify-between mb-2">
                <h4 className="font-semibold text-green-900">📁 Upload de Fotos:</h4>
                <div className={`px-2 py-1 rounded text-xs font-medium ${
                  storageStatus === 'ready' ? 'bg-green-100 text-green-800' :
                  storageStatus === 'error' ? 'bg-red-100 text-red-800' :
                  'bg-yellow-100 text-yellow-800'
                }`}>
                  {storageStatus === 'ready' ? '✅ Pronto' :
                   storageStatus === 'error' ? '❌ Erro' :
                   '🔄 Testando...'}
                </div>
              </div>
              <ul className="text-sm text-green-800 space-y-1">
                <li>• Formatos aceitos: JPEG, PNG, WebP, GIF</li>
                <li>• Tamanho máximo: 10MB por foto</li>
                <li>• As fotos são armazenadas com segurança</li>
                <li>• Você pode remover fotos clicando no "X"</li>
                <li>• Status de upload aparece em tempo real</li>
              </ul>
              {storageStatus === 'error' && (
                <div className="mt-2 p-2 bg-red-50 border border-red-200 rounded text-xs text-red-700">
                  ⚠️ Execute o SQL de configuração do storage antes de fazer upload de fotos.
                </div>
              )}
            </div>
        </div>

        {/* Botões de ação */}
        <div className="flex justify-end space-x-4">
          <Button variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button onClick={handleSave} disabled={validDamagesCount === 0}>
            <Save className="h-4 w-4 mr-2" />
            Salvar {validDamagesCount > 0 && `(${validDamagesCount} danos)`}
          </Button>
        </div>
      </div>
    </div>
  );
};

export default DamageCartModal;