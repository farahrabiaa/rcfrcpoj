/*
  # Add Payment Methods

  1. New Records
    - Add cash payment method
    - Add electronic payment method
    
  2. Description
    This migration adds two essential payment methods to the system:
    - Cash on delivery payment method
    - Electronic payment method
    
  Both methods are set to active status by default and include proper configuration.
*/

-- Check if payment_methods table exists
DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'payment_methods') THEN
    -- Insert cash payment method if it doesn't exist
    INSERT INTO payment_methods (name, type, description, status, settings)
    SELECT 
      'الدفع عند الاستلام', 
      'cash', 
      'الدفع نقداً عند استلام الطلب',
      'active',
      jsonb_build_object(
        'icon', '💰',
        'color', 'green',
        'steps', ARRAY[
          'الزبون يطلب من المتجر',
          'السائق يستلم الطلب من المتجر',
          'السائق يوصل الطلب للزبون',
          'الزبون يدفع المبلغ كاملاً (قيمة الطلب + التوصيل) للسائق'
        ],
        'balanceNotes', ARRAY[
          'رصيد البائع = 0 (حتى يتم التحصيل)',
          'رصيد السائق = 0 (حتى يتم التحصيل)'
        ],
        'note', '✅ هذا الخيار مناسب للطلبات التي يتم دفعها نقدًا عند التسليم'
      )
    WHERE NOT EXISTS (
      SELECT 1 FROM payment_methods WHERE type = 'cash'
    );
    
    -- Insert electronic payment method if it doesn't exist
    INSERT INTO payment_methods (name, type, description, status, settings)
    SELECT 
      'الدفع الإلكتروني', 
      'electronic', 
      'الدفع المسبق عبر بطاقة الائتمان أو المحفظة الإلكترونية',
      'active',
      jsonb_build_object(
        'icon', '💳',
        'color', 'blue',
        'steps', ARRAY[
          'الزبون يدفع كامل المبلغ إلكترونياً (قيمة الطلب + التوصيل)',
          'البائع يستلم قيمة الطلب مباشرة',
          'السائق يستلم قيمة التوصيل مباشرة',
          'السائق يوصل الطلب للزبون'
        ],
        'balanceNotes', ARRAY[
          'رصيد البائع = قيمة الطلب (فوراً)',
          'رصيد السائق = قيمة التوصيل (فوراً)'
        ],
        'note', '✅ هذا الخيار مناسب للطلبات التي تُدفع أونلاين'
      )
    WHERE NOT EXISTS (
      SELECT 1 FROM payment_methods WHERE type = 'electronic'
    );
  END IF;
END $$;