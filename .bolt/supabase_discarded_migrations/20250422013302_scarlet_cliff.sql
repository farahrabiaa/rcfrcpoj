/*
  # Initial Schema Setup

  1. New Tables
    - `profiles`
      - User profiles with roles
    - `vendors`
      - Vendor information
    - `drivers`
      - Driver information
    - `customers`
      - Customer information
    - `products`
      - Product information
    - `orders`
      - Order information
    - `order_items`
      - Order items
    - `ratings`
      - Ratings for vendors, drivers, and customers
    - `wallets`
      - Wallet information
    - `wallet_transactions`
      - Wallet transactions
    - `advertisements`
      - Advertisements

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  name TEXT,
  role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('admin', 'vendor', 'driver', 'customer')),
  phone TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create vendors table
CREATE TABLE IF NOT EXISTS vendors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users NOT NULL,
  store_name TEXT NOT NULL,
  phone TEXT,
  address TEXT,
  description TEXT,
  rating DECIMAL(3,2) DEFAULT 5.00,
  rating_count INT DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('open', 'closed', 'busy', 'suspended')),
  commission_rate DECIMAL(5,2) DEFAULT 10.00,
  delivery_type TEXT NOT NULL DEFAULT 'distance' CHECK (delivery_type IN ('distance', 'fixed', 'zones')),
  delivery_radius DECIMAL(10,2),
  price_per_km DECIMAL(10,2),
  min_order DECIMAL(10,2) DEFAULT 0.00,
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  logo_url TEXT,
  banner_url TEXT,
  featured_until TIMESTAMPTZ,
  featured_order INT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create drivers table
CREATE TABLE IF NOT EXISTS drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  status TEXT DEFAULT 'offline' CHECK (status IN ('available', 'busy', 'offline', 'suspended')),
  rating DECIMAL(3,2) DEFAULT 5.00,
  rating_count INT DEFAULT 0,
  commission_rate DECIMAL(5,2) DEFAULT 15.00,
  vehicle_type TEXT,
  vehicle_model TEXT,
  vehicle_year TEXT,
  vehicle_plate TEXT,
  working_areas TEXT[],
  id_card_url TEXT,
  license_url TEXT,
  insurance_url TEXT,
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  last_location_update TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create customers table
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users NOT NULL,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  address TEXT,
  email TEXT,
  notes TEXT,
  rating DECIMAL(3,2) DEFAULT 5.00,
  rating_count INT DEFAULT 0,
  points INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create products table
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID REFERENCES vendors NOT NULL,
  category_id UUID,
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  discount_price DECIMAL(10,2),
  wholesale_price DECIMAL(10,2),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  stock INT DEFAULT 0,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers NOT NULL,
  vendor_id UUID REFERENCES vendors NOT NULL,
  driver_id UUID REFERENCES drivers,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'processing', 'delivering', 'completed', 'rejected', 'cancelled')),
  total DECIMAL(10,2) NOT NULL,
  payment_method TEXT NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash', 'electronic')),
  delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  discount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  coupon_code TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create order_items table
CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders NOT NULL,
  product_id UUID REFERENCES products NOT NULL,
  variant_id UUID,
  quantity INT NOT NULL DEFAULT 1,
  price DECIMAL(10,2) NOT NULL,
  addons_data JSONB,
  attributes_data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create ratings table
CREATE TABLE IF NOT EXISTS ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders NOT NULL,
  from_type TEXT NOT NULL CHECK (from_type IN ('customer', 'vendor', 'driver')),
  from_id UUID NOT NULL,
  to_type TEXT NOT NULL CHECK (to_type IN ('customer', 'vendor', 'driver')),
  to_id UUID NOT NULL,
  rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create wallets table
CREATE TABLE IF NOT EXISTS wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users NOT NULL,
  user_type TEXT NOT NULL CHECK (user_type IN ('vendor', 'driver', 'customer')),
  balance DECIMAL(10,2) DEFAULT 0.00,
  available_balance DECIMAL(10,2) DEFAULT 0.00,
  pending_balance DECIMAL(10,2) DEFAULT 0.00,
  last_transaction TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create wallet_transactions table
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID REFERENCES wallets NOT NULL,
  order_id UUID REFERENCES orders,
  amount DECIMAL(10,2) NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('credit', 'debit', 'commission')),
  payment_type TEXT NOT NULL CHECK (payment_type IN ('cash', 'electronic', 'withdrawal', 'refund')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create advertisements table
CREATE TABLE IF NOT EXISTS advertisements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  vendor_id UUID REFERENCES vendors NOT NULL,
  image_url TEXT NOT NULL,
  link TEXT,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'pending', 'active', 'expired')),
  type TEXT NOT NULL DEFAULT 'banner' CHECK (type IN ('banner', 'popup', 'slider')),
  position TEXT NOT NULL DEFAULT 'home' CHECK (position IN ('home', 'category', 'product', 'checkout')),
  priority INT NOT NULL DEFAULT 1,
  clicks INT NOT NULL DEFAULT 0,
  views INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create vendor_hours table
CREATE TABLE IF NOT EXISTS vendor_hours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID REFERENCES vendors NOT NULL,
  day_of_week TEXT NOT NULL CHECK (day_of_week IN ('sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday')),
  open_time TIME,
  close_time TIME,
  is_closed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(vendor_id, day_of_week)
);

-- Create vendor_drivers table
CREATE TABLE IF NOT EXISTS vendor_drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID REFERENCES vendors NOT NULL,
  driver_id UUID REFERENCES drivers NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(vendor_id, driver_id)
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE advertisements ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_drivers ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view their own profile"
  ON profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- Vendors policies
CREATE POLICY "Vendors are viewable by everyone"
  ON vendors FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can update their own data"
  ON vendors FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Drivers policies
CREATE POLICY "Drivers are viewable by everyone"
  ON drivers FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Drivers can update their own data"
  ON drivers FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Customers policies
CREATE POLICY "Customers are viewable by everyone"
  ON customers FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Customers can update their own data"
  ON customers FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Products policies
CREATE POLICY "Products are viewable by everyone"
  ON products FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can manage their own products"
  ON products FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM vendors
      WHERE vendors.id = vendor_id
      AND vendors.user_id = auth.uid()
    )
  );

-- Orders policies
CREATE POLICY "Orders are viewable by related parties"
  ON orders FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT user_id FROM customers WHERE id = customer_id
      UNION
      SELECT user_id FROM vendors WHERE id = vendor_id
      UNION
      SELECT user_id FROM drivers WHERE id = driver_id
    )
    OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Order items policies
CREATE POLICY "Order items are viewable by related parties"
  ON order_items FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_id
      AND (
        orders.customer_id IN (SELECT id FROM customers WHERE user_id = auth.uid())
        OR
        orders.vendor_id IN (SELECT id FROM vendors WHERE user_id = auth.uid())
        OR
        orders.driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid())
      )
    )
    OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Ratings policies
CREATE POLICY "Ratings are viewable by everyone"
  ON ratings FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can create ratings"
  ON ratings FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Wallets policies
CREATE POLICY "Users can view their own wallet"
  ON wallets FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Wallet transactions policies
CREATE POLICY "Users can view their own transactions"
  ON wallet_transactions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM wallets
      WHERE wallets.id = wallet_id
      AND wallets.user_id = auth.uid()
    )
  );

-- Advertisements policies
CREATE POLICY "Advertisements are viewable by everyone"
  ON advertisements FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can manage their own advertisements"
  ON advertisements FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM vendors
      WHERE vendors.id = vendor_id
      AND vendors.user_id = auth.uid()
    )
    OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Vendor hours policies
CREATE POLICY "Vendor hours are viewable by everyone"
  ON vendor_hours FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can manage their own hours"
  ON vendor_hours FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM vendors
      WHERE vendors.id = vendor_id
      AND vendors.user_id = auth.uid()
    )
  );

-- Vendor drivers policies
CREATE POLICY "Vendor drivers are viewable by related parties"
  ON vendor_drivers FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM vendors
      WHERE vendors.id = vendor_id
      AND vendors.user_id = auth.uid()
    )
    OR
    EXISTS (
      SELECT 1 FROM drivers
      WHERE drivers.id = driver_id
      AND drivers.user_id = auth.uid()
    )
  );

CREATE POLICY "Vendors can manage their own drivers"
  ON vendor_drivers FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM vendors
      WHERE vendors.id = vendor_id
      AND vendors.user_id = auth.uid()
    )
  );

-- Create functions for ratings
CREATE OR REPLACE FUNCTION update_rating_after_insert()
RETURNS TRIGGER AS $$
BEGIN
  -- Update vendor rating
  IF NEW.to_type = 'vendor' THEN
    UPDATE vendors
    SET 
      rating = (
        SELECT AVG(rating)
        FROM ratings
        WHERE to_type = 'vendor' AND to_id = NEW.to_id
      ),
      rating_count = (
        SELECT COUNT(*)
        FROM ratings
        WHERE to_type = 'vendor' AND to_id = NEW.to_id
      )
    WHERE id = NEW.to_id;
  END IF;
  
  -- Update driver rating
  IF NEW.to_type = 'driver' THEN
    UPDATE drivers
    SET 
      rating = (
        SELECT AVG(rating)
        FROM ratings
        WHERE to_type = 'driver' AND to_id = NEW.to_id
      ),
      rating_count = (
        SELECT COUNT(*)
        FROM ratings
        WHERE to_type = 'driver' AND to_id = NEW.to_id
      )
    WHERE id = NEW.to_id;
  END IF;
  
  -- Update customer rating
  IF NEW.to_type = 'customer' THEN
    UPDATE customers
    SET 
      rating = (
        SELECT AVG(rating)
        FROM ratings
        WHERE to_type = 'customer' AND to_id = NEW.to_id
      ),
      rating_count = (
        SELECT COUNT(*)
        FROM ratings
        WHERE to_type = 'customer' AND to_id = NEW.to_id
      )
    WHERE id = NEW.to_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for ratings
CREATE TRIGGER update_rating_after_insert
AFTER INSERT ON ratings
FOR EACH ROW
EXECUTE FUNCTION update_rating_after_insert();

-- Create function to get ratings report
CREATE OR REPLACE FUNCTION get_ratings_report(p_type TEXT, p_year INT)
RETURNS TABLE (
  month INT,
  avg_rating DECIMAL(3,2),
  count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(1, 12) AS month
  )
  SELECT 
    m.month,
    COALESCE(AVG(r.rating), 0)::DECIMAL(3,2) AS avg_rating,
    COUNT(r.id) AS count
  FROM months m
  LEFT JOIN ratings r ON 
    EXTRACT(MONTH FROM r.created_at) = m.month AND
    EXTRACT(YEAR FROM r.created_at) = p_year AND
    r.to_type = p_type
  GROUP BY m.month
  ORDER BY m.month;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get financial summary
CREATE OR REPLACE FUNCTION get_financial_summary()
RETURNS JSON AS $$
DECLARE
  v_total_sales DECIMAL;
  v_electronic_payments DECIMAL;
  v_cash_payments DECIMAL;
  v_admin_commissions DECIMAL;
  v_vendor_balances DECIMAL;
  v_driver_balances DECIMAL;
BEGIN
  -- Get total sales
  SELECT COALESCE(SUM(total), 0) INTO v_total_sales
  FROM orders;
  
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
  WHERE type = 'commission';
  
  -- Get vendor balances
  SELECT COALESCE(SUM(balance), 0) INTO v_vendor_balances
  FROM wallets
  WHERE user_type = 'vendor';
  
  -- Get driver balances
  SELECT COALESCE(SUM(balance), 0) INTO v_driver_balances
  FROM wallets
  WHERE user_type = 'driver';
  
  RETURN json_build_object(
    'total_sales', v_total_sales,
    'electronic_payments', v_electronic_payments,
    'cash_payments', v_cash_payments,
    'admin_commissions', v_admin_commissions,
    'vendor_balances', v_vendor_balances,
    'driver_balances', v_driver_balances
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get admin commissions
CREATE OR REPLACE FUNCTION get_admin_commissions()
RETURNS JSON AS $$
DECLARE
  v_total DECIMAL;
  v_from_vendors DECIMAL;
  v_from_drivers DECIMAL;
  v_pending DECIMAL;
  v_monthly JSON;
BEGIN
  -- Get total commissions
  SELECT COALESCE(SUM(amount), 0) INTO v_total
  FROM wallet_transactions
  WHERE type = 'commission';
  
  -- Get commissions from vendors
  SELECT COALESCE(SUM(amount), 0) INTO v_from_vendors
  FROM wallet_transactions wt
  JOIN wallets w ON wt.wallet_id = w.id
  WHERE wt.type = 'commission' AND w.user_type = 'vendor';
  
  -- Get commissions from drivers
  SELECT COALESCE(SUM(amount), 0) INTO v_from_drivers
  FROM wallet_transactions wt
  JOIN wallets w ON wt.wallet_id = w.id
  WHERE wt.type = 'commission' AND w.user_type = 'driver';
  
  -- Get pending commissions
  SELECT COALESCE(SUM(amount), 0) INTO v_pending
  FROM wallet_transactions
  WHERE type = 'commission' AND status = 'pending';
  
  -- Get monthly commissions for current year
  SELECT json_agg(
    json_build_object(
      'month', month,
      'total', total
    )
  ) INTO v_monthly
  FROM (
    SELECT
      EXTRACT(MONTH FROM created_at)::INT AS month,
      COALESCE(SUM(amount), 0) AS total
    FROM wallet_transactions
    WHERE type = 'commission'
    AND EXTRACT(YEAR FROM created_at) = EXTRACT(YEAR FROM CURRENT_DATE)
    GROUP BY month
    ORDER BY month
  ) AS monthly_data;
  
  RETURN json_build_object(
    'total', v_total,
    'from_vendors', v_from_vendors,
    'from_drivers', v_from_drivers,
    'pending', v_pending,
    'monthly', v_monthly
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get vendor balances
CREATE OR REPLACE FUNCTION get_vendor_balances()
RETURNS JSON AS $$
DECLARE
  v_total DECIMAL;
  v_available DECIMAL;
  v_pending DECIMAL;
  v_monthly JSON;
BEGIN
  -- Get total vendor balances
  SELECT COALESCE(SUM(balance), 0) INTO v_total
  FROM wallets
  WHERE user_type = 'vendor';
  
  -- Get available balances
  SELECT COALESCE(SUM(available_balance), 0) INTO v_available
  FROM wallets
  WHERE user_type = 'vendor';
  
  -- Get pending balances
  SELECT COALESCE(SUM(pending_balance), 0) INTO v_pending
  FROM wallets
  WHERE user_type = 'vendor';
  
  -- Get monthly balances for current year
  SELECT json_agg(
    json_build_object(
      'month', month,
      'total', total
    )
  ) INTO v_monthly
  FROM (
    SELECT
      EXTRACT(MONTH FROM wt.created_at)::INT AS month,
      COALESCE(SUM(wt.amount), 0) AS total
    FROM wallet_transactions wt
    JOIN wallets w ON wt.wallet_id = w.id
    WHERE w.user_type = 'vendor'
    AND wt.type = 'credit'
    AND EXTRACT(YEAR FROM wt.created_at) = EXTRACT(YEAR FROM CURRENT_DATE)
    GROUP BY month
    ORDER BY month
  ) AS monthly_data;
  
  RETURN json_build_object(
    'total', v_total,
    'available', v_available,
    'pending', v_pending,
    'monthly', v_monthly
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get driver balances
CREATE OR REPLACE FUNCTION get_driver_balances()
RETURNS JSON AS $$
DECLARE
  v_total DECIMAL;
  v_available DECIMAL;
  v_pending DECIMAL;
  v_monthly JSON;
BEGIN
  -- Get total driver balances
  SELECT COALESCE(SUM(balance), 0) INTO v_total
  FROM wallets
  WHERE user_type = 'driver';
  
  -- Get available balances
  SELECT COALESCE(SUM(available_balance), 0) INTO v_available
  FROM wallets
  WHERE user_type = 'driver';
  
  -- Get pending balances
  SELECT COALESCE(SUM(pending_balance), 0) INTO v_pending
  FROM wallets
  WHERE user_type = 'driver';
  
  -- Get monthly balances for current year
  SELECT json_agg(
    json_build_object(
      'month', month,
      'total', total
    )
  ) INTO v_monthly
  FROM (
    SELECT
      EXTRACT(MONTH FROM wt.created_at)::INT AS month,
      COALESCE(SUM(wt.amount), 0) AS total
    FROM wallet_transactions wt
    JOIN wallets w ON wt.wallet_id = w.id
    WHERE w.user_type = 'driver'
    AND wt.type = 'credit'
    AND EXTRACT(YEAR FROM wt.created_at) = EXTRACT(YEAR FROM CURRENT_DATE)
    GROUP BY month
    ORDER BY month
  ) AS monthly_data;
  
  RETURN json_build_object(
    'total', v_total,
    'available', v_available,
    'pending', v_pending,
    'monthly', v_monthly
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to withdraw from wallet
CREATE OR REPLACE FUNCTION withdraw_from_wallet(p_wallet_id UUID, p_amount DECIMAL)
RETURNS JSON AS $$
DECLARE
  v_wallet wallets;
  v_transaction_id UUID;
BEGIN
  -- Get wallet
  SELECT * INTO v_wallet
  FROM wallets
  WHERE id = p_wallet_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Wallet not found'
    );
  END IF;
  
  -- Check if enough balance
  IF v_wallet.available_balance < p_amount THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Insufficient balance'
    );
  END IF;
  
  -- Create transaction
  INSERT INTO wallet_transactions (
    wallet_id,
    amount,
    type,
    payment_type,
    status,
    description
  ) VALUES (
    p_wallet_id,
    p_amount,
    'debit',
    'withdrawal',
    'pending',
    'Withdrawal request'
  ) RETURNING id INTO v_transaction_id;
  
  -- Update wallet
  UPDATE wallets
  SET
    available_balance = available_balance - p_amount,
    last_transaction = NOW(),
    updated_at = NOW()
  WHERE id = p_wallet_id;
  
  RETURN json_build_object(
    'success', true,
    'transaction_id', v_transaction_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to create order
CREATE OR REPLACE FUNCTION create_order(order_data JSON)
RETURNS UUID AS $$
DECLARE
  v_order_id UUID;
  v_item JSON;
BEGIN
  -- Insert order
  INSERT INTO orders (
    customer_id,
    vendor_id,
    total,
    payment_method,
    delivery_fee,
    discount,
    coupon_code,
    notes
  ) VALUES (
    (order_data->>'customer_id')::UUID,
    (order_data->>'vendor_id')::UUID,
    (order_data->>'total')::DECIMAL,
    order_data->>'payment_method',
    (order_data->>'delivery_fee')::DECIMAL,
    (order_data->>'discount')::DECIMAL,
    order_data->>'coupon_code',
    order_data->>'notes'
  ) RETURNING id INTO v_order_id;
  
  -- Insert order items
  FOR v_item IN SELECT * FROM json_array_elements(order_data->'items')
  LOOP
    INSERT INTO order_items (
      order_id,
      product_id,
      variant_id,
      quantity,
      price,
      addons_data,
      attributes_data
    ) VALUES (
      v_order_id,
      (v_item->>'product_id')::UUID,
      (v_item->>'variant_id')::UUID,
      (v_item->>'quantity')::INT,
      (v_item->>'price')::DECIMAL,
      v_item->'addons_data',
      v_item->'attributes_data'
    );
  END LOOP;
  
  RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert admin user
INSERT INTO auth.users (id, email, role)
VALUES ('00000000-0000-0000-0000-000000000000', 'admin@example.com', 'authenticated')
ON CONFLICT (id) DO NOTHING;

INSERT INTO profiles (id, name, role)
VALUES ('00000000-0000-0000-0000-000000000000', 'مدير النظام', 'admin')
ON CONFLICT (id) DO NOTHING;