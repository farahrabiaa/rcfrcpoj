/*
  # Fix Vendor Deletion Issue

  1. Changes
    - Update RLS policies to allow vendor deletion
    - Add explicit policy for deleting vendors
*/

-- Enable RLS
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$
BEGIN
  DROP POLICY IF EXISTS "Public can view active vendors" ON vendors;
  DROP POLICY IF EXISTS "Vendors are viewable by everyone" ON vendors;
  DROP POLICY IF EXISTS "Vendors can update their own data" ON vendors;
  DROP POLICY IF EXISTS "Users can create their own vendor" ON vendors;
  DROP POLICY IF EXISTS "Anyone can delete vendors" ON vendors;
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
  TO public
  USING (true);

CREATE POLICY "Users can create their own vendor" 
  ON vendors
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Vendors can update their own data" 
  ON vendors
  FOR UPDATE
  TO public
  USING (true);

-- Add explicit policy for deleting vendors
CREATE POLICY "Anyone can delete vendors" 
  ON vendors
  FOR DELETE
  TO public
  USING (true);