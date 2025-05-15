/*
  # إصلاح مشكلة حذف البائعين بشكل نهائي

  1. التغييرات
    - إضافة قيود CASCADE للعلاقات الخارجية المرتبطة بالبائعين
    - تحديث سياسات RLS للسماح بالحذف
    - إضافة دالة لحذف البائع وجميع البيانات المرتبطة به
*/

-- تحديث العلاقات الخارجية للمنتجات لتستخدم CASCADE
ALTER TABLE products 
  DROP CONSTRAINT IF EXISTS products_vendor_id_fkey;

ALTER TABLE products
  ADD CONSTRAINT products_vendor_id_fkey
  FOREIGN KEY (vendor_id) 
  REFERENCES vendors(id) 
  ON DELETE CASCADE;

-- تحديث العلاقات الخارجية للإعلانات لتستخدم CASCADE
ALTER TABLE advertisements 
  DROP CONSTRAINT IF EXISTS advertisements_vendor_id_fkey;

ALTER TABLE advertisements
  ADD CONSTRAINT advertisements_vendor_id_fkey
  FOREIGN KEY (vendor_id) 
  REFERENCES vendors(id) 
  ON DELETE CASCADE;

-- تحديث العلاقات الخارجية لفئات البائعين لتستخدم CASCADE
ALTER TABLE vendor_categories 
  DROP CONSTRAINT IF EXISTS vendor_categories_vendor_id_fkey;

ALTER TABLE vendor_categories
  ADD CONSTRAINT vendor_categories_vendor_id_fkey
  FOREIGN KEY (vendor_id) 
  REFERENCES vendors(id) 
  ON DELETE CASCADE;

-- تحديث العلاقات الخارجية للطلبات لتستخدم SET NULL
ALTER TABLE orders 
  DROP CONSTRAINT IF EXISTS orders_vendor_id_fkey;

ALTER TABLE orders
  ADD CONSTRAINT orders_vendor_id_fkey
  FOREIGN KEY (vendor_id) 
  REFERENCES vendors(id) 
  ON DELETE SET NULL;

-- تحديث سياسات RLS للسماح بحذف البائعين
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;

-- حذف السياسات الموجودة إذا كانت موجودة
DO $$
BEGIN
  DROP POLICY IF EXISTS "Public can view active vendors" ON vendors;
  DROP POLICY IF EXISTS "Vendors are viewable by everyone" ON vendors;
  DROP POLICY IF EXISTS "Vendors can update their own data" ON vendors;
  DROP POLICY IF EXISTS "Users can create their own vendor" ON vendors;
  DROP POLICY IF EXISTS "Anyone can delete vendors" ON vendors;
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

CREATE POLICY "Vendors can update their own data" 
  ON vendors
  FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

-- إضافة سياسة صريحة للسماح بحذف البائعين
CREATE POLICY "Anyone can delete vendors" 
  ON vendors
  FOR DELETE
  TO public
  USING (true);

-- إنشاء دالة لحذف البائع وجميع البيانات المرتبطة به
CREATE OR REPLACE FUNCTION delete_vendor_completely(p_vendor_id uuid)
RETURNS boolean AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- الحصول على معرف المستخدم المرتبط بالبائع
  SELECT user_id INTO v_user_id
  FROM vendors
  WHERE id = p_vendor_id;
  
  -- حذف المنتجات المرتبطة بالبائع
  DELETE FROM products
  WHERE vendor_id = p_vendor_id;
  
  -- حذف الإعلانات المرتبطة بالبائع
  DELETE FROM advertisements
  WHERE vendor_id = p_vendor_id;
  
  -- حذف فئات البائع
  DELETE FROM vendor_categories
  WHERE vendor_id = p_vendor_id;
  
  -- تحديث الطلبات المرتبطة بالبائع
  UPDATE orders
  SET vendor_id = NULL
  WHERE vendor_id = p_vendor_id;
  
  -- حذف البائع نفسه
  DELETE FROM vendors
  WHERE id = p_vendor_id;
  
  -- حذف المستخدم المرتبط بالبائع إذا كان موجودًا
  IF v_user_id IS NOT NULL THEN
    DELETE FROM custom_users
    WHERE id = v_user_id;
  END IF;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;