/*
  # Add Wholesale Customer Support

  1. New Tables
    - `wholesale_tiers` - Defines different wholesale customer tiers
    
  2. Changes
    - Add `wholesale_info` column to customers table
    
  3. Security
    - Enable RLS on new tables
    - Add policies for access control
*/

-- Create wholesale_tiers table
CREATE TABLE IF NOT EXISTS wholesale_tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  min_purchase_amount numeric NOT NULL DEFAULT 0,
  discount_percentage numeric NOT NULL DEFAULT 0,
  min_order_amount numeric NOT NULL DEFAULT 0,
  benefits text[] DEFAULT '{}',
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Add wholesale_info column to customers table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'customers' 
    AND column_name = 'wholesale_info'
  ) THEN
    ALTER TABLE customers ADD COLUMN wholesale_info jsonb DEFAULT NULL;
  END IF;
END
$$;

-- Enable RLS
ALTER TABLE wholesale_tiers ENABLE ROW LEVEL SECURITY;

-- Create policies for wholesale_tiers
CREATE POLICY "Wholesale tiers are viewable by everyone"
  ON wholesale_tiers
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage wholesale tiers"
  ON wholesale_tiers
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_users
      WHERE user_id = auth.uid()
    )
  );

-- Create trigger for wholesale_tiers table
CREATE TRIGGER update_wholesale_tiers_updated_at
  BEFORE UPDATE ON wholesale_tiers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert default tiers
INSERT INTO wholesale_tiers (name, description, min_purchase_amount, discount_percentage, min_order_amount, benefits, status)
VALUES 
  (
    'برونزي', 
    'المستوى الأساسي للتجار', 
    5000, 
    5, 
    500, 
    ARRAY['خصم 5% على جميع المنتجات', 'دعم أولوية للتجار', 'تقارير شهرية'], 
    'active'
  ),
  (
    'فضي', 
    'المستوى المتوسط للتجار', 
    10000, 
    10, 
    1000, 
    ARRAY['خصم 10% على جميع المنتجات', 'دعم أولوية للتجار', 'تقارير أسبوعية', 'شحن مجاني للطلبات فوق 2000₪'], 
    'active'
  ),
  (
    'ذهبي', 
    'المستوى المتقدم للتجار', 
    25000, 
    15, 
    2000, 
    ARRAY['خصم 15% على جميع المنتجات', 'دعم أولوية قصوى', 'تقارير يومية', 'شحن مجاني لجميع الطلبات', 'مدير حساب مخصص'], 
    'active'
  ),
  (
    'بلاتيني', 
    'المستوى الأعلى للتجار', 
    50000, 
    20, 
    5000, 
    ARRAY['خصم 20% على جميع المنتجات', 'دعم على مدار الساعة', 'تقارير مخصصة', 'شحن مجاني وسريع لجميع الطلبات', 'مدير حساب مخصص', 'أسعار خاصة للمنتجات الجديدة'], 
    'active'
  )
ON CONFLICT DO NOTHING;

-- Create function to get wholesale tier for a customer
CREATE OR REPLACE FUNCTION get_customer_wholesale_tier(p_customer_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_customer_info jsonb;
  v_tier_info jsonb;
BEGIN
  -- Get customer wholesale info
  SELECT wholesale_info INTO v_customer_info
  FROM customers
  WHERE id = p_customer_id;
  
  -- If customer has no wholesale info, return null
  IF v_customer_info IS NULL THEN
    RETURN NULL;
  END IF;
  
  -- Get tier info
  SELECT row_to_json(t)::jsonb INTO v_tier_info
  FROM (
    SELECT * FROM wholesale_tiers
    WHERE id = (v_customer_info->>'tier_id')::uuid
  ) t;
  
  -- Combine customer and tier info
  RETURN jsonb_build_object(
    'customer', v_customer_info,
    'tier', v_tier_info
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get all wholesale customers
CREATE OR REPLACE FUNCTION get_wholesale_customers()
RETURNS TABLE (
  id uuid,
  name text,
  company_name text,
  tier_id uuid,
  tier_name text,
  tax_number text,
  total_purchases numeric,
  status text,
  contact_phone text,
  contact_email text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.name,
    (c.wholesale_info->>'company_name')::text,
    (c.wholesale_info->>'tier_id')::uuid,
    wt.name,
    (c.wholesale_info->>'tax_number')::text,
    COALESCE((c.wholesale_info->>'total_purchases')::numeric, 0),
    (c.wholesale_info->>'status')::text,
    c.phone,
    c.email
  FROM customers c
  LEFT JOIN wholesale_tiers wt ON wt.id = (c.wholesale_info->>'tier_id')::uuid
  WHERE c.wholesale_info IS NOT NULL
  ORDER BY c.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;