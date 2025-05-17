/*
  # Create driver waiting list table

  1. New Tables
    - `driver_waiting_list` - Stores orders waiting for driver assignment
      - `id` (uuid, primary key)
      - `order_id` (uuid, references orders)
      - `vendor_id` (uuid, references vendors)
      - `status` (text)
      - `created_at` (timestamptz)
      - `created_by` (uuid, references auth.users)
      - `updated_at` (timestamptz)
  
  2. Security
    - Enable RLS on `driver_waiting_list` table
    - Add policies for authenticated users
  
  3. Functions
    - `add_order_to_waiting_list_v3` - Improved function to add orders to waiting list
    - `get_waiting_list_orders_v3` - Improved function to get orders from waiting list
*/

-- Create driver_waiting_list table if it doesn't exist
CREATE TABLE IF NOT EXISTS driver_waiting_list (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  vendor_id UUID REFERENCES vendors(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_at TIMESTAMPTZ,
  UNIQUE(order_id)
);

-- Create improved function to add an order to the waiting list
CREATE OR REPLACE FUNCTION add_order_to_waiting_list_v3(
  p_order_id UUID,
  p_vendor_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_order_exists BOOLEAN;
  v_user_id UUID;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  -- Check if order exists
  SELECT EXISTS(
    SELECT 1 FROM orders WHERE id = p_order_id
  ) INTO v_order_exists;
  
  IF NOT v_order_exists THEN
    RAISE EXCEPTION 'Order not found';
  END IF;
  
  -- Check if order is already in waiting list
  IF EXISTS(
    SELECT 1 FROM driver_waiting_list WHERE order_id = p_order_id
  ) THEN
    RAISE EXCEPTION 'Order already in waiting list';
  END IF;
  
  -- Add order to waiting list
  INSERT INTO driver_waiting_list (
    order_id,
    vendor_id,
    status,
    created_at,
    created_by,
    updated_at
  ) VALUES (
    p_order_id,
    p_vendor_id,
    'pending',
    now(),
    v_user_id,
    now()
  );
  
  -- Update order status
  UPDATE orders
  SET 
    status = 'waiting-for-driver',
    updated_at = now()
  WHERE id = p_order_id;
  
  -- Add status history record
  INSERT INTO order_status_history (
    order_id,
    status,
    note,
    created_at,
    created_by
  ) VALUES (
    p_order_id,
    'waiting-for-driver',
    'تم إضافة الطلب لقائمة انتظار السائقين',
    now(),
    v_user_id
  );
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error adding order to waiting list: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS on driver_waiting_list table
ALTER TABLE driver_waiting_list ENABLE ROW LEVEL SECURITY;

-- Create policies for driver_waiting_list table
DO $$
BEGIN
  -- Drop existing policies if they exist
  DROP POLICY IF EXISTS "Authenticated users can view waiting list" ON driver_waiting_list;
  DROP POLICY IF EXISTS "Authenticated users can insert into waiting list" ON driver_waiting_list;
  DROP POLICY IF EXISTS "Authenticated users can update waiting list" ON driver_waiting_list;
  DROP POLICY IF EXISTS "Authenticated users can delete from waiting list" ON driver_waiting_list;
  
  -- Create new policies
  CREATE POLICY "Authenticated users can view waiting list"
    ON driver_waiting_list
    FOR SELECT
    TO authenticated
    USING (true);
    
  CREATE POLICY "Authenticated users can insert into waiting list"
    ON driver_waiting_list
    FOR INSERT
    TO authenticated
    WITH CHECK (true);
    
  CREATE POLICY "Authenticated users can update waiting list"
    ON driver_waiting_list
    FOR UPDATE
    TO authenticated
    USING (true);
    
  CREATE POLICY "Authenticated users can delete from waiting list"
    ON driver_waiting_list
    FOR DELETE
    TO authenticated
    USING (
      auth.uid() = created_by OR
      EXISTS (SELECT 1 FROM custom_users WHERE id = auth.uid() AND role = 'admin')
    );
END $$;

-- Create indexes on driver_waiting_list for faster queries
CREATE INDEX IF NOT EXISTS idx_driver_waiting_list_order_id ON driver_waiting_list(order_id);
CREATE INDEX IF NOT EXISTS idx_driver_waiting_list_vendor_id ON driver_waiting_list(vendor_id);
CREATE INDEX IF NOT EXISTS idx_driver_waiting_list_status ON driver_waiting_list(status);
CREATE INDEX IF NOT EXISTS idx_driver_waiting_list_created_at ON driver_waiting_list(created_at);