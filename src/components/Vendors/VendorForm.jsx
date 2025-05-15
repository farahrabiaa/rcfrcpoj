import React, { useState, useEffect } from 'react';
import { toast } from 'react-toastify';
import { supabase } from '../../lib/supabase';
import MediaUpload from '../Products/MediaUpload';
import { BUCKETS } from '../../lib/supabaseStorage';
import MapSelector from './MapSelector';
import ServiceAreaSelector from './ServiceAreaSelector';
import CategorySelector from './CategorySelector';

export default function VendorForm({ onSubmit, initialData = null }) {
  const [formData, setFormData] = useState({
    // بيانات المتجر
    store_name: '',
    phone: '',
    address: '',
    description: '',
    delivery_type: 'distance',
    delivery_radius: 5,
    price_per_km: 2,
    min_delivery_fee: 5,
    delivery_fee_per_km: 1,
    status: 'active',
    logo_url: '',
    banner_url: '',
    commission_rate: 10,
    wallet_enabled: false,
    auto_charge: false,
    service_areas: [],
    categories: [],
    // بيانات الموقع
    latitude: null,
    longitude: null,
    // بيانات العضوية
    membership: {
      type: 'basic',
      expires_at: new Date(new Date().setFullYear(new Date().getFullYear() + 1)).toISOString().split('T')[0], // سنة من اليوم
      commission_rate: 10
    },
    // بيانات المتجر المميز
    featured: false,
    featured_until: new Date(new Date().setMonth(new Date().getMonth() + 1)).toISOString().split('T')[0], // شهر من اليوم
    featured_order: 1,
    ...initialData
  });

  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [mapKey, setMapKey] = useState(Date.now()); // لإعادة تحميل الخريطة عند تغيير الموقع

  // قائمة المناطق المتاحة
  const areas = [
    // مدن الضفة الغربية الرئيسية
    'رام الله',
    'البيرة',
    'نابلس',
    'جنين',
    'طولكرم',
    'قلقيلية',
    'طوباس',
    'سلفيت',
    'أريحا',
    'بيت لحم',
    'الخليل',
    // مناطق ومدن إضافية
    'بيت جالا',
    'بيت ساحور',
    'بيرزيت',
    'الظاهرية',
    'دورا',
    'يطا',
    'عنبتا',
    'بيت فجار',
    'بديا',
    'عزون',
    'بيت أمر',
    'حلحول',
    'سعير',
    'ترقوميا',
    'عرابة',
    'يعبد',
    'قباطية',
    'طمون',
    'عقابا',
    'بيت فوريك',
    'عصيرة الشمالية',
    'بيتا',
    'حوارة',
    'سبسطية',
    'عقربا'
  ];

  // جلب التصنيفات من قاعدة البيانات
  useEffect(() => {
    const fetchCategories = async () => {
      try {
        setLoading(true);
        const { data, error } = await supabase
          .from('categories')
          .select('*')
          .order('name');
        
        if (error) throw error;
        setCategories(data || []);
      } catch (error) {
        console.error('Error fetching categories:', error);
        toast.error('فشل في تحميل التصنيفات');
      } finally {
        setLoading(false);
      }
    };

    fetchCategories();
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    try {
      // التحقق من البيانات المطلوبة
      if (!formData.store_name || !formData.phone || !formData.address) {
        toast.error('الرجاء تعبئة جميع الحقول المطلوبة');
        return;
      }

      // التحقق من الحقول الإجبارية حسب نوع التوصيل
      if (formData.delivery_type === 'distance') {
        if (!formData.delivery_radius || !formData.price_per_km) {
          toast.error('الرجاء تعبئة نطاق التوصيل وسعر الكيلومتر');
          return;
        }
      }

      // التحقق من تاريخ انتهاء العضوية
      if (!formData.membership.expires_at) {
        toast.error('الرجاء تحديد تاريخ انتهاء العضوية');
        return;
      }

      // التحقق من اختيار تصنيف واحد على الأقل
      if (formData.categories.length === 0) {
        toast.error('الرجاء اختيار تصنيف واحد على الأقل');
        return;
      }

      // إعداد بيانات المتجر المميز
      const vendorData = { ...formData };
      if (formData.featured) {
        vendorData.featured_until = formData.featured_until;
        vendorData.featured_order = formData.featured_order;
      } else {
        vendorData.featured_until = null;
        vendorData.featured_order = null;
      }

      // تنفيذ الإرسال - pass the event object
      onSubmit(e, vendorData);
    } catch (error) {
      console.error('Error submitting form:', error);
      toast.error('حدث خطأ أثناء حفظ البيانات');
    }
  };

  const handleLocationSelect = (lat, lng) => {
    setFormData({
      ...formData,
      latitude: lat,
      longitude: lng
    });
    setMapKey(Date.now()); // إعادة تحميل الخريطة
  };

  const handleServiceAreasChange = (areas) => {
    setFormData({
      ...formData,
      service_areas: areas
    });
  };

  const handleCategoriesChange = (selectedCategories) => {
    setFormData({
      ...formData,
      categories: selectedCategories
    });
  };

  const handleLogoUpload = ({ preview }) => {
    if (preview) {
      setFormData({ ...formData, logo_url: preview });
    }
  };

  const handleBannerUpload = ({ preview }) => {
    if (preview) {
      setFormData({ ...formData, banner_url: preview });
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div className="bg-white rounded-lg shadow-md p-6">
        <h3 className="text-lg font-semibold mb-4">بيانات المتجر</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              اسم المتجر <span className="text-red-600">*</span>
            </label>
            <input
              type="text"
              value={formData.store_name}
              onChange={(e) => setFormData({ ...formData, store_name: e.target.value })}
              className="w-full border rounded-md px-3 py-2"
              required
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              رقم الهاتف <span className="text-red-600">*</span>
            </label>
            <input
              type="tel"
              value={formData.phone}
              onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
              className="w-full border rounded-md px-3 py-2"
              required
            />
          </div>
          
          <div className="col-span-1 md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              العنوان <span className="text-red-600">*</span>
            </label>
            <input
              type="text"
              value={formData.address}
              onChange={(e) => setFormData({ ...formData, address: e.target.value })}
              className="w-full border rounded-md px-3 py-2"
              required
            />
          </div>
          
          <div className="col-span-1 md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              وصف المتجر
            </label>
            <textarea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              className="w-full border rounded-md px-3 py-2"
              rows="3"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              صورة اللوجو
            </label>
            <MediaUpload
              type="image"
              preview={formData.logo_url}
              onUpload={handleLogoUpload}
              storeInSupabase={true}
              bucket={BUCKETS.VENDORS}
              folder="logos"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              صورة الغلاف
            </label>
            <MediaUpload
              type="image"
              preview={formData.banner_url}
              onUpload={handleBannerUpload}
              storeInSupabase={true}
              bucket={BUCKETS.VENDORS}
              folder="banners"
            />
          </div>
        </div>
      </div>

      <div className="bg-white rounded-lg shadow-md p-6">
        <h3 className="text-lg font-semibold mb-4">تصنيف المتجر</h3>
        <div className="mb-4">
          <CategorySelector 
            availableCategories={categories}
            selectedCategories={formData.categories}
            onChange={handleCategoriesChange}
            loading={loading}
          />
        </div>
      </div>

      <div className="bg-white rounded-lg shadow-md p-6">
        <h3 className="text-lg font-semibold mb-4">حالة المتجر</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              الحالة <span className="text-red-600">*</span>
            </label>
            <select
              value={formData.status}
              onChange={(e) => setFormData({ ...formData, status: e.target.value })}
              className="w-full border rounded-md px-3 py-2"
              required
            >
              <option value="active">نشط</option>
              <option value="inactive">غير نشط</option>
              <option value="pending">معلق</option>
              <option value="suspended">موقوف</option>
              <option value="busy">مشغول</option>
            </select>
          </div>
          
          <div>
            <label className="flex items-center space-x-2 mt-8">
              <input
                type="checkbox"
                checked={formData.featured}
                onChange={(e) => setFormData({ ...formData, featured: e.target.checked })}
                className="rounded text-blue-600"
              />
              <span>متجر مميز</span>
            </label>
          </div>

          {formData.featured && (
            <>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  تاريخ انتهاء التمييز
                </label>
                <input
                  type="date"
                  value={formData.featured_until}
                  onChange={(e) => setFormData({ ...formData, featured_until: e.target.value })}
                  className="w-full border rounded-md px-3 py-2"
                  required={formData.featured}
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  ترتيب العرض (الأقل = الأعلى)
                </label>
                <input
                  type="number"
                  value={formData.featured_order}
                  onChange={(e) => setFormData({ ...formData, featured_order: parseInt(e.target.value) })}
                  className="w-full border rounded-md px-3 py-2"
                  min="1"
                  required={formData.featured}
                />
              </div>
            </>
          )}
        </div>
      </div>

      <div className="bg-white rounded-lg shadow-md p-6">
        <h3 className="text-lg font-semibold mb-4">موقع المتجر</h3>
        <div className="mb-4">
          <p className="text-sm text-gray-500 mb-2">حدد موقع المتجر على الخريطة بالنقر على المكان المناسب</p>
          <MapSelector 
            key={mapKey}
            initialLat={formData.latitude}
            initialLng={formData.longitude}
            onLocationSelect={handleLocationSelect}
          />
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              خط العرض
            </label>
            <input
              type="text"
              value={formData.latitude || ''}
              onChange={(e) => setFormData({ ...formData, latitude: parseFloat(e.target.value) })}
              className="w-full border rounded-md px-3 py-2"
              placeholder="مثال: 31.5017"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              خط الطول
            </label>
            <input
              type="text"
              value={formData.longitude || ''}
              onChange={(e) => setFormData({ ...formData, longitude: parseFloat(e.target.value) })}
              className="w-full border rounded-md px-3 py-2"
              placeholder="مثال: 34.4668"
            />
          </div>
        </div>
      </div>
      
      <div className="bg-white rounded-lg shadow-md p-6">
        <h3 className="text-lg font-semibold mb-4">إعدادات التوصيل</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              نوع التوصيل <span className="text-red-600">*</span>
            </label>
            <select
              value={formData.delivery_type}
              onChange={(e) => setFormData({ ...formData, delivery_type: e.target.value })}
              className="w-full border rounded-md px-3 py-2"
              required
            >
              <option value="distance">حسب المسافة</option>
              <option value="fixed">سعر ثابت</option>
              <option value="zones">مناطق</option>
            </select>
          </div>
          
          {formData.delivery_type === 'distance' && (
            <>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  نطاق التوصيل (كم) <span className="text-red-600">*</span>
                </label>
                <input
                  type="number"
                  value={formData.delivery_radius}
                  onChange={(e) => setFormData({ ...formData, delivery_radius: Number(e.target.value) })}
                  className="w-full border rounded-md px-3 py-2"
                  min="0"
                  step="0.1"
                  required
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  سعر الكيلومتر (₪) <span className="text-red-600">*</span>
                </label>
                <input
                  type="number"
                  value={formData.price_per_km}
                  onChange={(e) => setFormData({ ...formData, price_per_km: Number(e.target.value) })}
                  className="w-full border rounded-md px-3 py-2"
                  min="0"
                  step="0.1"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  الحد الأدنى لتكلفة التوصيل (₪)
                </label>
                <input
                  type="number"
                  value={formData.min_delivery_fee}
                  onChange={(e) => setFormData({ ...formData, min_delivery_fee: Number(e.target.value) })}
                  className="w-full border rounded-md px-3 py-2"
                  min="0"
                  step="0.1"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  تكلفة التوصيل لكل كيلومتر (₪)
                </label>
                <input
                  type="number"
                  value={formData.delivery_fee_per_km}
                  onChange={(e) => setFormData({ ...formData, delivery_fee_per_km: Number(e.target.value) })}
                  className="w-full border rounded-md px-3 py-2"
                  min="0"
                  step="0.1"
                />
              </div>
            </>
          )}

          {formData.delivery_type === 'fixed' && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                سعر التوصيل الثابت (₪) <span className="text-red-600">*</span>
              </label>
              <input
                type="number"
                value={formData.min_delivery_fee}
                onChange={(e) => setFormData({ ...formData, min_delivery_fee: Number(e.target.value) })}
                className="w-full border rounded-md px-3 py-2"
                min="0"
                step="0.1"
                required
              />
            </div>
          )}
        </div>
      </div>

      <div className="bg-white rounded-lg shadow-md p-6">
        <h3 className="text-lg font-semibold mb-4">مناطق الخدمة</h3>
        <ServiceAreaSelector 
          availableAreas={areas}
          selectedAreas={formData.service_areas}
          onChange={handleServiceAreasChange}
        />
      </div>
      
      <div className="bg-white rounded-lg shadow-md p-6">
        <h3 className="text-lg font-semibold mb-4">إعدادات العضوية</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              نوع العضوية <span className="text-red-600">*</span>
            </label>
            <select
              value={formData.membership.type}
              onChange={(e) => setFormData({
                ...formData,
                membership: { ...formData.membership, type: e.target.value }
              })}
              className="w-full border rounded-md px-3 py-2"
              required
            >
              <option value="basic">أساسية</option>
              <option value="premium">مميزة</option>
              <option value="gold">ذهبية</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              نسبة العمولة (%) <span className="text-red-600">*</span>
            </label>
            <input
              type="number"
              value={formData.membership.commission_rate}
              onChange={(e) => setFormData({
                ...formData,
                membership: { ...formData.membership, commission_rate: Number(e.target.value) }
              })}
              className="w-full border rounded-md px-3 py-2"
              min="0"
              max="100"
              step="0.1"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              تاريخ انتهاء العضوية <span className="text-red-600">*</span>
            </label>
            <input
              type="date"
              value={formData.membership.expires_at}
              onChange={(e) => setFormData({
                ...formData,
                membership: { ...formData.membership, expires_at: e.target.value }
              })}
              className="w-full border rounded-md px-3 py-2"
              required
            />
          </div>
        </div>
      </div>
      
      <div className="bg-white rounded-lg shadow-md p-6">
        <h3 className="text-lg font-semibold mb-4">إعدادات إضافية</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              نسبة العمولة (%) <span className="text-red-600">*</span>
            </label>
            <input
              type="number"
              value={formData.commission_rate}
              onChange={(e) => setFormData({ ...formData, commission_rate: Number(e.target.value) })}
              className="w-full border rounded-md px-3 py-2"
              min="0"
              max="100"
              step="0.1"
              required
            />
          </div>
          
          <div>
            <label className="flex items-center space-x-2">
              <input
                type="checkbox"
                checked={formData.wallet_enabled}
                onChange={(e) => setFormData({ ...formData, wallet_enabled: e.target.checked })}
                className="rounded text-blue-600"
              />
              <span>تفعيل المحفظة</span>
            </label>
          </div>
          
          {formData.wallet_enabled && (
            <div>
              <label className="flex items-center space-x-2">
                <input
                  type="checkbox"
                  checked={formData.auto_charge}
                  onChange={(e) => setFormData({ ...formData, auto_charge: e.target.checked })}
                  className="rounded text-blue-600"
                />
                <span>تفعيل الشحن التلقائي</span>
              </label>
            </div>
          )}
        </div>
      </div>
      
      <div className="flex justify-end space-x-2">
        <button
          type="submit"
          className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
        >
          {initialData ? 'تحديث' : 'إضافة'}
        </button>
      </div>
    </form>
  );
}