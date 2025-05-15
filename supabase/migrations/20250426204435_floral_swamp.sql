/*
  # Add Payment Settings to App Settings

  1. Changes
    - Update app_settings table with payment settings
    - Add delivery_type and settings columns to shipping_methods table
*/

-- Update app_settings with payment settings if they don't exist
UPDATE app_settings
SET settings = jsonb_set(
  settings,
  '{payment}',
  jsonb_build_object(
    'cash', jsonb_build_object(
      'enabled', true,
      'name', 'الدفع عند الاستلام',
      'description', 'الدفع نقداً عند استلام الطلب',
      'steps', jsonb_build_array(
        'الزبون يطلب من المتجر',
        'السائق يستلم الطلب من المتجر',
        'السائق يوصل الطلب للزبون',
        'الزبون يدفع المبلغ كاملاً (قيمة الطلب + التوصيل) للسائق'
      ),
      'balanceNotes', jsonb_build_array(
        'رصيد البائع = 0 (حتى يتم التحصيل)',
        'رصيد السائق = 0 (حتى يتم التحصيل)'
      ),
      'icon', '💰',
      'color', 'green'
    ),
    'electronic', jsonb_build_object(
      'enabled', true,
      'name', 'الدفع الإلكتروني',
      'description', 'الدفع المسبق عبر بطاقة الائتمان أو المحفظة الإلكترونية',
      'steps', jsonb_build_array(
        'الزبون يدفع كامل المبلغ إلكترونياً (قيمة الطلب + التوصيل)',
        'البائع يستلم قيمة الطلب مباشرة',
        'السائق يستلم قيمة التوصيل مباشرة',
        'السائق يوصل الطلب للزبون'
      ),
      'balanceNotes', jsonb_build_array(
        'رصيد البائع = قيمة الطلب (فوراً)',
        'رصيد السائق = قيمة التوصيل (فوراً)'
      ),
      'icon', '💳',
      'color', 'blue'
    ),
    'wallet', jsonb_build_object(
      'enabled', true,
      'name', 'محفظة التطبيق',
      'description', 'الدفع من رصيد المحفظة في التطبيق',
      'steps', jsonb_build_array(
        'الزبون يشحن محفظته مسبقاً',
        'الزبون يدفع من رصيد المحفظة',
        'يتم خصم المبلغ من محفظة الزبون',
        'يتم إضافة قيمة الطلب لمحفظة البائع',
        'يتم إضافة قيمة التوصيل لمحفظة السائق'
      ),
      'balanceNotes', jsonb_build_array(
        'رصيد الزبون = -المبلغ الكلي',
        'رصيد البائع = +قيمة الطلب',
        'رصيد السائق = +قيمة التوصيل'
      ),
      'icon', '👛',
      'color', 'purple'
    ),
    'commissions', jsonb_build_object(
      'vendor', jsonb_build_object(
        'rate', 10,
        'description', 'نسبة عمولة البائع من قيمة الطلب',
        'autoDeduct', true
      ),
      'driver', jsonb_build_object(
        'rate', 15,
        'description', 'نسبة عمولة السائق من قيمة التوصيل',
        'autoDeduct', true
      )
    ),
    'wallet', jsonb_build_object(
      'enabled', true,
      'minWithdrawal', 100,
      'withdrawalFee', 5,
      'autoSettlement', jsonb_build_object(
        'enabled', true,
        'period', 'weekly',
        'minAmount', 500
      )
    )
  ),
  true
)
WHERE NOT EXISTS (
  SELECT 1 FROM app_settings AS a
  WHERE a.settings ? 'payment'
);

-- Create function to process payment
CREATE OR REPLACE FUNCTION process_payment(
  p_order_id uuid,
  p_payment_method text,
  p_amount numeric
)
RETURNS boolean AS $$
DECLARE
  v_customer_id uuid;
  v_vendor_id uuid;
  v_driver_id uuid;
  v_customer_wallet_id uuid;
  v_vendor_wallet_id uuid;
  v_driver_wallet_id uuid;
  v_vendor_commission numeric;
  v_driver_commission numeric;
  v_order_amount numeric;
  v_delivery_fee numeric;
