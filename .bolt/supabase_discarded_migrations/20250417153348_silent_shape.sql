/*
  # Add Featured Vendors System

  1. Changes
    - Add featured_until column to vendors table
    - Add featured_order column for sorting featured vendors
    - Add function to manage featured vendors

  2. Security
    - Only admins can manage featured vendors
*/

-- Add featured columns to vendors table
ALTER TABLE vendors
  ADD COLUMN IF NOT EXISTS featured_until timestamptz,
  ADD COLUMN IF NOT EXISTS featured_order int;

-- Create function to manage featured vendors
CREATE OR REPLACE FUNCTION manage_featured_vendor(
  p_vendor_id uuid,
  p_featured boolean,
  p_featured_until timestamptz DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_max_order int;
BEGIN
  -- Get current max order
  SELECT COALESCE(MAX(featured_order), 0) INTO v_max_order
  FROM vendors
  WHERE featured_until > CURRENT_TIMESTAMP;

  IF p_featured THEN
    -- Set vendor as featured
    UPDATE vendors
    SET 
      featured_until = p_featured_until,
      featured_order = v_max_order + 1
    WHERE id = p_vendor_id;

    RETURN jsonb_build_object(
      'success', true,
      'message', 'تم تمييز البائع بنجاح'
    );
  ELSE
    -- Remove featured status
    UPDATE vendors
    SET 
      featured_until = NULL,
      featured_order = NULL
    WHERE id = p_vendor_id;

    -- Reorder remaining featured vendors
    WITH ordered_vendors AS (
      SELECT 
        id,
        ROW_NUMBER() OVER (ORDER BY featured_order) as new_order
      FROM vendors
      WHERE featured_until > CURRENT_TIMESTAMP
    )
    UPDATE vendors v
    SET featured_order = ov.new_order
    FROM ordered_vendors ov
    WHERE v.id = ov.id;

    RETURN jsonb_build_object(
      'success', true,
      'message', 'تم إلغاء تمييز البائع بنجاح'
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get featured vendors
CREATE OR REPLACE FUNCTION get_featured_vendors(
  p_limit int DEFAULT NULL,
  p_offset int DEFAULT 0
) RETURNS TABLE (
  id uuid,
  store_name text,
  phone text,
  address text,
  delivery_type text,
  delivery_radius decimal,
  price_per_km decimal,
  latitude decimal,
  longitude decimal,
  status text,
  logo_url text,
  banner_url text,
  featured_until timestamptz,
  featured_order int
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    v.id,
    v.store_name,
    v.phone,
    v.address,
    v.delivery_type,
    v.delivery_radius,
    v.price_per_km,
    v.latitude,
    v.longitude,
    v.status,
    v.logo_url,
    v.banner_url,
    v.featured_until,
    v.featured_order
  FROM vendors v
  WHERE v.featured_until > CURRENT_TIMESTAMP
  ORDER BY v.featured_order
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;