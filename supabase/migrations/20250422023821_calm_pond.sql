/*
  # Create App Settings Table

  1. New Tables
    - `app_settings`
      - `id` (uuid, primary key)
      - `settings` (jsonb, stores application settings)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on app_settings table
    - Add policies for:
      - Everyone can view settings
      - Only admins can modify settings
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

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "App settings are viewable by everyone" ON app_settings;
  DROP POLICY IF EXISTS "Only admins can modify app settings" ON app_settings;
END $$;

-- Create policies
CREATE POLICY "App settings are viewable by everyone" 
  ON app_settings
  FOR SELECT 
  TO authenticated 
  USING (true);

CREATE POLICY "Only admins can modify app settings" 
  ON app_settings
  FOR ALL
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT user_id FROM admin_users
    )
  );