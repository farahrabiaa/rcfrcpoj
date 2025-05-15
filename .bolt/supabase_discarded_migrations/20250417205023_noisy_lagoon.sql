/*
  # Add Media Storage Support

  1. New Tables
    - `product_media`
      - Stores product images and videos
      - Supports featured image, gallery images, and video
    
  2. Security
    - Enable RLS on new tables
    - Add policies for authenticated users
*/

-- Create product_media table
CREATE TABLE IF NOT EXISTS product_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES products(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('featured_image', 'gallery', 'video')),
  file_name text NOT NULL,
  file_size bigint NOT NULL,
  mime_type text NOT NULL,
  url text NOT NULL,
  width int,
  height int,
  duration int, -- For videos
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE product_media ENABLE ROW LEVEL SECURITY;

-- Policies for product_media
CREATE POLICY "Product media is viewable by everyone"
  ON product_media
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Vendors can manage their own product media"
  ON product_media
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM products p
      WHERE p.id = product_id
      AND p.vendor_id IN (
        SELECT id FROM vendors WHERE user_id = auth.uid()
      )
    )
  );

-- Function to delete old media when updating
CREATE OR REPLACE FUNCTION delete_old_product_media() RETURNS trigger AS $$
BEGIN
  -- Delete old featured image when updating
  IF NEW.type = 'featured_image' THEN
    DELETE FROM product_media
    WHERE product_id = NEW.product_id
    AND type = 'featured_image'
    AND id != NEW.id;
  END IF;

  -- Delete old video when updating
  IF NEW.type = 'video' THEN
    DELETE FROM product_media
    WHERE product_id = NEW.product_id
    AND type = 'video'
    AND id != NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to delete old media
CREATE TRIGGER delete_old_product_media_trigger
  BEFORE INSERT OR UPDATE ON product_media
  FOR EACH ROW
  EXECUTE FUNCTION delete_old_product_media();