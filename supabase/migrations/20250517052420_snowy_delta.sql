/*
  # Fix Order Status Update

  1. New Functions
    - `update_order_status_v2`: Improved function to update order status with better error handling
    - `get_order_status_history_with_users`: Function to get order status history with user information

  2. Security
    - Enable RLS on order_status_history table
    - Add policies for order status history
*/

-- Create a new function to update order status with better error handling
CREATE OR REPLACE FUNCTION update_order_status_v2(
  p_order_id UUID,
  p_status TEXT,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_exists BOOLEAN;
  v_user_id UUID;
  v_history_id UUID;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  -- Check if order exists
  SELECT EXISTS(SELECT 1 FROM orders WHERE id = p_order_id) INTO v_order_exists;
  
  IF NOT v_order_exists THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'الطلب غير موجود'
    );
  END IF;
  
  -- Add status history record
  INSERT INTO order_status_history (
    order_id,
    status,
    note,
    created_by
  )
  VALUES (
    p_order_id,
    p_status,
    COALESCE(p_note, 
      CASE 
        WHEN p_status = 'processing' THEN 'تم بدء تحضير الطلب'
        WHEN p_status = 'delivering' THEN 'تم تحويل الطلب للتوصيل'
        WHEN p_status = 'waiting-for-driver' THEN 'تم إضافة الطلب لقائمة انتظار السائقين'
        WHEN p_status = 'completed' THEN 'تم إكمال الطلب'
        WHEN p_status = 'accepted' THEN 'تم قبول الطلب'
        WHEN p_status = 'rejected' THEN 'تم رفض الطلب'
        ELSE 'تم تغيير الحالة'
      END
    ),
    v_user_id
  )
  RETURNING id INTO v_history_id;
  
  -- Update order status
  UPDATE orders
  SET 
    status = p_status,
    updated_at = NOW()
  WHERE id = p_order_id;
  
  -- Return success
  RETURN jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'status', p_status,
    'history_id', v_history_id,
    'message', 'تم تحديث حالة الطلب بنجاح'
  );
END;
$$;

-- Create a function to get order status history with user information
CREATE OR REPLACE FUNCTION get_order_status_history_with_users(p_order_id UUID)
RETURNS SETOF order_status_history
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM order_status_history
  WHERE order_id = p_order_id
  ORDER BY created_at ASC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION update_order_status_v2 TO service_role;
GRANT EXECUTE ON FUNCTION update_order_status_v2 TO authenticated;
GRANT EXECUTE ON FUNCTION get_order_status_history_with_users TO service_role;
GRANT EXECUTE ON FUNCTION get_order_status_history_with_users TO authenticated;

-- Enable RLS on order_status_history if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'order_status_history'
  ) THEN
    -- Enable RLS
    ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
    
    -- Create policies
    DROP POLICY IF EXISTS "Users can view order status history" ON order_status_history;
    CREATE POLICY "Users can view order status history"
      ON order_status_history
      FOR SELECT
      TO authenticated
      USING (true);
      
    DROP POLICY IF EXISTS "Users can insert order status history" ON order_status_history;
    CREATE POLICY "Users can insert order status history"
      ON order_status_history
      FOR INSERT
      TO authenticated
      WITH CHECK (true);
  END IF;
END $$;