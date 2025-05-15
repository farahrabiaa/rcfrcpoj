-- Add auto_charge and wallet_enabled columns to vendors table if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'vendors' 
    AND column_name = 'auto_charge'
  ) THEN
    ALTER TABLE vendors ADD COLUMN auto_charge boolean DEFAULT false;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'vendors' 
    AND column_name = 'wallet_enabled'
  ) THEN
    ALTER TABLE vendors ADD COLUMN wallet_enabled boolean DEFAULT false;
  END IF;
END
$$;

-- Update RLS policies for vendors table
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$
BEGIN
  DROP POLICY IF EXISTS "Vendors are viewable by everyone" ON vendors;
  DROP POLICY IF EXISTS "Vendors can update their own info" ON vendors;
  DROP POLICY IF EXISTS "Public can view active vendors" ON vendors;
  DROP POLICY IF EXISTS "Vendors can update their own data" ON vendors;
  DROP POLICY IF EXISTS "Admins can manage all vendors" ON vendors;
  DROP POLICY IF EXISTS "Users can create their own vendor" ON vendors;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create new policies
CREATE POLICY "Public can view active vendors" 
  ON vendors
  FOR SELECT 
  TO public
  USING (status = 'active');

CREATE POLICY "Vendors are viewable by everyone" 
  ON vendors
  FOR SELECT 
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can update their own data" 
  ON vendors
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can manage all vendors" 
  ON vendors
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_users
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create their own vendor" 
  ON vendors
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Create function to update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for vendors table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_vendors_updated_at'
  ) THEN
    CREATE TRIGGER update_vendors_updated_at
    BEFORE UPDATE ON vendors
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
  END IF;
EXCEPTION
  WHEN undefined_table THEN
    NULL;
END
$$;