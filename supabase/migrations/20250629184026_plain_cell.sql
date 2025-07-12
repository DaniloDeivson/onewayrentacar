/*
  # Melhorias no Módulo de Multas

  1. Adicionar colunas faltantes na tabela fines
    - document_ref (referência do documento)
    - observations (observações)
  
  2. Atualizar constraints para incluir tipos de infração predefinidos
  
  3. Corrigir integração com painel de custos
*/

-- Adicionar colunas faltantes na tabela fines se não existirem
DO $$
BEGIN
  -- Adicionar document_ref se não existir
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fines' AND column_name = 'document_ref'
  ) THEN
    ALTER TABLE fines ADD COLUMN document_ref text;
  END IF;
  
  -- Adicionar observations se não existir
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fines' AND column_name = 'observations'
  ) THEN
    ALTER TABLE fines ADD COLUMN observations text;
  END IF;
END $$;

-- Atualizar constraint para tipos de infração predefinidos
ALTER TABLE fines DROP CONSTRAINT IF EXISTS fines_infraction_type_check;

ALTER TABLE fines ADD CONSTRAINT fines_infraction_type_check 
CHECK (infraction_type IN (
  'Excesso de velocidade',
  'Estacionamento irregular',
  'Avanço de sinal vermelho',
  'Uso de celular ao volante',
  'Não uso do cinto de segurança',
  'Dirigir sem CNH',
  'Ultrapassagem proibida',
  'Estacionamento em vaga de deficiente',
  'Não parar na faixa de pedestres',
  'Dirigir sob efeito de álcool',
  'Transitar na contramão',
  'Estacionamento em local proibido',
  'Não respeitar distância de segurança',
  'Trafegar no acostamento',
  'Conversão proibida',
  'Parar sobre a faixa de pedestres',
  'Estacionamento em fila dupla',
  'Não dar preferência ao pedestre',
  'Velocidade incompatível com o local',
  'Outros'
));

-- Atualizar função de pós-processamento para incluir as novas colunas
CREATE OR REPLACE FUNCTION fn_fine_postprocess()
RETURNS TRIGGER AS $$
DECLARE
  v_driver_name text;
  v_vehicle_plate text;
BEGIN
  -- Buscar dados do motorista e veículo
  SELECT e.name INTO v_driver_name
  FROM employees e
  WHERE e.id = NEW.driver_id;
  
  SELECT v.plate INTO v_vehicle_plate
  FROM vehicles v
  WHERE v.id = NEW.vehicle_id;
  
  -- Criar custo automático para a multa
  INSERT INTO costs (
    tenant_id,
    category,
    vehicle_id,
    description,
    amount,
    cost_date,
    status,
    document_ref,
    observations,
    origin,
    created_by_employee_id,
    source_reference_id,
    source_reference_type
  ) VALUES (
    NEW.tenant_id,
    'Multa',
    NEW.vehicle_id,
    CONCAT('Multa ', NEW.fine_number, ' - ', NEW.infraction_type),
    NEW.amount,
    NEW.infraction_date,
    'Pendente',
    NEW.document_ref,
    CONCAT(
      'Motorista responsável: ', COALESCE(v_driver_name, 'Não informado'), 
      ' | Veículo: ', COALESCE(v_vehicle_plate, 'N/A'),
      CASE WHEN NEW.observations IS NOT NULL THEN ' | Obs: ' || NEW.observations ELSE '' END
    ),
    'Sistema',
    NEW.employee_id,
    NEW.id,
    'fine'
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recriar view para multas detalhadas com as novas colunas
DROP VIEW IF EXISTS vw_fines_detailed;

CREATE VIEW vw_fines_detailed AS
SELECT 
  f.id,
  f.tenant_id,
  f.vehicle_id,
  v.plate as vehicle_plate,
  v.model as vehicle_model,
  v.year as vehicle_year,
  f.driver_id,
  d.name as driver_name,
  d.employee_code as driver_code,
  f.employee_id,
  e.name as created_by_name,
  e.role as created_by_role,
  f.fine_number,
  f.infraction_type,
  f.amount,
  f.infraction_date,
  f.due_date,
  f.notified,
  f.status,
  f.document_ref,
  f.observations,
  f.created_at,
  f.updated_at,
  -- Campos calculados
  CASE 
    WHEN f.due_date < CURRENT_DATE AND f.status = 'Pendente' THEN true
    ELSE false
  END as is_overdue,
  CURRENT_DATE - f.due_date as days_overdue
FROM fines f
LEFT JOIN vehicles v ON v.id = f.vehicle_id
LEFT JOIN employees d ON d.id = f.driver_id
LEFT JOIN employees e ON e.id = f.employee_id;