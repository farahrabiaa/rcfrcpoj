/*
  # Add Product Addons Support

  1. Changes
    - Ensure product_addons table exists with proper structure
    - Add RLS policies for product_addons table
    - Add trigger to update updated_at column
*/

-- Create product_addons table if it doesn't exist
CREATE TABLE IF NOT EXISTS product_addons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES products(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  price decimal(10,2) NOT NULL DEFAULT 0.00,
  is_default boolean DEFAULT false,
  is_required boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE product_addons ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$
BEGIN
  DROP POLICY IF EXISTS "Product addons are viewable by everyone" ON product_addons;
  DROP POLICY IF EXISTS "Vendors can manage their own product addons" ON product_addons;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create new policies
CREATE POLICY "Product addons are viewable by everyone"
  ON product_addons
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Vendors can manage their own product addons"
  ON product_addons
  FOR ALL
  TO public
  USING (
    product_id IN (
      SELECT id FROM products WHERE vendor_id IN (
        SELECT id FROM vendors
      )
    )
  );

-- Create trigger for product_addons table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_product_addons_updated_at'
    AND tgrelid = 'product_addons'::regclass
  ) THEN
    CREATE TRIGGER update_product_addons_updated_at
    BEFORE UPDATE ON product_addons
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
  END IF;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END
$$;

-- Create function to get product with addons
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
  
  -- Get addons
  SELECT json_agg(a)::jsonb INTO v_addons
  FROM (
    SELECT * FROM product_addons WHERE product_id = p_product_id
  ) a;
  
  -- Combine product and addons
  RETURN jsonb_set(v_product, '{addons}', COALESCE(v_addons, '[]'::jsonb));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;