/*
  # Add Delivery Methods Support

  1. New Tables
    - `delivery_methods`
      - Predefined delivery methods that vendors can use
    - `vendor_delivery_methods`
      - Links vendors with their enabled delivery methods and custom settings

  2. Security
    - Enable RLS on new tables
    - Add policies for authenticated users
*/

-- Create delivery_methods table
CREATE TABLE IF NOT EXISTS delivery_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  type text NOT NULL CHECK (type IN ('distance', 'fixed', 'zones')),
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create vendor_delivery_methods table
CREATE TABLE IF NOT EXISTS vendor_delivery_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid REFERENCES vendors(id) ON DELETE CASCADE,
  method_id uuid REFERENCES delivery_methods(id) ON DELETE CASCADE,
  is_enabled boolean DEFAULT true,
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  -- Distance-based settings
  price_per_km decimal(10,2),
  min_distance decimal(10,2),
  max_distance decimal(10,2),
  base_fee decimal(10,2),
  -- Fixed price settings
  fixed_price decimal(10,2),
  -- Zone-based settings
  zones jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (vendor_id, method_id)
);

-- Enable RLS
ALTER TABLE delivery_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_delivery_methods ENABLE ROW LEVEL SECURITY;

-- Policies for delivery_methods
CREATE POLICY "Delivery methods are viewable by everyone"
  ON delivery_methods
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can modify delivery methods"
  ON delivery_methods
  FOR ALL
  TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

-- Policies for vendor_delivery_methods
CREATE POLICY "Vendor delivery methods are viewable by everyone"
  ON vendor_delivery_methods
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can manage their own delivery methods"
  ON vendor_delivery_methods
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM vendors v
      WHERE v.id = vendor_id
      AND v.user_id = auth.uid()
    )
  );

-- Insert default delivery methods
INSERT INTO delivery_methods (
  name,
  description,
  type,
  settings,
  status
) VALUES 
(
  'توصيل حسب المسافة',
  'حساب سعر التوصيل بناءً على المسافة',
  'distance',
  jsonb_build_object(
    'min_distance', 1,
    'max_distance', 20,
    'base_fee', 5,
    'price_per_km', 2
  ),
  'active'
),
(
  'توصيل بسعر ثابت',
  'سعر توصيل ثابت لجميع الطلبات',
  'fixed',
  jsonb_build_object(
    'fixed_price', 10
  ),
  'active'
),
(
  'توصيل حسب المنطقة',
  'أسعار توصيل مختلفة لكل منطقة',
  'zones',
  jsonb_build_object(
    'zones', jsonb_build_array(
      jsonb_build_object(
        'name', 'المنطقة أ',
        'price', 10
      ),
      jsonb_build_object(
        'name', 'المنطقة ب',
        'price', 15
      ),
      jsonb_build_object(
        'name', 'المنطقة ج',
        'price', 20
      )
    )
  ),
  'active'
);

-- Functions for delivery methods
CREATE OR REPLACE FUNCTION calculate_delivery_fee(
  p_vendor_id uuid,
  p_method_id uuid,
  p_distance decimal DEFAULT NULL,
  p_zone text DEFAULT NULL
) RETURNS decimal AS $$
DECLARE
  v_method vendor_delivery_methods;
  v_fee decimal;
BEGIN
  -- Get vendor's delivery method settings
  SELECT * INTO v_method
  FROM vendor_delivery_methods
  WHERE vendor_id = p_vendor_id
  AND method_id = p_method_id
  AND is_enabled = true;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- Calculate fee based on method type
  CASE (
    SELECT type FROM delivery_methods WHERE id = v_method.method_id
  )
    WHEN 'distance' THEN
      IF p_distance IS NULL THEN
        RETURN NULL;
      END IF;

      -- Check distance limits
      IF p_distance < v_method.min_distance OR 
         (v_method.max_distance IS NOT NULL AND p_distance > v_method.max_distance) THEN
        RETURN NULL;
      END IF;

      -- Calculate distance-based fee
      v_fee := v_method.base_fee + (p_distance * v_method.price_per_km);

    WHEN 'fixed' THEN
      v_fee := v_method.fixed_price;

    WHEN 'zones' THEN
      IF p_zone IS NULL THEN
        RETURN NULL;
      END IF;

      -- Get zone price
      SELECT (zone->>'price')::decimal INTO v_fee
      FROM jsonb_array_elements(v_method.zones) AS zone
      WHERE zone->>'name' = p_zone;

    ELSE
      RETURN NULL;
  END CASE;

  RETURN v_fee;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get available delivery methods for a vendor
CREATE OR REPLACE FUNCTION get_vendor_delivery_methods(
  p_vendor_id uuid
) RETURNS jsonb AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', dm.id,
      'name', dm.name,
      'description', dm.description,
      'type', dm.type,
      'settings', dm.settings,
      'vendor_settings', vdm.settings,
      'is_enabled', vdm.is_enabled,
      'price_per_km', vdm.price_per_km,
      'min_distance', vdm.min_distance,
      'max_distance', vdm.max_distance,
      'base_fee', vdm.base_fee,
      'fixed_price', vdm.fixed_price,
      'zones', vdm.zones
    )
  )
  INTO v_result
  FROM delivery_methods dm
  LEFT JOIN vendor_delivery_methods vdm ON vdm.method_id = dm.id
  WHERE dm.status = 'active'
  AND (vdm.vendor_id = p_vendor_id OR vdm.vendor_id IS NULL);

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;