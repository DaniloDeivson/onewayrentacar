import { useCallback, useEffect, useState, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import { useNavigate } from 'react-router-dom'
import { Employee } from '../types/database'

interface AuthState {
  loading: boolean
  isAuthenticated: boolean
  user: Employee | null
  error: string | null
}

export interface UseAuthReturn {
  loading: boolean
  isAuthenticated: boolean
  user: Employee | null
  error: string | null
  signIn: (email: string, password: string) => Promise<void>
  signUp: (email: string, password: string, userData: Partial<Employee>) => Promise<{ success: boolean; message: string }>
  signOut: () => Promise<void>
  hasPermission: (permission: string) => boolean
  isAdmin: boolean
  isManager: boolean
}

// Cache para evitar chamadas repetidas ao banco
const employeeCache = new Map<string, { data: Employee; timestamp: number }>()
const CACHE_DURATION = 5 * 60 * 1000 // 5 minutos

export function useAuth(): UseAuthReturn {
  const navigate = useNavigate()
  const [state, setState] = useState<AuthState>({
    loading: true,
    isAuthenticated: false,
    user: null,
    error: null
  })

  // Verificar se o usuário existe na tabela employees usando query direta
  const checkEmployeeAccess = useCallback(async (userId: string) => {
    try {
      // Verificar cache primeiro
      const cached = employeeCache.get(userId)
      if (cached && Date.now() - cached.timestamp < CACHE_DURATION) {
        console.log('📦 Usando dados do cache para usuário:', userId)
        return cached.data
      }

      // Obter o email do usuário autenticado
      const { data: { user } } = await supabase.auth.getUser()
      if (!user?.email) {
        throw new Error('Email do usuário não encontrado')
      }

      // Buscar diretamente na tabela employees (RLS temporariamente desabilitado)
      let data, error;
      try {
        const result = await supabase
          .from('employees')
          .select('*')
          .eq('id', user.id)
          .eq('active', true)
          .maybeSingle();
        data = result.data;
        error = result.error;
      } catch {
        console.log('Erro ao buscar usuário na tabela employees');
        data = null;
        error = { message: 'Erro ao buscar funcionário' };
      }

      if (error) {
        console.error('Database error:', error)
        throw new Error(`Erro de acesso: ${error.message}`)
      }

      if (!data) {
        localStorage.setItem('authError', 'Usuário não encontrado ou inativo');
        await supabase.auth.signOut();
        throw new Error('Usuário não encontrado ou inativo')
      }

      // Verificar se o usuário não tem status problemático
      if (data.contact_info?.status &&
          ['orphaned', 'orphaned_duplicate', 'duplicate_resolved'].includes(data.contact_info.status)) {
        localStorage.setItem('authError', 'Usuário inativo ou com status inválido');
        await supabase.auth.signOut();
        throw new Error('Usuário inativo ou com status inválido')
      }

      // Salvar no cache
      employeeCache.set(userId, { data, timestamp: Date.now() })
      return data
    } catch (error) {
      console.error('Erro ao verificar acesso:', error)
      throw error
    }
  }, [])

  // Função para verificar permissões - memoizada
  const hasPermission = useMemo(() => {
    return (permission: string): boolean => {
      if (!state.user) return false
      // Admin tem todas as permissões
      if (state.user.role === 'Admin') return true
      // Checar permissão específica
      if (!state.user.permissions) return false
      const permissionKey = permission as keyof typeof state.user.permissions
      return !!(state.user.permissions[permissionKey] === true)
    }
  }, [state.user])

  // Verificar se é admin - memoizado
  const isAdmin = useMemo(() => state.user?.role === 'Admin', [state.user?.role])
  
  // Verificar se é manager - memoizado (mantido para compatibilidade)
  const isManager = useMemo(() => state.user?.role === 'Admin', [state.user?.role])

  // Login com email/senha
  const signIn = useCallback(async (email: string, password: string) => {
    // Exibir erro salvo do logout anterior, se houver
    const savedError = localStorage.getItem('authError');
    if (savedError) {
      setState(prev => ({ ...prev, error: savedError }));
      localStorage.removeItem('authError');
      return;
    }

    try {
      setState(prev => ({ ...prev, loading: true, error: null }))

      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email: email.toLowerCase(),
        password
      })

      if (authError) throw authError

      if (!authData.user) {
        throw new Error('Usuário não encontrado')
      }

      const employee = await checkEmployeeAccess(authData.user.id)

      setState({
        loading: false,
        isAuthenticated: true,
        user: employee,
        error: null
      })

      // Redirecionar para a rota raiz (dashboard)
      navigate('/', { replace: true })
    } catch (error) {
      console.error('Erro no login:', error)
      setState(prev => ({
        ...prev,
        loading: false,
        isAuthenticated: false,
        user: null,
        error: error instanceof Error ? error.message : 'Erro ao fazer login'
      }))
    }
  }, [navigate, checkEmployeeAccess])

  // Registro de novo usuário
  const signUp = useCallback(async (email: string, password: string, userData: Partial<Employee>) => {
    try {
      setState(prev => ({ ...prev, loading: true, error: null }))

      // 1. Criar usuário no auth
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email: email.toLowerCase(),
        password,
        options: {
          emailRedirectTo: `${window.location.origin}/auth/callback`,
          data: {
            name: userData.name,
            role: userData.role || 'User',
            tenant_id: userData.tenant_id
          }
        }
      })

      if (authError) throw authError

      if (!authData.user) {
        throw new Error('Erro ao criar usuário')
      }

      // 2. Criar registro na tabela employees
      const { error: employeeError } = await supabase
        .from('employees')
        .insert([{
          id: authData.user.id, // Usar o mesmo ID do auth (já é string)
          name: userData.name || '',
          role: userData.role || 'User',
          tenant_id: userData.tenant_id || '00000000-0000-0000-0000-000000000001',
          contact_info: userData.contact_info || { email: email.toLowerCase() },
          permissions: userData.permissions || {},
          roles_extra: userData.roles_extra || [],
          active: userData.active !== false, // Padrão true
        }])

      if (employeeError) {
        console.error('Erro ao criar funcionário:', employeeError)
        // Se falhar ao criar o funcionário, tentar deletar o usuário do auth
        try {
          await supabase.auth.admin.deleteUser(authData.user.id)
        } catch (deleteError) {
          console.error('Erro ao deletar usuário do auth após falha:', deleteError)
        }
        throw new Error('Erro ao criar registro do funcionário')
      }

      setState({
        loading: false,
        isAuthenticated: false,
        user: null,
        error: null
      })

      return { success: true, message: 'Usuário criado com sucesso! Verifique seu email para confirmar o cadastro.' }
    } catch (error) {
      console.error('Erro no registro:', error)
      setState(prev => ({
        ...prev,
        loading: false,
        isAuthenticated: false,
        user: null,
        error: error instanceof Error ? error.message : 'Erro ao registrar usuário'
      }))
      throw error
    }
  }, [])

  // Logout
  const signOut = useCallback(async () => {
    try {
      setState(prev => ({ ...prev, loading: true }))
      
      const { error } = await supabase.auth.signOut()
      if (error) throw error

      // Limpar cache ao fazer logout
      employeeCache.clear()

      setState({
        loading: false,
        isAuthenticated: false,
        user: null,
        error: null
      })

      navigate('/login')
    } catch (error) {
      console.error('Erro ao fazer logout:', error)
      setState(prev => ({
        ...prev,
        loading: false,
        error: error instanceof Error ? error.message : 'Erro ao fazer logout'
      }))
    }
  }, [navigate])

  // Verificar sessão atual - memoizado para evitar re-execuções desnecessárias
  useEffect(() => {
    let isMounted = true

    const checkSession = async () => {
      try {
        if (!isMounted) return
        
        setState(prev => ({ ...prev, loading: true }))
        const { data: { session }, error } = await supabase.auth.getSession()
        
        if (!isMounted) return
        
        if (error) throw error

        if (session?.user) {
          console.log('🔍 Verificando sessão para usuário:', session.user.id)
          const employee = await checkEmployeeAccess(session.user.id)
          
          if (!isMounted) return
          
          console.log('✅ Dados do funcionário carregados:', employee)
          
          setState({
            loading: false,
            isAuthenticated: true,
            user: employee,
            error: null
          })
        } else {
          console.log('❌ Nenhuma sessão encontrada')
          if (isMounted) {
            setState({
              loading: false,
              isAuthenticated: false,
              user: null,
              error: null
            })
          }
        }
      } catch (error) {
        console.error('Erro ao verificar sessão:', error)
        if (isMounted) {
          setState({
            loading: false,
            isAuthenticated: false,
            user: null,
            error: error instanceof Error ? error.message : 'Erro ao verificar sessão'
          })
        }
      }
    }

    checkSession()

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (!isMounted) return
      
      console.log('🔄 Auth state change:', event, session?.user?.id)
      if (event === 'SIGNED_IN' && session?.user) {
        try {
          setState(prev => ({ ...prev, loading: true }))
          const employee = await checkEmployeeAccess(session.user.id)
          
          if (!isMounted) return
          
          console.log('✅ Funcionário carregado após sign in:', employee)
          setState({
            loading: false,
            isAuthenticated: true,
            user: employee,
            error: null
          })
        } catch (error) {
          console.error('❌ Erro ao carregar funcionário após sign in:', error)
          if (isMounted) {
            setState({
              loading: false,
              isAuthenticated: false,
              user: null,
              error: error instanceof Error ? error.message : 'Erro ao verificar sessão'
            })
          }
        }
      } else if (event === 'SIGNED_OUT') {
        console.log('👋 Usuário deslogado')
        if (isMounted) {
          // Limpar cache ao fazer logout
          employeeCache.clear()
          setState({
            loading: false,
            isAuthenticated: false,
            user: null,
            error: null
          })
        }
      }
    })

    return () => {
      isMounted = false
      subscription.unsubscribe()
    }
  }, [checkEmployeeAccess])

  return {
    loading: state.loading,
    isAuthenticated: state.isAuthenticated,
    user: state.user,
    error: state.error,
    signIn,
    signUp,
    signOut,
    hasPermission,
    isAdmin,
    isManager
  }
}