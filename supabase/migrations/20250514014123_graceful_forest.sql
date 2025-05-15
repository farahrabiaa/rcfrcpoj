/*
  # Fix RLS policies for vendor categories

  1. Changes
    - Update RLS policies for vendor_to_category table
    - Add proper policies to allow operations on the junction table
    - Fix the vendor_categories_table RLS policies
*/

-- First, enable RLS on the vendor_to_category table if not already enabled
ALTER TABLE IF EXISTS public.vendor_to_category ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Anyone can view vendor to category relationships" ON public.vendor_to_category;
DROP POLICY IF EXISTS "Admins can manage vendor to category relationships" ON public.vendor_to_category;

-- Create new policies for vendor_to_category table
CREATE POLICY "Anyone can view vendor to category relationships" 
ON public.vendor_to_category 
FOR SELECT 
TO public 
USING (true);

CREATE POLICY "Anyone can manage vendor to category relationships" 
ON public.vendor_to_category 
FOR ALL 
TO public 
USING (true)
WITH CHECK (true);

-- Fix vendor_categories_table policies if needed
DROP POLICY IF EXISTS "Vendor categories are viewable by everyone" ON public.vendor_categories_table;
DROP POLICY IF EXISTS "Admins can manage vendor categories" ON public.vendor_categories_table;

-- Create new policies for vendor_categories_table
CREATE POLICY "Vendor categories are viewable by everyone" 
ON public.vendor_categories_table 
FOR SELECT 
TO public 
USING (true);

CREATE POLICY "Anyone can manage vendor categories" 
ON public.vendor_categories_table 
FOR ALL 
TO public 
USING (true)
WITH CHECK (true);