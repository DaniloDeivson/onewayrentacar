-- Adicionar campos estimated_cost e repaired à tabela inspection_damages
-- Para suportar orçamentos de danos e controle de reparo

ALTER TABLE public.inspection_damages 
ADD COLUMN estimated_cost numeric(10,2) DEFAULT 0 CHECK (estimated_cost >= 0),
ADD COLUMN repaired boolean DEFAULT false,
ADD COLUMN observations text;

-- Adicionar comentários aos campos
COMMENT ON COLUMN public.inspection_damages.estimated_cost IS 'Custo estimado para reparo do dano';
COMMENT ON COLUMN public.inspection_damages.repaired IS 'Indica se o dano foi reparado';
COMMENT ON COLUMN public.inspection_damages.observations IS 'Observações sobre o dano ou reparo';

-- Criar índices para otimizar consultas
CREATE INDEX IF NOT EXISTS idx_inspection_damages_estimated_cost ON public.inspection_damages(estimated_cost);
CREATE INDEX IF NOT EXISTS idx_inspection_damages_repaired ON public.inspection_damages(repaired); 