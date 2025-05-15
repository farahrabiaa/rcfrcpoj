/*
  # Referral System Implementation
  
  1. New Tables
    - `referral_codes` - Stores unique referral codes for users
    - `referrals` - Tracks referral relationships between users
    - `referral_rewards` - Defines reward configurations for referrals
    - `referral_transactions` - Records point/reward transactions from referrals
  
  2. Security
    - Enable RLS on all tables
    - Add policies for proper access control
    
  3. Functions
    - Functions to generate and validate referral codes
    - Functions to process referrals and distribute rewards
*/

-- Create referral_rewards table
CREATE TABLE IF NOT EXISTS referral_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  type TEXT NOT NULL,
  points_reward INTEGER NOT NULL,
  points_referrer INTEGER NOT NULL,
  usage_limit INTEGER,
  used_count INTEGER DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT referral_rewards_type_check CHECK (type IN ('user', 'influencer')),
  CONSTRAINT referral_rewards_status_check CHECK (status IN ('active', 'inactive'))
);

-- Create referral_codes table
CREATE TABLE IF NOT EXISTS referral_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  usage_limit INTEGER,
  used_count INTEGER DEFAULT 0,
  points_reward INTEGER NOT NULL,
  points_referrer INTEGER NOT NULL,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT referral_codes_type_check CHECK (type IN ('user', 'influencer')),
  CONSTRAINT referral_codes_status_check CHECK (status IN ('active', 'inactive', 'expired'))
);

-- Create referrals table
CREATE TABLE IF NOT EXISTS referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES auth.users(id),
  referred_id UUID NOT NULL REFERENCES auth.users(id),
  code_id UUID NOT NULL REFERENCES referral_codes(id),
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ,
  CONSTRAINT referrals_status_check CHECK (status IN ('pending', 'completed', 'cancelled')),
  CONSTRAINT referrals_unique_referred UNIQUE (referred_id)
);

-- Create referral_transactions table
CREATE TABLE IF NOT EXISTS referral_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id UUID NOT NULL REFERENCES referrals(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  points INTEGER NOT NULL,
  type TEXT NOT NULL,
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT referral_transactions_type_check CHECK (type IN ('reward', 'referrer_bonus'))
);

-- Enable RLS on all tables
ALTER TABLE referral_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_transactions ENABLE ROW LEVEL SECURITY;

-- Create policies for referral_rewards
CREATE POLICY "Referral rewards are viewable by everyone"
  ON referral_rewards
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage referral rewards"
  ON referral_rewards
  FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- Create policies for referral_codes
CREATE POLICY "Users can view their own referral codes"
  ON referral_codes
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can create their own referral codes"
  ON referral_codes
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Create policies for referrals
CREATE POLICY "Users can view their own referrals"
  ON referrals
  FOR SELECT
  TO authenticated
  USING (referrer_id = auth.uid() OR referred_id = auth.uid());

CREATE POLICY "Anyone can create referrals"
  ON referrals
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Create policies for referral_transactions
CREATE POLICY "Users can view their own referral transactions"
  ON referral_transactions
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Create function to generate a unique referral code
CREATE OR REPLACE FUNCTION generate_referral_code(p_user_id UUID, p_length INTEGER DEFAULT 8)
RETURNS TEXT AS $$
DECLARE
  v_code TEXT;
  v_exists BOOLEAN;
BEGIN
  LOOP
    -- Generate a random code
    SELECT array_to_string(array(
      SELECT substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', ceil(random() * 36)::integer, 1)
      FROM generate_series(1, p_length)
    ), '') INTO v_code;
    
    -- Check if code already exists
    SELECT EXISTS(
      SELECT 1 FROM referral_codes WHERE code = v_code
    ) INTO v_exists;
    
    -- Exit loop if code is unique
    EXIT WHEN NOT v_exists;
  END LOOP;
  
  RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to create a referral code for a user
