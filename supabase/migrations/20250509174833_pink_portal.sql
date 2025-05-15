/*
  # Points and Rewards System

  1. New Tables
    - `points_accounts` - Stores customer points balances
    - `points_transactions` - Records points earned and spent
    - `points_rewards` - Defines available rewards for points redemption
    - `points_redemptions` - Tracks reward redemptions
    
  2. Security
    - Enable RLS on all tables
    - Add policies for access control
*/

-- Create points_accounts table
CREATE TABLE IF NOT EXISTS points_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid REFERENCES customers(id) ON DELETE CASCADE NOT NULL,
  balance integer NOT NULL DEFAULT 0,
  total_earned integer NOT NULL DEFAULT 0,
  total_spent integer NOT NULL DEFAULT 0,
  last_activity timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create points_transactions table
CREATE TABLE IF NOT EXISTS points_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid REFERENCES points_accounts(id) ON DELETE CASCADE NOT NULL,
  order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  amount integer NOT NULL,
  type text NOT NULL CHECK (type IN ('earn', 'spend', 'expire', 'adjust')),
  description text NOT NULL,
  reference_id uuid,
  created_at timestamptz DEFAULT now()
);

-- Create points_rewards table
CREATE TABLE IF NOT EXISTS points_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  points_cost integer NOT NULL,
  reward_type text NOT NULL CHECK (reward_type IN ('free_delivery', 'order_discount', 'delivery_discount', 'product_discount', 'gift')),
  discount_type text CHECK (discount_type IN ('percentage', 'fixed')),
  discount_value numeric,
  min_order_amount numeric,
  max_discount numeric,
  usage_limit integer,
  used_count integer DEFAULT 0,
  start_date date NOT NULL,
  end_date date NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create points_redemptions table
CREATE TABLE IF NOT EXISTS points_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid REFERENCES points_accounts(id) ON DELETE CASCADE NOT NULL,
  reward_id uuid REFERENCES points_rewards(id) ON DELETE CASCADE NOT NULL,
  order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  points_spent integer NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'used', 'expired', 'cancelled')),
  code text NOT NULL,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Create function to update updated_at column
CREATE OR REPLACE FUNCTION update_points_accounts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for points_accounts table
CREATE TRIGGER update_points_accounts_updated_at
  BEFORE UPDATE ON points_accounts
  FOR EACH ROW
  EXECUTE FUNCTION update_points_accounts_updated_at();

-- Create function to update updated_at column
CREATE OR REPLACE FUNCTION update_points_rewards_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for points_rewards table
CREATE TRIGGER update_points_rewards_updated_at
  BEFORE UPDATE ON points_rewards
  FOR EACH ROW
  EXECUTE FUNCTION update_points_rewards_updated_at();

