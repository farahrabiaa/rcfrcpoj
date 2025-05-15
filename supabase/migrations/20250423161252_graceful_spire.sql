-- Add auto_charge column to vendors table if it doesn't exist
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

-- Check if policies exist before attempting to create them
DO $$
BEGIN
  -- Drop existing policies if they exist
  DROP POLICY IF EXISTS "Public can view active vendors" ON vendors;
  DROP POLICY IF EXISTS "Vendors are viewable by everyone" ON vendors;
  DROP POLICY IF EXISTS "Vendors can update their own data" ON vendors;
  DROP POLICY IF EXISTS "Users can create their own vendor" ON vendors;
  
  -- Check if "Admins can manage all vendors" policy exists before creating it
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'vendors' 
    AND policyname = 'Admins can manage all vendors'
  ) THEN
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
  END IF;
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
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can create their own vendor" 
  ON vendors
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);