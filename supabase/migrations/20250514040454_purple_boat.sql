/*
# Add Wholesale Customer Management

1. New Tables
  - `customer_wholesale_tiers` - Junction table for customers and wholesale tiers

2. New Functions
  - `get_wholesale_customers()` - Returns all wholesale customers with their tier information
  - `convert_to_wholesale_customer()` - Converts a customer to a wholesale customer
  - `update_wholesale_customer_status()` - Updates a wholesale customer's status
  - `calculate_wholesale_price()` - Calculates the wholesale price for a product
  - `is_eligible_for_wholesale_pricing()` - Checks if a customer is eligible for wholesale pricing

3. Security
  - Enable RLS on the new table
  - Add policies for admins and customers
*/

-- Create junction table for customers and wholesale tiers
CREATE TABLE IF NOT EXISTS customer_wholesale_tiers (
  customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
  tier_id UUID REFERENCES wholesale_tiers(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (customer_id, tier_id),
  CONSTRAINT customer_wholesale_tiers_status_check CHECK (status IN ('pending', 'approved', 'rejected'))
);

-- Enable RLS
ALTER TABLE customer_wholesale_tiers ENABLE ROW LEVEL SECURITY;

-- Create policies (removed the duplicate policy)
CREATE POLICY "Customers can view their own wholesale tiers"
  ON customer_wholesale_tiers
  FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM customers WHERE customers.id = customer_wholesale_tiers.customer_id AND customers.user_id = auth.uid()));

-- Create function to get wholesale customers with their tier information
CREATE OR REPLACE FUNCTION get_wholesale_customers()
RETURNS SETOF json AS $$
BEGIN
  RETURN QUERY
  SELECT 
    json_build_object(
      'id', c.id,
      'name', c.name,
      'email', c.email,
      'phone', c.phone,
      'address', c.address,
      'tier', json_build_object(
        'id', wt.id,
        'name', wt.name,
        'discount_percentage', wt.discount_percentage,
        'min_purchase_amount', wt.min_purchase_amount,
        'min_order_amount', wt.min_order_amount
      ),
      'status', cwt.status,
      'approved_at', cwt.approved_at,
      'created_at', cwt.created_at,
      'total_purchases', COALESCE(
        (SELECT SUM(o.total)
         FROM ord o
         WHERE o.customer_id = c.id AND o.status = 'completed'),
        0
      )
    )
  FROM 
    customers c
    JOIN customer_wholesale_tiers cwt ON c.id = cwt.customer_id
    JOIN wholesale_tiers wt ON cwt.tier_id = wt.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to convert a customer to a wholesale customer
CREATE OR REPLACE FUNCTION convert_to_wholesale_customer(
  p_customer_id UUID,
  p_tier_id UUID,
  p_status TEXT DEFAULT 'pending'
)
RETURNS BOOLEAN AS $$
DECLARE
  v_approved_at TIMESTAMPTZ;
BEGIN
  -- Set approved_at if status is 'approved'
  IF p_status = 'approved' THEN
    v_approved_at := now();
  ELSE
    v_approved_at := NULL;
  END IF;

  -- Insert or update the customer_wholesale_tiers record
  INSERT INTO customer_wholesale_tiers (
    customer_id,
    tier_id,
    status,
    approved_at,
    created_at,
    updated_at
  ) VALUES (
    p_customer_id,
    p_tier_id,
    p_status,
    v_approved_at,
    now(),
    now()
  )
  ON CONFLICT (customer_id, tier_id) 
  DO UPDATE SET
    status = p_status,
    approved_at = v_approved_at,
    updated_at = now();

  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update wholesale customer status
CREATE OR REPLACE FUNCTION update_wholesale_customer_status(
  p_customer_id UUID,
  p_status TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_approved_at TIMESTAMPTZ;
BEGIN
  -- Set approved_at if status is 'approved'
  IF p_status = 'approved' THEN
    v_approved_at := now();
  ELSE
    v_approved_at := NULL;
  END IF;

  -- Update the customer_wholesale_tiers record
  UPDATE customer_wholesale_tiers
  SET 
    status = p_status,
    approved_at = v_approved_at,
    updated_at = now()
  WHERE customer_id = p_customer_id;

  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to calculate wholesale price for a product
CREATE OR REPLACE FUNCTION calculate_wholesale_price(
  p_product_id UUID,
  p_customer_id UUID,
  p_quantity INTEGER DEFAULT 1
)
RETURNS NUMERIC AS $$
DECLARE
  v_tier_id UUID;
  v_discount_percentage NUMERIC;
  v_product_price NUMERIC;
  v_wholesale_price NUMERIC;
BEGIN
  -- Get the customer's tier
  SELECT tier_id INTO v_tier_id
  FROM customer_wholesale_tiers
  WHERE customer_id = p_customer_id AND status = 'approved';
  
  IF v_tier_id IS NULL THEN
    -- Customer is not a wholesale customer or not approved
    RETURN NULL;
  END IF;
  
  -- Get the tier's discount percentage
  SELECT discount_percentage INTO v_discount_percentage
  FROM wholesale_tiers
  WHERE id = v_tier_id;
  
  -- Get the product's price
  SELECT price INTO v_product_price
  FROM products
  WHERE id = p_product_id;
  
  -- Calculate the wholesale price
  v_wholesale_price := v_product_price * (1 - (v_discount_percentage / 100));
  
  -- Return the wholesale price
  RETURN v_wholesale_price;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if a customer is eligible for wholesale pricing
CREATE OR REPLACE FUNCTION is_eligible_for_wholesale_pricing(
  p_customer_id UUID,
  p_order_total NUMERIC
)
RETURNS BOOLEAN AS $$
DECLARE
  v_tier_id UUID;
  v_min_order_amount NUMERIC;
BEGIN
  -- Get the customer's tier
  SELECT cwt.tier_id INTO v_tier_id
  FROM customer_wholesale_tiers cwt
  WHERE cwt.customer_id = p_customer_id AND cwt.status = 'approved';
  
  IF v_tier_id IS NULL THEN
    -- Customer is not a wholesale customer or not approved
    RETURN FALSE;
  END IF;
  
  -- Get the tier's minimum order amount
  SELECT wt.min_order_amount INTO v_min_order_amount
  FROM wholesale_tiers wt
  WHERE wt.id = v_tier_id;
  
  -- Check if the order total meets the minimum order amount
  RETURN p_order_total >= v_min_order_amount;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to update the updated_at column
CREATE OR REPLACE FUNCTION update_customer_wholesale_tiers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_customer_wholesale_tiers_updated_at
BEFORE UPDATE ON customer_wholesale_tiers
FOR EACH ROW
EXECUTE FUNCTION update_customer_wholesale_tiers_updated_at();