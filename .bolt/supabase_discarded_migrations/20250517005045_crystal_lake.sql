/*
  # Payment Methods Implementation

  1. New Tables
    - `payment_methods` - Stores available payment methods
    - `payment_method_settings` - Stores settings for payment methods

  2. Changes
    - Fixed references to orders table in wallet transactions
    - Added payment methods data
*/

-- Create payment_methods table if it doesn't exist
CREATE TABLE IF NOT EXISTS payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  type TEXT NOT NULL, -- 'cash', 'electronic', 'wallet'
  icon TEXT,
  color TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  settings JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT payment_methods_type_check CHECK (type IN ('cash', 'electronic', 'wallet'))
);

-- Create payment_method_settings table if it doesn't exist
CREATE TABLE IF NOT EXISTS payment_method_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  value JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS on payment tables
ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_method_settings ENABLE ROW LEVEL SECURITY;

-- Create policies for payment_methods
CREATE POLICY "Anyone can view active payment methods"
  ON payment_methods
  FOR SELECT
  USING (status = 'active');

CREATE POLICY "Admins can manage payment methods"
  ON payment_methods
  FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- Create policies for payment_method_settings
CREATE POLICY "Admins can manage payment method settings"
  ON payment_method_settings
  FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- Insert default payment methods
INSERT INTO payment_methods (name, description, type, icon, color, status, settings)
VALUES 
  ('الدفع عند الاستلام', 'الدفع نقداً عند استلام الطلب', 'cash', '💰', 'green', 'active', '{
    "steps": [
      "الزبون يطلب من المتجر",
      "السائق يستلم الطلب من المتجر",
      "السائق يوصل الطلب للزبون",
      "الزبون يدفع المبلغ كاملاً (قيمة الطلب + التوصيل) للسائق"
    ],
    "balanceNotes": [
      "رصيد البائع = 0 (حتى يتم التحصيل)",
      "رصيد السائق = 0 (حتى يتم التحصيل)"
    ]
  }'),
  ('الدفع الإلكتروني', 'الدفع المسبق عبر بطاقة الائتمان أو المحفظة الإلكترونية', 'electronic', '💳', 'blue', 'active', '{
    "steps": [
      "الزبون يدفع كامل المبلغ إلكترونياً (قيمة الطلب + التوصيل)",
      "البائع يستلم قيمة الطلب مباشرة",
      "السائق يستلم قيمة التوصيل مباشرة",
      "السائق يوصل الطلب للزبون"
    ],
    "balanceNotes": [
      "رصيد البائع = قيمة الطلب (فوراً)",
      "رصيد السائق = قيمة التوصيل (فوراً)"
    ]
  }'),
  ('المحفظة', 'الدفع باستخدام رصيد المحفظة', 'wallet', '👛', 'purple', 'active', '{
    "steps": [
      "الزبون يدفع من رصيد محفظته",
      "يتم خصم المبلغ من محفظة الزبون",
      "يتم إضافة قيمة الطلب لمحفظة البائع",
      "يتم إضافة قيمة التوصيل لمحفظة السائق"
    ],
    "balanceNotes": [
      "رصيد البائع = قيمة الطلب (فوراً)",
      "رصيد السائق = قيمة التوصيل (فوراً)"
    ]
  }');

