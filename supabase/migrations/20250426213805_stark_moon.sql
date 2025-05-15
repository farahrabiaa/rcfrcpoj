/*
  # Media Management System

  1. New Tables
    - `media_files`
      - Stores information about uploaded media files
      - Tracks usage, ownership, and metadata
    
  2. Security
    - Enable RLS on new table
    - Add policies for admin and vendor access
*/

-- Create media_files table
CREATE TABLE IF NOT EXISTS media_files (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users,
  filename text NOT NULL,
  original_filename text NOT NULL,
  file_path text NOT NULL,
  file_size integer NOT NULL,
  mime_type text NOT NULL,
  bucket text NOT NULL,
  width integer,
  height integer,
  duration integer,
  alt_text text,
  title text,
  description text,
  usage_count integer DEFAULT 0,
  is_public boolean DEFAULT true,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create index on user_id for better performance
CREATE INDEX IF NOT EXISTS idx_media_files_user_id ON media_files(user_id);

-- Create index on mime_type for better filtering
CREATE INDEX IF NOT EXISTS idx_media_files_mime_type ON media_files(mime_type);

-- Create index on bucket for better filtering
CREATE INDEX IF NOT EXISTS idx_media_files_bucket ON media_files(bucket);

-- Enable RLS
ALTER TABLE media_files ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Media files are viewable by everyone"
  ON media_files
  FOR SELECT
  TO authenticated
  USING (is_public OR user_id = auth.uid());

CREATE POLICY "Users can insert their own media files"
  ON media_files
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own media files"
  ON media_files
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete their own media files"
  ON media_files
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Admins can manage all media files"
  ON media_files
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_users
      WHERE user_id = auth.uid()
    )
  );

-- Create trigger for media_files table
CREATE TRIGGER update_media_files_updated_at
  BEFORE UPDATE ON media_files
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Create function to get media files by user
CREATE OR REPLACE FUNCTION get_media_files_by_user(p_user_id uuid)
RETURNS SETOF media_files AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM media_files
  WHERE user_id = p_user_id
  ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get media files by bucket
CREATE OR REPLACE FUNCTION get_media_files_by_bucket(p_bucket text)
RETURNS SETOF media_files AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM media_files
  WHERE bucket = p_bucket
  ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get media files by mime type
CREATE OR REPLACE FUNCTION get_media_files_by_mime_type(p_mime_type text)
RETURNS SETOF media_files AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM media_files
  WHERE mime_type LIKE p_mime_type || '%'
  ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to search media files
CREATE OR REPLACE FUNCTION search_media_files(p_query text)
RETURNS SETOF media_files AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM media_files
  WHERE 
    filename ILIKE '%' || p_query || '%' OR
    original_filename ILIKE '%' || p_query || '%' OR
    alt_text ILIKE '%' || p_query || '%' OR
    title ILIKE '%' || p_query || '%' OR
    description ILIKE '%' || p_query || '%'
  ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to increment usage count
CREATE OR REPLACE FUNCTION increment_media_usage(p_media_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE media_files
  SET usage_count = usage_count + 1
  WHERE id = p_media_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;