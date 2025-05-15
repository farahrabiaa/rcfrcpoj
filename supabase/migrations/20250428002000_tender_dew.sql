-- إضافة مؤشر للبحث في بيانات عملاء الجملة
CREATE INDEX IF NOT EXISTS idx_customers_wholesale_info ON customers USING GIN (wholesale_info);

-- إنشاء دالة للتحقق من أهلية العميل للجملة
CREATE OR REPLACE FUNCTION is_wholesale_customer(p_customer_id uuid)
RETURNS boolean AS $$
DECLARE
  v_wholesale_info jsonb;
BEGIN
  -- الحصول على بيانات الجملة للعميل
  SELECT wholesale_info INTO v_wholesale_info
  FROM customers
  WHERE id = p_customer_id;
  
  -- إذا لم تكن هناك بيانات جملة، فالعميل ليس عميل جملة
  IF v_wholesale_info IS NULL THEN
    RETURN false;
  END IF;
  
  -- التحقق من حالة عميل الجملة
  RETURN (v_wholesale_info->>'status')::text = 'approved';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة للحصول على مستوى عميل الجملة
CREATE OR REPLACE FUNCTION get_wholesale_tier(p_customer_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_wholesale_info jsonb;
  v_tier_id uuid;
  v_tier_info jsonb;
BEGIN
  -- الحصول على بيانات الجملة للعميل
  SELECT wholesale_info INTO v_wholesale_info
  FROM customers
  WHERE id = p_customer_id;
  
  -- إذا لم تكن هناك بيانات جملة، فالعميل ليس عميل جملة
  IF v_wholesale_info IS NULL THEN
    RETURN NULL;
  END IF;
  
  -- الحصول على معرف المستوى
  v_tier_id := (v_wholesale_info->>'tier_id')::uuid;
  
  -- الحصول على بيانات المستوى
  SELECT row_to_json(t)::jsonb INTO v_tier_info
  FROM (
    SELECT * FROM wholesale_tiers
    WHERE id = v_tier_id
  ) t;
  
  -- إعادة بيانات المستوى
  RETURN v_tier_info;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة للحصول على نسبة الخصم لعميل الجملة
CREATE OR REPLACE FUNCTION get_wholesale_discount(p_customer_id uuid)
RETURNS numeric AS $$
DECLARE
  v_wholesale_info jsonb;
  v_tier_id uuid;
  v_discount numeric;
BEGIN
  -- الحصول على بيانات الجملة للعميل
  SELECT wholesale_info INTO v_wholesale_info
  FROM customers
  WHERE id = p_customer_id;
  
  -- إذا لم تكن هناك بيانات جملة، فالخصم 0
  IF v_wholesale_info IS NULL THEN
    RETURN 0;
  END IF;
  
  -- التحقق من حالة عميل الجملة
  IF (v_wholesale_info->>'status')::text != 'approved' THEN
    RETURN 0;
  END IF;
  
  -- الحصول على معرف المستوى
  v_tier_id := (v_wholesale_info->>'tier_id')::uuid;
  
  -- الحصول على نسبة الخصم من المستوى
  SELECT discount_percentage INTO v_discount
  FROM wholesale_tiers
  WHERE id = v_tier_id;
  
  -- إعادة نسبة الخصم
  RETURN COALESCE(v_discount, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة لتحديث إجمالي مشتريات عميل الجملة
CREATE OR REPLACE FUNCTION update_wholesale_customer_purchases(p_customer_id uuid, p_amount numeric)
RETURNS void AS $$
DECLARE
  v_wholesale_info jsonb;
  v_total_purchases numeric;
BEGIN
  -- الحصول على بيانات الجملة للعميل
  SELECT wholesale_info INTO v_wholesale_info
  FROM customers
  WHERE id = p_customer_id;
  
  -- إذا لم تكن هناك بيانات جملة، فلا شيء للتحديث
  IF v_wholesale_info IS NULL THEN
    RETURN;
  END IF;
  
  -- حساب إجمالي المشتريات الجديد
  v_total_purchases := COALESCE((v_wholesale_info->>'total_purchases')::numeric, 0) + p_amount;
  
  -- تحديث بيانات الجملة
  UPDATE customers
  SET wholesale_info = jsonb_set(
    wholesale_info,
    '{total_purchases}',
    to_jsonb(v_total_purchases)
  )
  WHERE id = p_customer_id;
  
  -- تحديث مستوى العميل بناءً على إجمالي المشتريات
  PERFORM update_wholesale_customer_tier(p_customer_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة لتحديث مستوى عميل الجملة بناءً على إجمالي المشتريات
CREATE OR REPLACE FUNCTION update_wholesale_customer_tier(p_customer_id uuid)
RETURNS void AS $$
DECLARE
  v_wholesale_info jsonb;
  v_total_purchases numeric;
  v_current_tier_id uuid;
  v_new_tier_id uuid;
BEGIN
  -- الحصول على بيانات الجملة للعميل
  SELECT wholesale_info INTO v_wholesale_info
  FROM customers
  WHERE id = p_customer_id;
  
  -- إذا لم تكن هناك بيانات جملة، فلا شيء للتحديث
  IF v_wholesale_info IS NULL THEN
    RETURN;
  END IF;
  
  -- الحصول على إجمالي المشتريات والمستوى الحالي
  v_total_purchases := COALESCE((v_wholesale_info->>'total_purchases')::numeric, 0);
  v_current_tier_id := (v_wholesale_info->>'tier_id')::uuid;
  
  -- الحصول على المستوى الجديد بناءً على إجمالي المشتريات
  SELECT id INTO v_new_tier_id
  FROM wholesale_tiers
  WHERE min_purchase_amount <= v_total_purchases
  AND status = 'active'
  ORDER BY min_purchase_amount DESC
  LIMIT 1;
  
  -- إذا كان المستوى الجديد مختلفًا عن المستوى الحالي، قم بالتحديث
  IF v_new_tier_id IS NOT NULL AND v_new_tier_id != v_current_tier_id THEN
    UPDATE customers
    SET wholesale_info = jsonb_set(
      wholesale_info,
      '{tier_id}',
      to_jsonb(v_new_tier_id::text)
    )
    WHERE id = p_customer_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- حذف الدالة الحالية إذا كانت موجودة
DROP FUNCTION IF EXISTS get_wholesale_customers();

-- إنشاء دالة جديدة للحصول على جميع عملاء الجملة
CREATE FUNCTION get_wholesale_customers()
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
  contact_email text,
  approval_date timestamptz,
  last_purchase_date timestamptz
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
    c.email,
    (c.wholesale_info->>'approval_date')::timestamptz,
    (c.wholesale_info->>'last_purchase_date')::timestamptz
  FROM customers c
  LEFT JOIN wholesale_tiers wt ON wt.id = (c.wholesale_info->>'tier_id')::uuid
  WHERE c.wholesale_info IS NOT NULL
  ORDER BY c.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة لتحويل عميل عادي إلى عميل جملة
CREATE OR REPLACE FUNCTION convert_to_wholesale_customer(
  p_customer_id uuid,
  p_company_name text,
  p_tax_number text,
  p_tier_id uuid
)
RETURNS boolean AS $$
DECLARE
  v_wholesale_info jsonb;
BEGIN
  -- التحقق من وجود العميل
  IF NOT EXISTS (SELECT 1 FROM customers WHERE id = p_customer_id) THEN
    RETURN false;
  END IF;
  
  -- التحقق من وجود المستوى
  IF NOT EXISTS (SELECT 1 FROM wholesale_tiers WHERE id = p_tier_id) THEN
    RETURN false;
  END IF;
  
  -- إنشاء بيانات الجملة
  v_wholesale_info := jsonb_build_object(
    'company_name', p_company_name,
    'tier_id', p_tier_id,
    'tax_number', p_tax_number,
    'status', 'pending',
    'total_purchases', 0,
    'approval_date', null,
    'last_purchase_date', null
  );
  
  -- تحديث بيانات العميل
  UPDATE customers
  SET wholesale_info = v_wholesale_info
  WHERE id = p_customer_id;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة لتحديث حالة عميل الجملة
CREATE OR REPLACE FUNCTION update_wholesale_customer_status(
  p_customer_id uuid,
  p_status text
)
RETURNS boolean AS $$
DECLARE
  v_wholesale_info jsonb;
BEGIN
  -- التحقق من وجود العميل
  IF NOT EXISTS (SELECT 1 FROM customers WHERE id = p_customer_id) THEN
    RETURN false;
  END IF;
  
  -- الحصول على بيانات الجملة للعميل
  SELECT wholesale_info INTO v_wholesale_info
  FROM customers
  WHERE id = p_customer_id;
  
  -- إذا لم تكن هناك بيانات جملة، فلا شيء للتحديث
  IF v_wholesale_info IS NULL THEN
    RETURN false;
  END IF;
  
  -- تحديث حالة عميل الجملة
  UPDATE customers
  SET wholesale_info = jsonb_set(
    wholesale_info,
    '{status}',
    to_jsonb(p_status)
  )
  WHERE id = p_customer_id;
  
  -- إذا كانت الحالة الجديدة هي "approved"، قم بتحديث تاريخ الموافقة
  IF p_status = 'approved' THEN
    UPDATE customers
    SET wholesale_info = jsonb_set(
      wholesale_info,
      '{approval_date}',
      to_jsonb(now()::text)
    )
    WHERE id = p_customer_id;
  END IF;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة لحساب سعر الجملة للمنتج
CREATE OR REPLACE FUNCTION calculate_wholesale_price(
  p_product_id uuid,
  p_customer_id uuid,
  p_quantity integer DEFAULT 1
)
RETURNS numeric AS $$
DECLARE
  v_product_price numeric;
  v_product_wholesale_price numeric;
  v_discount_percentage numeric;
  v_final_price numeric;
  v_tier_min_order_amount numeric;
BEGIN
  -- الحصول على سعر المنتج وسعر الجملة
  SELECT price, wholesale_price INTO v_product_price, v_product_wholesale_price
  FROM products
  WHERE id = p_product_id;
  
  -- إذا لم يكن هناك سعر للمنتج، فإرجاع 0
  IF v_product_price IS NULL THEN
    RETURN 0;
  END IF;
  
  -- التحقق مما إذا كان العميل عميل جملة
  IF NOT is_wholesale_customer(p_customer_id) THEN
    RETURN v_product_price;
  END IF;
  
  -- الحصول على نسبة الخصم لعميل الجملة
  v_discount_percentage := get_wholesale_discount(p_customer_id);
  
  -- الحصول على الحد الأدنى للطلب من مستوى العميل
  SELECT min_order_amount INTO v_tier_min_order_amount
  FROM wholesale_tiers
  WHERE id = (
    SELECT (wholesale_info->>'tier_id')::uuid
    FROM customers
    WHERE id = p_customer_id
  );
  
  -- إذا كان هناك سعر جملة محدد للمنتج، استخدمه
  IF v_product_wholesale_price IS NOT NULL THEN
    v_final_price := v_product_wholesale_price;
  ELSE
    -- وإلا، استخدم نسبة الخصم
    v_final_price := v_product_price * (1 - v_discount_percentage / 100);
  END IF;
  
  -- إرجاع السعر النهائي
  RETURN v_final_price;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة للتحقق من أهلية الطلب للحصول على أسعار الجملة
CREATE OR REPLACE FUNCTION is_eligible_for_wholesale_pricing(
  p_customer_id uuid,
  p_order_total numeric
)
RETURNS boolean AS $$
DECLARE
  v_tier_min_order_amount numeric;
BEGIN
  -- التحقق مما إذا كان العميل عميل جملة
  IF NOT is_wholesale_customer(p_customer_id) THEN
    RETURN false;
  END IF;
  
  -- الحصول على الحد الأدنى للطلب من مستوى العميل
  SELECT min_order_amount INTO v_tier_min_order_amount
  FROM wholesale_tiers
  WHERE id = (
    SELECT (wholesale_info->>'tier_id')::uuid
    FROM customers
    WHERE id = p_customer_id
  );
  
  -- التحقق مما إذا كان إجمالي الطلب يلبي الحد الأدنى
  RETURN p_order_total >= v_tier_min_order_amount;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;