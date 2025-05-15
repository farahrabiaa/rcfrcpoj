/*
  # Create Basic Tables

  1. New Tables
    - `profiles`
      - User profiles with role information
    - `vendors`
      - Vendor information and settings
    - `drivers`
      - Driver information and settings
    - `customers`
      - Customer information
    - `categories`
      - Product categories
    
  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  name text,
  role text NOT NULL CHECK (role IN ('admin', 'vendor', 'driver', 'customer')),
  phone text,
  email text,
  avatar_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create vendors table
CREATE TABLE IF NOT EXISTS vendors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  store_name text NOT NULL,
  phone text,
  address text,
  description text,
  rating decimal(3,2) DEFAULT 5.00,
  rating_count int DEFAULT 0,
  commission_rate decimal(5,2) DEFAULT 10.00,
  delivery_type text NOT NULL DEFAULT 'distance' CHECK (delivery_type IN ('distance', 'fixed', 'zones')),
  delivery_radius decimal(10,2),
  price_per_km decimal(10,2),
  latitude decimal(10,8),
  longitude decimal(11,8),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'pending', 'suspended')),
  logo_url text,
  banner_url text,
  featured_until timestamptz,
  featured_order int,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create drivers table
CREATE TABLE IF NOT EXISTS drivers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  name text NOT NULL,
  phone text,
  email text,
  status text NOT NULL DEFAULT 'offline' CHECK (status IN ('offline', 'available', 'busy')),
  rating decimal(3,2) DEFAULT 5.00,
  rating_count int DEFAULT 0,
  commission_rate decimal(5,2) DEFAULT 15.00,
  latitude decimal(10,8),
  longitude decimal(11,8),
  last_location_update timestamptz,
  vehicle_type text,
  vehicle_model text,
  vehicle_year text,
  vehicle_plate text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create customers table
CREATE TABLE IF NOT EXISTS customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users,
  name text NOT NULL,
  phone text NOT NULL,
  email text,
  address text,
  notes text,
  rating decimal(3,2) DEFAULT 5.00,
  rating_count int DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create categories table
CREATE TABLE IF NOT EXISTS categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE NOT NULL,
  parent_id uuid REFERENCES categories(id),
  description text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create vendor_categories table
CREATE TABLE IF NOT EXISTS vendor_categories (
  vendor_id uuid REFERENCES vendors(id) ON DELETE CASCADE,
  category_id uuid REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (vendor_id, category_id)
);

-- Create admin_users table
CREATE TABLE IF NOT EXISTS admin_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL UNIQUE,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

-- Policies for profiles
CREATE POLICY "Users can view their own profile"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- Policies for vendors
CREATE POLICY "Vendors are viewable by everyone"
  ON vendors
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can update their own info"
  ON vendors
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Policies for drivers
CREATE POLICY "Drivers are viewable by everyone"
  ON drivers
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Drivers can update their own info"
  ON drivers
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Policies for customers
CREATE POLICY "Customers are viewable by everyone"
  ON customers
  FOR SELECT
  TO authenticated
  USING (true);

-- Policies for categories
CREATE POLICY "Categories are viewable by everyone" 
  ON categories
  FOR SELECT 
  TO authenticated 
  USING (true);

-- Policies for vendor_categories
CREATE POLICY "Vendor categories are viewable by everyone" 
  ON vendor_categories
  FOR SELECT 
  TO authenticated 
  USING (true);

-- Insert default categories
INSERT INTO categories (name, slug, description)
VALUES 
  ('مطاعم', 'restaurants', 'جميع أنواع المطاعم والمأكولات'),
  ('سوبر ماركت', 'supermarkets', 'محلات البقالة والسوبر ماركت'),
  ('مشروبات ساخنة', 'hot-beverages', 'القهوة والشاي والمشروبات الساخنة'),
  ('عصائر', 'juices', 'العصائر الطازجة والمشروبات الباردة'),
  ('حلويات', 'desserts', 'الحلويات والكيك');

-- Create function to handle user registration
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, name, role, email)
  VALUES (new.id, new.raw_user_meta_data->>'name', 
          COALESCE(new.raw_user_meta_data->>'role', 'customer'),
          new.email);
  
  -- If role is admin, add to admin_users
  IF (new.raw_user_meta_data->>'role' = 'admin') THEN
    INSERT INTO admin_users (user_id) VALUES (new.id);
  END IF;
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user registration
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();