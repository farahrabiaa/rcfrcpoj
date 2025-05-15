import React, { useState, useEffect } from 'react';
import { toast } from 'react-toastify';
import { supabase } from '../../lib/supabase';
import MediaUpload from './MediaUpload';
import Gallery from './Gallery';
import ProductVariants from './ProductVariants';
import WholesalePrices from './WholesalePrices';
import ScheduledDiscounts from './ScheduledDiscounts';
import ProductAttributes from './ProductAttributes';
import ProductAddons from './ProductAddons';

export default function ProductForm({ onSubmit, initialData = null }) {
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    price: '',
    wholesale_price: '',
    discount_price: '',
    scheduled_discounts: [],
    vendor_id: '',
    category_id: '',
    status: 'active',
    image: '',
    gallery: [],
    video: '',
    stock: 0,
    addons: [],
    type: 'regular',
    variants: [],
    wholesale_prices: [],
    attributes: [],
    ...initialData
  });

  const [vendors, setVendors] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);

  // Fetch vendors and categories from the database
  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        
        // Fetch vendors
        const { data: vendorsData, error: vendorsError } = await supabase
          .from('vendors')
          .select('id, store_name')
          .order('store_name');
        
        if (vendorsError) {
          console.error('Error fetching vendors:', vendorsError);
          // Fallback to mock data if API fails
          setVendors([
            { id: 1, store_name: 'متجر كوفي' },
            { id: 2, store_name: 'متجر الشاي' },
            { id: 3, store_name: 'متجر العصائر' }
          ]);
        } else {
          setVendors(vendorsData || []);
        }
        
        // Fetch categories
        const { data: categoriesData, error: categoriesError } = await supabase
          .from('categories')
          .select('id, name')
          .order('name');
        
        if (categoriesError) {
          console.error('Error fetching categories:', categoriesError);
          // Fallback to mock data if API fails
          setCategories([
            { id: 1, name: 'مشروبات ساخنة' },
            { id: 2, name: 'عصائر' },
            { id: 3, name: 'حلويات' }
          ]);
        } else {
          setCategories(categoriesData || []);
        }
      } catch (error) {
        console.error('Error fetching data:', error);
        // Fallback to mock data
        setVendors([
          { id: 1, store_name: 'متجر كوفي' },
          { id: 2, store_name: 'متجر الشاي' },
          { id: 3, store_name: 'متجر العصائر' }
        ]);
        setCategories([
          { id: 1, name: 'مشروبات ساخنة' },
          { id: 2, name: 'عصائر' },
          { id: 3, name: 'حلويات' }
        ]);
      } finally {
        setLoading(false);
      }
    };
    
    fetchData();
  }, []);

  const handleSubmit = (e) => {
    e.preventDefault();
    
    // Validate required fields
    if (!formData.name || !formData.price || !formData.vendor_id || !formData.category_id) {
      toast.error('الرجاء تعبئة جميع الحقول المطلوبة');
      return;
    }

    onSubmit(formData);
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="col-span-1 md:col-span-2">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            نوع المنتج
          </label>
          <div className="flex gap-4">
            <label className="flex items-center">
              <input
                type="radio"
                value="regular"
                checked={formData.type === 'regular'}
                onChange={(e) => setFormData({ ...formData, type: e.target.value })}
                className="ml-2"
              />
              منتج عادي
            </label>
            <label className="flex items-center">
              <input
                type="radio"
                value="variant"
                checked={formData.type === 'variant'}
                onChange={(e) => setFormData({ ...formData, type: e.target.value })}
                className="ml-2"
              />
              منتج متعدد الأنواع
            </label>
          </div>
        </div>

        <div className="col-span-1 md:col-span-2">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            الصورة المميزة
          </label>
          <MediaUpload
            type="image"
            preview={formData.image}
            onUpload={({ preview }) => setFormData({ ...formData, image: preview })}
          />
        </div>

        <div className="col-span-1 md:col-span-2">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            معرض الصور
          </label>
          <Gallery
            images={formData.gallery}
            onUpdate={(gallery) => setFormData({ ...formData, gallery })}
          />
        </div>

        <div className="col-span-1 md:col-span-2">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            فيديو المنتج
          </label>
          <MediaUpload
            type="video"
            preview={formData.video}
            onUpload={({ preview }) => setFormData({ ...formData, video: preview })}
          />
        </div>

        <div className="col-span-1 md:col-span-2">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            اسم المنتج <span className="text-red-600">*</span>
          </label>
          <input
            type="text"
            value={formData.name}
            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
            className="w-full border rounded-md px-3 py-2"
            required
          />
        </div>

        <div className="col-span-1 md:col-span-2">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            الوصف
          </label>
          <textarea
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            className="w-full border rounded-md px-3 py-2"
            rows="3"
          />
        </div>

        {formData.type === 'regular' ? (
          <>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  السعر (₪) <span className="text-red-600">*</span>
                </label>
                <input
                  type="number"
                  value={formData.price}
                  onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                  className="w-full border rounded-md px-3 py-2"
                  min="0"
                  step="0.01"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  سعر الجملة (₪)
                </label>
                <input
                  type="number"
                  value={formData.wholesale_price}
                  onChange={(e) => setFormData({ ...formData, wholesale_price: e.target.value })}
                  className="w-full border rounded-md px-3 py-2"
                  min="0"
                  step="0.01"
                />
                <p className="text-xs text-gray-500 mt-1">اختياري</p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  سعر التخفيض الحالي (₪)
                </label>
                <input
                  type="number"
                  value={formData.discount_price}
                  onChange={(e) => setFormData({ ...formData, discount_price: e.target.value })}
                  className="w-full border rounded-md px-3 py-2"
                  min="0"
                  step="0.01"
                />
                <p className="text-xs text-gray-500 mt-1">اختياري</p>
              </div>
            </div>

            <div className="col-span-1 md:col-span-2">
              <ScheduledDiscounts
                discounts={formData.scheduled_discounts}
                onChange={(discounts) => setFormData({ ...formData, scheduled_discounts: discounts })}
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                المخزون <span className="text-red-600">*</span>
              </label>
              <input
                type="number"
                value={formData.stock}
                onChange={(e) => setFormData({ ...formData, stock: parseInt(e.target.value) })}
                className="w-full border rounded-md px-3 py-2"
                min="0"
                required
              />
            </div>
          </>
        ) : (
          <div className="col-span-1 md:col-span-2">
            <ProductVariants
              variants={formData.variants}
              onChange={(variants) => setFormData({ ...formData, variants })}
            />
          </div>
        )}

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            المتجر <span className="text-red-600">*</span>
          </label>
          <select
            value={formData.vendor_id}
            onChange={(e) => setFormData({ ...formData, vendor_id: e.target.value })}
            className="w-full border rounded-md px-3 py-2"
            required
            disabled={loading}
          >
            <option value="">اختر المتجر</option>
            {vendors.map(vendor => (
              <option key={vendor.id} value={vendor.id}>
                {vendor.store_name}
              </option>
            ))}
          </select>
          {loading && <p className="text-sm text-gray-500 mt-1">جاري تحميل المتاجر...</p>}
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            التصنيف <span className="text-red-600">*</span>
          </label>
          <select
            value={formData.category_id}
            onChange={(e) => setFormData({ ...formData, category_id: e.target.value })}
            className="w-full border rounded-md px-3 py-2"
            required
            disabled={loading}
          >
            <option value="">اختر التصنيف</option>
            {categories.map(category => (
              <option key={category.id} value={category.id}>
                {category.name}
              </option>
            ))}
          </select>
          {loading && <p className="text-sm text-gray-500 mt-1">جاري تحميل التصنيفات...</p>}
        </div>

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
            <option value="draft">مسودة</option>
          </select>
        </div>

        <div className="col-span-1 md:col-span-2">
          <WholesalePrices
            prices={formData.wholesale_prices}
            onChange={(prices) => setFormData({ ...formData, wholesale_prices: prices })}
          />
          <p className="text-xs text-gray-500 mt-1">أسعار الجملة اختيارية</p>
        </div>

        <div className="col-span-1 md:col-span-2">
          <ProductAttributes
            attributes={formData.attributes}
            onChange={(attributes) => setFormData({ ...formData, attributes })}
          />
        </div>

        <div className="col-span-1 md:col-span-2">
          <ProductAddons
            addons={formData.addons}
            onChange={(addons) => setFormData({ ...formData, addons })}
          />
        </div>
      </div>

      <div className="flex justify-end space-x-2 pt-4">
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