/*
  # Fix Driver Waiting List Functionality

  1. New Functions
    - `add_order_to_waiting_list_v2`: Improved function to add orders to the waiting list
    - `get_waiting_list_orders_v2`: Enhanced function to retrieve orders from the waiting list
  
  2. Security
    - Added RLS policies for the driver_waiting_list table
    - Ensured proper access control for different user roles
  
  3. Performance
    - Added indexes for faster queries on the waiting list
*/

-- Create improved function to add an order to the waiting list
CREATE OR REPLACE FUNCTION add_order_to_waiting_list_v2(
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
    created_by
  ) VALUES (
    p_order_id,
    p_vendor_id,
    'pending',
    now(),
    v_user_id
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

-- Create improved function to get orders in the waiting list
CREATE OR REPLACE FUNCTION get_waiting_list_orders_v2(
  p_vendor_id UUID DEFAULT NULL,
  p_status TEXT DEFAULT 'pending',
  p_limit INT DEFAULT 100,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  order_id UUID,
  vendor_id UUID,
  status TEXT,
  created_at TIMESTAMPTZ,
  created_by UUID,
  updated_at TIMESTAMPTZ,
  order_data JSONB,
  vendor_data JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dwl.id,
    dwl.order_id,
    dwl.vendor_id,
    dwl.status,
    dwl.created_at,
    dwl.created_by,
    dwl.updated_at,
    jsonb_build_object(
      'id', o.id,
      'total', o.total,
      'status', o.status,
      'created_at', o.created_at,
      'customer_name', o.customer_name,
      'customer_phone', o.customer_phone,
      'address', o.address
    ) AS order_data,
    jsonb_build_object(
      'id', v.id,
      'store_name', v.store_name,
      'phone', v.phone,
      'address', v.address
    ) AS vendor_data
  FROM 
    driver_waiting_list dwl
  JOIN 
    orders o ON dwl.order_id = o.id
  LEFT JOIN 
    vendors v ON dwl.vendor_id = v.id
  WHERE 
    (p_vendor_id IS NULL OR dwl.vendor_id = p_vendor_id) AND
    dwl.status = p_status
  ORDER BY 
    dwl.created_at ASC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Make sure RLS is enabled on driver_waiting_list table
ALTER TABLE driver_waiting_list ENABLE ROW LEVEL SECURITY;

-- Create or replace policies for driver_waiting_list table
DO $$
BEGIN
  -- Drop existing policies if they exist
  DROP POLICY IF EXISTS "Authenticated users can view waiting list" ON driver_waiting_list;
  DROP POLICY IF EXISTS "Authenticated users can insert into waiting list" ON driver_waiting_list;
  DROP POLICY IF EXISTS "Authenticated users can update waiting list" ON driver_waiting_list;
  
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

-- Create indexes on driver_waiting_list for faster queries if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_driver_waiting_list_order_id') THEN
    CREATE INDEX idx_driver_waiting_list_order_id ON driver_waiting_list(order_id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_driver_waiting_list_vendor_id') THEN
    CREATE INDEX idx_driver_waiting_list_vendor_id ON driver_waiting_list(vendor_id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_driver_waiting_list_status') THEN
    CREATE INDEX idx_driver_waiting_list_status ON driver_waiting_list(status);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_driver_waiting_list_created_at') THEN
    CREATE INDEX idx_driver_waiting_list_created_at ON driver_waiting_list(created_at);
  END IF;
END $$;

-- Add created_by and updated_at columns to driver_waiting_list if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'driver_waiting_list' AND column_name = 'created_by'
  ) THEN
    ALTER TABLE driver_waiting_list ADD COLUMN created_by UUID REFERENCES auth.users(id);
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'driver_waiting_list' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE driver_waiting_list ADD COLUMN updated_at TIMESTAMPTZ;
  END IF;
END $$;