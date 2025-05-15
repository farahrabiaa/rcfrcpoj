/*
  # إضافة حقل صورة للتصنيفات وربط تصنيفات البائعين

  1. التغييرات
    - إضافة حقل image_url لجدول التصنيفات
    - إنشاء دالة لربط تصنيفات البائعين بتصنيفات لوحة التحكم
    - تحديث سياسات RLS للسماح بإدارة التصنيفات
*/

-- إضافة حقل image_url لجدول التصنيفات إذا لم يكن موجودًا
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'categories' 
    AND column_name = 'image_url'
  ) THEN
    ALTER TABLE categories ADD COLUMN image_url text;
  END IF;
END
$$;

-- تحديث سياسات RLS للسماح بإدارة التصنيفات
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- حذف السياسات الموجودة إذا كانت موجودة
DO $$
BEGIN
  DROP POLICY IF EXISTS "Categories are viewable by everyone" ON categories;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- إنشاء سياسات جديدة
CREATE POLICY "Categories are viewable by everyone" 
  ON categories
  FOR SELECT 
  TO public
  USING (true);

CREATE POLICY "Anyone can manage categories" 
  ON categories
  FOR ALL
  TO public
  USING (true)
  WITH CHECK (true);

-- إنشاء دالة لربط تصنيفات البائعين بتصنيفات لوحة التحكم
CREATE OR REPLACE FUNCTION link_vendor_to_category(
  p_vendor_id uuid,
  p_category_id uuid
)
RETURNS boolean AS $$
BEGIN
  -- التحقق من وجود البائع والتصنيف
  IF NOT EXISTS (SELECT 1 FROM vendors WHERE id = p_vendor_id) THEN
    RETURN false;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM categories WHERE id = p_category_id) THEN
    RETURN false;
  END IF;
  
  -- إضافة العلاقة
  INSERT INTO vendor_categories (vendor_id, category_id)
  VALUES (p_vendor_id, p_category_id)
  ON CONFLICT (vendor_id, category_id) DO NOTHING;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة لإلغاء ربط تصنيف من بائع
CREATE OR REPLACE FUNCTION unlink_vendor_from_category(
  p_vendor_id uuid,
  p_category_id uuid
)
RETURNS boolean AS $$
BEGIN
  -- حذف العلاقة
  DELETE FROM vendor_categories
  WHERE vendor_id = p_vendor_id AND category_id = p_category_id;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة للحصول على تصنيفات بائع معين
CREATE OR REPLACE FUNCTION get_vendor_categories(p_vendor_id uuid)
RETURNS TABLE (
  id uuid,
  name text,
  slug text,
  description text,
  image_url text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.name,
    c.slug,
    c.description,
    c.image_url
  FROM vendor_categories vc
  JOIN categories c ON vc.category_id = c.id
  WHERE vc.vendor_id = p_vendor_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة للحصول على البائعين في تصنيف معين
CREATE OR REPLACE FUNCTION get_category_vendors(p_category_id uuid)
RETURNS TABLE (
  id uuid,
  store_name text,
  logo_url text,
  rating decimal(3,2)
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.id,
    v.store_name,
    v.logo_url,
    v.rating
  FROM vendor_categories vc
  JOIN vendors v ON vc.vendor_id = v.id
  WHERE vc.category_id = p_category_id
  AND v.status = 'active';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;