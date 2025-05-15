/*
  # Create Shipping Methods Table

  1. New Tables
    - `shipping_zones`
      - Shipping zones for different delivery areas
    - `shipping_methods`
      - Shipping methods with different delivery types and settings
      
  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Create shipping_zones table
CREATE TABLE IF NOT EXISTS shipping_zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid REFERENCES auth.users ON DELETE CASCADE,
  name text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create shipping_methods table
CREATE TABLE IF NOT EXISTS shipping_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_id uuid REFERENCES shipping_zones(id) ON DELETE CASCADE,
  name text NOT NULL,
  cost numeric NOT NULL DEFAULT 0,
  min_amount numeric,
  max_amount numeric,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT min_max_check CHECK (min_amount IS NULL OR max_amount IS NULL OR min_amount <= max_amount)
);

-- Enable RLS
ALTER TABLE shipping_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipping_methods ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$
BEGIN
  DROP POLICY IF EXISTS "Vendors can read own shipping zones" ON shipping_zones;
  DROP POLICY IF EXISTS "Vendors can create own shipping zones" ON shipping_zones;
  DROP POLICY IF EXISTS "Vendors can update own shipping zones" ON shipping_zones;
  DROP POLICY IF EXISTS "Vendors can delete own shipping zones" ON shipping_zones;
  
  DROP POLICY IF EXISTS "Anyone can read shipping methods" ON shipping_methods;
  DROP POLICY IF EXISTS "Vendors can create shipping methods for own zones" ON shipping_methods;
  DROP POLICY IF EXISTS "Vendors can update shipping methods for own zones" ON shipping_methods;
  DROP POLICY IF EXISTS "Vendors can delete shipping methods for own zones" ON shipping_methods;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create policies for shipping_zones
CREATE POLICY "Vendors can read own shipping zones"
  ON shipping_zones
  FOR SELECT
  TO authenticated
  USING (auth.uid() = vendor_id);

CREATE POLICY "Vendors can create own shipping zones"
  ON shipping_zones
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = vendor_id);

CREATE POLICY "Vendors can update own shipping zones"
  ON shipping_zones
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = vendor_id)
  WITH CHECK (auth.uid() = vendor_id);

CREATE POLICY "Vendors can delete own shipping zones"
  ON shipping_zones
  FOR DELETE
  TO authenticated
  USING (auth.uid() = vendor_id);

-- Create policies for shipping_methods
CREATE POLICY "Anyone can read shipping methods"
  ON shipping_methods
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can create shipping methods for own zones"
  ON shipping_methods
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM shipping_zones
      WHERE shipping_zones.id = shipping_methods.zone_id
      AND shipping_zones.vendor_id = auth.uid()
    )
  );

CREATE POLICY "Vendors can update shipping methods for own zones"
  ON shipping_methods
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM shipping_zones
      WHERE shipping_zones.id = shipping_methods.zone_id
      AND shipping_zones.vendor_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM shipping_zones
      WHERE shipping_zones.id = shipping_methods.zone_id
      AND shipping_zones.vendor_id = auth.uid()
    )
  );

CREATE POLICY "Vendors can delete shipping methods for own zones"
  ON shipping_methods
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM shipping_zones
      WHERE shipping_zones.id = shipping_methods.zone_id
      AND shipping_zones.vendor_id = auth.uid()
    )
  );

-- Create triggers to update updated_at column if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_shipping_zones_updated_at'
    AND tgrelid = 'shipping_zones'::regclass
  ) THEN
    CREATE TRIGGER update_shipping_zones_updated_at
      BEFORE UPDATE ON shipping_zones
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_shipping_methods_updated_at'
    AND tgrelid = 'shipping_methods'::regclass
  ) THEN
    CREATE TRIGGER update_shipping_methods_updated_at
      BEFORE UPDATE ON shipping_methods
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
  END IF;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Insert some sample data
INSERT INTO shipping_zones (name, vendor_id) VALUES 
  ('المنطقة الشمالية', NULL),
  ('المنطقة الوسطى', NULL),
  ('المنطقة الجنوبية', NULL)
ON CONFLICT DO NOTHING;

-- Insert sample shipping methods
INSERT INTO shipping_methods (name, zone_id, cost) 
VALUES 
  (
    'توصيل حسب المسافة', 
    (SELECT id FROM shipping_zones WHERE name = 'المنطقة الشمالية' LIMIT 1), 
    10
  ),
  (
    'توصيل بسعر ثابت', 
    (SELECT id FROM shipping_zones WHERE name = 'المنطقة الوسطى' LIMIT 1), 
    15
  ),
  (
    'توصيل حسب المناطق', 
    (SELECT id FROM shipping_zones WHERE name = 'المنطقة الجنوبية' LIMIT 1), 
    0
  )
ON CONFLICT DO NOTHING;