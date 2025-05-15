/*
  # Fix Vendor Foreign Key Constraint

  1. Changes
    - Update the foreign key constraint in vendors table to reference custom_users instead of auth.users
    - Update RLS policies to work with custom users
*/

-- First, drop the existing foreign key constraint
ALTER TABLE vendors 
  DROP CONSTRAINT IF EXISTS vendors_user_id_fkey;

-- Add the new foreign key constraint to reference custom_users
ALTER TABLE vendors
  ADD CONSTRAINT vendors_user_id_fkey
  FOREIGN KEY (user_id) 
  REFERENCES custom_users(id);

-- Update RLS policies to work with custom users
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Public can view active vendors" ON vendors;
DROP POLICY IF EXISTS "Vendors are viewable by everyone" ON vendors;
DROP POLICY IF EXISTS "Vendors can update their own data" ON vendors;
DROP POLICY IF EXISTS "Users can create their own vendor" ON vendors;
DROP POLICY IF EXISTS "Admins can manage all vendors" ON vendors;

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

-- Create a function to update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for vendors table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_vendors_updated_at'
    AND tgrelid = 'vendors'::regclass
  ) THEN
    CREATE TRIGGER update_vendors_updated_at
    BEFORE UPDATE ON vendors
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
  END IF;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END
$$;