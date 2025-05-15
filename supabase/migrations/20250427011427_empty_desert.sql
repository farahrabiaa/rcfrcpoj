/*
  # إضافة أعمدة العضوية واللوجو والبانر لجدول البائعين

  1. التغييرات
    - إضافة عمود membership لتخزين بيانات العضوية كـ JSON
    - التأكد من وجود أعمدة logo_url و banner_url
    - إنشاء مؤشرات للبحث السريع
*/

-- إضافة عمود membership إذا لم يكن موجودًا
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'vendors' 
    AND column_name = 'membership'
  ) THEN
    ALTER TABLE vendors ADD COLUMN membership jsonb DEFAULT jsonb_build_object(
      'type', 'basic',
      'expires_at', (CURRENT_DATE + INTERVAL '1 year')::text,
      'commission_rate', 10
    );
  END IF;
END
$$;

-- التأكد من وجود أعمدة logo_url و banner_url
DO $$
BEGIN
  -- التحقق من وجود عمود logo_url
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'vendors' 
    AND column_name = 'logo_url'
  ) THEN
    ALTER TABLE vendors ADD COLUMN logo_url text DEFAULT NULL;
  END IF;

  -- التحقق من وجود عمود banner_url
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'vendors' 
    AND column_name = 'banner_url'
  ) THEN
    ALTER TABLE vendors ADD COLUMN banner_url text DEFAULT NULL;
  END IF;
END
$$;

-- إنشاء مؤشر للبحث في بيانات العضوية
CREATE INDEX IF NOT EXISTS idx_vendors_membership ON vendors USING gin (membership);

-- تحديث البائعين الحاليين بقيم افتراضية للعضوية إذا كانت فارغة
UPDATE vendors
SET membership = jsonb_build_object(
  'type', 'basic',
  'expires_at', (CURRENT_DATE + INTERVAL '1 year')::text,
  'commission_rate', 10
)
WHERE membership IS NULL;

-- إنشاء دالة للتحقق من صلاحية العضوية
CREATE OR REPLACE FUNCTION is_membership_valid(p_vendor_id uuid)
RETURNS boolean AS $$
DECLARE
  v_expires_at date;
  v_membership jsonb;
BEGIN
  -- الحصول على بيانات العضوية
  SELECT membership INTO v_membership
  FROM vendors
  WHERE id = p_vendor_id;
  
  -- إذا لم تكن هناك بيانات عضوية، فالعضوية غير صالحة
  IF v_membership IS NULL THEN
    RETURN false;
  END IF;
  
  -- تحويل تاريخ الانتهاء إلى نوع date
  BEGIN
    v_expires_at := (v_membership->>'expires_at')::date;
  EXCEPTION WHEN OTHERS THEN
    -- إذا كان هناك خطأ في التحويل، فالعضوية غير صالحة
    RETURN false;
  END;
  
  -- التحقق من صلاحية العضوية
  RETURN v_expires_at >= CURRENT_DATE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة للحصول على نوع العضوية
CREATE OR REPLACE FUNCTION get_membership_type(p_vendor_id uuid)
RETURNS text AS $$
DECLARE
  v_membership jsonb;
BEGIN
  -- الحصول على بيانات العضوية
  SELECT membership INTO v_membership
  FROM vendors
  WHERE id = p_vendor_id;
  
  -- إذا لم تكن هناك بيانات عضوية، فالنوع هو 'basic'
  IF v_membership IS NULL THEN
    RETURN 'basic';
  END IF;
  
  -- إعادة نوع العضوية
  RETURN v_membership->>'type';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة للحصول على نسبة العمولة حسب العضوية
CREATE OR REPLACE FUNCTION get_membership_commission_rate(p_vendor_id uuid)
RETURNS numeric AS $$
DECLARE
  v_membership jsonb;
  v_commission_rate numeric;
BEGIN
  -- الحصول على بيانات العضوية
  SELECT membership INTO v_membership
  FROM vendors
  WHERE id = p_vendor_id;
  
  -- إذا لم تكن هناك بيانات عضوية، فالنسبة هي 10%
  IF v_membership IS NULL THEN
    RETURN 10;
  END IF;
  
  -- محاولة الحصول على نسبة العمولة من بيانات العضوية
  BEGIN
    v_commission_rate := (v_membership->>'commission_rate')::numeric;
  EXCEPTION WHEN OTHERS THEN
    -- إذا كان هناك خطأ في التحويل، فالنسبة هي 10%
    RETURN 10;
  END;
  
  -- إعادة نسبة العمولة
  RETURN v_commission_rate;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;