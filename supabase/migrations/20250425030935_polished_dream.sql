/*
  # Add addons_data to products table

  1. Changes
    - Add addons_data column to products table
    - This column will store JSON data for product addons
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

-- Create function to get products with addons
CREATE OR REPLACE FUNCTION get_product_with_addons(p_product_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_product jsonb;
  v_addons jsonb;
BEGIN
  -- Get product
  SELECT row_to_json(p)::jsonb INTO v_product
  FROM (
    SELECT * FROM products WHERE id = p_product_id
  ) p;
  
  -- Get addons from addons_data column
  SELECT addons_data INTO v_addons
  FROM products
  WHERE id = p_product_id;
  
  -- Return product with addons
  RETURN v_product;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;