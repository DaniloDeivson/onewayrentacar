import React, { useState } from 'react';
import { Card, CardHeader, CardContent } from '../UI/Card';
import { Button } from '../UI/Button';
import { UserPlus, Users } from 'lucide-react';
import RegisterForm from '../Auth/RegisterForm';
import toast from 'react-hot-toast';

interface UserRegistrationSectionProps {
  onUserCreated?: () => void;
}

export default function UserRegistrationSection({ onUserCreated }: UserRegistrationSectionProps) {
  const [isFormVisible, setIsFormVisible] = useState(false);

  const handleSuccess = () => {
    setIsFormVisible(false);
    toast.success('Usuário cadastrado com sucesso!');
    // Notificar o componente pai que um usuário foi criado
    if (onUserCreated) {
      onUserCreated();
    }
  };

  return (
    <Card className="mb-6">
      <CardHeader className="p-4 lg:p-6">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div className="flex items-center">
            <UserPlus className="h-6 w-6 text-primary-600 mr-3" />
            <h3 className="text-lg font-semibold text-secondary-900">Cadastro de Usuários</h3>
          </div>
          <Button 
            onClick={() => setIsFormVisible(!isFormVisible)}
            size="sm"
          >
            {isFormVisible ? 'Cancelar' : (
              <>
                <UserPlus className="h-4 w-4 mr-2" />
                Novo Usuário
              </>
            )}
          </Button>
        </div>
      </CardHeader>
      <CardContent className="p-4 lg:p-6">
        {isFormVisible ? (
          <RegisterForm onSuccess={handleSuccess} onCancel={() => setIsFormVisible(false)} isAdminPanel={true} />
        ) : (
          <div className="text-center py-8">
            <Users className="h-12 w-12 text-secondary-400 mx-auto mb-4" />
            <p className="text-secondary-600">Cadastre novos usuários no sistema</p>
            <p className="text-secondary-500 text-sm mt-2">
              Clique no botão "Novo Usuário" para iniciar o cadastro
            </p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}