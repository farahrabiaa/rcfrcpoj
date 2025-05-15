-- Create the app_settings table
CREATE TABLE IF NOT EXISTS public.app_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Create function to ensure single row
CREATE OR REPLACE FUNCTION ensure_single_settings_row()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.app_settings) THEN
    RAISE EXCEPTION 'Only one settings row is allowed';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to ensure single row only if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'ensure_single_settings_row_trigger'
    AND tgrelid = 'public.app_settings'::regclass
  ) THEN
    CREATE TRIGGER ensure_single_settings_row_trigger
      BEFORE INSERT ON public.app_settings
      FOR EACH ROW
      EXECUTE FUNCTION ensure_single_settings_row();
  END IF;
EXCEPTION
  WHEN undefined_object THEN
    -- If the table doesn't exist yet, we'll create the trigger directly
    CREATE TRIGGER ensure_single_settings_row_trigger
      BEFORE INSERT ON public.app_settings
      FOR EACH ROW
      EXECUTE FUNCTION ensure_single_settings_row();
END
$$;

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

-- Create policies
CREATE POLICY "Settings viewable by authenticated"
  ON public.app_settings
  FOR SELECT
  TO authenticated
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