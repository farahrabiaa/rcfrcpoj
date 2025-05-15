/*
  # Add delivery_type and settings to shipping_methods

  1. Changes
    - Add delivery_type column to shipping_methods table
    - Add settings column to shipping_methods table to store JSON configuration
*/

-- Add delivery_type column to shipping_methods table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'shipping_methods' 
    AND column_name = 'delivery_type'
  ) THEN
    ALTER TABLE shipping_methods ADD COLUMN delivery_type text DEFAULT 'distance';
  END IF;
END
$$;

-- Add settings column to shipping_methods table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'shipping_methods' 
    AND column_name = 'settings'
  ) THEN
    ALTER TABLE shipping_methods ADD COLUMN settings jsonb DEFAULT NULL;
  END IF;
END
$$;

-- Update existing shipping methods with default settings
UPDATE shipping_methods
SET 
  settings = CASE 
    WHEN delivery_type = 'distance' OR delivery_type IS NULL THEN 
      '{"min_distance": 1, "max_distance": 20, "base_fee": 5, "price_per_km": 2}'::jsonb
    WHEN delivery_type = 'fixed' THEN 
      '{"fixed_price": 10}'::jsonb
    WHEN delivery_type = 'zones' THEN 
      '{"zones": [{"name": "المنطقة أ", "price": 10}, {"name": "المنطقة ب", "price": 15}, {"name": "المنطقة ج", "price": 20}]}'::jsonb
    ELSE NULL
  END
WHERE settings IS NULL;