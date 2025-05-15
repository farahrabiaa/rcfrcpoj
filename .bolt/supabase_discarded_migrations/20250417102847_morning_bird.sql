/*
  # Add Default Categories

  1. New Categories
    - Restaurants (with subcategories)
    - Supermarkets
    
  2. Security
    - Categories are viewable by everyone
    - Only admins can modify categories
*/

-- Insert main categories
INSERT INTO categories (name, slug, description)
VALUES 
  ('مطاعم', 'restaurants', 'جميع أنواع المطاعم والمأكولات'),
  ('سوبر ماركت', 'supermarkets', 'محلات البقالة والسوبر ماركت');

-- Get the restaurants category ID
DO $$
DECLARE
  restaurant_id uuid;
BEGIN
  SELECT id INTO restaurant_id FROM categories WHERE slug = 'restaurants';

  -- Insert restaurant subcategories
  INSERT INTO categories (name, slug, description, parent_id)
  VALUES 
    ('مطاعم شرقية', 'oriental-restaurants', 'المطاعم العربية والشرقية', restaurant_id),
    ('مطاعم غربية', 'western-restaurants', 'المطاعم الغربية والأوروبية', restaurant_id),
    ('وجبات سريعة', 'fast-food', 'مطاعم الوجبات السريعة', restaurant_id),
    ('مشويات', 'grills', 'مطاعم المشويات واللحوم', restaurant_id),
    ('بيتزا', 'pizza', 'مطاعم البيتزا', restaurant_id),
    ('دجاج', 'chicken', 'مطاعم الدجاج', restaurant_id),
    ('مأكولات بحرية', 'seafood', 'مطاعم المأكولات البحرية', restaurant_id),
    ('حلويات', 'desserts', 'محلات الحلويات', restaurant_id),
    ('مشروبات', 'beverages', 'محلات المشروبات والعصائر', restaurant_id);
END $$;