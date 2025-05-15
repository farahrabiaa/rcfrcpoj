/*
  # Add Product Attributes Support

  1. New Tables
    - `product_attributes`
      - Defines common attributes that can be applied to products
    - `product_attribute_values`
      - Stores predefined values for select-type attributes
    - `product_attribute_assignments`
      - Links products with their attribute values

  2. Security
    - Enable RLS on new tables
    - Add policies for authenticated users
*/

-- Create product_attributes table
CREATE TABLE IF NOT EXISTS product_attributes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid REFERENCES vendors(id),
  name text NOT NULL,
  type text NOT NULL CHECK (type IN ('select', 'text', 'number')),
  required boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create product_attribute_values table
CREATE TABLE IF NOT EXISTS product_attribute_values (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attribute_id uuid REFERENCES product_attributes(id) ON DELETE CASCADE,
  value text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create product_attribute_assignments table
CREATE TABLE IF NOT EXISTS product_attribute_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES products(id) ON DELETE CASCADE,
  attribute_id uuid REFERENCES product_attributes(id) ON DELETE CASCADE,
  value text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE product_attributes ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_attribute_values ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_attribute_assignments ENABLE ROW LEVEL SECURITY;

-- Policies for product_attributes
CREATE POLICY "Product attributes are viewable by everyone"
  ON product_attributes
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can manage their own attributes"
  ON product_attributes
  FOR ALL
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT user_id FROM vendors WHERE id = vendor_id
    )
  );

-- Policies for product_attribute_values
CREATE POLICY "Attribute values are viewable by everyone"
  ON product_attribute_values
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can manage their own attribute values"
  ON product_attribute_values
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM product_attributes pa
      WHERE pa.id = attribute_id
      AND pa.vendor_id IN (
        SELECT id FROM vendors WHERE user_id = auth.uid()
      )
    )
  );

-- Policies for product_attribute_assignments
CREATE POLICY "Attribute assignments are viewable by everyone"
  ON product_attribute_assignments
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can manage their own attribute assignments"
  ON product_attribute_assignments
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM products p
      WHERE p.id = product_id
      AND p.vendor_id IN (
        SELECT id FROM vendors WHERE user_id = auth.uid()
      )
    )
  );

-- Functions for attribute management
CREATE OR REPLACE FUNCTION validate_attribute_value(
  p_attribute_id uuid,
  p_value text
) RETURNS boolean AS $$
DECLARE
  v_attribute product_attributes;
BEGIN
  -- Get attribute
  SELECT * INTO v_attribute
  FROM product_attributes
  WHERE id = p_attribute_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Validate based on type
  CASE v_attribute.type
    WHEN 'select' THEN
      RETURN EXISTS (
        SELECT 1 FROM product_attribute_values
        WHERE attribute_id = p_attribute_id
        AND value = p_value
      );
    WHEN 'number' THEN
      RETURN p_value ~ '^[0-9]+(\.[0-9]+)?$';
    ELSE
      RETURN true; -- Text type accepts any value
  END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get product attributes with values
CREATE OR REPLACE FUNCTION get_product_attributes(
  p_product_id uuid
) RETURNS jsonb AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', pa.id,
      'name', pa.name,
      'type', pa.type,
      'required', pa.required,
      'value', paa.value,
      'available_values', CASE
        WHEN pa.type = 'select' THEN (
          SELECT jsonb_agg(value)
          FROM product_attribute_values
          WHERE attribute_id = pa.id
        )
        ELSE NULL
      END
    )
  )
  INTO v_result
  FROM product_attributes pa
  LEFT JOIN product_attribute_assignments paa ON paa.attribute_id = pa.id
  WHERE paa.product_id = p_product_id;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;