/*
  # إضافة جدول لربط البائعين بالسائقين

  1. جداول جديدة
    - `vendor_drivers`
      - جدول لربط البائعين بالسائقين المعينين لهم
      
  2. الأمان
    - تفعيل RLS على الجدول الجديد
    - إضافة سياسات للوصول
*/

-- إنشاء جدول vendor_drivers
CREATE TABLE IF NOT EXISTS vendor_drivers (
  vendor_id uuid REFERENCES vendors(id) ON DELETE CASCADE,
  driver_id uuid REFERENCES drivers(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (vendor_id, driver_id)
);

-- تفعيل RLS
ALTER TABLE vendor_drivers ENABLE ROW LEVEL SECURITY;

-- إنشاء سياسات الوصول
CREATE POLICY "Vendor drivers are viewable by everyone"
  ON vendor_drivers
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Vendors can manage their own drivers"
  ON vendor_drivers
  FOR ALL
  TO public
  USING (true)
  WITH CHECK (true);

-- إنشاء دالة للحصول على السائقين المعينين لبائع معين
CREATE OR REPLACE FUNCTION get_vendor_drivers(p_vendor_id uuid)
RETURNS TABLE (
  driver_id uuid,
  name text,
  phone text,
  email text,
  status text,
  rating decimal(3,2),
  rating_count int,
  vehicle_type text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id,
    d.name,
    d.phone,
    d.email,
    d.status,
    d.rating,
    d.rating_count,
    d.vehicle_type
  FROM vendor_drivers vd
  JOIN drivers d ON vd.driver_id = d.id
  WHERE vd.vendor_id = p_vendor_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة لتعيين سائق لبائع
CREATE OR REPLACE FUNCTION assign_driver_to_vendor(p_vendor_id uuid, p_driver_id uuid)
RETURNS boolean AS $$
BEGIN
  -- التحقق من وجود البائع والسائق
  IF NOT EXISTS (SELECT 1 FROM vendors WHERE id = p_vendor_id) THEN
    RETURN false;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM drivers WHERE id = p_driver_id) THEN
    RETURN false;
  END IF;
  
  -- إضافة العلاقة
  INSERT INTO vendor_drivers (vendor_id, driver_id)
  VALUES (p_vendor_id, p_driver_id)
  ON CONFLICT (vendor_id, driver_id) DO NOTHING;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة لإلغاء تعيين سائق من بائع
CREATE OR REPLACE FUNCTION unassign_driver_from_vendor(p_vendor_id uuid, p_driver_id uuid)
RETURNS boolean AS $$
BEGIN
  -- حذف العلاقة
  DELETE FROM vendor_drivers
  WHERE vendor_id = p_vendor_id AND driver_id = p_driver_id;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;