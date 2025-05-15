/*
  # Points and Rewards System Implementation

  1. New Tables
    - `points_settings`
      - Points value configuration
      - Points earning rules
      - Points expiration settings
    
    - `user_points`
      - User points balance
      - Points history
      - Points expiration tracking
    
    - `points_transactions`
      - Points earning/spending records
      - Transaction details and metadata
    
    - `rewards`
      - Available rewards
      - Points cost
      - Reward rules and limitations

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Create points_settings table
CREATE TABLE IF NOT EXISTS points_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  points_value decimal(10,2) NOT NULL DEFAULT 0.10, -- Value of 1 point in currency
  min_points_redeem int NOT NULL DEFAULT 100, -- Minimum points for redemption
  points_expiry_days int, -- NULL means points don't expire
  points_per_currency decimal(10,2) NOT NULL DEFAULT 1.00, -- Points earned per currency unit
  min_order_points decimal(10,2) NOT NULL DEFAULT 10.00, -- Minimum order amount to earn points
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create user_points table
CREATE TABLE IF NOT EXISTS user_points (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  total_points int NOT NULL DEFAULT 0,
  available_points int NOT NULL DEFAULT 0,
  pending_points int NOT NULL DEFAULT 0,
  lifetime_points int NOT NULL DEFAULT 0,
  last_earned_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT positive_points CHECK (total_points >= 0 AND available_points >= 0 AND pending_points >= 0)
);

-- Create points_transactions table
CREATE TABLE IF NOT EXISTS points_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  order_id uuid REFERENCES orders,
  points int NOT NULL,
  type text NOT NULL CHECK (type IN ('earn', 'spend', 'expire', 'refund')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
  expires_at timestamptz,
  description text,
  metadata jsonb,
  created_at timestamptz DEFAULT now()
);

-- Create rewards table
CREATE TABLE IF NOT EXISTS rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  points_cost int NOT NULL,
  reward_type text NOT NULL CHECK (
    reward_type IN ('delivery_discount', 'order_discount', 'free_delivery')
  ),
  discount_value decimal(10,2),
  discount_type text CHECK (discount_type IN ('percentage', 'fixed')),
  min_order_amount decimal(10,2),
  max_discount decimal(10,2),
  usage_limit int,
  used_count int DEFAULT 0,
  start_date timestamptz NOT NULL,
  end_date timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'expired')),
  conditions jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create reward_redemptions table
CREATE TABLE IF NOT EXISTS reward_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reward_id uuid REFERENCES rewards NOT NULL,
  user_id uuid REFERENCES auth.users NOT NULL,
  order_id uuid REFERENCES orders,
  points_spent int NOT NULL,
  discount_amount decimal(10,2),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE points_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE points_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_redemptions ENABLE ROW LEVEL SECURITY;

-- Points Settings Policies
CREATE POLICY "Points settings are viewable by everyone"
  ON points_settings FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can modify points settings"
  ON points_settings FOR ALL
  TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

-- User Points Policies
CREATE POLICY "Users can view their own points"
  ON user_points FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "System can modify user points"
  ON user_points FOR ALL
  TO authenticated
  USING (true);

-- Points Transactions Policies
CREATE POLICY "Users can view their own transactions"
  ON points_transactions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "System can create transactions"
  ON points_transactions FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Rewards Policies
CREATE POLICY "Rewards are viewable by everyone"
  ON rewards FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can modify rewards"
  ON rewards FOR ALL
  TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

-- Reward Redemptions Policies
CREATE POLICY "Users can view their own redemptions"
  ON reward_redemptions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "System can create redemptions"
  ON reward_redemptions FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Insert default points settings
INSERT INTO points_settings (
  points_value,
  min_points_redeem,
  points_expiry_days,
  points_per_currency,
  min_order_points
) VALUES (
  0.10, -- 1 point = 0.10₪
  100,  -- Minimum 100 points to redeem
  365,  -- Points expire after 1 year
  1.00, -- Earn 1 point per 1₪ spent
  10.00 -- Minimum order amount 10₪ to earn points
);

-- Functions for points management
CREATE OR REPLACE FUNCTION calculate_order_points(
  p_order_amount decimal,
  OUT earned_points int
) AS $$
DECLARE
  v_settings points_settings;
BEGIN
  -- Get current points settings
  SELECT * INTO v_settings FROM points_settings LIMIT 1;
  
  -- Calculate points
  IF p_order_amount >= v_settings.min_order_points THEN
    earned_points := FLOOR(p_order_amount * v_settings.points_per_currency);
  ELSE
    earned_points := 0;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION award_points(
  p_user_id uuid,
  p_order_id uuid,
  p_amount decimal,
  p_description text DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_points int;
  v_settings points_settings;
  v_expires_at timestamptz;
BEGIN
  -- Calculate points
  SELECT * INTO v_points FROM calculate_order_points(p_amount);
  
  -- Get settings
  SELECT * INTO v_settings FROM points_settings LIMIT 1;
  
  -- Calculate expiration
  IF v_settings.points_expiry_days IS NOT NULL THEN
    v_expires_at := CURRENT_TIMESTAMP + (v_settings.points_expiry_days || ' days')::interval;
  END IF;
  
  -- Create transaction
  INSERT INTO points_transactions (
    user_id,
    order_id,
    points,
    type,
    status,
    expires_at,
    description
  ) VALUES (
    p_user_id,
    p_order_id,
    v_points,
    'earn',
    'pending',
    v_expires_at,
    COALESCE(p_description, 'نقاط مكتسبة من الطلب #' || p_order_id)
  );
  
  -- Update user points
  INSERT INTO user_points (
    user_id,
    total_points,
    available_points,
    pending_points,
    lifetime_points,
    last_earned_at
  ) VALUES (
    p_user_id,
    v_points,
    0,
    v_points,
    v_points,
    CURRENT_TIMESTAMP
  )
  ON CONFLICT (user_id) DO UPDATE
  SET
    total_points = user_points.total_points + v_points,
    pending_points = user_points.pending_points + v_points,
    lifetime_points = user_points.lifetime_points + v_points,
    last_earned_at = CURRENT_TIMESTAMP,
    updated_at = CURRENT_TIMESTAMP;
    
  RETURN jsonb_build_object(
    'success', true,
    'points_earned', v_points,
    'expires_at', v_expires_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION redeem_points(
  p_user_id uuid,
  p_reward_id uuid,
  p_order_id uuid DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_reward rewards;
  v_user_points user_points;
  v_points_cost int;
BEGIN
  -- Get reward
  SELECT * INTO v_reward
  FROM rewards
  WHERE id = p_reward_id AND status = 'active'
  AND CURRENT_TIMESTAMP BETWEEN start_date AND end_date;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'المكافأة غير متوفرة'
    );
  END IF;
  
  -- Check usage limit
  IF v_reward.usage_limit IS NOT NULL 
  AND v_reward.used_count >= v_reward.usage_limit THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'تم استنفاذ الحد الأقصى لاستخدام هذه المكافأة'
    );
  END IF;
  
  -- Get user points
  SELECT * INTO v_user_points
  FROM user_points
  WHERE user_id = p_user_id;
  
  IF NOT FOUND OR v_user_points.available_points < v_reward.points_cost THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'نقاط غير كافية'
    );
  END IF;
  
  -- Create redemption
  INSERT INTO reward_redemptions (
    reward_id,
    user_id,
    order_id,
    points_spent,
    status
  ) VALUES (
    p_reward_id,
    p_user_id,
    p_order_id,
    v_reward.points_cost,
    'pending'
  );
  
  -- Update user points
  UPDATE user_points
  SET
    total_points = total_points - v_reward.points_cost,
    available_points = available_points - v_reward.points_cost,
    updated_at = CURRENT_TIMESTAMP
  WHERE user_id = p_user_id;
  
  -- Update reward usage
  UPDATE rewards
  SET
    used_count = used_count + 1,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_reward_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'points_spent', v_reward.points_cost,
    'reward', row_to_json(v_reward)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to process pending points
CREATE OR REPLACE FUNCTION process_pending_points() RETURNS void AS $$
BEGIN
  -- Move pending points to available points after order completion
  UPDATE user_points up
  SET
    available_points = available_points + pt.pending_points,
    pending_points = pending_points - pt.pending_points,
    updated_at = CURRENT_TIMESTAMP
  FROM (
    SELECT
      user_id,
      SUM(points) as pending_points
    FROM points_transactions
    WHERE status = 'pending'
    AND created_at <= CURRENT_TIMESTAMP - interval '24 hours'
    GROUP BY user_id
  ) pt
  WHERE up.user_id = pt.user_id;
  
  -- Update transactions status
  UPDATE points_transactions
  SET status = 'completed'
  WHERE status = 'pending'
  AND created_at <= CURRENT_TIMESTAMP - interval '24 hours';
  
  -- Process expired points
  WITH expired_points AS (
    SELECT
      user_id,
      SUM(points) as points_to_expire
    FROM points_transactions
    WHERE status = 'completed'
    AND expires_at <= CURRENT_TIMESTAMP
    AND type = 'earn'
    GROUP BY user_id
  )
  UPDATE user_points up
  SET
    total_points = total_points - ep.points_to_expire,
    available_points = available_points - ep.points_to_expire,
    updated_at = CURRENT_TIMESTAMP
  FROM expired_points ep
  WHERE up.user_id = ep.user_id;
  
  -- Record expired points transactions
  INSERT INTO points_transactions (
    user_id,
    points,
    type,
    status,
    description
  )
  SELECT
    user_id,
    points,
    'expire',
    'completed',
    'نقاط منتهية الصلاحية'
  FROM points_transactions
  WHERE status = 'completed'
  AND expires_at <= CURRENT_TIMESTAMP
  AND type = 'earn';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;