BEGIN
  -- Get order details
  SELECT 
    customer_id, 
    vendor_id, 
    driver_id,
    subtotal,
    delivery_fee
  INTO 
    v_customer_id, 
    v_vendor_id, 
    v_driver_id,
    v_order_amount,
    v_delivery_fee
  FROM orders
  WHERE id = p_order_id;
  
  -- Get wallet IDs
  SELECT id INTO v_customer_wallet_id FROM wallets WHERE user_id = v_customer_id;
  SELECT id INTO v_vendor_wallet_id FROM wallets WHERE user_id = v_vendor_id;
  
  IF v_driver_id IS NOT NULL THEN
    SELECT id INTO v_driver_wallet_id FROM wallets WHERE user_id = v_driver_id;
  END IF;
  
  -- Get commission rates
  SELECT COALESCE(commission_rate, 10) INTO v_vendor_commission FROM vendors WHERE id = v_vendor_id;
  
  IF v_driver_id IS NOT NULL THEN
    SELECT COALESCE(commission_rate, 15) INTO v_driver_commission FROM drivers WHERE id = v_driver_id;
  ELSE
    v_driver_commission := 0;
  END IF;
  
  -- Process payment based on payment method
  CASE p_payment_method
    WHEN 'cash' THEN
      -- Cash payment - no immediate wallet transactions
      -- Will be settled later when cash is collected
      NULL;
      
    WHEN 'electronic' THEN
      -- Electronic payment - immediate wallet transactions
      
      -- Add to vendor wallet (minus commission)
      IF v_vendor_wallet_id IS NOT NULL THEN
        INSERT INTO wallet_transactions (
          wallet_id,
          order_id,
          amount,
          type,
          payment_type,
          status,
          description
        ) VALUES (
          v_vendor_wallet_id,
          p_order_id,
          v_order_amount * (1 - v_vendor_commission / 100),
          'credit',
          'electronic',
          'completed',
          'دفع إلكتروني للطلب #' || p_order_id
        );
        
        -- Add commission transaction
        INSERT INTO wallet_transactions (
          wallet_id,
          order_id,
          amount,
          type,
          payment_type,
          status,
          description
        ) VALUES (
          v_vendor_wallet_id,
          p_order_id,
          v_order_amount * (v_vendor_commission / 100),
          'debit',
          'commission',
          'completed',
          'عمولة النظام للطلب #' || p_order_id
        );
      END IF;
      
      -- Add to driver wallet (minus commission) if driver exists
      IF v_driver_wallet_id IS NOT NULL AND v_driver_id IS NOT NULL THEN
        INSERT INTO wallet_transactions (
          wallet_id,
          order_id,
          amount,
          type,
          payment_type,
          status,
          description
        ) VALUES (
          v_driver_wallet_id,
          p_order_id,
          v_delivery_fee * (1 - v_driver_commission / 100),
          'credit',
          'electronic',
          'completed',
          'أجرة توصيل للطلب #' || p_order_id
        );
        
        -- Add commission transaction
        INSERT INTO wallet_transactions (
          wallet_id,
          order_id,
          amount,
          type,
          payment_type,
          status,
          description
        ) VALUES (
          v_driver_wallet_id,
          p_order_id,
          v_delivery_fee * (v_driver_commission / 100),
          'debit',
          'commission',
          'completed',
          'عمولة النظام للطلب #' || p_order_id
        );
      END IF;
      
    WHEN 'wallet' THEN
      -- Wallet payment - deduct from customer wallet
      IF v_customer_wallet_id IS NOT NULL THEN
        INSERT INTO wallet_transactions (
          wallet_id,
          order_id,
          amount,
          type,
          payment_type,
          status,
          description
        ) VALUES (
          v_customer_wallet_id,
          p_order_id,
          p_amount,
          'debit',
          'wallet',
          'completed',
          'دفع من المحفظة للطلب #' || p_order_id
        );
      END IF;
      
      -- Add to vendor wallet (minus commission)
      IF v_vendor_wallet_id IS NOT NULL THEN
        INSERT INTO wallet_transactions (
          wallet_id,
          order_id,
          amount,
          type,
          payment_type,
          status,
          description
        ) VALUES (
          v_vendor_wallet_id,
          p_order_id,
          v_order_amount * (1 - v_vendor_commission / 100),
          'credit',
          'wallet',
          'completed',
          'دفع من محفظة الزبون للطلب #' || p_order_id
        );
        
        -- Add commission transaction
        INSERT INTO wallet_transactions (
          wallet_id,
          order_id,
          amount,
          type,
          payment_type,
          status,
          description
        ) VALUES (
          v_vendor_wallet_id,
          p_order_id,
          v_order_amount * (v_vendor_commission / 100),
          'debit',
          'commission',
          'completed',
          'عمولة النظام للطلب #' || p_order_id
        );
      END IF;
      
      -- Add to driver wallet (minus commission) if driver exists
      IF v_driver_wallet_id IS NOT NULL AND v_driver_id IS NOT NULL THEN
        INSERT INTO wallet_transactions (
          wallet_id,
          order_id,
          amount,
          type,
          payment_type,
          status,
          description
        ) VALUES (
          v_driver_wallet_id,
          p_order_id,
          v_delivery_fee * (1 - v_driver_commission / 100),
          'credit',
          'wallet',
          'completed',
          'أجرة توصيل للطلب #' || p_order_id
        );
        
        -- Add commission transaction
        INSERT INTO wallet_transactions (
          wallet_id,
          order_id,
          amount,
          type,
          payment_type,
          status,
          description
        ) VALUES (
          v_driver_wallet_id,
          p_order_id,
          v_delivery_fee * (v_driver_commission / 100),
          'debit',
          'commission',
          'completed',
          'عمولة النظام للطلب #' || p_order_id
        );
      END IF;
  END CASE;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;