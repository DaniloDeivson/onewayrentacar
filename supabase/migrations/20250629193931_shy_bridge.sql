/*
  # Add document column to suppliers table

  1. Changes
    - Add `document` column to `suppliers` table to store CNPJ/CPF information
    - Column allows NULL values since it's optional
    - Add index for better query performance

  2. Security
    - No changes to RLS policies needed as the column follows the same tenant isolation pattern
*/

-- Add document column to suppliers table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'suppliers' AND column_name = 'document'
  ) THEN
    ALTER TABLE suppliers ADD COLUMN document text;
  END IF;
END $$;

-- Add index for document column for better search performance
CREATE INDEX IF NOT EXISTS idx_suppliers_document ON suppliers(document);