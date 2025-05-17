/*
  # Wallet Charging System

  1. New Functions
    - `charge_driver_wallet` - Function to charge a driver's wallet
    - `charge_vendor_wallet` - Function to charge a vendor's wallet
    - `get_wallet_balance` - Function to get wallet balance for any user type
    - `get_wallet_transactions` - Function to get wallet transactions

  2. Security
    - Enable RLS on wallet tables
    - Add policies for wallet access
*/

-- Create wallet_transactions table if it doesn't exist
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL,
  amount NUMERIC NOT NULL,
  type TEXT NOT NULL, -- 'credit' or 'debit'
  payment_type TEXT NOT NULL, -- 'cash', 'electronic', 'admin_charge', 'withdrawal', 'commission', etc.
  status TEXT NOT NULL DEFAULT 'completed',
  description TEXT,
  order_id UUID REFERENCES ord(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT wallet_transactions_type_check CHECK (type IN ('credit', 'debit')),
  CONSTRAINT wallet_transactions_status_check CHECK (status IN ('pending', 'completed', 'failed'))
);

-- Create wallets table if it doesn't exist
CREATE TABLE IF NOT EXISTS wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  balance NUMERIC NOT NULL DEFAULT 0,
  pending_balance NUMERIC NOT NULL DEFAULT 0,
  auto_charge BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT wallets_balance_check CHECK (balance >= 0),
  CONSTRAINT wallets_pending_balance_check CHECK (pending_balance >= 0)
);

-- Create driver_wallets view if it doesn't exist
CREATE OR REPLACE VIEW driver_wallets AS
SELECT 
  w.*,
  d.id AS driver_id,
  d.name,
  d.phone,
  d.email,
  d.status,
  d.rating,
  d.rating_count,
  d.commission_rate,
  (SELECT COUNT(*) FROM ord WHERE driver_id = d.id) AS total_orders,
  (SELECT COUNT(*) FROM ord WHERE driver_id = d.id AND status = 'completed') AS completed_orders,
  (SELECT COALESCE(SUM(total), 0) FROM ord WHERE driver_id = d.id) AS total_earnings
FROM 
  wallets w
  JOIN drivers d ON d.user_id = w.user_id;

-- Create vendor_wallets view if it doesn't exist
CREATE OR REPLACE VIEW vendor_wallets AS
SELECT 
  w.*,
  v.id AS vendor_id,
  v.store_name,
  v.phone,
  v.status,
  v.rating,
  v.rating_count,
  v.commission_rate,
  (SELECT COUNT(*) FROM ord WHERE vendor_id = v.id) AS total_orders,
  (SELECT COALESCE(SUM(total), 0) FROM ord WHERE vendor_id = v.id) AS total_earnings
FROM 
  wallets w
  JOIN vendors v ON v.user_id = w.user_id;

-- Enable RLS on wallet tables
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

-- Create policies for wallets
CREATE POLICY "Users can view their own wallets"
  ON wallets
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Admins can view all wallets"
  ON wallets
  FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

CREATE POLICY "Admins can update wallets"
  ON wallets
  FOR UPDATE
  TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- Create policies for wallet_transactions
CREATE POLICY "Users can view their own wallet transactions"
  ON wallet_transactions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM wallets
      WHERE wallets.id = wallet_transactions.wallet_id
      AND wallets.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can view all wallet transactions"
  ON wallet_transactions
  FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

CREATE POLICY "Admins can insert wallet transactions"
  ON wallet_transactions
  FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- Create function to get wallet balance
