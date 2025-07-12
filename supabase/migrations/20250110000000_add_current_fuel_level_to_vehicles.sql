-- Adicionar campo current_fuel_level à tabela vehicles
-- Este campo armazena o nível atual de combustível do veículo (0-100)

ALTER TABLE public.vehicles 
ADD COLUMN current_fuel_level numeric(5,2) DEFAULT 0 CHECK (current_fuel_level >= 0 AND current_fuel_level <= 100);

-- Adicionar comentário ao campo
COMMENT ON COLUMN public.vehicles.current_fuel_level IS 'Nível atual de combustível do veículo em porcentagem (0-100)';

-- Criar índice para otimizar consultas por nível de combustível
CREATE INDEX IF NOT EXISTS idx_vehicles_current_fuel_level ON public.vehicles(current_fuel_level);

-- Atualizar trigger para incluir o novo campo
DROP TRIGGER IF EXISTS simple_vehicle_trigger ON vehicles;
CREATE TRIGGER simple_vehicle_trigger 
BEFORE INSERT OR UPDATE ON vehicles 
FOR EACH ROW 
EXECUTE FUNCTION simple_vehicle_trigger(); 