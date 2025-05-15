/*
  # Add addons_data column to products table

  1. Changes
    - Add addons_data column to products table to store product add-ons as JSON
    - Create index on addons_data for better query performance
*/

-- Add addons_data column to products table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'products' 
    AND column_name = 'addons_data'
  ) THEN
    ALTER TABLE products ADD COLUMN addons_data jsonb DEFAULT NULL;
  END IF;
END
$$;

-- Create index on addons_data for better performance
CREATE INDEX IF NOT EXISTS idx_products_addons_data ON products USING GIN (addons_data);

-- Enable RLS on products table
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$
BEGIN
  DROP POLICY IF EXISTS "Products are viewable by everyone" ON products;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create new policies
CREATE POLICY "Products are viewable by everyone"
  ON products
  FOR SELECT
  TO public
  USING (true);