CREATE OR REPLACE FUNCTION get_wallet_balance(
  p_user_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_wallet RECORD;
BEGIN
  -- Get wallet
  SELECT * INTO v_wallet
  FROM wallets
  WHERE user_id = p_user_id;
  
  -- If wallet doesn't exist, return zero balance
  IF v_wallet.id IS NULL THEN
    RETURN json_build_object(
      'balance', 0,
      'pending_balance', 0,
      'auto_charge', false,
      'has_wallet', false
    );
  END IF;
  
  -- Return wallet balance
  RETURN json_build_object(
    'balance', v_wallet.balance,
    'pending_balance', v_wallet.pending_balance,
    'auto_charge', v_wallet.auto_charge,
    'has_wallet', true,
    'wallet_id', v_wallet.id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get wallet transactions
CREATE OR REPLACE FUNCTION get_wallet_transactions(
  p_wallet_id UUID,
  p_limit INTEGER DEFAULT 10,
  p_offset INTEGER DEFAULT 0,
  p_type TEXT DEFAULT NULL,
  p_status TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  amount NUMERIC,
  type TEXT,
  payment_type TEXT,
  status TEXT,
  description TEXT,
  order_id UUID,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    wt.id,
    wt.amount,
    wt.type,
    wt.payment_type,
    wt.status,
    wt.description,
    wt.order_id,
    wt.created_at
  FROM 
    wallet_transactions wt
  WHERE 
    wt.wallet_id = p_wallet_id
    AND (p_type IS NULL OR wt.type = p_type)
    AND (p_status IS NULL OR wt.status = p_status)
  ORDER BY 
    wt.created_at DESC
  LIMIT 
    p_limit
  OFFSET 
    p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to charge driver wallet
CREATE OR REPLACE FUNCTION charge_driver_wallet(
  p_driver_id UUID,
  p_amount NUMERIC,
  p_description TEXT DEFAULT 'شحن رصيد',
  p_payment_type TEXT DEFAULT 'admin_charge'
)
RETURNS JSON AS $$
DECLARE
  v_driver RECORD;
  v_wallet_id UUID;
  v_transaction_id UUID;
BEGIN
  -- Check if amount is positive
  IF p_amount <= 0 THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Amount must be positive'
    );
  END IF;

  -- Get driver
  SELECT * INTO v_driver
  FROM drivers
  WHERE id = p_driver_id;
  
  -- Check if driver exists
  IF v_driver.id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Driver not found'
    );
  END IF;
  
  -- Get or create wallet
  SELECT id INTO v_wallet_id
  FROM wallets
  WHERE user_id = v_driver.user_id;
  
  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id)
    VALUES (v_driver.user_id)
    RETURNING id INTO v_wallet_id;
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
    v_wallet_id,
    p_amount,
    'credit',
    p_payment_type,
    'completed',
    p_description
  )
  RETURNING id INTO v_transaction_id;
  
  -- Update wallet balance
  UPDATE wallets
  SET 
    balance = balance + p_amount,
    updated_at = now()
  WHERE id = v_wallet_id;
  
  -- Return success
  RETURN json_build_object(
    'success', true,
    'message', 'Driver wallet charged successfully',
    'transaction_id', v_transaction_id,
    'amount', p_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to charge vendor wallet
CREATE OR REPLACE FUNCTION charge_vendor_wallet(
  p_vendor_id UUID,
  p_amount NUMERIC,
  p_description TEXT DEFAULT 'شحن رصيد',
  p_payment_type TEXT DEFAULT 'admin_charge'
)
RETURNS JSON AS $$
DECLARE
  v_vendor RECORD;
  v_wallet_id UUID;
  v_transaction_id UUID;
BEGIN
  -- Check if amount is positive
  IF p_amount <= 0 THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Amount must be positive'
    );
  END IF;

  -- Get vendor
  SELECT * INTO v_vendor
  FROM vendors
  WHERE id = p_vendor_id;
  
  -- Check if vendor exists
  IF v_vendor.id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Vendor not found'
    );
  END IF;
  
  -- Get or create wallet
  SELECT id INTO v_wallet_id
  FROM wallets
  WHERE user_id = v_vendor.user_id;
  
  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id)
    VALUES (v_vendor.user_id)
    RETURNING id INTO v_wallet_id;
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
    v_wallet_id,
    p_amount,
    'credit',
    p_payment_type,
    'completed',
    p_description
  )
  RETURNING id INTO v_transaction_id;
  
  -- Update wallet balance
  UPDATE wallets
  SET 
    balance = balance + p_amount,
    updated_at = now()
  WHERE id = v_wallet_id;
  
  -- Return success
  RETURN json_build_object(
    'success', true,
    'message', 'Vendor wallet charged successfully',
    'transaction_id', v_transaction_id,
    'amount', p_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get driver wallet
CREATE OR REPLACE FUNCTION get_driver_wallet(
  p_driver_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_driver RECORD;
  v_wallet RECORD;
BEGIN
  -- Get driver
  SELECT * INTO v_driver
  FROM drivers
  WHERE id = p_driver_id;
  
  -- Check if driver exists
  IF v_driver.id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Driver not found'
    );
  END IF;
  
  -- Get wallet
  SELECT * INTO v_wallet
  FROM wallets
  WHERE user_id = v_driver.user_id;
  
  -- If wallet doesn't exist, return zero balance
  IF v_wallet.id IS NULL THEN
    RETURN json_build_object(
      'success', true,
      'balance', 0,
      'pending_balance', 0,
      'auto_charge', false,
      'has_wallet', false
    );
  END IF;
  
  -- Return wallet info
  RETURN json_build_object(
    'success', true,
    'balance', v_wallet.balance,
    'pending_balance', v_wallet.pending_balance,
    'auto_charge', v_wallet.auto_charge,
    'has_wallet', true,
    'wallet_id', v_wallet.id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get vendor wallet
CREATE OR REPLACE FUNCTION get_vendor_wallet(
  p_vendor_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_vendor RECORD;
  v_wallet RECORD;
BEGIN
  -- Get vendor
  SELECT * INTO v_vendor
  FROM vendors
  WHERE id = p_vendor_id;
  
  -- Check if vendor exists
  IF v_vendor.id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Vendor not found'
    );
  END IF;
  
  -- Get wallet
  SELECT * INTO v_wallet
  FROM wallets
  WHERE user_id = v_vendor.user_id;
  
  -- If wallet doesn't exist, return zero balance
  IF v_wallet.id IS NULL THEN
    RETURN json_build_object(
      'success', true,
      'balance', 0,
      'pending_balance', 0,
      'auto_charge', false,
      'has_wallet', false
    );
  END IF;
  
  -- Return wallet info
  RETURN json_build_object(
    'success', true,
    'balance', v_wallet.balance,
    'pending_balance', v_wallet.pending_balance,
    'auto_charge', v_wallet.auto_charge,
    'has_wallet', true,
    'wallet_id', v_wallet.id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get all vendor wallets
CREATE OR REPLACE FUNCTION get_all_vendor_wallets()
RETURNS SETOF vendor_wallets AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM vendor_wallets
  ORDER BY store_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get all driver wallets
CREATE OR REPLACE FUNCTION get_all_driver_wallets()
RETURNS SETOF driver_wallets AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM driver_wallets
  ORDER BY name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;