import React, { useState } from 'react';
import { v4 as uuidv4 } from 'uuid';
import { toast } from 'react-toastify';
import WholesalePrices from './WholesalePrices';

export default function ProductVariants({ variants = [], onChange }) {
  const [newVariant, setNewVariant] = useState({
    name: '',
    price: 0,
    wholesale_price: 0,
    discount_price: 0,
    stock: 0,
    image: '',
    sku: ''
  });

  const handleAddVariant = () => {
    if (!newVariant.name) {
      toast.error('الرجاء إدخال اسم النوع');
      return;
    }

    const variant = {
      id: uuidv4(),
      ...newVariant
    };

    onChange([...variants, variant]);
    setNewVariant({
      name: '',
      price: 0,
      wholesale_price: 0,
      discount_price: 0,
      stock: 0,
      image: '',
      sku: ''
    });
  };

  const handleRemoveVariant = (variantId) => {
    onChange(variants.filter(v => v.id !== variantId));
  };

  const handleUpdateVariant = (variantId, field, value) => {
    onChange(variants.map(v => 
      v.id === variantId 
        ? { ...v, [field]: value }
        : v
    ));
  };

  return (
    <div className="space-y-4">
      <div className="border rounded-lg p-4">
        <h3 className="font-medium text-gray-900 mb-4">الأنواع المتوفرة</h3>
        
        {variants.length > 0 ? (
          <div className="space-y-4">
            {variants.map(variant => (
              <div key={variant.id} className="flex items-start space-x-4 p-4 bg-gray-50 rounded-lg">
                <div className="flex-1 grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      اسم النوع
                    </label>
                    <input
                      type="text"
                      value={variant.name}
                      onChange={(e) => handleUpdateVariant(variant.id, 'name', e.target.value)}
                      className="w-full border rounded-md px-3 py-1.5"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      السعر (₪)
                    </label>
                    <input
                      type="number"
                      value={variant.price}
                      onChange={(e) => handleUpdateVariant(variant.id, 'price', parseFloat(e.target.value))}
                      className="w-full border rounded-md px-3 py-1.5"
                      min="0"
                      step="0.01"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      سعر الجملة (₪)
                    </label>
                    <input
                      type="number"
                      value={variant.wholesale_price}
                      onChange={(e) => handleUpdateVariant(variant.id, 'wholesale_price', parseFloat(e.target.value))}
                      className="w-full border rounded-md px-3 py-1.5"
                      min="0"
                      step="0.01"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      سعر التخفيض (₪)
                    </label>
                    <input
                      type="number"
                      value={variant.discount_price}
                      onChange={(e) => handleUpdateVariant(variant.id, 'discount_price', parseFloat(e.target.value))}
                      className="w-full border rounded-md px-3 py-1.5"
                      min="0"
                      step="0.01"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      المخزون
                    </label>
                    <input
                      type="number"
                      value={variant.stock}
                      onChange={(e) => handleUpdateVariant(variant.id, 'stock', parseInt(e.target.value))}
                      className="w-full border rounded-md px-3 py-1.5"
                      min="0"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      رقم المنتج (SKU)
                    </label>
                    <input
                      type="text"
                      value={variant.sku}
                      onChange={(e) => handleUpdateVariant(variant.id, 'sku', e.target.value)}
                      className="w-full border rounded-md px-3 py-1.5"
                    />
                  </div>
                  
                  <div className="col-span-2">
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      رابط الصورة
                    </label>
                    <input
                      type="url"
                      value={variant.image}
                      onChange={(e) => handleUpdateVariant(variant.id, 'image', e.target.value)}
                      className="w-full border rounded-md px-3 py-1.5"
                      placeholder="https://example.com/image.jpg"
                    />
                  </div>
                </div>
                
                <button
                  type="button"
                  onClick={() => handleRemoveVariant(variant.id)}
                  className="text-red-600 hover:text-red-800"
                >
                  حذف
                </button>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-gray-500 text-center py-4">لا توجد أنواع بعد</p>
        )}
      </div>

      <div className="border rounded-lg p-4">
        <h3 className="font-medium text-gray-900 mb-4">إضافة نوع جديد</h3>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              اسم النوع
            </label>
            <input
              type="text"
              value={newVariant.name}
              onChange={(e) => setNewVariant({ ...newVariant, name: e.target.value })}
              className="w-full border rounded-md px-3 py-1.5"
              placeholder="مثال: أحمر كبير"
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              السعر (₪)
            </label>
            <input
              type="number"
              value={newVariant.price}
              onChange={(e) => setNewVariant({ ...newVariant, price: parseFloat(e.target.value) })}
              className="w-full border rounded-md px-3 py-1.5"
              min="0"
              step="0.01"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              سعر الجملة (₪)
            </label>
            <input
              type="number"
              value={newVariant.wholesale_price}
              onChange={(e) => setNewVariant({ ...newVariant, wholesale_price: parseFloat(e.target.value) })}
              className="w-full border rounded-md px-3 py-1.5"
              min="0"
              step="0.01"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              سعر التخفيض (₪)
            </label>
            <input
              type="number"
              value={newVariant.discount_price}
              onChange={(e) => setNewVariant({ ...newVariant, discount_price: parseFloat(e.target.value) })}
              className="w-full border rounded-md px-3 py-1.5"
              min="0"
              step="0.01"
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              المخزون
            </label>
            <input
              type="number"
              value={newVariant.stock}
              onChange={(e) => setNewVariant({ ...newVariant, stock: parseInt(e.target.value) })}
              className="w-full border rounded-md px-3 py-1.5"
              min="0"
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              رقم المنتج (SKU)
            </label>
            <input
              type="text"
              value={newVariant.sku}
              onChange={(e) => setNewVariant({ ...newVariant, sku: e.target.value })}
              className="w-full border rounded-md px-3 py-1.5"
              placeholder="ABC123"
            />
          </div>
          
          <div className="col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-1">
              رابط الصورة
            </label>
            <input
              type="url"
              value={newVariant.image}
              onChange={(e) => setNewVariant({ ...newVariant, image: e.target.value })}
              className="w-full border rounded-md px-3 py-1.5"
              placeholder="https://example.com/image.jpg"
            />
          </div>
        </div>
        
        <div className="mt-4 flex justify-end">
          <button
            type="button"
            onClick={handleAddVariant}
            className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
          >
            إضافة النوع
          </button>
        </div>
      </div>
    </div>
  );
}