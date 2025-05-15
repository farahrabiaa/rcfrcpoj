/*
  # Wholesale Pricing System Implementation

  1. New Tables
    - `wholesale_tiers`
      - Defines customer tiers with minimum purchase requirements
      - Stores tier-specific discounts and benefits
    
    - `wholesale_customers`
      - Links customers to their wholesale tier
      - Tracks customer purchase history and tier status
    
    - `wholesale_prices`
      - Product-specific wholesale pricing
      - Tier-based price overrides

  2. Security
    - Enable RLS on new tables
    - Add policies for authenticated users
*/

-- Create wholesale_tiers table
CREATE TABLE IF NOT EXISTS wholesale_tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  min_purchase_amount decimal(10,2) NOT NULL,
  discount_percentage decimal(5,2) NOT NULL,
  min_order_amount decimal(10,2) NOT NULL,
  benefits jsonb,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create wholesale_customers table
CREATE TABLE IF NOT EXISTS wholesale_customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  tier_id uuid REFERENCES wholesale_tiers NOT NULL,
  company_name text,
  tax_number text,
  contact_name text,
  contact_phone text,
  contact_email text,
  billing_address text,
  shipping_address text,
  total_purchases decimal(10,2) DEFAULT 0,
  last_purchase_date timestamptz,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'suspended')),
  approval_date timestamptz,
  approved_by uuid REFERENCES auth.users,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create wholesale_prices table
CREATE TABLE IF NOT EXISTS wholesale_prices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES products NOT NULL,
  tier_id uuid REFERENCES wholesale_tiers NOT NULL,
  price decimal(10,2) NOT NULL,
  min_quantity int NOT NULL DEFAULT 1,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (product_id, tier_id)
);

-- Enable RLS
ALTER TABLE wholesale_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE wholesale_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE wholesale_prices ENABLE ROW LEVEL SECURITY;

-- Policies for wholesale_tiers
CREATE POLICY "Wholesale tiers are viewable by everyone"
  ON wholesale_tiers
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can modify wholesale tiers"
  ON wholesale_tiers
  FOR ALL
  TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

-- Policies for wholesale_customers
CREATE POLICY "Wholesale customers can view their own data"
  ON wholesale_customers
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all wholesale customers"
  ON wholesale_customers
  FOR SELECT
  TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

CREATE POLICY "Only admins can modify wholesale customers"
  ON wholesale_customers
  FOR ALL
  TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

-- Policies for wholesale_prices
CREATE POLICY "Wholesale prices are viewable by wholesale customers"
  ON wholesale_prices
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM wholesale_customers wc
      WHERE wc.user_id = auth.uid()
      AND wc.status = 'approved'
    )
  );

CREATE POLICY "Only admins can modify wholesale prices"
  ON wholesale_prices
  FOR ALL
  TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

-- Insert default wholesale tiers
INSERT INTO wholesale_tiers (
  name,
  description,
  min_purchase_amount,
  discount_percentage,
  min_order_amount,
  benefits,
  status
) VALUES 
(
  'برونزي',
  'المستوى الأساسي للتجار',
  5000.00, -- الحد الأدنى للمشتريات السنوية
  5.00,    -- خصم 5%
  500.00,  -- الحد الأدنى للطلب
  jsonb_build_array(
    'خصم 5% على جميع المنتجات',
    'دعم أولوية للتجار',
    'تقارير شهرية'
  ),
  'active'
),
(
  'فضي',
  'المستوى المتوسط للتجار',
  10000.00, -- الحد الأدنى للمشتريات السنوية
  10.00,    -- خصم 10%
  1000.00,  -- الحد الأدنى للطلب
  jsonb_build_array(
    'خصم 10% على جميع المنتجات',
    'دعم أولوية للتجار',
    'تقارير أسبوعية',
    'شحن مجاني للطلبات فوق 2000₪'
  ),
  'active'
),
(
  'ذهبي',
  'المستوى المتقدم للتجار',
  25000.00, -- الحد الأدنى للمشتريات السنوية
  15.00,    -- خصم 15%
  2000.00,  -- الحد الأدنى للطلب
  jsonb_build_array(
    'خصم 15% على جميع المنتجات',
    'دعم أولوية قصوى',
    'تقارير يومية',
    'شحن مجاني لجميع الطلبات',
    'مدير حساب مخصص'
  ),
  'active'
),
(
  'بلاتيني',
  'المستوى الأعلى للتجار',
  50000.00, -- الحد الأدنى للمشتريات السنوية
  20.00,    -- خصم 20%
  5000.00,  -- الحد الأدنى للطلب
  jsonb_build_array(
    'خصم 20% على جميع المنتجات',
    'دعم على مدار الساعة',
    'تقارير مخصصة',
    'شحن مجاني وسريع لجميع الطلبات',
    'مدير حساب مخصص',
    'أسعار خاصة للمنتجات الجديدة'
  ),
  'active'
);

