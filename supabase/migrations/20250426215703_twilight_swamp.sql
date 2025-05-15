-- Create advertisements table if it doesn't exist
CREATE TABLE IF NOT EXISTS advertisements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  vendor_id uuid REFERENCES vendors(id) NOT NULL,
  image_url text NOT NULL,
  link text,
  start_date date NOT NULL,
  end_date date NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'pending', 'active', 'expired')),
  type text NOT NULL DEFAULT 'banner' CHECK (type IN ('banner', 'popup', 'slider')),
  position text NOT NULL DEFAULT 'home' CHECK (position IN ('home', 'category', 'product', 'checkout')),
  priority int NOT NULL DEFAULT 1,
  clicks int NOT NULL DEFAULT 0,
  views int NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE advertisements ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$
BEGIN
  DROP POLICY IF EXISTS "Advertisements are viewable by everyone" ON advertisements;
  DROP POLICY IF EXISTS "Vendors can manage their own advertisements" ON advertisements;
  DROP POLICY IF EXISTS "Public can view active advertisements" ON advertisements;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create new policies
CREATE POLICY "Advertisements are viewable by everyone"
  ON advertisements
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Public can view active advertisements"
  ON advertisements
  FOR SELECT
  TO public
  USING (
    status = 'active' AND 
    start_date <= CURRENT_DATE AND 
    end_date >= CURRENT_DATE
  );

CREATE POLICY "Vendors can manage their own advertisements"
  ON advertisements
  FOR ALL
  TO authenticated
  USING (
    vendor_id IN (
      SELECT id FROM vendors
      WHERE vendors.user_id = auth.uid()
    )
  );

-- Create trigger for advertisements table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_advertisements_updated_at'
    AND tgrelid = 'advertisements'::regclass
  ) THEN
    CREATE TRIGGER update_advertisements_updated_at
      BEFORE UPDATE ON advertisements
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
  END IF;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create function to increment advertisement views
CREATE OR REPLACE FUNCTION increment_advertisement_views(p_ad_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE advertisements
  SET views = views + 1
  WHERE id = p_ad_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to increment advertisement clicks
CREATE OR REPLACE FUNCTION increment_advertisement_clicks(p_ad_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE advertisements
  SET clicks = clicks + 1
  WHERE id = p_ad_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get active advertisements by position
CREATE OR REPLACE FUNCTION get_active_advertisements(p_position text)
RETURNS SETOF advertisements AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM advertisements
  WHERE 
    status = 'active' AND 
    start_date <= CURRENT_DATE AND 
    end_date >= CURRENT_DATE AND
    (p_position IS NULL OR position = p_position)
  ORDER BY priority ASC, created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert sample advertisements if none exist
DO $$
DECLARE
  v_vendor_id uuid;
BEGIN
  -- Check if there are any advertisements
  IF NOT EXISTS (SELECT 1 FROM advertisements LIMIT 1) THEN
    -- Get a vendor ID
    SELECT id INTO v_vendor_id FROM vendors LIMIT 1;
    
    -- Only insert if we found a vendor
    IF v_vendor_id IS NOT NULL THEN
      INSERT INTO advertisements (
        title, 
        description, 
        vendor_id, 
        image_url, 
        link, 
        start_date, 
        end_date, 
        status, 
        type, 
        position, 
        priority
      ) VALUES (
        'عرض خاص',
        'خصم 20% على جميع المنتجات',
        v_vendor_id,
        'https://images.unsplash.com/photo-1509042239860-f550ce710b93?q=80&w=1000&auto=format&fit=crop',
        '/products',
        CURRENT_DATE,
        CURRENT_DATE + INTERVAL '30 days',
        'active',
        'banner',
        'home',
        1
      );
    END IF;
  END IF;
END $$;