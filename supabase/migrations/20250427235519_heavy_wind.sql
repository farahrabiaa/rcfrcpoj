/*
  # إصلاح مشكلة حذف البائعين

  1. التغييرات
    - تحديث سياسات RLS للسماح بحذف البائعين
    - إضافة سياسة صريحة للسماح بحذف البائعين
    - إضافة سياسات للسماح بحذف المنتجات والإعلانات المرتبطة بالبائع
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

-- إضافة سياسة للسماح بحذف المنتجات المرتبطة بالبائع
DO $$
BEGIN
  DROP POLICY IF EXISTS "Anyone can delete products" ON products;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

CREATE POLICY "Anyone can delete products" 
  ON products
  FOR DELETE
  TO public
  USING (true);

-- إضافة سياسة للسماح بحذف الإعلانات المرتبطة بالبائع
DO $$
BEGIN
  DROP POLICY IF EXISTS "Anyone can delete advertisements" ON advertisements;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

CREATE POLICY "Anyone can delete advertisements" 
  ON advertisements
  FOR DELETE
  TO public
  USING (true);