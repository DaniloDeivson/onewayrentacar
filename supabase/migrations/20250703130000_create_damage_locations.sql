-- Migration: Criar tabela de localizações de danos (damage_locations)
CREATE TABLE IF NOT EXISTS damage_locations (
  id serial PRIMARY KEY,
  name text NOT NULL UNIQUE
);

-- Inserir localizações padrão
INSERT INTO damage_locations (name) VALUES
  ('Porta dianteira esquerda'),
  ('Porta dianteira direita'),
  ('Porta traseira esquerda'),
  ('Porta traseira direita'),
  ('Para-choque dianteiro'),
  ('Para-choque traseiro'),
  ('Capô'),
  ('Teto'),
  ('Porta-malas'),
  ('Retrovisor esquerdo'),
  ('Retrovisor direito'),
  ('Farol esquerdo'),
  ('Farol direito'),
  ('Lanterna esquerda'),
  ('Lanterna direita'),
  ('Vidro dianteiro'),
  ('Vidro traseiro'),
  ('Roda dianteira esquerda'),
  ('Roda dianteira direita'),
  ('Roda traseira esquerda'),
  ('Roda traseira direita'); 