/*
  # Add Delivery Coupons System

  1. New Tables
    - `delivery_coupons`
      - Stores coupon codes and their rules
    - `coupon_usage`
      - Tracks coupon usage by users
    - `coupon_conditions`
      - Stores coupon restrictions and conditions

  2. Security
    - Enable RLS on new tables
    - Add policies for authenticated users
*/

-- Create delivery_coupons table
CREATE TABLE IF NOT EXISTS delivery_coupons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  type text NOT NULL CHECK (type IN ('percentage', 'fixed')),
  value decimal(10,2) NOT NULL,
  min_order decimal(10,2),
  max_discount decimal(10,2),
  usage_limit int,
  used_count int DEFAULT 0,
  start_date date NOT NULL,
  end_date date NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'expired')),
  description text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create coupon_conditions table
CREATE TABLE IF NOT EXISTS coupon_conditions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id uuid REFERENCES delivery_coupons(id) ON DELETE CASCADE,
  condition_type text NOT NULL CHECK (
    condition_type IN ('vendor', 'category', 'area', 'delivery_type', 'first_order')
  ),
  condition_value jsonb NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create coupon_usage table
CREATE TABLE IF NOT EXISTS coupon_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id uuid REFERENCES delivery_coupons(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id),
  order_id uuid REFERENCES orders(id),
  discount_amount decimal(10,2) NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE delivery_coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_usage ENABLE ROW LEVEL SECURITY;

-- Policies for delivery_coupons
CREATE POLICY "Coupons are viewable by everyone"
  ON delivery_coupons
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can modify coupons"
  ON delivery_coupons
  FOR ALL
  TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

-- Policies for coupon_conditions
CREATE POLICY "Coupon conditions are viewable by everyone"
  ON coupon_conditions
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can modify coupon conditions"
  ON coupon_conditions
  FOR ALL
  TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

-- Policies for coupon_usage
CREATE POLICY "Users can view their own coupon usage"
  ON coupon_usage
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert coupon usage"
  ON coupon_usage
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Functions for coupon validation and application
CREATE OR REPLACE FUNCTION validate_coupon(
  p_code text,
  p_user_id uuid,
  p_order_data jsonb
) RETURNS jsonb AS $$
DECLARE
  v_coupon delivery_coupons;
  v_conditions jsonb;
  v_discount decimal;
  v_delivery_fee decimal;
  v_error text;
BEGIN
  -- Get coupon
  SELECT * INTO v_coupon
  FROM delivery_coupons
  WHERE code = p_code AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', 'كود الخصم غير صالح'
    );
  END IF;

  -- Check dates
  IF CURRENT_DATE < v_coupon.start_date OR CURRENT_DATE > v_coupon.end_date THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', 'كود الخصم منتهي الصلاحية'
    );
  END IF;

  -- Check usage limit
  IF v_coupon.usage_limit IS NOT NULL AND v_coupon.used_count >= v_coupon.usage_limit THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', 'تم استنفاذ الحد الأقصى لاستخدام كود الخصم'
    );
  END IF;

  -- Check minimum order
  IF v_coupon.min_order IS NOT NULL AND (p_order_data->>'total')::decimal < v_coupon.min_order THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', format('الحد الأدنى للطلب هو %s₪', v_coupon.min_order)
    );
  END IF;

  -- Get conditions
  SELECT jsonb_agg(jsonb_build_object(
    'type', condition_type,
    'value', condition_value
  )) INTO v_conditions
  FROM coupon_conditions
  WHERE coupon_id = v_coupon.id;

  -- Check conditions
  IF v_conditions IS NOT NULL THEN
    FOR i IN 0..jsonb_array_length(v_conditions) - 1 LOOP
      CASE v_conditions->i->>'type'
        WHEN 'vendor' THEN
          IF NOT (v_conditions->i->'value' @> jsonb_build_array(p_order_data->>'vendor_id')) THEN
            RETURN jsonb_build_object(
              'valid', false,
              'error', 'كود الخصم غير صالح لهذا المتجر'
            );
          END IF;
        WHEN 'category' THEN
          IF NOT EXISTS (
            SELECT 1
            FROM jsonb_array_elements(p_order_data->'items') AS item
            WHERE v_conditions->i->'value' @> jsonb_build_array(item->>'category_id')
          ) THEN
            RETURN jsonb_build_object(
              'valid', false,
              'error', 'كود الخصم غير صالح لهذه المنتجات'
            );
          END IF;
        WHEN 'area' THEN
          IF NOT (v_conditions->i->'value' @> jsonb_build_array(p_order_data->>'delivery_area')) THEN
            RETURN jsonb_build_object(
              'valid', false,
              'error', 'كود الخصم غير صالح لمنطقة التوصيل'
            );
          END IF;
        WHEN 'delivery_type' THEN
          IF NOT (v_conditions->i->'value' @> jsonb_build_array(p_order_data->>'delivery_type')) THEN
            RETURN jsonb_build_object(
              'valid', false,
              'error', 'كود الخصم غير صالح لنوع التوصيل المحدد'
            );
          END IF;
        WHEN 'first_order' THEN
          IF EXISTS (
            SELECT 1 FROM orders WHERE user_id = p_user_id
          ) THEN
            RETURN jsonb_build_object(
              'valid', false,
              'error', 'كود الخصم صالح للطلب الأول فقط'
            );
          END IF;
      END CASE;
    END LOOP;
  END IF;

  -- Calculate discount
  v_delivery_fee := (p_order_data->>'delivery_fee')::decimal;
  
  IF v_coupon.type = 'percentage' THEN
    v_discount := (v_delivery_fee * v_coupon.value) / 100;
    IF v_coupon.max_discount IS NOT NULL THEN
      v_discount := LEAST(v_discount, v_coupon.max_discount);
    END IF;
  ELSE
    v_discount := v_coupon.value;
  END IF;

  RETURN jsonb_build_object(
    'valid', true,
    'coupon', row_to_json(v_coupon),
    'discount', v_discount,
    'final_delivery_fee', GREATEST(0, v_delivery_fee - v_discount)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION apply_coupon(
  p_code text,
  p_order_id uuid,
  p_user_id uuid,
  p_discount_amount decimal
) RETURNS jsonb AS $$
DECLARE
  v_coupon_id uuid;
BEGIN
  -- Get coupon ID
  SELECT id INTO v_coupon_id
  FROM delivery_coupons
  WHERE code = p_code;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'كود الخصم غير صالح'
    );
  END IF;

  -- Record usage
  INSERT INTO coupon_usage (
    coupon_id,
    user_id,
    order_id,
    discount_amount
  ) VALUES (
    v_coupon_id,
    p_user_id,
    p_order_id,
    p_discount_amount
  );

  -- Update usage count
  UPDATE delivery_coupons
  SET used_count = used_count + 1
  WHERE id = v_coupon_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم تطبيق كود الخصم بنجاح'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;