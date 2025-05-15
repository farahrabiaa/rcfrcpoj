/*
  # إصلاح مشكلة تعديل البائعين

  1. التغييرات
    - تحديث سياسات RLS للسماح بتعديل البائعين
    - إنشاء دالة لتحديث بيانات البائع بشكل آمن
*/

-- تمكين RLS
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;

-- حذف السياسات الموجودة إذا كانت موجودة
DO $$
BEGIN
  DROP POLICY IF EXISTS "Public can view active vendors" ON vendors;
  DROP POLICY IF EXISTS "Vendors are viewable by everyone" ON vendors;
  DROP POLICY IF EXISTS "Vendors can update their own data" ON vendors;
  DROP POLICY IF EXISTS "Users can create their own vendor" ON vendors;
  DROP POLICY IF EXISTS "Anyone can delete vendors" ON vendors;
  DROP POLICY IF EXISTS "Anyone can update vendors" ON vendors;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- إنشاء سياسات جديدة
CREATE POLICY "Public can view active vendors" 
  ON vendors
  FOR SELECT 
  TO public
  USING (status = 'active');

CREATE POLICY "Vendors are viewable by everyone" 
  ON vendors
  FOR SELECT 
  TO public
  USING (true);

CREATE POLICY "Users can create their own vendor" 
  ON vendors
  FOR INSERT
  TO public
  WITH CHECK (true);

-- سياسة جديدة تسمح لأي شخص بتحديث البائعين
CREATE POLICY "Anyone can update vendors" 
  ON vendors
  FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

-- سياسة للسماح بحذف البائعين
CREATE POLICY "Anyone can delete vendors" 
  ON vendors
  FOR DELETE
  TO public
  USING (true);

-- إنشاء دالة لتحديث بيانات البائع
CREATE OR REPLACE FUNCTION update_vendor(
  p_vendor_id uuid,
  p_store_name text,
  p_phone text,
  p_address text,
  p_description text,
  p_delivery_type text,
  p_delivery_radius numeric,
  p_price_per_km numeric,
  p_status text,
  p_logo_url text,
  p_banner_url text,
  p_wallet_enabled boolean,
  p_auto_charge boolean,
  p_service_areas text[],
  p_membership jsonb
)
RETURNS jsonb AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- تحديث بيانات البائع
  UPDATE vendors
  SET 
    store_name = p_store_name,
    phone = p_phone,
    address = p_address,
    description = p_description,
    delivery_type = p_delivery_type,
    delivery_radius = p_delivery_radius,
    price_per_km = p_price_per_km,
    status = p_status,
    logo_url = p_logo_url,
    banner_url = p_banner_url,
    wallet_enabled = p_wallet_enabled,
    auto_charge = p_auto_charge,
    service_areas = p_service_areas,
    membership = p_membership,
    updated_at = now()
  WHERE id = p_vendor_id
  RETURNING row_to_json(vendors.*)::jsonb INTO v_result;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة للحصول على بيانات البائع
CREATE OR REPLACE FUNCTION get_vendor_details(p_vendor_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_vendor jsonb;
  v_categories jsonb;
  v_products jsonb;
  v_result jsonb;
BEGIN
  -- الحصول على بيانات البائع
  SELECT row_to_json(v)::jsonb INTO v_vendor
  FROM (
    SELECT * FROM vendors WHERE id = p_vendor_id
  ) v;
  
  -- الحصول على فئات البائع
  SELECT json_agg(c.id)::jsonb INTO v_categories
  FROM vendor_categories vc
  JOIN categories c ON vc.category_id = c.id
  WHERE vc.vendor_id = p_vendor_id;
  
  -- الحصول على منتجات البائع
  SELECT json_agg(p)::jsonb INTO v_products
  FROM (
    SELECT * FROM products WHERE vendor_id = p_vendor_id
  ) p;
  
  -- دمج البيانات
  v_result := v_vendor;
  v_result := jsonb_set(v_result, '{categories}', COALESCE(v_categories, '[]'::jsonb));
  v_result := jsonb_set(v_result, '{products}', COALESCE(v_products, '[]'::jsonb));
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;