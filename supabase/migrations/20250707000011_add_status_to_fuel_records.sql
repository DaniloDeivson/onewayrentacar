ALTER TABLE fuel_records
ADD COLUMN status TEXT NOT NULL DEFAULT 'Pendente' CHECK (status IN ('Pendente', 'Aprovado', 'Rejeitado')); 