-- Functions for wholesale management
CREATE OR REPLACE FUNCTION calculate_wholesale_price(
  p_product_id uuid,
  p_user_id uuid,
  p_quantity int DEFAULT 1
) RETURNS decimal AS $$
DECLARE
  v_tier_id uuid;
  v_price decimal;
BEGIN
  -- Get customer's tier
  SELECT tier_id INTO v_tier_id
  FROM wholesale_customers
  WHERE user_id = p_user_id
  AND status = 'approved';

  IF NOT FOUND THEN
    RETURN NULL; -- Not a wholesale customer
  END IF;

  -- Get tier-specific price if exists
  SELECT price INTO v_price
  FROM wholesale_prices
  WHERE product_id = p_product_id
  AND tier_id = v_tier_id
  AND min_quantity <= p_quantity
  ORDER BY min_quantity DESC
  LIMIT 1;

  -- If no tier-specific price, calculate using tier discount
  IF v_price IS NULL THEN
    SELECT 
      p.price * (1 - (wt.discount_percentage / 100)) INTO v_price
    FROM products p
    JOIN wholesale_tiers wt ON wt.id = v_tier_id
    WHERE p.id = p_product_id;
  END IF;

  RETURN v_price;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if order meets wholesale requirements
CREATE OR REPLACE FUNCTION check_wholesale_requirements(
  p_user_id uuid,
  p_order_amount decimal
) RETURNS jsonb AS $$
DECLARE
  v_customer wholesale_customers;
  v_tier wholesale_tiers;
BEGIN
  -- Get customer and tier info
  SELECT wc.*, wt.* INTO v_customer, v_tier
  FROM wholesale_customers wc
  JOIN wholesale_tiers wt ON wt.id = wc.tier_id
  WHERE wc.user_id = p_user_id
  AND wc.status = 'approved';

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', 'ليس زبون جملة'
    );
  END IF;

  -- Check minimum order amount
  IF p_order_amount < v_tier.min_order_amount THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', format('الحد الأدنى للطلب هو %s₪', v_tier.min_order_amount)
    );
  END IF;

  RETURN jsonb_build_object(
    'valid', true,
    'tier', row_to_json(v_tier)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update customer tier based on purchases
CREATE OR REPLACE FUNCTION update_wholesale_customer_tier() RETURNS void AS $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT 
      wc.id as customer_id,
      wc.tier_id as current_tier_id,
      wc.total_purchases,
      (
        SELECT id 
        FROM wholesale_tiers wt
        WHERE wt.status = 'active'
        AND wt.min_purchase_amount <= wc.total_purchases
        ORDER BY wt.min_purchase_amount DESC
        LIMIT 1
      ) as new_tier_id
    FROM wholesale_customers wc
    WHERE wc.status = 'approved'
  ) LOOP
    -- Update tier if changed
    IF r.current_tier_id != r.new_tier_id THEN
      UPDATE wholesale_customers
      SET 
        tier_id = r.new_tier_id,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = r.customer_id;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;