/*
  # Create Dependent Tables

  1. New Tables
    - `products`
      - Product information
    - `product_addons`
      - Product add-ons and options
    - `orders`
      - Order information
    - `order_items`
      - Order line items
    - `wallets`
      - User wallet information
    - `wallet_transactions`
      - Wallet transaction history
    - `ratings`
      - User ratings and reviews
    
  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Create products table
CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid REFERENCES vendors(id) ON DELETE CASCADE NOT NULL,
  category_id uuid REFERENCES categories(id),
  name text NOT NULL,
  description text,
  price decimal(10,2) NOT NULL,
  wholesale_price decimal(10,2),
  discount_price decimal(10,2),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'draft')),
  stock int DEFAULT 0,
  image_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create product_addons table
CREATE TABLE IF NOT EXISTS product_addons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES products(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  price decimal(10,2) NOT NULL DEFAULT 0.00,
  is_default boolean DEFAULT false,
  is_required boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid REFERENCES customers(id) NOT NULL,
  vendor_id uuid REFERENCES vendors(id) NOT NULL,
  driver_id uuid REFERENCES drivers(id),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'processing', 'ready', 'delivering', 'completed', 'rejected', 'cancelled')),
  total decimal(10,2) NOT NULL,
  subtotal decimal(10,2) NOT NULL,
  delivery_fee decimal(10,2) NOT NULL DEFAULT 0,
  payment_method text NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash', 'electronic', 'wallet')),
  notes text,
  address text,
  latitude decimal(10,8),
  longitude decimal(11,8),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create order_items table
CREATE TABLE IF NOT EXISTS order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  product_id uuid REFERENCES products(id) NOT NULL,
  quantity int NOT NULL DEFAULT 1,
  price decimal(10,2) NOT NULL,
  addons_data jsonb,
  created_at timestamptz DEFAULT now()
);

-- Create wallets table
CREATE TABLE IF NOT EXISTS wallets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL UNIQUE,
  balance decimal(10,2) DEFAULT 0.00,
  available_balance decimal(10,2) DEFAULT 0.00,
  pending_balance decimal(10,2) DEFAULT 0.00,
  last_transaction timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create wallet_transactions table
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id uuid REFERENCES wallets(id) ON DELETE CASCADE NOT NULL,
  order_id uuid REFERENCES orders(id),
  amount decimal(10,2) NOT NULL,
  type text NOT NULL CHECK (type IN ('credit', 'debit')),
  payment_type text NOT NULL CHECK (payment_type IN ('cash', 'electronic', 'wallet', 'withdrawal', 'commission')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
  description text,
  created_at timestamptz DEFAULT now()
);

-- Create ratings table
CREATE TABLE IF NOT EXISTS ratings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) NOT NULL,
  from_type text NOT NULL CHECK (from_type IN ('customer', 'vendor', 'driver')),
  from_id uuid NOT NULL,
  to_type text NOT NULL CHECK (to_type IN ('customer', 'vendor', 'driver')),
  to_id uuid NOT NULL,
  rating int NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment text,
  created_at timestamptz DEFAULT now()
);

-- Create advertisements table
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
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_addons ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE advertisements ENABLE ROW LEVEL SECURITY;

-- Policies for products
CREATE POLICY "Products are viewable by everyone"
  ON products
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can manage their own products"
  ON products
  FOR ALL
  TO authenticated
  USING (vendor_id IN (SELECT id FROM vendors WHERE user_id = auth.uid()));

-- Policies for product_addons
CREATE POLICY "Product addons are viewable by everyone"
  ON product_addons
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can manage their own product addons"
  ON product_addons
  FOR ALL
  TO authenticated
  USING (
    product_id IN (
      SELECT id FROM products WHERE vendor_id IN (
        SELECT id FROM vendors WHERE user_id = auth.uid()
      )
    )
  );

-- Policies for orders
CREATE POLICY "Vendors can view their own orders"
  ON orders
  FOR SELECT
  TO authenticated
  USING (vendor_id IN (SELECT id FROM vendors WHERE user_id = auth.uid()));

CREATE POLICY "Drivers can view their assigned orders"
  ON orders
  FOR SELECT
  TO authenticated
  USING (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()));

CREATE POLICY "Customers can view their own orders"
  ON orders
  FOR SELECT
  TO authenticated
  USING (customer_id IN (SELECT id FROM customers WHERE user_id = auth.uid()));

-- Policies for order_items
CREATE POLICY "Order items are viewable by related parties"
  ON order_items
  FOR SELECT
  TO authenticated
  USING (
    order_id IN (
      SELECT id FROM orders WHERE 
        vendor_id IN (SELECT id FROM vendors WHERE user_id = auth.uid()) OR
        driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()) OR
        customer_id IN (SELECT id FROM customers WHERE user_id = auth.uid())
    )
  );

-- Policies for wallets
CREATE POLICY "Users can view their own wallet"
  ON wallets
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Policies for wallet_transactions
CREATE POLICY "Users can view their own wallet transactions"
  ON wallet_transactions
  FOR SELECT
  TO authenticated
  USING (
    wallet_id IN (
      SELECT id FROM wallets WHERE user_id = auth.uid()
    )
  );

-- Policies for ratings
CREATE POLICY "Ratings are viewable by everyone"
  ON ratings
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can create ratings"
  ON ratings
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Policies for advertisements
CREATE POLICY "Advertisements are viewable by everyone"
  ON advertisements
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can manage their own advertisements"
  ON advertisements
  FOR ALL
  TO authenticated
  USING (vendor_id IN (SELECT id FROM vendors WHERE user_id = auth.uid()));

-- Create function to update ratings
CREATE OR REPLACE FUNCTION update_rating_average()
RETURNS TRIGGER AS $$
DECLARE
  v_table_name text;
  v_avg_rating decimal(3,2);
  v_count int;
BEGIN
  -- Determine which table to update based on to_type
  v_table_name := 'vendors';
  IF NEW.to_type = 'driver' THEN
    v_table_name := 'drivers';
  ELSIF NEW.to_type = 'customer' THEN
    v_table_name := 'customers';
  END IF;
  
  -- Calculate new average rating and count
  EXECUTE format('
    SELECT 
      AVG(rating)::decimal(3,2), 
      COUNT(*)
    FROM ratings 
    WHERE to_type = %L AND to_id = %L
  ', NEW.to_type, NEW.to_id) INTO v_avg_rating, v_count;
  
  -- Update the appropriate table
  EXECUTE format('
    UPDATE %I
    SET rating = %L, rating_count = %L
    WHERE id = %L
  ', v_table_name, v_avg_rating, v_count, NEW.to_id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for ratings
CREATE TRIGGER update_rating_after_insert
  AFTER INSERT ON ratings
  FOR EACH ROW
  EXECUTE FUNCTION update_rating_average();

-- Create function to get ratings report
CREATE OR REPLACE FUNCTION get_ratings_report(p_type text, p_year int)
RETURNS TABLE (
  month int,
  avg_rating decimal(3,2),
  count int
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    EXTRACT(MONTH FROM created_at)::int as month,
    AVG(rating)::decimal(3,2) as avg_rating,
    COUNT(*) as count
  FROM ratings
  WHERE to_type = p_type
  AND EXTRACT(YEAR FROM created_at) = p_year
  GROUP BY month
  ORDER BY month;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get financial summary
CREATE OR REPLACE FUNCTION get_financial_summary()
RETURNS jsonb AS $$
DECLARE
  v_total_sales decimal;
  v_electronic_payments decimal;
  v_cash_payments decimal;
  v_admin_commissions decimal;
  v_vendor_balances decimal;
  v_driver_balances decimal;
  v_result jsonb;
BEGIN
  -- Get total sales
  SELECT COALESCE(SUM(total), 0) INTO v_total_sales FROM orders;
  
  -- Get electronic payments
  SELECT COALESCE(SUM(total), 0) INTO v_electronic_payments 
  FROM orders 
  WHERE payment_method = 'electronic';
  
  -- Get cash payments
  SELECT COALESCE(SUM(total), 0) INTO v_cash_payments 
  FROM orders 
  WHERE payment_method = 'cash';
  
  -- Get admin commissions
  SELECT COALESCE(SUM(amount), 0) INTO v_admin_commissions 
  FROM wallet_transactions 
  WHERE payment_type = 'commission';
  
  -- Get vendor balances
  SELECT COALESCE(SUM(balance), 0) INTO v_vendor_balances 
  FROM wallets 
  WHERE user_id IN (SELECT user_id FROM vendors);
  
  -- Get driver balances
  SELECT COALESCE(SUM(balance), 0) INTO v_driver_balances 
  FROM wallets 
  WHERE user_id IN (SELECT user_id FROM drivers);
  
  -- Build result
  v_result := jsonb_build_object(
    'total_sales', v_total_sales,
    'electronic_payments', v_electronic_payments,
    'cash_payments', v_cash_payments,
    'admin_commissions', v_admin_commissions,
    'vendor_balances', v_vendor_balances,
    'driver_balances', v_driver_balances
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;