/*
  # Media Files Table Schema

  1. New Tables
    - `media_files` - Stores metadata for uploaded media files
  2. Security
    - Enable RLS on `media_files` table
    - Add policies for authenticated users to manage their own files
    - Add policies for public users to view public files
  3. Functions
    - Add function to increment media usage count
    - Add trigger to update updated_at timestamp
*/

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS increment_media_usage(UUID);

-- Create media_files table if it doesn't exist
CREATE TABLE IF NOT EXISTS media_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  filename TEXT NOT NULL,
  original_filename TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size INTEGER NOT NULL,
  mime_type TEXT NOT NULL,
  bucket TEXT NOT NULL,
  width INTEGER,
  height INTEGER,
  duration INTEGER,
  alt_text TEXT,
  title TEXT,
  description TEXT,
  usage_count INTEGER DEFAULT 0,
  is_public BOOLEAN DEFAULT true,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

-- Enable RLS
ALTER TABLE media_files ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Public can view public media files"
  ON media_files
  FOR SELECT
  TO public
  USING (is_public = true);

CREATE POLICY "Users can view own media files"
  ON media_files
  FOR SELECT
  TO authenticated
  USING ((auth.uid() = user_id) OR (is_public = true));

CREATE POLICY "Users can insert media files"
  ON media_files
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own media files"
  ON media_files
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own media files"
  ON media_files
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Create function to increment media usage count
CREATE OR REPLACE FUNCTION increment_media_usage(p_media_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE media_files
  SET usage_count = COALESCE(usage_count, 0) + 1
  WHERE id = p_media_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_media_files_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update updated_at timestamp
CREATE TRIGGER update_media_files_updated_at
BEFORE UPDATE ON media_files
FOR EACH ROW
EXECUTE FUNCTION update_media_files_updated_at();