/*
  # Create Coupons System

  1. New Tables
    - `coupons` - Stores coupon codes and their settings
    - `order_coupons` - Junction table linking orders to coupons
  
  2. Security
    - Enable RLS on both tables
    - Add policies for proper access control
  
  3. Functions
    - `validate_coupon` - Checks if a coupon is valid for a given order
    - `apply_coupon_to_order` - Applies a coupon to an order
    - `get_coupon_usage_stats` - Gets usage statistics for coupons
*/

-- Create coupons table if it doesn't exist
CREATE TABLE IF NOT EXISTS coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL,
  value NUMERIC NOT NULL,
  min_order_amount NUMERIC,
  max_discount NUMERIC,
  usage_limit INTEGER,
  used_count INTEGER DEFAULT 0,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT coupons_type_check CHECK (type IN ('percentage', 'fixed')),
  CONSTRAINT coupons_status_check CHECK (status IN ('active', 'inactive')),
  CONSTRAINT coupons_value_check CHECK (value > 0),
  CONSTRAINT coupons_dates_check CHECK (start_date <= end_date)
);

-- Create order_coupons junction table if it doesn't exist
CREATE TABLE IF NOT EXISTS order_coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES ord(id) ON DELETE CASCADE,
  coupon_id UUID NOT NULL REFERENCES coupons(id) ON DELETE RESTRICT,
  discount_amount NUMERIC NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT order_coupons_discount_amount_check CHECK (discount_amount >= 0),
  CONSTRAINT order_coupons_unique UNIQUE (order_id, coupon_id)
);

-- Enable RLS
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_coupons ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Coupons are viewable by everyone" ON coupons;
DROP POLICY IF EXISTS "Admins can manage coupons" ON coupons;
DROP POLICY IF EXISTS "Order coupons are viewable by related parties" ON order_coupons;
DROP POLICY IF EXISTS "Customers can apply coupons to their orders" ON order_coupons;

-- Create policies for coupons
CREATE POLICY "Coupons are viewable by everyone"
  ON coupons
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage coupons"
  ON coupons
  FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE admin_users.user_id = auth.uid()));

-- Create policies for order_coupons
CREATE POLICY "Order coupons are viewable by related parties"
  ON order_coupons
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM ord
      WHERE ord.id = order_coupons.order_id
      AND (
        -- Vendor can view
        (ord.vendor_id IN (SELECT vendors.id FROM vendors WHERE vendors.user_id = auth.uid()))
        -- Driver can view
        OR (ord.driver_id IN (SELECT drivers.id FROM drivers WHERE drivers.user_id = auth.uid()))
        -- Customer can view
        OR (ord.customer_id IN (SELECT customers.id FROM customers WHERE customers.user_id = auth.uid()))
      )
    )
  );

CREATE POLICY "Customers can apply coupons to their orders"
  ON order_coupons
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM ord
      WHERE ord.id = order_coupons.order_id
      AND ord.customer_id IN (SELECT customers.id FROM customers WHERE customers.user_id = auth.uid())
    )
  );

-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS validate_coupon(TEXT, NUMERIC, UUID);
DROP FUNCTION IF EXISTS apply_coupon_to_order(UUID, TEXT);
DROP FUNCTION IF EXISTS get_coupon_usage_stats(UUID);

