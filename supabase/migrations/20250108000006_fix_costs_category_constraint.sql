-- Corrigir constraint da categoria na tabela costs
-- Adicionar "Aluguel de Veículo" como categoria válida

-- Remover a constraint existente
ALTER TABLE costs DROP CONSTRAINT IF EXISTS costs_category_check;

-- Adicionar a nova constraint com todas as categorias válidas
ALTER TABLE costs ADD CONSTRAINT costs_category_check 
  CHECK (category IN (
    'Multa', 'Funilaria', 'Seguro', 'Avulsa', 'Compra', 'Excesso Km', 
    'Diária Extra', 'Combustível', 'Avaria', 'Manutenção', 'Aluguel de Veículo'
  ));

-- Verificar se a constraint foi aplicada corretamente
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'costs'::regclass 
AND conname = 'costs_category_check'; 