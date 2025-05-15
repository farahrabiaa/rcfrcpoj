/*
  # Referral System Implementation

  1. New Tables
    - `referral_codes`
      - For tracking user and influencer referral codes
    - `referral_rewards`
      - Configurable rewards for referrals
    - `referral_transactions`
      - Track referral usage and rewards

  2. Security
    - Enable RLS on new tables
    - Add policies for authenticated users
*/

-- Create referral_codes table
CREATE TABLE IF NOT EXISTS referral_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  code text UNIQUE NOT NULL,
  type text NOT NULL CHECK (type IN ('user', 'influencer')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  usage_limit int,
  used_count int DEFAULT 0,
  points_reward int NOT NULL,
  points_referrer int NOT NULL,
  expires_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Create referral_rewards table
CREATE TABLE IF NOT EXISTS referral_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  type text NOT NULL CHECK (type IN ('user', 'influencer')),
  points_reward int NOT NULL,
  points_referrer int NOT NULL,
  usage_limit int,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create referral_transactions table
CREATE TABLE IF NOT EXISTS referral_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_code_id uuid REFERENCES referral_codes NOT NULL,
  referrer_id uuid REFERENCES auth.users NOT NULL,
  referred_id uuid REFERENCES auth.users NOT NULL,
  points_awarded_referrer int NOT NULL,
  points_awarded_referred int NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_transactions ENABLE ROW LEVEL SECURITY;

-- Policies for referral_codes
CREATE POLICY "Users can view their own referral codes"
  ON referral_codes
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "System can create referral codes"
  ON referral_codes
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Policies for referral_rewards
CREATE POLICY "Referral rewards are viewable by everyone"
  ON referral_rewards
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can modify referral rewards"
  ON referral_rewards
  FOR ALL
  TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

-- Policies for referral_transactions
CREATE POLICY "Users can view their own referral transactions"
  ON referral_transactions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = referrer_id OR auth.uid() = referred_id);

-- Functions for referral management
CREATE OR REPLACE FUNCTION generate_referral_code(
  p_user_id uuid,
  p_type text DEFAULT 'user'
) RETURNS text AS $$
DECLARE
  v_code text;
  v_exists boolean;
BEGIN
  LOOP
    -- Generate random code
    IF p_type = 'user' THEN
      -- 6 characters for regular users
      v_code := upper(substring(md5(random()::text) from 1 for 6));
    ELSE
      -- 8 characters for influencers
      v_code := upper(substring(md5(random()::text) from 1 for 8));
    END IF;

    -- Check if code exists
    SELECT EXISTS (
      SELECT 1 FROM referral_codes WHERE code = v_code
    ) INTO v_exists;

    EXIT WHEN NOT v_exists;
  END LOOP;

  RETURN v_code;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_referral_code(
  p_user_id uuid,
  p_type text DEFAULT 'user',
  p_usage_limit int DEFAULT NULL,
  p_expires_at timestamptz DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_code text;
  v_reward referral_rewards;
BEGIN
  -- Get reward settings
  SELECT * INTO v_reward
  FROM referral_rewards
  WHERE type = p_type AND status = 'active'
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'لم يتم العثور على إعدادات المكافآت'
    );
  END IF;

  -- Generate unique code
  v_code := generate_referral_code(p_user_id, p_type);

  -- Create referral code
  INSERT INTO referral_codes (
    user_id,
    code,
    type,
    usage_limit,
    points_reward,
    points_referrer,
    expires_at
  ) VALUES (
    p_user_id,
    v_code,
    p_type,
    p_usage_limit,
    v_reward.points_reward,
    v_reward.points_referrer,
    p_expires_at
  );

  RETURN jsonb_build_object(
    'success', true,
    'code', v_code,
    'points_reward', v_reward.points_reward,
    'points_referrer', v_reward.points_referrer
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION apply_referral_code(
  p_code text,
  p_user_id uuid
) RETURNS jsonb AS $$
DECLARE
  v_referral referral_codes;
  v_transaction_id uuid;
BEGIN
  -- Get referral code
  SELECT * INTO v_referral
  FROM referral_codes
  WHERE code = p_code AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'كود الإحالة غير صالح'
    );
  END IF;

  -- Check if code is expired
  IF v_referral.expires_at IS NOT NULL AND v_referral.expires_at < CURRENT_TIMESTAMP THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'كود الإحالة منتهي الصلاحية'
    );
  END IF;

  -- Check usage limit
  IF v_referral.usage_limit IS NOT NULL AND v_referral.used_count >= v_referral.usage_limit THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'تم استنفاذ الحد الأقصى لاستخدام كود الإحالة'
    );
  END IF;

  -- Check if user is trying to use their own code
  IF v_referral.user_id = p_user_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'لا يمكنك استخدام كود الإحالة الخاص بك'
    );
  END IF;

  -- Check if user already used a referral code
  IF EXISTS (
    SELECT 1 FROM referral_transactions
    WHERE referred_id = p_user_id AND status != 'cancelled'
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'لقد قمت باستخدام كود إحالة من قبل'
    );
  END IF;

  -- Create transaction
  INSERT INTO referral_transactions (
    referral_code_id,
    referrer_id,
    referred_id,
    points_awarded_referrer,
    points_awarded_referred,
    status
  ) VALUES (
    v_referral.id,
    v_referral.user_id,
    p_user_id,
    v_referral.points_referrer,
    v_referral.points_reward,
    'pending'
  ) RETURNING id INTO v_transaction_id;

  -- Update usage count
  UPDATE referral_codes
  SET used_count = used_count + 1
  WHERE id = v_referral.id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم تطبيق كود الإحالة بنجاح',
    'points_reward', v_referral.points_reward
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert default referral rewards
INSERT INTO referral_rewards (
  name,
  description,
  type,
  points_reward,
  points_referrer,
  usage_limit,
  status
) VALUES 
(
  'مكافأة إحالة المستخدم',
  'احصل على نقاط عند دعوة صديق',
  'user',
  100, -- المستخدم الجديد يحصل على 100 نقطة
  50,  -- المستخدم الداعي يحصل على 50 نقطة
  NULL,
  'active'
),
(
  'مكافأة إحالة المشاهير',
  'برنامج إحالة خاص للمشاهير',
  'influencer',
  200, -- المستخدم الجديد يحصل على 200 نقطة
  100, -- المشهور يحصل على 100 نقطة لكل إحالة
  NULL,
  'active'
);