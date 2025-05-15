/*
  # App Settings Table

  1. New Tables
    - `app_settings`
      - Stores global application settings
      - JSON structure for flexible settings storage
      
  2. Security
    - Enable RLS on new table
    - Add policies for admin access
*/

-- Create app_settings table
CREATE TABLE IF NOT EXISTS app_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Policies for app_settings
CREATE POLICY "App settings are viewable by everyone"
  ON app_settings
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can modify app settings"
  ON app_settings
  FOR ALL
  TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

-- Insert default settings
INSERT INTO app_settings (settings)
VALUES (
  jsonb_build_object(
    'store', jsonb_build_object(
      'name', 'متجر خدماتكم',
      'description', 'نظام متكامل لإدارة المتجر',
      'email', 'info@example.com',
      'phone', '0599123456',
      'address', 'غزة، فلسطين',
      'logo', '/logo.png',
      'currency', 'ILS',
      'language', 'ar'
    ),
    'social', jsonb_build_object(
      'facebook', '',
      'twitter', '',
      'instagram', '',
      'whatsapp', ''
    ),
    'notifications', jsonb_build_object(
      'email', true,
      'sms', false,
      'push', true
    )
  )
);

-- Create function to update settings
CREATE OR REPLACE FUNCTION update_app_settings(p_settings jsonb)
RETURNS jsonb AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Update settings
  UPDATE app_settings
  SET 
    settings = p_settings,
    updated_at = now()
  RETURNING settings INTO v_result;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get settings
CREATE OR REPLACE FUNCTION get_app_settings()
RETURNS jsonb AS $$
DECLARE
  v_settings jsonb;
BEGIN
  SELECT settings INTO v_settings FROM app_settings LIMIT 1;
  RETURN v_settings;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;