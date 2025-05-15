/*
  # إنشاء جدول مستخدمين مخصص

  1. جداول جديدة
    - `custom_users`
      - جدول مستخدمين مخصص بدون الاعتماد على نظام المصادقة
    
  2. الأمان
    - تفعيل RLS على الجدول الجديد
    - إضافة سياسات للوصول
*/

-- إنشاء جدول المستخدمين المخصص
CREATE TABLE IF NOT EXISTS custom_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  name text NOT NULL,
  email text UNIQUE,
  phone text,
  role text NOT NULL DEFAULT 'customer' CHECK (role IN ('admin', 'vendor', 'driver', 'customer')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'blocked')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- تفعيل RLS
ALTER TABLE custom_users ENABLE ROW LEVEL SECURITY;

-- إنشاء سياسات الوصول
CREATE POLICY "المستخدمون المصرح لهم يمكنهم رؤية جميع المستخدمين"
  ON custom_users
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "المستخدمون المصرح لهم يمكنهم إدارة المستخدمين"
  ON custom_users
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- إنشاء دالة لتشفير كلمة المرور
CREATE OR REPLACE FUNCTION hash_password(password text)
RETURNS text AS $$
BEGIN
  RETURN encode(sha256(password::bytea), 'hex');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة للتحقق من كلمة المرور
CREATE OR REPLACE FUNCTION verify_password(username text, password text)
RETURNS boolean AS $$
DECLARE
  stored_hash text;
BEGIN
  SELECT password_hash INTO stored_hash
  FROM custom_users
  WHERE custom_users.username = verify_password.username;
  
  IF stored_hash IS NULL THEN
    RETURN false;
  END IF;
  
  RETURN stored_hash = encode(sha256(password::bytea), 'hex');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء دالة لإضافة مستخدم جديد
CREATE OR REPLACE FUNCTION add_custom_user(
  p_username text,
  p_password text,
  p_name text,
  p_email text,
  p_phone text,
  p_role text DEFAULT 'customer'
)
RETURNS uuid AS $$
DECLARE
  v_user_id uuid;
BEGIN
  INSERT INTO custom_users (
    username,
    password_hash,
    name,
    email,
    phone,
    role
  ) VALUES (
    p_username,
    hash_password(p_password),
    p_name,
    p_email,
    p_phone,
    p_role
  ) RETURNING id INTO v_user_id;
  
  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إضافة مستخدم مدير افتراضي
SELECT add_custom_user(
  'admin',
  'admin123',
  'مدير النظام',
  'admin@example.com',
  '0599123456',
  'admin'
);