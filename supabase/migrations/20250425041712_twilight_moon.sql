-- Add working_areas column to drivers table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'drivers' 
    AND column_name = 'working_areas'
  ) THEN
    ALTER TABLE drivers ADD COLUMN working_areas text[] DEFAULT '{}';
  END IF;
END
$$;

-- Create index on working_areas for better performance
CREATE INDEX IF NOT EXISTS idx_drivers_working_areas ON drivers USING GIN (working_areas);

-- Update RLS policies for drivers table
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$
BEGIN
  DROP POLICY IF EXISTS "Drivers are viewable by everyone" ON drivers;
  DROP POLICY IF EXISTS "Drivers can update their own info" ON drivers;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create new policies
CREATE POLICY "Drivers are viewable by everyone"
  ON drivers
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Drivers can update their own info"
  ON drivers
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Create function to update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for drivers table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_drivers_updated_at'
    AND tgrelid = 'drivers'::regclass
  ) THEN
    CREATE TRIGGER update_drivers_updated_at
    BEFORE UPDATE ON drivers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
  END IF;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END
$$;

-- Update drivers foreign key to reference custom_users
ALTER TABLE drivers 
  DROP CONSTRAINT IF EXISTS drivers_user_id_fkey;

-- Add the new foreign key constraint to reference custom_users
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'drivers_user_id_fkey'
  ) THEN
    ALTER TABLE drivers
      ADD CONSTRAINT drivers_user_id_fkey
      FOREIGN KEY (user_id) 
      REFERENCES custom_users(id);
  END IF;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END
$$;

-- Create function to search drivers by working area
CREATE OR REPLACE FUNCTION search_drivers_by_area(p_area text)
RETURNS SETOF drivers AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM drivers
  WHERE working_areas @> ARRAY[p_area]
  AND status = 'available';
END;
$$ LANGUAGE plpgsql;

-- Create function to get all working areas
CREATE OR REPLACE FUNCTION get_all_working_areas()
RETURNS TABLE (area text) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT unnest(working_areas)
  FROM drivers
  WHERE status = 'available'
  ORDER BY unnest(working_areas);
END;
$$ LANGUAGE plpgsql;

-- Create function to get available drivers for a specific area
CREATE OR REPLACE FUNCTION get_available_drivers_for_area(p_area text)
RETURNS TABLE (
  id uuid,
  name text,
  phone text,
  rating decimal(3,2),
  vehicle_type text
) AS $$
BEGIN
  RETURN QUERY
  SELECT d.id, d.name, d.phone, d.rating, d.vehicle_type
  FROM drivers d
  WHERE d.working_areas @> ARRAY[p_area]
  AND d.status = 'available'
  ORDER BY d.rating DESC;
END;
$$ LANGUAGE plpgsql;