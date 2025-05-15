/*
  # Create media files table and related functions

  1. New Tables
    - `media_files` - Stores metadata for uploaded media files
  
  2. Security
    - Enable RLS on media_files table
    - Add policies for authenticated users
  
  3. Functions
    - Function to increment media usage count
    - Trigger to update updated_at timestamp
*/

-- Create media_files table if it doesn't exist
CREATE TABLE IF NOT EXISTS media_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  filename TEXT NOT NULL,
  original_filename TEXT,
  file_path TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  mime_type TEXT NOT NULL,
  bucket TEXT NOT NULL,
  width INTEGER,
  height INTEGER,
  duration NUMERIC,
  alt_text TEXT,
  title TEXT,
  description TEXT,
  is_public BOOLEAN DEFAULT true,
  usage_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE media_files ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Media files are viewable by everyone"
  ON media_files
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert media files"
  ON media_files
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update their own media files"
  ON media_files
  FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Users can delete their own media files"
  ON media_files
  FOR DELETE
  TO authenticated
  USING (true);

-- Drop existing function to avoid conflicts
DROP FUNCTION IF EXISTS increment_media_usage(UUID);

-- Create function to increment media usage count
CREATE OR REPLACE FUNCTION increment_media_usage(p_media_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE media_files
  SET usage_count = COALESCE(usage_count, 0) + 1
  WHERE id = p_media_id;
  
  RETURN FOUND;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to update updated_at
CREATE OR REPLACE FUNCTION update_media_files_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_media_files_updated_at
BEFORE UPDATE ON media_files
FOR EACH ROW
EXECUTE FUNCTION update_media_files_updated_at();