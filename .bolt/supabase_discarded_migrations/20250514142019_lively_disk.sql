/*
  # Add Advertisements for Vendor Categories
  
  1. New Advertisements
    - Add a banner advertisement for the "Market" vendor category
    - Add a banner advertisement for the "Restaurant" vendor category
    
  2. Changes
    - Insert new records into the advertisements table
    - Ensure proper linking to vendor categories
    
  3. Security
    - No changes to security policies
*/

-- Insert advertisement for Market vendors
INSERT INTO advertisements (
  title,
  description,
  vendor_id,
  image_url,
  link,
  start_date,
  end_date,
  status,
  type,
  position,
  priority,
  views,
  clicks
)
SELECT
  'تسوق من أفضل الماركت في المدينة',
  'أسعار منافسة وتوصيل سريع لجميع المنتجات',
  v.id,
  'https://images.pexels.com/photos/264636/pexels-photo-264636.jpeg?auto=compress&cs=tinysrgb&w=1200',
  '/vendors/categories/supermarket',
  CURRENT_DATE,
  (CURRENT_DATE + INTERVAL '1 year'),
  'active',
  'banner',
  'home',
  1,
  0,
  0
FROM vendors v
JOIN vendor_categories vc ON v.id = vc.vendor_id
JOIN categories c ON vc.category_id = c.id
WHERE c.name = 'سوبر ماركت' OR c.slug = 'supermarkets' OR c.type = 'supermarket'
LIMIT 1;

-- Insert advertisement for Restaurant vendors
INSERT INTO advertisements (
  title,
  description,
  vendor_id,
  image_url,
  link,
  start_date,
  end_date,
  status,
  type,
  position,
  priority,
  views,
  clicks
)
SELECT
  'اكتشف أشهى المأكولات من مطاعمنا المميزة',
  'وجبات شهية وتوصيل سريع من أفضل المطاعم',
  v.id,
  'https://images.pexels.com/photos/958545/pexels-photo-958545.jpeg?auto=compress&cs=tinysrgb&w=1200',
  '/vendors/categories/restaurants',
  CURRENT_DATE,
  (CURRENT_DATE + INTERVAL '1 year'),
  'active',
  'banner',
  'home',
  2,
  0,
  0
FROM vendors v
JOIN vendor_categories vc ON v.id = vc.vendor_id
JOIN categories c ON vc.category_id = c.id
WHERE c.name = 'مطاعم' OR c.slug = 'restaurants' OR c.type = 'restaurant'
LIMIT 1;

-- If no vendors are found for the categories, insert with NULL vendor_id
INSERT INTO advertisements (
  title,
  description,
  vendor_id,
  image_url,
  link,
  start_date,
  end_date,
  status,
  type,
  position,
  priority,
  views,
  clicks
)
SELECT
  'تسوق من أفضل الماركت في المدينة',
  'أسعار منافسة وتوصيل سريع لجميع المنتجات',
  NULL,
  'https://images.pexels.com/photos/264636/pexels-photo-264636.jpeg?auto=compress&cs=tinysrgb&w=1200',
  '/vendors/categories/supermarket',
  CURRENT_DATE,
  (CURRENT_DATE + INTERVAL '1 year'),
  'active',
  'banner',
  'home',
  1,
  0,
  0
WHERE NOT EXISTS (
  SELECT 1 FROM advertisements 
  WHERE title = 'تسوق من أفضل الماركت في المدينة'
);

INSERT INTO advertisements (
  title,
  description,
  vendor_id,
  image_url,
  link,
  start_date,
  end_date,
  status,
  type,
  position,
  priority,
  views,
  clicks
)
SELECT
  'اكتشف أشهى المأكولات من مطاعمنا المميزة',
  'وجبات شهية وتوصيل سريع من أفضل المطاعم',
  NULL,
  'https://images.pexels.com/photos/958545/pexels-photo-958545.jpeg?auto=compress&cs=tinysrgb&w=1200',
  '/vendors/categories/restaurants',
  CURRENT_DATE,
  (CURRENT_DATE + INTERVAL '1 year'),
  'active',
  'banner',
  'home',
  2,
  0,
  0
