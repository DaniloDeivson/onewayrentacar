import { useState } from 'react'
import { supabase } from '../../lib/supabase'
import { Loader2 } from 'lucide-react'
import type { Employee } from '../../types/database'

interface UpdateFormProps {
  onSuccess?: () => void
  onCancel?: () => void
  initialData: Employee
  updateEmployee: (id: string, data: Partial<Employee>) => Promise<unknown>
}

export function UpdateForm({ onSuccess, onCancel, initialData, updateEmployee }: UpdateFormProps) {
  const [name, setName] = useState(initialData.name)
  const [phone, setPhone] = useState(initialData.contact_info?.phone || '')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (newPassword && newPassword !== confirmPassword) {
      setError('As senhas não coincidem')
      return
    }

    if (!initialData.id) {
      setError('Usuário não encontrado')
      return
    }

    try {
      setLoading(true)
      setError(null)

      // Atualizar senha se fornecida
      if (newPassword) {
        try {
          const { error: passwordError } = await supabase.auth.updateUser({
            password: newPassword
          })

          if (passwordError) {
            throw passwordError
          }
        } catch (passwordError) {
          console.warn('Erro ao atualizar senha:', passwordError);
          // Não falhar se não conseguir atualizar a senha
        }
      }

      // Atualizar dados do funcionário
      await updateEmployee(initialData.id, {
        name: name.trim(),
        contact_info: {
          email: initialData.contact_info.email,
          phone: phone.trim() || undefined
        }
      })

      if (onSuccess) {
        onSuccess()
      }
    } catch (error) {
      console.error('Erro na atualização:', error)
      setError(error instanceof Error ? error.message : 'Erro ao atualizar dados')
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label htmlFor="name" className="block text-sm font-medium text-secondary-700">
          Nome
        </label>
        <input
          type="text"
          id="name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          className="mt-1 block w-full rounded-md border-secondary-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
          required
        />
      </div>

      <div>
        <label htmlFor="phone" className="block text-sm font-medium text-secondary-700">
          Telefone
        </label>
        <input
          type="tel"
          id="phone"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          className="mt-1 block w-full rounded-md border-secondary-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
        />
      </div>

      <div>
        <label htmlFor="new-password" className="block text-sm font-medium text-secondary-700">
          Nova Senha (opcional)
        </label>
        <input
          type="password"
          id="new-password"
          value={newPassword}
          onChange={(e) => setNewPassword(e.target.value)}
          className="mt-1 block w-full rounded-md border-secondary-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
        />
      </div>

      {newPassword && (
        <div>
          <label htmlFor="confirm-password" className="block text-sm font-medium text-secondary-700">
            Confirmar Nova Senha
          </label>
          <input
            type="password"
            id="confirm-password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            className="mt-1 block w-full rounded-md border-secondary-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
          />
        </div>
      )}

      {error && (
        <div className="rounded-md bg-red-50 p-4">
          <div className="flex">
            <div className="ml-3">
              <h3 className="text-sm font-medium text-red-800">Erro</h3>
              <div className="mt-2 text-sm text-red-700">
                <p>{error}</p>
              </div>
            </div>
          </div>
        </div>
      )}

      <div className="flex justify-end space-x-3">
        <button
          type="button"
          onClick={onCancel}
          className="inline-flex justify-center rounded-md border border-secondary-300 bg-white px-4 py-2 text-sm font-medium text-secondary-700 shadow-sm hover:bg-secondary-50 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-offset-2"
        >
          Cancelar
        </button>
        <button
          type="submit"
          disabled={loading}
          className="inline-flex justify-center rounded-md border border-transparent bg-primary-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-offset-2"
        >
          {loading ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Salvando...
            </>
          ) : (
            'Salvar'
          )}
        </button>
      </div>
    </form>
  )
} 