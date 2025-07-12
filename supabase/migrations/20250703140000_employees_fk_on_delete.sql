-- Migration: Ajustar FKs para permitir exclusão real de funcionários/usuários

-- Exemplo: Ajustar employee_id em service_notes para ON DELETE SET NULL
ALTER TABLE service_notes DROP CONSTRAINT IF EXISTS service_notes_employee_id_fkey;
ALTER TABLE service_notes ADD CONSTRAINT service_notes_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL;

-- Exemplo: Ajustar employee_id em inspections para ON DELETE SET NULL
ALTER TABLE inspections DROP CONSTRAINT IF EXISTS inspections_employee_id_fkey;
ALTER TABLE inspections ADD CONSTRAINT inspections_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL;

-- Exemplo: Ajustar salesperson_id em contracts para ON DELETE SET NULL
ALTER TABLE contracts DROP CONSTRAINT IF EXISTS contracts_salesperson_id_fkey;
ALTER TABLE contracts ADD CONSTRAINT contracts_salesperson_id_fkey FOREIGN KEY (salesperson_id) REFERENCES employees(id) ON DELETE SET NULL;

-- Exemplo: Ajustar employee_id em fines para ON DELETE SET NULL
ALTER TABLE fines DROP CONSTRAINT IF EXISTS fines_employee_id_fkey;
ALTER TABLE fines ADD CONSTRAINT fines_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL;

-- Exemplo: Ajustar created_by_employee_id em costs para ON DELETE SET NULL
ALTER TABLE costs DROP CONSTRAINT IF EXISTS costs_created_by_employee_id_fkey;
ALTER TABLE costs ADD CONSTRAINT costs_created_by_employee_id_fkey FOREIGN KEY (created_by_employee_id) REFERENCES employees(id) ON DELETE SET NULL;

-- Exemplo: Ajustar driver_id e employee_id em multas para ON DELETE SET NULL
ALTER TABLE fines DROP CONSTRAINT IF EXISTS fines_driver_id_fkey;
ALTER TABLE fines ADD CONSTRAINT fines_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES employees(id) ON DELETE SET NULL;

-- Exemplo: Ajustar driver_id e employee_id em outras tabelas, se existirem
-- Repita para todas as FKs que referenciam employees 