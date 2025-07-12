-- Migration: Add contract_number column to contracts table
-- Date: 2025-07-05 14:00:00

ALTER TABLE contracts ADD COLUMN contract_number TEXT UNIQUE; 