WHERE NOT EXISTS (
  SELECT 1 FROM advertisements 
  WHERE title = 'اكتشف أشهى المأكولات من مطاعمنا المميزة'
);

-- Create slider advertisements for the same categories
INSERT INTO slider_advertisements (
  title,
  description,
  vendor_id,
  image_url,
  video_url,
  link,
  start_date,
  end_date,
  status,
  priority,
  is_video,
  clicks,
  views
)
SELECT
  'أفضل عروض الماركت',
  'تسوق الآن واحصل على خصومات حصرية',
  v.id,
  'https://images.pexels.com/photos/3962294/pexels-photo-3962294.jpeg?auto=compress&cs=tinysrgb&w=1200',
  NULL,
  '/vendors/categories/supermarket',
  CURRENT_DATE,
  (CURRENT_DATE + INTERVAL '1 year'),
  'active',
  1,
  false,
  0,
  0
FROM vendors v
JOIN vendor_categories vc ON v.id = vc.vendor_id
JOIN categories c ON vc.category_id = c.id
WHERE c.name = 'سوبر ماركت' OR c.slug = 'supermarkets' OR c.type = 'supermarket'
LIMIT 1;

INSERT INTO slider_advertisements (
  title,
  description,
  vendor_id,
  image_url,
  video_url,
  link,
  start_date,
  end_date,
  status,
  priority,
  is_video,
  clicks,
  views
)
SELECT
  'أشهى المأكولات من مطاعمنا',
  'اطلب الآن وتمتع بتجربة طعام فريدة',
  v.id,
  'https://images.pexels.com/photos/1640772/pexels-photo-1640772.jpeg?auto=compress&cs=tinysrgb&w=1200',
  NULL,
  '/vendors/categories/restaurants',
  CURRENT_DATE,
  (CURRENT_DATE + INTERVAL '1 year'),
  'active',
  2,
  false,
  0,
  0
FROM vendors v
JOIN vendor_categories vc ON v.id = vc.vendor_id
JOIN categories c ON vc.category_id = c.id
WHERE c.name = 'مطاعم' OR c.slug = 'restaurants' OR c.type = 'restaurant'
LIMIT 1;

-- If no vendors are found for the categories, insert with NULL vendor_id
INSERT INTO slider_advertisements (
  title,
  description,
  vendor_id,
  image_url,
  video_url,
  link,
  start_date,
  end_date,
  status,
  priority,
  is_video,
  clicks,
  views
)
SELECT
  'أفضل عروض الماركت',
  'تسوق الآن واحصل على خصومات حصرية',
  NULL,
  'https://images.pexels.com/photos/3962294/pexels-photo-3962294.jpeg?auto=compress&cs=tinysrgb&w=1200',
  NULL,
  '/vendors/categories/supermarket',
  CURRENT_DATE,
  (CURRENT_DATE + INTERVAL '1 year'),
  'active',
  1,
  false,
  0,
  0
WHERE NOT EXISTS (
  SELECT 1 FROM slider_advertisements 
  WHERE title = 'أفضل عروض الماركت'
);

INSERT INTO slider_advertisements (
  title,
  description,
  vendor_id,
  image_url,
  video_url,
  link,
  start_date,
  end_date,
  status,
  priority,
  is_video,
  clicks,
  views
)
SELECT
  'أشهى المأكولات من مطاعمنا',
  'اطلب الآن وتمتع بتجربة طعام فريدة',
  NULL,
  'https://images.pexels.com/photos/1640772/pexels-photo-1640772.jpeg?auto=compress&cs=tinysrgb&w=1200',
  NULL,
  '/vendors/categories/restaurants',
  CURRENT_DATE,
  (CURRENT_DATE + INTERVAL '1 year'),
  'active',
  2,
  false,
  0,
  0
WHERE NOT EXISTS (
  SELECT 1 FROM slider_advertisements 
  WHERE title = 'أشهى المأكولات من مطاعمنا'
);