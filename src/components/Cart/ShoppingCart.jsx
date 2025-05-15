import React, { useState } from 'react';
import { toast } from 'react-toastify';

export default function ShoppingCart({ items, onUpdateQuantity, onRemoveItem, onCheckout }) {
  const [loading, setLoading] = useState(false);

  const calculateTotal = () => {
    return items.reduce((total, item) => total + (item.price * item.quantity), 0);
  };

  const handleQuantityChange = (itemId, newQuantity) => {
    if (newQuantity < 1) return;
    onUpdateQuantity(itemId, newQuantity);
  };

  const handleCheckout = async () => {
    if (items.length === 0) {
      toast.error('السلة فارغة');
      return;
    }

    setLoading(true);
    try {
      await onCheckout();
      toast.success('تم إنشاء الطلب بنجاح');
    } catch (error) {
      toast.error('حدث خطأ أثناء إنشاء الطلب');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <h2 className="text-xl font-semibold mb-4">سلة المشتريات</h2>
      
      {items.length === 0 ? (
        <p className="text-gray-500 text-center py-8">السلة فارغة</p>
      ) : (
        <>
          <div className="space-y-4 mb-6">
            {items.map(item => (
              <div key={item.id} className="flex items-center justify-between border-b pb-4">
                <div className="flex items-center space-x-4">
                  {item.image && (
                    <img 
                      src={item.image} 
                      alt={item.name} 
                      className="w-16 h-16 object-cover rounded"
                    />
                  )}
                  <div>
                    <h3 className="font-medium">{item.name}</h3>
                    <p className="text-gray-600">₪{item.price}</p>
                  </div>
                </div>
                
                <div className="flex items-center space-x-4">
                  <div className="flex items-center border rounded">
                    <button
                      onClick={() => handleQuantityChange(item.id, item.quantity - 1)}
                      className="px-3 py-1 hover:bg-gray-100"
                    >
                      -
                    </button>
                    <span className="px-3 py-1 border-x">{item.quantity}</span>
                    <button
                      onClick={() => handleQuantityChange(item.id, item.quantity + 1)}
                      className="px-3 py-1 hover:bg-gray-100"
                    >
                      +
                    </button>
                  </div>
                  
                  <button
                    onClick={() => onRemoveItem(item.id)}
                    className="text-red-600 hover:text-red-800"
                  >
                    حذف
                  </button>
                </div>
              </div>
            ))}
          </div>

          <div className="border-t pt-4">
            <div className="flex justify-between items-center mb-4">
              <span className="font-medium">المجموع:</span>
              <span className="text-xl font-bold">₪{calculateTotal()}</span>
            </div>

            <button
              onClick={handleCheckout}
              disabled={loading}
              className={`w-full bg-blue-600 text-white py-2 rounded-lg ${
                loading 
                  ? 'opacity-50 cursor-not-allowed'
                  : 'hover:bg-blue-700'
              }`}
            >
              {loading ? 'جاري إنشاء الطلب...' : 'إتمام الطلب'}
            </button>
          </div>
        </>
      )}
    </div>
  );
}