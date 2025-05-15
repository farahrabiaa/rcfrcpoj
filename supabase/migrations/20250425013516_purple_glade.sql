/*
  # Fix app_settings RLS policies

  1. Changes
    - Drop existing policies
    - Create new policies that allow public access for SELECT
    - Keep admin-only restrictions for INSERT/UPDATE
*/

-- Enable RLS
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$
BEGIN
  DROP POLICY IF EXISTS "Settings viewable by authenticated" ON public.app_settings;
  DROP POLICY IF EXISTS "Settings insertable when empty" ON public.app_settings;
  DROP POLICY IF EXISTS "Settings updatable by admins" ON public.app_settings;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END
$$;

-- Create new policies with public access for SELECT
CREATE POLICY "Settings viewable by everyone"
  ON public.app_settings
  FOR SELECT 
  TO public  -- Changed from 'authenticated' to 'public'
  USING (true);

CREATE POLICY "Settings insertable when empty"
  ON public.app_settings
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Only allow insert if table is empty AND user is admin
    (NOT EXISTS (SELECT 1 FROM public.app_settings))
    AND
    (EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    ))
  );

CREATE POLICY "Settings updatable by admins"
  ON public.app_settings
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  );

-- Insert default settings if none exist
INSERT INTO public.app_settings (settings)
SELECT jsonb_build_object(
  'store', jsonb_build_object(
    'name', 'متجر خدماتكم',
    'description', 'نظام متكامل لإدارة المتجر',
    'email', 'info@example.com',
    'phone', '0599123456',
    'address', 'غزة، فلسطين',
    'logo', '/logo.svg',
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
  ),
  'login', jsonb_build_object(
    'logo', '/logo.svg',
    'background', '/login-bg.jpg'
  )
)
WHERE NOT EXISTS (SELECT 1 FROM public.app_settings);