CREATE OR REPLACE FUNCTION create_user_referral_code(
  p_user_id UUID,
  p_type TEXT DEFAULT 'user',
  p_usage_limit INTEGER DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_code TEXT;
  v_reward RECORD;
  v_code_id UUID;
BEGIN
  -- Check if user already has a referral code of this type
  IF EXISTS (
    SELECT 1 FROM referral_codes 
    WHERE user_id = p_user_id AND type = p_type AND status = 'active'
  ) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'User already has an active referral code of this type'
    );
  END IF;
  
  -- Get reward configuration
  SELECT * INTO v_reward
  FROM referral_rewards
  WHERE type = p_type AND status = 'active'
  LIMIT 1;
  
  IF v_reward.id IS NULL THEN
    -- Use default values if no reward configuration exists
    v_reward.points_reward := 100;
    v_reward.points_referrer := 50;
  END IF;
  
  -- Generate a unique referral code
  v_code := generate_referral_code(p_user_id);
  
  -- Create the referral code
  INSERT INTO referral_codes (
    user_id,
    code,
    type,
    status,
    usage_limit,
    points_reward,
    points_referrer,
    expires_at
  ) VALUES (
    p_user_id,
    v_code,
    p_type,
    'active',
    p_usage_limit,
    v_reward.points_reward,
    v_reward.points_referrer,
    CASE 
      WHEN p_type = 'user' THEN NULL -- User codes don't expire
      ELSE (CURRENT_DATE + INTERVAL '1 year')::TIMESTAMPTZ -- Influencer codes expire after 1 year
    END
  )
  RETURNING id INTO v_code_id;
  
  -- Return success
  RETURN json_build_object(
    'success', true,
    'code', v_code,
    'code_id', v_code_id,
    'points_reward', v_reward.points_reward,
    'points_referrer', v_reward.points_referrer
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to apply a referral code
CREATE OR REPLACE FUNCTION apply_referral_code(
  p_user_id UUID,
  p_code TEXT
)
RETURNS JSON AS $$
DECLARE
  v_code RECORD;
  v_referral_id UUID;
BEGIN
  -- Check if user has already been referred
  IF EXISTS (
    SELECT 1 FROM referrals WHERE referred_id = p_user_id
  ) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'User has already been referred'
    );
  END IF;
  
  -- Get referral code
  SELECT * INTO v_code
  FROM referral_codes
  WHERE code = p_code AND status = 'active';
  
  -- Check if code exists
  IF v_code.id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid referral code'
    );
  END IF;
  
  -- Check if code has reached usage limit
  IF v_code.usage_limit IS NOT NULL AND v_code.used_count >= v_code.usage_limit THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Referral code has reached its usage limit'
    );
  END IF;
  
  -- Check if code has expired
  IF v_code.expires_at IS NOT NULL AND v_code.expires_at < now() THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Referral code has expired'
    );
  END IF;
  
  -- Check if user is trying to refer themselves
  IF v_code.user_id = p_user_id THEN
    RETURN json_build_object(
      'success', false,
      'message', 'You cannot refer yourself'
    );
  END IF;
  
  -- Create referral
  INSERT INTO referrals (
    referrer_id,
    referred_id,
    code_id,
    status
  ) VALUES (
    v_code.user_id,
    p_user_id,
    v_code.id,
    'pending'
  )
  RETURNING id INTO v_referral_id;
  
  -- Increment code usage count
  UPDATE referral_codes
  SET used_count = used_count + 1
  WHERE id = v_code.id;
  
  -- Return success
  RETURN json_build_object(
    'success', true,
    'message', 'Referral code applied successfully',
    'referral_id', v_referral_id,
    'points_reward', v_code.points_reward,
    'points_referrer', v_code.points_referrer
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to complete a referral and award points
CREATE OR REPLACE FUNCTION complete_referral(
  p_referral_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_referral RECORD;
  v_code RECORD;
  v_points_account_id UUID;
BEGIN
  -- Get referral
  SELECT * INTO v_referral
  FROM referrals
  WHERE id = p_referral_id;
  
  -- Check if referral exists
  IF v_referral.id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Referral not found'
    );
  END IF;
  
  -- Check if referral is already completed
  IF v_referral.status = 'completed' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Referral already completed'
    );
  END IF;
  
  -- Get referral code
  SELECT * INTO v_code
  FROM referral_codes
  WHERE id = v_referral.code_id;
  
  -- Update referral status
  UPDATE referrals
  SET 
    status = 'completed',
    completed_at = now()
  WHERE id = p_referral_id;
  
  -- Award points to referred user
  PERFORM add_customer_points(
    p_customer_id := v_referral.referred_id,
    p_amount := v_code.points_reward,
    p_type := 'earn',
    p_description := 'Referral bonus'
  );
  
  -- Record referral transaction for referred user
  INSERT INTO referral_transactions (
    referral_id,
    user_id,
    points,
    type,
    description
  ) VALUES (
    p_referral_id,
    v_referral.referred_id,
    v_code.points_reward,
    'reward',
    'Referral signup bonus'
  );
  
  -- Award points to referrer
  PERFORM add_customer_points(
    p_customer_id := v_referral.referrer_id,
    p_amount := v_code.points_referrer,
    p_type := 'earn',
    p_description := 'Referral bonus for inviting a friend'
  );
  
  -- Record referral transaction for referrer
  INSERT INTO referral_transactions (
    referral_id,
    user_id,
    points,
    type,
    description
  ) VALUES (
    p_referral_id,
    v_referral.referrer_id,
    v_code.points_referrer,
    'referrer_bonus',
    'Bonus for referring a new user'
  );
  
  -- Return success
  RETURN json_build_object(
    'success', true,
    'message', 'Referral completed successfully',
    'points_awarded_to_referred', v_code.points_reward,
    'points_awarded_to_referrer', v_code.points_referrer
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get user referrals
CREATE OR REPLACE FUNCTION get_user_referrals(
  p_user_id UUID
)
RETURNS TABLE (
  id UUID,
  referrer_id UUID,
  referrer_name TEXT,
  referred_id UUID,
  referred_name TEXT,
  code TEXT,
  status TEXT,
  created_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    r.id,
    r.referrer_id,
    COALESCE(p_referrer.name, 'Unknown') AS referrer_name,
    r.referred_id,
    COALESCE(p_referred.name, 'Unknown') AS referred_name,
    rc.code,
    r.status,
    r.created_at,
    r.completed_at
  FROM 
    referrals r
    JOIN referral_codes rc ON r.code_id = rc.id
    LEFT JOIN profiles p_referrer ON r.referrer_id = p_referrer.id
    LEFT JOIN profiles p_referred ON r.referred_id = p_referred.id
  WHERE 
    r.referrer_id = p_user_id OR r.referred_id = p_user_id
  ORDER BY 
    r.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get referral statistics
CREATE OR REPLACE FUNCTION get_referral_statistics(
  p_user_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_total_referrals INTEGER;
  v_completed_referrals INTEGER;
  v_pending_referrals INTEGER;
  v_total_points_earned INTEGER;
  v_code TEXT;
  v_code_usage INTEGER;
  v_code_limit INTEGER;
BEGIN
  -- Get referral counts
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'completed'),
    COUNT(*) FILTER (WHERE status = 'pending')
  INTO 
    v_total_referrals,
    v_completed_referrals,
    v_pending_referrals
  FROM 
    referrals
  WHERE 
    referrer_id = p_user_id;
  
  -- Get total points earned from referrals
  SELECT 
    COALESCE(SUM(points), 0)
  INTO 
    v_total_points_earned
  FROM 
    referral_transactions
  WHERE 
    user_id = p_user_id;
  
  -- Get active referral code
  SELECT 
    code,
    used_count,
    usage_limit
  INTO 
    v_code,
    v_code_usage,
    v_code_limit
  FROM 
    referral_codes
  WHERE 
    user_id = p_user_id
    AND status = 'active'
  ORDER BY 
    created_at DESC
  LIMIT 1;
  
  -- Return statistics
  RETURN json_build_object(
    'total_referrals', v_total_referrals,
    'completed_referrals', v_completed_referrals,
    'pending_referrals', v_pending_referrals,
    'total_points_earned', v_total_points_earned,
    'active_code', v_code,
    'code_usage', v_code_usage,
    'code_limit', v_code_limit
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert default referral rewards if they don't exist
INSERT INTO referral_rewards (name, description, type, points_reward, points_referrer, status)
VALUES 
  ('مكافأة إحالة المستخدم', 'احصل على نقاط عند دعوة صديق', 'user', 100, 50, 'active'),
  ('مكافأة إحالة المشاهير', 'برنامج إحالة خاص للمشاهير', 'influencer', 200, 100, 'active')
ON CONFLICT DO NOTHING;