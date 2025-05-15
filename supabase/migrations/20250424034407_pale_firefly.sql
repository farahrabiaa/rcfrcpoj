/*
  # Add service_areas to vendors table

  1. Changes
    - Add service_areas column to vendors table
    - This column will store an array of service areas for each vendor
*/

-- Add service_areas column to vendors table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'vendors' 
    AND column_name = 'service_areas'
  ) THEN
    ALTER TABLE vendors ADD COLUMN service_areas text[] DEFAULT '{}';
  END IF;
END
$$;

-- Create index on service_areas for better performance
CREATE INDEX IF NOT EXISTS idx_vendors_service_areas ON vendors USING GIN (service_areas);

-- Add function to search vendors by service area
CREATE OR REPLACE FUNCTION search_vendors_by_area(p_area text)
RETURNS SETOF vendors AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM vendors
  WHERE service_areas @> ARRAY[p_area]
  AND status = 'active';
END;
$$ LANGUAGE plpgsql;

-- Add function to get all service areas
CREATE OR REPLACE FUNCTION get_all_service_areas()
RETURNS TABLE (area text) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT unnest(service_areas)
  FROM vendors
  WHERE status = 'active'
  ORDER BY unnest(service_areas);
END;
$$ LANGUAGE plpgsql;