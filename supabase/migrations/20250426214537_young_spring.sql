/*
  # Fix Media Upload RLS Policies

  1. Changes
    - Add public access policy for storage buckets
    - Fix RLS policies for media_files table
    - Ensure authenticated users can upload files to storage
*/

-- Create storage policies for public access with IF NOT EXISTS
DO $$
BEGIN
  -- Public Read Access policies
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' 
    AND schemaname = 'storage' 
    AND policyname = 'Public Access'
  ) THEN
    CREATE POLICY "Public Access"
    ON storage.objects
    FOR SELECT
    USING (bucket_id IN ('products', 'vendors', 'profiles', 'advertisements', 'general'));
  END IF;

  -- Allow authenticated users to insert files
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' 
    AND schemaname = 'storage' 
    AND policyname = 'Authenticated users can upload files'
  ) THEN
    CREATE POLICY "Authenticated users can upload files"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id IN ('products', 'vendors', 'profiles', 'advertisements', 'general'));
  END IF;

  -- Allow authenticated users to update their own files
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' 
    AND schemaname = 'storage' 
    AND policyname = 'Authenticated users can update own files'
  ) THEN
    CREATE POLICY "Authenticated users can update own files"
    ON storage.objects
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = owner);
  END IF;

  -- Allow authenticated users to delete their own files
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' 
    AND schemaname = 'storage' 
    AND policyname = 'Authenticated users can delete own files'
  ) THEN
    CREATE POLICY "Authenticated users can delete own files"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (auth.uid() = owner);
  END IF;
END $$;

-- Fix media_files table policies
DO $$
BEGIN
  -- Drop existing policies if they exist
  DROP POLICY IF EXISTS "Media files are viewable by everyone" ON media_files;
  DROP POLICY IF EXISTS "Users can insert their own media files" ON media_files;
  DROP POLICY IF EXISTS "Users can update their own media files" ON media_files;
  DROP POLICY IF EXISTS "Users can delete their own media files" ON media_files;
  DROP POLICY IF EXISTS "Admins can manage all media files" ON media_files;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create new policies for media_files table
CREATE POLICY "Anyone can view media files"
  ON media_files
  FOR SELECT
  TO public
  USING (is_public OR user_id = auth.uid() OR user_id IS NULL);

CREATE POLICY "Anyone can insert media files"
  ON media_files
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Anyone can update media files"
  ON media_files
  FOR UPDATE
  TO public
  USING (true);

CREATE POLICY "Anyone can delete media files"
  ON media_files
  FOR DELETE
  TO public
  USING (true);