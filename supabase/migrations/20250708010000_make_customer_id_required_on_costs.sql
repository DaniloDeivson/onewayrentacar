-- Torna customer_id obrigatório na tabela costs
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'costs' AND column_name = 'customer_id'
  ) THEN
    -- Atualiza registros antigos sem cliente para um valor padrão ou NULL (ajuste conforme necessário)
    -- UPDATE costs SET customer_id = '<algum_id>' WHERE customer_id IS NULL;
    -- Torna a coluna obrigatória
    ALTER TABLE costs ALTER COLUMN customer_id SET NOT NULL;
  END IF;
END $$; 