-- Create function to validate coupon
CREATE OR REPLACE FUNCTION validate_coupon(
  p_code TEXT,
  p_order_amount NUMERIC,
  p_customer_id UUID DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_coupon RECORD;
  v_valid BOOLEAN := false;
  v_message TEXT := 'Invalid coupon code';
  v_discount NUMERIC := 0;
BEGIN
  -- Get coupon
  SELECT * INTO v_coupon
  FROM coupons
  WHERE code = p_code AND status = 'active';
  
  -- Check if coupon exists
  IF v_coupon.id IS NULL THEN
    RETURN json_build_object(
      'valid', false,
      'message', 'Coupon code not found',
      'discount', 0
    );
  END IF;
  
  -- Check dates
  IF CURRENT_DATE < v_coupon.start_date OR CURRENT_DATE > v_coupon.end_date THEN
    RETURN json_build_object(
      'valid', false,
      'message', 'Coupon is not valid at this time',
      'discount', 0
    );
  END IF;
  
  -- Check usage limit
  IF v_coupon.usage_limit IS NOT NULL AND v_coupon.used_count >= v_coupon.usage_limit THEN
    RETURN json_build_object(
      'valid', false,
      'message', 'Coupon usage limit reached',
      'discount', 0
    );
  END IF;
  
  -- Check minimum order amount
  IF v_coupon.min_order_amount IS NOT NULL AND p_order_amount < v_coupon.min_order_amount THEN
    RETURN json_build_object(
      'valid', false,
      'message', 'Order amount does not meet minimum requirement',
      'discount', 0
    );
  END IF;
  
  -- Calculate discount
  IF v_coupon.type = 'percentage' THEN
    v_discount := p_order_amount * (v_coupon.value / 100);
    
    -- Apply max discount if set
    IF v_coupon.max_discount IS NOT NULL AND v_discount > v_coupon.max_discount THEN
      v_discount := v_coupon.max_discount;
    END IF;
  ELSE -- fixed discount
    v_discount := v_coupon.value;
    
    -- Ensure discount doesn't exceed order amount
    IF v_discount > p_order_amount THEN
      v_discount := p_order_amount;
    END IF;
  END IF;
  
  -- Return validation result
  RETURN json_build_object(
    'valid', true,
    'message', 'Coupon is valid',
    'discount', v_discount,
    'coupon_id', v_coupon.id,
    'coupon_code', v_coupon.code,
    'coupon_type', v_coupon.type,
    'coupon_value', v_coupon.value
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to apply coupon to order
CREATE OR REPLACE FUNCTION apply_coupon_to_order(
  p_order_id UUID,
  p_coupon_code TEXT
)
RETURNS JSON AS $$
DECLARE
  v_order RECORD;
  v_validation JSON;
  v_coupon_id UUID;
  v_discount NUMERIC;
BEGIN
  -- Get order
  SELECT * INTO v_order
  FROM ord
  WHERE id = p_order_id;
  
  -- Check if order exists
  IF v_order.id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Order not found'
    );
  END IF;
  
  -- Check if order already has a coupon
  IF EXISTS (SELECT 1 FROM order_coupons WHERE order_id = p_order_id) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Order already has a coupon applied'
    );
  END IF;
  
  -- Validate coupon
  v_validation := validate_coupon(p_coupon_code, v_order.total);
  
  -- Check if coupon is valid
  IF NOT (v_validation->>'valid')::BOOLEAN THEN
    RETURN json_build_object(
      'success', false,
      'message', v_validation->>'message'
    );
  END IF;
  
  -- Get coupon ID and discount
  v_coupon_id := (v_validation->>'coupon_id')::UUID;
  v_discount := (v_validation->>'discount')::NUMERIC;
  
  -- Apply coupon to order
  INSERT INTO order_coupons (
    order_id,
    coupon_id,
    discount_amount
  ) VALUES (
    p_order_id,
    v_coupon_id,
    v_discount
  );
  
  -- Update order total
  UPDATE ord
  SET 
    total = total - v_discount,
    updated_at = now()
  WHERE id = p_order_id;
  
  -- Increment coupon usage count
  UPDATE coupons
  SET 
    used_count = used_count + 1,
    updated_at = now()
  WHERE id = v_coupon_id;
  
  -- Return success
  RETURN json_build_object(
    'success', true,
    'message', 'Coupon applied successfully',
    'discount', v_discount,
    'new_total', v_order.total - v_discount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get coupon usage stats
CREATE OR REPLACE FUNCTION get_coupon_usage_stats(
  p_coupon_id UUID DEFAULT NULL
)
RETURNS TABLE (
  coupon_id UUID,
  coupon_code TEXT,
  total_usage INTEGER,
  total_discount NUMERIC,
  avg_discount NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id AS coupon_id,
    c.code AS coupon_code,
    COUNT(oc.id) AS total_usage,
    COALESCE(SUM(oc.discount_amount), 0) AS total_discount,
    COALESCE(AVG(oc.discount_amount), 0) AS avg_discount
  FROM 
    coupons c
    LEFT JOIN order_coupons oc ON c.id = oc.coupon_id
  WHERE 
    (p_coupon_id IS NULL OR c.id = p_coupon_id)
  GROUP BY 
    c.id, c.code
  ORDER BY 
    total_usage DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger and function if they exist
DROP TRIGGER IF EXISTS update_coupons_updated_at ON coupons;
DROP FUNCTION IF EXISTS update_coupons_updated_at();

-- Create trigger to update updated_at column
CREATE OR REPLACE FUNCTION update_coupons_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_coupons_updated_at
BEFORE UPDATE ON coupons
FOR EACH ROW
EXECUTE FUNCTION update_coupons_updated_at();