-- Create function to add points to a customer account
CREATE OR REPLACE FUNCTION add_customer_points(
  p_customer_id uuid,
  p_amount integer,
  p_type text,
  p_description text,
  p_order_id uuid DEFAULT NULL,
  p_reference_id uuid DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
  v_account_id uuid;
  v_transaction_id uuid;
BEGIN
  -- Get or create points account
  SELECT id INTO v_account_id
  FROM points_accounts
  WHERE customer_id = p_customer_id;
  
  IF v_account_id IS NULL THEN
    INSERT INTO points_accounts (customer_id)
    VALUES (p_customer_id)
    RETURNING id INTO v_account_id;
  END IF;
  
  -- Update account balance
  IF p_type = 'earn' THEN
    UPDATE points_accounts
    SET 
      balance = balance + p_amount,
      total_earned = total_earned + p_amount,
      last_activity = now()
    WHERE id = v_account_id;
  ELSIF p_type = 'spend' THEN
    UPDATE points_accounts
    SET 
      balance = balance - p_amount,
      total_spent = total_spent + p_amount,
      last_activity = now()
    WHERE id = v_account_id;
  ELSIF p_type = 'expire' THEN
    UPDATE points_accounts
    SET 
      balance = balance - p_amount,
      last_activity = now()
    WHERE id = v_account_id;
  ELSIF p_type = 'adjust' THEN
    UPDATE points_accounts
    SET 
      balance = balance + p_amount,
      last_activity = now()
    WHERE id = v_account_id;
  END IF;
  
  -- Create transaction record
  INSERT INTO points_transactions (
    account_id,
    order_id,
    amount,
    type,
    description,
    reference_id
  ) VALUES (
    v_account_id,
    p_order_id,
    p_amount,
    p_type,
    p_description,
    p_reference_id
  ) RETURNING id INTO v_transaction_id;
  
  RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to redeem points for a reward
CREATE OR REPLACE FUNCTION redeem_points_for_reward(
  p_customer_id uuid,
  p_reward_id uuid
)
RETURNS jsonb AS $$
DECLARE
  v_account_id uuid;
  v_account_balance integer;
  v_reward_points_cost integer;
  v_reward_status text;
  v_reward_start_date date;
  v_reward_end_date date;
  v_redemption_id uuid;
  v_redemption_code text;
  v_redemption_expires_at timestamptz;
  v_result jsonb;
BEGIN
  -- Get account ID and balance
  SELECT id, balance INTO v_account_id, v_account_balance
  FROM points_accounts
  WHERE customer_id = p_customer_id;
  
  -- Check if account exists
  IF v_account_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'لا يوجد حساب نقاط لهذا العميل'
    );
  END IF;
  
  -- Get reward details
  SELECT 
    points_cost, 
    status,
    start_date,
    end_date
  INTO 
    v_reward_points_cost,
    v_reward_status,
    v_reward_start_date,
    v_reward_end_date
  FROM points_rewards
  WHERE id = p_reward_id;
  
  -- Check if reward exists
  IF v_reward_points_cost IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'المكافأة غير موجودة'
    );
  END IF;
  
  -- Check if reward is active
  IF v_reward_status != 'active' THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'المكافأة غير نشطة'
    );
  END IF;
  
  -- Check if reward is within valid date range
  IF CURRENT_DATE < v_reward_start_date OR CURRENT_DATE > v_reward_end_date THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'المكافأة خارج نطاق التاريخ الصالح'
    );
  END IF;
  
  -- Check if customer has enough points
  IF v_account_balance < v_reward_points_cost THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'رصيد النقاط غير كافٍ',
      'required', v_reward_points_cost,
      'balance', v_account_balance
    );
  END IF;
  
  -- Generate redemption code (random 8 character alphanumeric)
  v_redemption_code := upper(substring(md5(random()::text) from 1 for 8));
  
  -- Set expiration date (30 days from now)
  v_redemption_expires_at := now() + interval '30 days';
  
  -- Create redemption record
  INSERT INTO points_redemptions (
    account_id,
    reward_id,
    points_spent,
    status,
    code,
    expires_at
  ) VALUES (
    v_account_id,
    p_reward_id,
    v_reward_points_cost,
    'active',
    v_redemption_code,
    v_redemption_expires_at
  ) RETURNING id INTO v_redemption_id;
  
  -- Deduct points from account
  PERFORM add_customer_points(
    p_customer_id,
    v_reward_points_cost,
    'spend',
    'استبدال نقاط بمكافأة',
    NULL,
    v_redemption_id
  );
  
  -- Increment used count for the reward
  UPDATE points_rewards
  SET used_count = COALESCE(used_count, 0) + 1
  WHERE id = p_reward_id;
  
  -- Return success response
  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم استبدال النقاط بنجاح',
    'redemption_id', v_redemption_id,
    'code', v_redemption_code,
    'expires_at', v_redemption_expires_at,
    'points_spent', v_reward_points_cost,
    'remaining_balance', v_account_balance - v_reward_points_cost
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to validate a redemption code
CREATE OR REPLACE FUNCTION validate_redemption_code(
  p_code text,
  p_order_id uuid DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_redemption_id uuid;
  v_redemption_status text;
  v_redemption_expires_at timestamptz;
  v_reward_id uuid;
  v_reward_data jsonb;
  v_result jsonb;
BEGIN
  -- Get redemption details
  SELECT 
    id, 
    status, 
    expires_at,
    reward_id
  INTO 
    v_redemption_id,
    v_redemption_status,
    v_redemption_expires_at,
    v_reward_id
  FROM points_redemptions
  WHERE code = p_code;
  
  -- Check if redemption exists
  IF v_redemption_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'رمز الاستبدال غير صالح'
    );
  END IF;
  
  -- Check if redemption is active
  IF v_redemption_status != 'active' THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'رمز الاستبدال غير نشط أو تم استخدامه بالفعل'
    );
  END IF;
  
  -- Check if redemption is expired
  IF v_redemption_expires_at < now() THEN
    -- Mark as expired
    UPDATE points_redemptions
    SET status = 'expired'
    WHERE id = v_redemption_id;
    
    RETURN jsonb_build_object(
      'success', false,
      'message', 'رمز الاستبدال منتهي الصلاحية'
    );
  END IF;
  
  -- Get reward details
  SELECT row_to_json(r)::jsonb INTO v_reward_data
  FROM (
    SELECT * FROM points_rewards
    WHERE id = v_reward_id
  ) r;
  
  -- If order_id is provided, mark redemption as used
  IF p_order_id IS NOT NULL THEN
    UPDATE points_redemptions
    SET 
      status = 'used',
      order_id = p_order_id,
      used_at = now()
    WHERE id = v_redemption_id;
  END IF;
  
  -- Return success response
  RETURN jsonb_build_object(
    'success', true,
    'message', 'رمز الاستبدال صالح',
    'redemption_id', v_redemption_id,
    'reward', v_reward_data,
    'expires_at', v_redemption_expires_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to calculate points for an order
CREATE OR REPLACE FUNCTION calculate_order_points(
  p_order_total numeric,
  p_points_per_currency numeric DEFAULT 1.0
)
RETURNS integer AS $$
DECLARE
  v_points integer;
BEGIN
  -- Calculate points (rounded down to nearest integer)
  v_points := floor(p_order_total * p_points_per_currency);
  
  RETURN v_points;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get customer points balance
CREATE OR REPLACE FUNCTION get_customer_points_balance(
  p_customer_id uuid
)
RETURNS jsonb AS $$
DECLARE
  v_account_id uuid;
  v_balance integer;
  v_total_earned integer;
  v_total_spent integer;
  v_last_activity timestamptz;
  v_result jsonb;
BEGIN
  -- Get account details
  SELECT 
    id, 
    balance, 
    total_earned, 
    total_spent, 
    last_activity
  INTO 
    v_account_id,
    v_balance,
    v_total_earned,
    v_total_spent,
    v_last_activity
  FROM points_accounts
  WHERE customer_id = p_customer_id;
  
  -- If account doesn't exist, return zeros
  IF v_account_id IS NULL THEN
    RETURN jsonb_build_object(
      'balance', 0,
      'total_earned', 0,
      'total_spent', 0,
      'last_activity', null,
      'has_account', false
    );
  END IF;
  
  -- Return account details
  RETURN jsonb_build_object(
    'balance', v_balance,
    'total_earned', v_total_earned,
    'total_spent', v_total_spent,
    'last_activity', v_last_activity,
    'has_account', true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get customer points transactions
CREATE OR REPLACE FUNCTION get_customer_points_transactions(
  p_customer_id uuid,
  p_limit integer DEFAULT 10,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  amount integer,
  type text,
  description text,
  order_id uuid,
  created_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pt.id,
    pt.amount,
    pt.type,
    pt.description,
    pt.order_id,
    pt.created_at
  FROM points_transactions pt
  JOIN points_accounts pa ON pt.account_id = pa.id
  WHERE pa.customer_id = p_customer_id
  ORDER BY pt.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get customer redemptions
CREATE OR REPLACE FUNCTION get_customer_redemptions(
  p_customer_id uuid,
  p_status text DEFAULT NULL,
  p_limit integer DEFAULT 10,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  reward_id uuid,
  reward_name text,
  points_spent integer,
  status text,
  code text,
  expires_at timestamptz,
  used_at timestamptz,
  created_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pr.id,
    pr.reward_id,
    r.name,
    pr.points_spent,
    pr.status,
    pr.code,
    pr.expires_at,
    pr.used_at,
    pr.created_at
  FROM points_redemptions pr
  JOIN points_accounts pa ON pr.account_id = pa.id
  JOIN points_rewards r ON pr.reward_id = r.id
  WHERE pa.customer_id = p_customer_id
  AND (p_status IS NULL OR pr.status = p_status)
  ORDER BY pr.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get available rewards
CREATE OR REPLACE FUNCTION get_available_rewards(
  p_customer_id uuid DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  name text,
  description text,
  points_cost integer,
  reward_type text,
  discount_type text,
  discount_value numeric,
  min_order_amount numeric,
  max_discount numeric,
  start_date date,
  end_date date,
  can_redeem boolean
) AS $$
DECLARE
  v_customer_points integer := 0;
BEGIN
  -- Get customer points balance if customer_id is provided
  IF p_customer_id IS NOT NULL THEN
    SELECT balance INTO v_customer_points
    FROM points_accounts
    WHERE customer_id = p_customer_id;
  END IF;
  
  RETURN QUERY
  SELECT 
    r.id,
    r.name,
    r.description,
    r.points_cost,
    r.reward_type,
    r.discount_type,
    r.discount_value,
    r.min_order_amount,
    r.max_discount,
    r.start_date,
    r.end_date,
    CASE 
      WHEN p_customer_id IS NULL THEN false
      WHEN v_customer_points >= r.points_cost THEN true
      ELSE false
    END as can_redeem
  FROM points_rewards r
  WHERE r.status = 'active'
  AND r.start_date <= CURRENT_DATE
  AND r.end_date >= CURRENT_DATE
  AND (r.usage_limit IS NULL OR r.used_count < r.usage_limit)
  ORDER BY r.points_cost ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to apply reward to order
CREATE OR REPLACE FUNCTION apply_reward_to_order(
  p_order_id uuid,
  p_redemption_code text
)
RETURNS jsonb AS $$
DECLARE
  v_validation jsonb;
  v_reward jsonb;
  v_redemption_id uuid;
  v_order_total numeric;
  v_order_subtotal numeric;
  v_order_delivery_fee numeric;
  v_discount_amount numeric := 0;
  v_new_total numeric;
  v_result jsonb;
BEGIN
  -- Validate redemption code
  v_validation := validate_redemption_code(p_code, NULL);
  
  -- Check if validation was successful
  IF NOT (v_validation->>'success')::boolean THEN
    RETURN v_validation;
  END IF;
  
  -- Extract data from validation
  v_redemption_id := (v_validation->>'redemption_id')::uuid;
  v_reward := v_validation->'reward';
  
  -- Get order details
  SELECT 
    total,
    subtotal,
    delivery_fee
  INTO 
    v_order_total,
    v_order_subtotal,
    v_order_delivery_fee
  FROM orders
  WHERE id = p_order_id;
  
  -- Calculate discount based on reward type
  CASE (v_reward->>'reward_type')::text
    WHEN 'free_delivery' THEN
      v_discount_amount := v_order_delivery_fee;
      
    WHEN 'order_discount' THEN
      -- Check if order meets minimum amount
      IF (v_reward->>'min_order_amount')::numeric IS NOT NULL AND v_order_subtotal < (v_reward->>'min_order_amount')::numeric THEN
        RETURN jsonb_build_object(
          'success', false,
          'message', 'الطلب لا يلبي الحد الأدنى للمبلغ المطلوب للخصم'
        );
      END IF;
      
      -- Calculate discount
      IF (v_reward->>'discount_type')::text = 'percentage' THEN
        v_discount_amount := v_order_subtotal * (v_reward->>'discount_value')::numeric / 100;
        
        -- Apply max discount if specified
        IF (v_reward->>'max_discount')::numeric IS NOT NULL THEN
          v_discount_amount := LEAST(v_discount_amount, (v_reward->>'max_discount')::numeric);
        END IF;
      ELSE
        v_discount_amount := (v_reward->>'discount_value')::numeric;
      END IF;
      
    WHEN 'delivery_discount' THEN
      -- Calculate discount
      IF (v_reward->>'discount_type')::text = 'percentage' THEN
        v_discount_amount := v_order_delivery_fee * (v_reward->>'discount_value')::numeric / 100;
      ELSE
        v_discount_amount := LEAST((v_reward->>'discount_value')::numeric, v_order_delivery_fee);
      END IF;
  END CASE;
  
  -- Calculate new total
  v_new_total := v_order_total - v_discount_amount;
  
  -- Update order with discount
  UPDATE orders
  SET 
    total = v_new_total
  WHERE id = p_order_id;
  
  -- Mark redemption as used
  UPDATE points_redemptions
  SET 
    status = 'used',
    order_id = p_order_id,
    used_at = now()
  WHERE id = v_redemption_id;
  
  -- Return success response
  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم تطبيق المكافأة بنجاح',
    'discount_amount', v_discount_amount,
    'new_total', v_new_total
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert default rewards
INSERT INTO points_rewards (
  name, 
  description, 
  points_cost, 
  reward_type, 
  discount_type, 
  discount_value, 
  min_order_amount, 
  max_discount, 
  start_date, 
  end_date, 
  status
)
VALUES 
  (
    'توصيل مجاني', 
    'احصل على توصيل مجاني لطلبك التالي', 
    200, 
    'free_delivery', 
    NULL, 
    NULL, 
    50, 
    NULL, 
    CURRENT_DATE, 
    CURRENT_DATE + INTERVAL '1 year', 
    'active'
  ),
  (
    'خصم 10%', 
    'خصم 10% على طلبك التالي', 
    300, 
    'order_discount', 
    'percentage', 
    10, 
    100, 
    50, 
    CURRENT_DATE, 
    CURRENT_DATE + INTERVAL '1 year', 
    'active'
  ),
  (
    'خصم 20 شيكل', 
    'خصم 20 شيكل على طلبك التالي', 
    400, 
    'order_discount', 
    'fixed', 
    20, 
    150, 
    NULL, 
    CURRENT_DATE, 
    CURRENT_DATE + INTERVAL '1 year', 
    'active'
  ),
  (
    'خصم 50% على التوصيل', 
    'خصم 50% على رسوم التوصيل', 
    100, 
    'delivery_discount', 
    'percentage', 
    50, 
    NULL, 
    NULL, 
    CURRENT_DATE, 
    CURRENT_DATE + INTERVAL '1 year', 
    'active'
  )
ON CONFLICT DO NOTHING;