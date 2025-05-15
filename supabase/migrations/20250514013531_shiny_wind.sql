/*
  # Create Vendor Categories Table

  1. New Tables
    - `vendor_categories_table` - A table to store vendor categories
      - `id` (uuid, primary key) - Unique identifier for the category
      - `name` (text) - Name of the category
      - `description` (text) - Description of the category
      - `image_url` (text) - URL to the category image
      - `slug` (text) - URL-friendly version of the name
      - `created_at` (timestamptz) - Creation timestamp
      - `updated_at` (timestamptz) - Last update timestamp
  
  2. Security
    - Enable RLS on the table
    - Add policies for public access
*/

-- Create the vendor categories table
CREATE TABLE IF NOT EXISTS vendor_categories_table (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  image_url text,
  slug text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create index on slug for faster lookups
CREATE INDEX IF NOT EXISTS idx_vendor_categories_table_slug ON vendor_categories_table(slug);

-- Enable Row Level Security
ALTER TABLE vendor_categories_table ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Vendor categories are viewable by everyone" 
  ON vendor_categories_table
  FOR SELECT 
  TO public 
  USING (true);

CREATE POLICY "Admins can manage vendor categories" 
  ON vendor_categories_table
  FOR ALL 
  TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM admin_users 
      WHERE admin_users.user_id = auth.uid()
    )
  );

-- Create trigger to update the updated_at column
CREATE TRIGGER update_vendor_categories_table_updated_at
BEFORE UPDATE ON vendor_categories_table
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Create a junction table for vendor to category relationships
CREATE TABLE IF NOT EXISTS vendor_to_category (
  vendor_id uuid REFERENCES vendors(id) ON DELETE CASCADE,
  category_id uuid REFERENCES vendor_categories_table(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (vendor_id, category_id)
);

-- Enable Row Level Security on junction table
ALTER TABLE vendor_to_category ENABLE ROW LEVEL SECURITY;

-- Create policies for junction table
CREATE POLICY "Vendor to category relationships are viewable by everyone" 
  ON vendor_to_category
  FOR SELECT 
  TO public 
  USING (true);

CREATE POLICY "Admins can manage vendor to category relationships" 
  ON vendor_to_category
  FOR ALL 
  TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM admin_users 
      WHERE admin_users.user_id = auth.uid()
    )
  );

-- Insert some initial categories
INSERT INTO vendor_categories_table (name, description, slug)
VALUES 
  ('مطاعم', 'جميع أنواع المطاعم والمأكولات', 'restaurants'),
  ('ماركت', 'محلات البقالة والسوبر ماركت', 'markets')
ON CONFLICT (id) DO NOTHING;