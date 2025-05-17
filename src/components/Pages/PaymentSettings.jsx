import React, { useState, useEffect } from 'react';
import { toast } from 'react-toastify';
import { getPaymentSettings, updatePaymentSettings } from '../../lib/walletApi';
import { supabase } from '../../lib/supabase';

export default function PaymentSettings() {
  const [loading, setLoading] = useState(false);
  const [paymentMethods, setPaymentMethods] = useState([]);
  const [settings, setSettings] = useState({
    deliveryCommission: 15,
    autoDeductFromDriver: true,
    autoChargeVendor: true,
    paymentMethods: [],
    wallet: {
      enabled: true,
      name: 'توصيل محفظة (الدفع المسبق)',
      description: 'عند تفعيل هذا الخيار، يتم التعامل مع الطلبات المدفوعة مسبقًا (عبر المحفظة أو الدفع الإلكتروني)',
      steps: [
        'يُعتبر التوصيل في هذه الحالة مدفوعًا مسبقًا',
        'يتم شحن محفظة البائع بالكامل بقيمة الطلب + التوصيل',
        'يتم خصم نفس القيمة من محفظة السائق تلقائيًا',
        'السائق يستلم من الزبون فقط أجرة التوصيل يدًا بيد'
      ],
      note: '✅ هذا النظام مناسب لتطبيقات الدفع المسبق والطلبات التي تُدفع أونلاين'
    },
    traditional: {
      enabled: true,
      name: 'المحفظة التقليدية (الدفع عند الاستلام)',
      description: 'في هذا النظام، يتم تقسيم المبلغ مباشرة عند التسليم',
      steps: [
        'الزبون يدفع كامل المبلغ (الطلب + التوصيل) للسائق',
        'يتم تحويل قيمة الطلب إلى محفظة البائع',
        'ويتم إضافة قيمة التوصيل إلى محفظة السائق'
      ],
      note: '✅ هذا الخيار مناسب للطلبات التي يتم دفعها نقدًا عند التسليم'
    },
    cash: {
      enabled: true,
      name: 'الدفع عند الاستلام',
      description: 'الدفع نقداً عند استلام الطلب',
      steps: [
        'الزبون يطلب من المتجر',
        'السائق يستلم الطلب من المتجر',
        'السائق يوصل الطلب للزبون',
        'الزبون يدفع المبلغ كاملاً (قيمة الطلب + التوصيل) للسائق'
      ],
      balanceNotes: [
        'رصيد البائع = 0 (حتى يتم التحصيل)',
        'رصيد السائق = 0 (حتى يتم التحصيل)'
      ],
      icon: '💰',
      color: 'green'
    },
    electronic: {
      enabled: true,
      name: 'الدفع الإلكتروني',
      description: 'الدفع المسبق عبر بطاقة الائتمان أو المحفظة الإلكترونية',
      steps: [
        'الزبون يدفع كامل المبلغ إلكترونياً (قيمة الطلب + التوصيل)',
        'البائع يستلم قيمة الطلب مباشرة',
        'السائق يستلم قيمة التوصيل مباشرة',
        'السائق يوصل الطلب للزبون'
      ],
      balanceNotes: [
        'رصيد البائع = قيمة الطلب (فوراً)',
        'رصيد السائق = قيمة التوصيل (فوراً)'
      ],
      icon: '💳',
      color: 'blue'
    }
  });

  // تحميل الإعدادات من قاعدة البيانات
  useEffect(() => {
    fetchPaymentMethods();
    const loadSettings = async () => {
      try {
        setLoading(true);
        const paymentSettings = await getPaymentSettings();
        
        if (paymentSettings && paymentSettings.wallet) {
          setSettings(paymentSettings);
        }
      } catch (error) {
        console.error('Error loading wallet settings:', error);
        toast.error('فشل في تحميل إعدادات المحفظة');
      } finally {
        setLoading(false);
      }
    };
    
    loadSettings();
  }, []);

  // تحميل طرق الدفع من قاعدة البيانات
  const fetchPaymentMethods = async () => {
    try {
      const { data, error } = await supabase
        .from('payment_methods')
        .select('*')
        .order('id');
      
      if (error) throw error;
      setPaymentMethods(data || []);
    } catch (error) {
      console.error('Error fetching payment methods:', error);
      toast.error('فشل في تحميل طرق الدفع');
    }
  };

  const handleSave = async () => {
    try {
      setLoading(true);
      
      // حفظ الإعدادات في قاعدة البيانات
      const paymentSettings = {
        ...settings
        // يمكن إضافة المزيد من الإعدادات هنا
      };
      
      updatePaymentSettings(paymentSettings);
      
      toast.success('تم حفظ إعدادات المحفظة بنجاح');
    } catch (error) {
      console.error('Error saving wallet settings:', error);
      toast.error('فشل في حفظ إعدادات المحفظة');
    } finally {
      setLoading(false);
    }
  };

  // تحديث حالة طريقة الدفع
  const handlePaymentMethodStatusChange = async (id, enabled) => {
    try {
      setLoading(true);
      
      const { error } = await supabase
        .from('payment_methods')
        .update({ status: enabled ? 'active' : 'inactive' })
        .eq('id', id);
      
      if (error) throw error;
      
      // تحديث القائمة المحلية
      setPaymentMethods(methods => 
        methods.map(method => 
          method.id === id ? { ...method, status: enabled ? 'active' : 'inactive' } : method
        )
      );
      
      toast.success(`تم ${enabled ? 'تفعيل' : 'تعطيل'} طريقة الدفع بنجاح`);
    } catch (error) {
      console.error('Error updating payment method status:', error);
      toast.error('فشل في تحديث حالة طريقة الدفع');
    } finally {
      setLoading(false);
    }
  };

  const PaymentMethodCard = ({ type, method }) => (
    <div className="bg-gradient-to-br from-white to-gray-50 rounded-lg shadow-md p-6 border border-gray-100">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className={`p-2 rounded-full ${
            method.type === 'wallet' ? 'bg-purple-100 text-purple-600' : 
            method.type === 'electronic' ? 'bg-blue-100 text-blue-600' : 
            'bg-green-100 text-green-600'
          }`}>
            {method.icon || (
              method.type === 'wallet' ? '👛' : 
              method.type === 'electronic' ? '💳' : 
              '💰'
            )}
          </div>
          <h3 className="text-xl font-bold">{method.name || 'طريقة دفع'}</h3>
        </div>
        <label className="relative inline-flex items-center cursor-pointer">
          <input
            type="checkbox"
            checked={method.status === 'active'}
            onChange={(e) => handlePaymentMethodStatusChange(method.id, e.target.checked)}
            className="sr-only peer"
          />
          <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:right-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
        </label>
      </div>

      <div className="space-y-6">
        <div className="bg-white p-4 rounded-lg border border-gray-100">
          <p className="text-gray-600">{method.description}</p>
        </div>

        <div>
          <h4 className="font-semibold text-gray-800 mb-3 flex items-center gap-2">
            <span className="text-blue-600">📝</span>
            خطوات العمل
          </h4>
          <div className="space-y-2">
            {method.settings?.steps?.map((step, index) => (
              <div key={index} className="bg-white px-4 py-2 rounded-lg shadow-sm">
                {step}
              </div>
            ))}
          </div>
        </div>

        {method.settings?.note && (
          <div className={`p-4 rounded-lg ${
            method.type === 'wallet' ? 'bg-purple-50 text-purple-800' : 
            method.type === 'electronic' ? 'bg-blue-50 text-blue-800' : 
            'bg-green-50 text-green-800'
          }`}>
            <p>{method.settings.note}</p>
          </div>
        )}
      </div>
    </div>
  );

  return (
    <div className="space-y-8">
      <div className="flex justify-between items-center bg-white p-4 rounded-lg shadow-sm border border-gray-100">
        <div className="flex items-center gap-3">
          <div className="p-2 bg-blue-100 text-blue-600 rounded-lg">⚙️</div>
          <h2 className="text-2xl font-bold">إعدادات طرق الدفع</h2>
        </div>
        <button
          onClick={handleSave}
          disabled={loading}
          className={`bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-2 ${loading ? 'opacity-70 cursor-not-allowed' : ''}`}
        >
          <span>💾</span>
          {loading ? 'جاري الحفظ...' : 'حفظ التغييرات'}
        </button>
      </div>

      {/* Payment Methods */}
      <div className="grid grid-cols-1 gap-8 mt-8">
        <h2 className="text-2xl font-bold mb-4">طرق الدفع المتاحة</h2>
        {paymentMethods.length === 0 ? (
          <div className="bg-white p-8 rounded-lg shadow-md text-center">
            <p className="text-gray-500">لا توجد طرق دفع متاحة</p>
          </div>
        ) : (
          paymentMethods.map(method => (
            <div key={method.id} className="bg-gradient-to-br from-white to-gray-50 rounded-lg shadow-md p-6 border border-gray-100">
              <div className="flex items-center justify-between mb-6">
                <div className="flex items-center gap-3">
                  <div className={`p-2 rounded-full ${
                    method.type === 'wallet' ? 'bg-purple-100 text-purple-600' : 
                    method.type === 'electronic' ? 'bg-blue-100 text-blue-600' : 
                    'bg-green-100 text-green-600'
                  }`}>
                    {method.settings?.icon || (
                      method.type === 'wallet' ? '👛' : 
                      method.type === 'electronic' ? '💳' : 
                      '💰'
                    )}
                  </div>
                  <h3 className="text-xl font-bold">{method.name}</h3>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={method.status === 'active'}
                    onChange={(e) => handlePaymentMethodStatusChange(method.id, e.target.checked)}
                    className="sr-only peer"
                  />
                  <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:right-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                </label>
              </div>

              <div className="space-y-6">
                <div className="bg-white p-4 rounded-lg border border-gray-100">
                  <p className="text-gray-600">{method.description}</p>
                </div>

                <div>
                  <h4 className="font-semibold text-gray-800 mb-3 flex items-center gap-2">
                    <span className="text-blue-600">📝</span>
                    خطوات العمل
                  </h4>
                  <div className="space-y-2">
                    {method.settings?.steps?.map((step, index) => (
                      <div key={index} className="bg-white px-4 py-2 rounded-lg shadow-sm">
                        {step}
                      </div>
                    ))}
                  </div>
                </div>

                {method.settings?.note && (
                  <div className={`p-4 rounded-lg ${
                    method.type === 'wallet' ? 'bg-purple-50 text-purple-800' : 
                    method.type === 'electronic' ? 'bg-blue-50 text-blue-800' : 
                    'bg-green-50 text-green-800'
                  }`}>
                    <p>{method.settings.note}</p>
                  </div>
                )}
              </div>
            </div>
          ))
        )}
      </div>

      {/* Commission Settings */}
      <div className="bg-gradient-to-br from-white to-gray-50 rounded-lg shadow-md p-6 border border-gray-100">
        <div className="flex items-center gap-3 mb-6">
          <div className="p-2 bg-purple-100 text-purple-600 rounded-full">💰</div>
          <h3 className="text-xl font-bold">إعدادات العمولة والخصومات</h3>
        </div>
        
        <div className="space-y-6">
          <div className="bg-white p-4 rounded-lg border border-gray-100">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              نسبة عمولة البائع (%)
            </label>
            <div className="flex items-center gap-2">
              <input
                type="number"
                value={settings.deliveryCommission}
                onChange={(e) => setSettings({ ...settings, deliveryCommission: Number(e.target.value) })}
                className="w-32 border rounded-lg px-4 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                min="0"
                max="100"
              />
              <span className="text-gray-600">%</span>
            </div>
          </div>

          <div className="bg-white p-4 rounded-lg border border-gray-100 space-y-3">
            <label className="flex items-center gap-3 p-2 hover:bg-gray-50 rounded-lg transition-colors cursor-pointer">
              <input
                type="checkbox"
                checked={settings.autoDeductFromDriver}
                onChange={(e) => setSettings({ ...settings, autoDeductFromDriver: e.target.checked })}
                className="rounded text-blue-600 focus:ring-blue-500 w-5 h-5"
              />
              <span>خصم تلقائي من السائق (الدفع المسبق)</span>
            </label>

            <label className="flex items-center gap-3 p-2 hover:bg-gray-50 rounded-lg transition-colors cursor-pointer">
              <input
                type="checkbox"
                checked={settings.autoChargeVendor}
                onChange={(e) => setSettings({ ...settings, autoChargeVendor: e.target.checked })}
                className="rounded text-blue-600 focus:ring-blue-500 w-5 h-5"
              />
              <span>شحن محفظة البائع تلقائيًا</span>
            </label>
          </div>

          <div className="bg-gradient-to-r from-blue-50 to-purple-50 p-6 rounded-lg">
            <h4 className="font-semibold text-gray-800 mb-3 flex items-center gap-2">
              <span>🧪</span>
              مثال توضيحي
            </h4>
            <p className="text-gray-600 mb-4">الطلب: 70 شيكل (60 للمنتج + 10 توصيل)</p>
            <div className="space-y-2">
              <p className="text-blue-600 bg-white px-4 py-2 rounded-lg shadow-sm">
                🔹 عمولة البائع = {settings.deliveryCommission}% من 60 شيكل = {(60 * settings.deliveryCommission / 100).toFixed(2)} شيكل
              </p>
              <p className="text-red-600 bg-white px-4 py-2 rounded-lg shadow-sm">
                🔹 عمولة السائق = {settings.deliveryCommission}% من 10 شيكل = {(10 * settings.deliveryCommission / 100).toFixed(2)} شيكل
              </p>
              <p className="text-green-600 bg-white px-4 py-2 rounded-lg shadow-sm">
                🔹 إجمالي العمولة للنظام = {(60 * settings.deliveryCommission / 100 + 10 * settings.deliveryCommission / 100).toFixed(2)} شيكل
              </p>
            </div>
          </div>
        </div>
      </div>

      <PaymentMethodCard type="wallet" method={settings.wallet} />
      <PaymentMethodCard type="traditional" method={settings.traditional} />
    </div>
  );
}