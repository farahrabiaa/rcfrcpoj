/*
  # Fix app_settings table and policies

  1. Changes
    - Drop existing policies before creating new ones
    - Ensure single row constraint for app_settings
    - Add default settings
*/

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "App settings are viewable by everyone" ON app_settings;
  DROP POLICY IF EXISTS "Only admins can modify app settings" ON app_settings;
  DROP POLICY IF EXISTS "Anyone can view settings" ON app_settings;
  DROP POLICY IF EXISTS "Admins can update settings" ON app_settings;
  DROP POLICY IF EXISTS "Allow initial settings creation when empty" ON app_settings;
  DROP POLICY IF EXISTS "Settings viewable by all users" ON app_settings;
  DROP POLICY IF EXISTS "Settings modifiable by admins" ON app_settings;
  DROP POLICY IF EXISTS "Settings creatable when empty" ON app_settings;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create new policies with unique names
CREATE POLICY "Settings viewable by authenticated" 
  ON app_settings
  FOR SELECT 
  TO authenticated 
  USING (true);

CREATE POLICY "Settings updatable by admins" 
  ON app_settings
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Settings insertable when empty" 
  ON app_settings
  FOR INSERT
  TO authenticated
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM app_settings)
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Update default settings to include login settings
UPDATE app_settings
SET settings = jsonb_set(
  settings,
  '{login}',
  jsonb_build_object(
    'logo', '/logo.svg',
    'background', '/login-bg.jpg'
  ),
  true
)
WHERE NOT EXISTS (
  SELECT 1 FROM app_settings AS a
  WHERE a.settings ? 'login'
);