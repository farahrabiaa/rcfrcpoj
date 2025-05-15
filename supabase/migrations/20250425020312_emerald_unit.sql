/*
  # Add Custom User Functions

  1. New Functions
    - `hash_password` - Function to hash passwords
    - `verify_password` - Function to verify passwords
    - `add_custom_user` - Function to add a new custom user
    
  2. Security
    - All functions are SECURITY DEFINER to ensure proper access control
*/

-- Create function to hash passwords if it doesn't exist
CREATE OR REPLACE FUNCTION hash_password(password text)
RETURNS text AS $$
BEGIN
  RETURN encode(sha256(password::bytea), 'hex');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to verify passwords if it doesn't exist
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

-- Create function to add a new custom user if it doesn't exist
CREATE OR REPLACE FUNCTION add_custom_user(
  p_username text,
  p_password text,
  p_name text,
  p_email text,
  p_phone text DEFAULT NULL,
  p_role text DEFAULT 'customer'
)
RETURNS uuid AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Check if username already exists
  IF EXISTS (SELECT 1 FROM custom_users WHERE username = p_username) THEN
    RAISE EXCEPTION 'Username already exists';
  END IF;
  
  -- Check if email already exists (if provided)
  IF p_email IS NOT NULL AND EXISTS (SELECT 1 FROM custom_users WHERE email = p_email) THEN
    RAISE EXCEPTION 'Email already exists';
  END IF;
  
  -- Insert new user
  INSERT INTO custom_users (
    username,
    password_hash,
    name,
    email,
    phone,
    role,
    status
  ) VALUES (
    p_username,
    hash_password(p_password),
    p_name,
    p_email,
    p_phone,
    p_role,
    'active'
  ) RETURNING id INTO v_user_id;
  
  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update RLS policies for custom_users table
ALTER TABLE custom_users ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$
BEGIN
  DROP POLICY IF EXISTS "المستخدمون المصرح لهم يمكنهم رؤية جميع المستخدمين" ON custom_users;
  DROP POLICY IF EXISTS "المستخدمون المصرح لهم يمكنهم إدارة المستخدمين" ON custom_users;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create new policies
CREATE POLICY "المستخدمون المصرح لهم يمكنهم رؤية جميع المستخدمين"
  ON custom_users
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "المستخدمون المصرح لهم يمكنهم إدارة المستخدمين"
  ON custom_users
  FOR ALL
  TO public
  USING (true);