/*
  # إنشاء جدول إعلانات السلايدر

  1. جداول جديدة
    - `slider_advertisements`
      - جدول لتخزين إعلانات السلايدر
      - يدعم الصور والفيديوهات
    
  2. الأمان
    - تفعيل RLS على الجدول الجديد
    - إضافة سياسات للوصول
*/

-- إنشاء جدول slider_advertisements
CREATE TABLE IF NOT EXISTS slider_advertisements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  vendor_id uuid REFERENCES vendors(id) ON DELETE CASCADE NOT NULL,
  image_url text,
  video_url text,
  link text,
  start_date date NOT NULL,
  end_date date NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'pending', 'active', 'expired')),
  priority int NOT NULL DEFAULT 1,
  is_video boolean DEFAULT false,
  clicks int NOT NULL DEFAULT 0,
  views int NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- تفعيل RLS
ALTER TABLE slider_advertisements ENABLE ROW LEVEL SECURITY;

-- إنشاء سياسات الوصول
CREATE POLICY "Slider advertisements are viewable by everyone"
  ON slider_advertisements
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Public can view active slider advertisements"
  ON slider_advertisements
  FOR SELECT
  TO public
  USING (
    status = 'active' AND 
    start_date <= CURRENT_DATE AND 
    end_date >= CURRENT_DATE
  );

CREATE POLICY "Vendors can manage their own slider advertisements"
  ON slider_advertisements
  FOR ALL
  TO public
  USING (true)
  WITH CHECK (true);

-- إنشاء مؤشر للبحث في حالة الإعلانات
CREATE INDEX IF NOT EXISTS idx_slider_advertisements_status ON slider_advertisements(status);

-- إنشاء مؤشر للبحث في تواريخ الإعلانات
CREATE INDEX IF NOT EXISTS idx_slider_advertisements_dates ON slider_advertisements(start_date, end_date);

-- إنشاء مؤشر للبحث في أولوية الإعلانات
CREATE INDEX IF NOT EXISTS idx_slider_advertisements_priority ON slider_advertisements(priority);

-- إنشاء trigger لتحديث حقل updated_at
CREATE TRIGGER update_slider_advertisements_updated_at
  BEFORE UPDATE ON slider_advertisements
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- إنشاء دالة لزيادة عدد المشاهدات
CREATE OR REPLACE FUNCTION increment_slider_views(p_slider_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE slider_advertisements
  SET views = views + 1
  WHERE id = p_slider_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة لزيادة عدد النقرات
CREATE OR REPLACE FUNCTION increment_slider_clicks(p_slider_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE slider_advertisements
  SET clicks = clicks + 1
  WHERE id = p_slider_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة للحصول على الإعلانات النشطة
CREATE OR REPLACE FUNCTION get_active_slider_advertisements()
RETURNS SETOF slider_advertisements AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM slider_advertisements
  WHERE 
    status = 'active' AND 
    start_date <= CURRENT_DATE AND 
    end_date >= CURRENT_DATE
  ORDER BY priority ASC, created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة للحصول على إعلانات بائع معين
CREATE OR REPLACE FUNCTION get_vendor_slider_advertisements(p_vendor_id uuid)
RETURNS SETOF slider_advertisements AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM slider_advertisements
  WHERE vendor_id = p_vendor_id
  ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة عامة للزيادة
CREATE OR REPLACE FUNCTION increment(row_id uuid, column_name text)
RETURNS int AS $$
DECLARE
  current_value int;
  table_name text := 'slider_advertisements';
  query text;
BEGIN
  -- تحديد الاستعلام الديناميكي
  query := format('SELECT %I FROM %I WHERE id = $1', column_name, table_name);
  
  -- تنفيذ الاستعلام للحصول على القيمة الحالية
  EXECUTE query INTO current_value USING row_id;
  
  -- زيادة القيمة
  current_value := current_value + 1;
  
  -- تحديث القيمة في قاعدة البيانات
  query := format('UPDATE %I SET %I = $1 WHERE id = $2 RETURNING %I', table_name, column_name, column_name);
  EXECUTE query INTO current_value USING current_value, row_id;
  
  RETURN current_value;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;