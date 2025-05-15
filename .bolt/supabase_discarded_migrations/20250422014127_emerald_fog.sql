/*
  # Wallet System Implementation

  1. New Tables
    - `orders`
      - Base table for all orders in the system
    - `wallet_transactions`
      - Tracks all wallet transactions
    - `delivery_payments`
      - Handles payment processing for deliveries

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Create orders table first
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid REFERENCES auth.users NOT NULL,
  vendor_id uuid REFERENCES auth.users NOT NULL,
  driver_id uuid REFERENCES auth.users,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'processing', 'delivering', 'completed', 'cancelled')),
  total decimal(10,2) NOT NULL,
  delivery_fee decimal(10,2) NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create wallet_transactions table
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  order_id uuid REFERENCES orders,
  amount decimal(10,2) NOT NULL,
  type text NOT NULL CHECK (type IN ('credit', 'debit')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
  description text,
  created_at timestamptz DEFAULT now()
);

-- Create delivery_payments table
CREATE TABLE IF NOT EXISTS delivery_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders NOT NULL,
  payment_type text NOT NULL CHECK (payment_type IN ('cash', 'wallet')),
  amount decimal(10,2) NOT NULL,
  delivery_fee decimal(10,2) NOT NULL,
  vendor_amount decimal(10,2) NOT NULL,
  driver_amount decimal(10,2) NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_payments ENABLE ROW LEVEL SECURITY;

-- Policies for orders
CREATE POLICY "Users can view their own orders"
  ON orders
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = customer_id OR 
    auth.uid() = vendor_id OR 
    auth.uid() = driver_id
  );

CREATE POLICY "Customers can create orders"
  ON orders
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "Vendors and drivers can update their orders"
  ON orders
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = vendor_id OR auth.uid() = driver_id);

-- Policies for wallet_transactions
CREATE POLICY "Users can view their own transactions"
  ON wallet_transactions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert transactions"
  ON wallet_transactions
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Policies for delivery_payments
CREATE POLICY "Vendors and drivers can view their related payments"
  ON delivery_payments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_id
      AND (o.vendor_id = auth.uid() OR o.driver_id = auth.uid())
    )
  );

-- Functions for payment processing
CREATE OR REPLACE FUNCTION process_cash_payment(
  p_order_id uuid,
  p_amount decimal,
  p_delivery_fee decimal
) RETURNS uuid AS $$
DECLARE
  v_payment_id uuid;
  v_vendor_amount decimal;
  v_driver_amount decimal;
BEGIN
  -- Calculate amounts
  v_vendor_amount := p_amount;
  v_driver_amount := p_delivery_fee;
  
  -- Create payment record
  INSERT INTO delivery_payments (
    order_id,
    payment_type,
    amount,
    delivery_fee,
    vendor_amount,
    driver_amount,
    status
  ) VALUES (
    p_order_id,
    'cash',
    p_amount,
    p_delivery_fee,
    v_vendor_amount,
    v_driver_amount,
    'pending'
  ) RETURNING id INTO v_payment_id;

  -- Create vendor transaction
  INSERT INTO wallet_transactions (
    user_id,
    order_id,
    amount,
    type,
    description
  )
  SELECT 
    o.vendor_id,
    p_order_id,
    v_vendor_amount,
    'credit',
    'مبلغ الطلب - دفع نقدي'
  FROM orders o
  WHERE o.id = p_order_id;

  -- Create driver transaction
  INSERT INTO wallet_transactions (
    user_id,
    order_id,
    amount,
    type,
    description
  )
  SELECT 
    o.driver_id,
    p_order_id,
    v_driver_amount,
    'credit',
    'رسوم التوصيل - دفع نقدي'
  FROM orders o
  WHERE o.id = p_order_id;

  RETURN v_payment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION process_wallet_payment(
  p_order_id uuid,
  p_amount decimal,
  p_delivery_fee decimal
) RETURNS uuid AS $$
DECLARE
  v_payment_id uuid;
  v_vendor_amount decimal;
  v_driver_amount decimal;
BEGIN
  -- Calculate amounts
  v_vendor_amount := p_amount + p_delivery_fee;
  v_driver_amount := p_delivery_fee;
  
  -- Create payment record
  INSERT INTO delivery_payments (
    order_id,
    payment_type,
    amount,
    delivery_fee,
    vendor_amount,
    driver_amount,
    status
  ) VALUES (
    p_order_id,
    'wallet',
    p_amount,
    p_delivery_fee,
    v_vendor_amount,
    v_driver_amount,
    'pending'
  ) RETURNING id INTO v_payment_id;

  -- Create vendor transaction
  INSERT INTO wallet_transactions (
    user_id,
    order_id,
    amount,
    type,
    description
  )
  SELECT 
    o.vendor_id,
    p_order_id,
    v_vendor_amount,
    'credit',
    'مبلغ الطلب + التوصيل - دفع محفظة'
  FROM orders o
  WHERE o.id = p_order_id;

  -- Create driver transaction for delivery fee
  INSERT INTO wallet_transactions (
    user_id,
    order_id,
    amount,
    type,
    description
  )
  SELECT 
    o.driver_id,
    p_order_id,
    v_driver_amount,
    'debit',
    'خصم رسوم التوصيل - دفع محفظة'
  FROM orders o
  WHERE o.id = p_order_id;

  RETURN v_payment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;