-- Insert default payment settings
INSERT INTO payment_method_settings (name, value)
VALUES 
  ('wallet_settings', '{
    "deliveryCommission": 15,
    "autoDeductFromDriver": true,
    "autoChargeVendor": true,
    "wallet": {
      "enabled": true,
      "name": "توصيل محفظة (الدفع المسبق)",
      "description": "عند تفعيل هذا الخيار، يتم التعامل مع الطلبات المدفوعة مسبقًا (عبر المحفظة أو الدفع الإلكتروني)",
      "steps": [
        "يُعتبر التوصيل في هذه الحالة مدفوعًا مسبقًا",
        "يتم شحن محفظة البائع بالكامل بقيمة الطلب + التوصيل",
        "يتم خصم نفس القيمة من محفظة السائق تلقائيًا",
        "السائق يستلم من الزبون فقط أجرة التوصيل يدًا بيد"
      ],
      "note": "✅ هذا النظام مناسب لتطبيقات الدفع المسبق والطلبات التي تُدفع أونلاين"
    },
    "traditional": {
      "enabled": true,
      "name": "المحفظة التقليدية (الدفع عند الاستلام)",
      "description": "في هذا النظام، يتم تقسيم المبلغ مباشرة عند التسليم",
      "steps": [
        "الزبون يدفع كامل المبلغ (الطلب + التوصيل) للسائق",
        "يتم تحويل قيمة الطلب إلى محفظة البائع",
        "ويتم إضافة قيمة التوصيل إلى محفظة السائق"
      ],
      "note": "✅ هذا الخيار مناسب للطلبات التي يتم دفعها نقدًا عند التسليم"
    }
  }');

-- Create function to get payment methods
CREATE OR REPLACE FUNCTION get_payment_methods()
RETURNS SETOF payment_methods AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM payment_methods
  WHERE status = 'active'
  ORDER BY id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get payment settings
CREATE OR REPLACE FUNCTION get_payment_settings()
RETURNS JSONB AS $$
DECLARE
  v_settings JSONB;
BEGIN
  SELECT value INTO v_settings
  FROM payment_method_settings
  WHERE name = 'wallet_settings'
  LIMIT 1;
  
  IF v_settings IS NULL THEN
    v_settings := '{
      "deliveryCommission": 15,
      "autoDeductFromDriver": true,
      "autoChargeVendor": true,
      "wallet": {
        "enabled": true,
        "name": "توصيل محفظة (الدفع المسبق)",
        "description": "عند تفعيل هذا الخيار، يتم التعامل مع الطلبات المدفوعة مسبقًا (عبر المحفظة أو الدفع الإلكتروني)",
        "steps": [
          "يُعتبر التوصيل في هذه الحالة مدفوعًا مسبقًا",
          "يتم شحن محفظة البائع بالكامل بقيمة الطلب + التوصيل",
          "يتم خصم نفس القيمة من محفظة السائق تلقائيًا",
          "السائق يستلم من الزبون فقط أجرة التوصيل يدًا بيد"
        ],
        "note": "✅ هذا النظام مناسب لتطبيقات الدفع المسبق والطلبات التي تُدفع أونلاين"
      },
      "traditional": {
        "enabled": true,
        "name": "المحفظة التقليدية (الدفع عند الاستلام)",
        "description": "في هذا النظام، يتم تقسيم المبلغ مباشرة عند التسليم",
        "steps": [
          "الزبون يدفع كامل المبلغ (الطلب + التوصيل) للسائق",
          "يتم تحويل قيمة الطلب إلى محفظة البائع",
          "ويتم إضافة قيمة التوصيل إلى محفظة السائق"
        ],
        "note": "✅ هذا الخيار مناسب للطلبات التي يتم دفعها نقدًا عند التسليم"
      }
    }'::jsonb;
    
    -- Insert default settings
    INSERT INTO payment_method_settings (name, value)
    VALUES ('wallet_settings', v_settings);
  END IF;
  
  RETURN v_settings;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update payment settings
CREATE OR REPLACE FUNCTION update_payment_settings(
  p_settings JSONB
)
RETURNS BOOLEAN AS $$
BEGIN
  -- Update settings
  UPDATE payment_method_settings
  SET 
    value = p_settings,
    updated_at = now()
  WHERE name = 'wallet_settings';
  
  -- If no rows were updated, insert new settings
  IF NOT FOUND THEN
    INSERT INTO payment_method_settings (name, value)
    VALUES ('wallet_settings', p_settings);
  END IF;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;