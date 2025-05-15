/*
  # Update Login Logo

  1. Changes
    - Update the login logo in app_settings
*/

-- Update login logo in app_settings
UPDATE app_settings
SET settings = jsonb_set(
  settings,
  '{login,logo}',
  '"new-logo.svg"',
  true
);