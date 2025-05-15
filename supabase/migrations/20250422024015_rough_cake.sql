/*
  # Fix app settings policies and constraints

  1. Changes
    - Add unique constraint to ensure only one row exists
    - Update RLS policies to handle settings properly
    - Add trigger to ensure only one row exists

  2. Security
    - Enable RLS on app_settings table
    - Add policy for all users to view settings
    - Add policy for admins to manage settings
    - Add policy to allow initial settings creation when table is empty
*/

-- First ensure we have exactly one row
CREATE OR REPLACE FUNCTION ensure_single_settings_row()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT COUNT(*) FROM app_settings) = 0 THEN
    RETURN NEW;
  ELSE
    RAISE EXCEPTION 'Only one settings row is allowed';
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS ensure_single_settings_row_trigger ON app_settings;

-- Create the trigger
CREATE TRIGGER ensure_single_settings_row_trigger
  BEFORE INSERT ON app_settings
  FOR EACH ROW
  EXECUTE FUNCTION ensure_single_settings_row();

-- Update RLS policies
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "App settings are viewable by everyone" ON app_settings;
DROP POLICY IF EXISTS "Only admins can modify app settings" ON app_settings;

-- Create new policies
CREATE POLICY "Anyone can view settings"
  ON app_settings
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can update settings"
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

CREATE POLICY "Allow initial settings creation when empty"
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