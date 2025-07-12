-- Drop existing policies
DROP POLICY IF EXISTS "Employees can view their own profile" ON public.employees;
DROP POLICY IF EXISTS "Employees can update their own profile" ON public.employees;
DROP POLICY IF EXISTS "Admins can view all employees" ON public.employees;
DROP POLICY IF EXISTS "Admins can manage employees" ON public.employees;
DROP POLICY IF EXISTS "Only admins can view removed users" ON public.removed_users;
DROP POLICY IF EXISTS "Only admins can manage removed users" ON public.removed_users;

-- Habilitar RLS nas tabelas
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.removed_users ENABLE ROW LEVEL SECURITY;

-- Políticas para employees
CREATE POLICY "Employees can view their own profile"
  ON public.employees
  FOR SELECT
  TO authenticated
  USING (
    id::uuid = auth.uid()
    AND active = true
  );

CREATE POLICY "Employees can update their own profile"
  ON public.employees
  FOR UPDATE
  TO authenticated
  USING (
    id::uuid = auth.uid()
    AND active = true
  )
  WITH CHECK (
    id::uuid = auth.uid()
    AND active = true
  );

CREATE POLICY "Admins can view all employees"
  ON public.employees
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.employees e
      WHERE e.id::uuid = auth.uid()
      AND e.role = 'Admin'
      AND e.active = true
    )
  );

CREATE POLICY "Admins can manage employees"
  ON public.employees
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.employees e
      WHERE e.id::uuid = auth.uid()
      AND e.role = 'Admin'
      AND e.active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.employees e
      WHERE e.id::uuid = auth.uid()
      AND e.role = 'Admin'
      AND e.active = true
    )
  );

-- Políticas para removed_users
CREATE POLICY "Only admins can view removed users"
  ON public.removed_users
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.employees e
      WHERE e.id::uuid = auth.uid()
      AND e.role = 'Admin'
      AND e.active = true
    )
  );

CREATE POLICY "Only admins can manage removed users"
  ON public.removed_users
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.employees e
      WHERE e.id::uuid = auth.uid()
      AND e.role = 'Admin'
      AND e.active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.employees e
      WHERE e.id::uuid = auth.uid()
      AND e.role = 'Admin'
      AND e.active = true
    )
  ); 