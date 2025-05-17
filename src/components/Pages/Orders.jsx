import React, { useState, useEffect, useCallback } from 'react';
import { toast } from 'react-toastify';
import { supabase } from '../../lib/supabase';
import OrderProcessing from '../Orders/OrderProcessing';
import { Dialog, Transition } from '@headlessui/react';
import { Fragment } from 'react';

const FIELD_LABELS = {
  customer_name: 'اسم العميل',
  customer_phone: 'هاتف العميل',
  address: 'العنوان',
  vendor_name: 'اسم التاجر',
  total: 'المبلغ',
  status: 'الحالة',
  created_at: 'تاريخ الطلب'
};

const SELECT_FIELDS = [
  'id',
  'total',
  'status',
  'created_at',
  'address'
];

const DISPLAY_FIELDS = [
  'customer_name',
  'customer_phone',
  'address',
  'vendor_name',
  'total',
  'status',
  'created_at'
];

export default function Orders() {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedOrder, setSelectedOrder] = useState(null);
  const [showProcessingModal, setShowProcessingModal] = useState(false);

  const getGoogleMapsLink = (address) => {
    if (!address) return null;
    const encodedAddress = encodeURIComponent(address);
    return `https://www.google.com/maps/search/?api=1&query=${encodedAddress}`;
  };

  const fetchOrders = useCallback(async () => {
    setLoading(true);
    setError(null);
    
    try {
      // Check if Supabase client is properly initialized
      if (!supabase) {
        throw new Error('Supabase client is not initialized');
      }

      // Add error handling for the connection
      const { data: connectionTest } = await supabase.from('orders').select('count').limit(1).single();
      if (!connectionTest) {
        throw new Error('Could not connect to the database');
      }

      // Fetch orders with customer and vendor information with timeout
      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Request timeout')), 10000)
      );

      const fetchPromise = supabase
        .from('orders')
        .select(`
          id,
          total,
          status,
          created_at,
          address,
          customer_name,
          customer_phone,
          vendor_name
        `)
        .order('created_at', { ascending: false });

      const { data, error: supabaseError } = await Promise.race([
        fetchPromise,
        timeoutPromise
      ]);

      if (supabaseError) {
        console.error('Supabase error:', supabaseError);
        throw new Error(`Database error: ${supabaseError.message}`);
      }

      if (!data) {
        throw new Error('No data received from the server');
      }

      // Transform the data to match the expected format
      const transformedOrders = data.map(order => ({
        id: order.id,
        customer_name: order.customer_name || 'غير معروف',
        customer_phone: order.customer_phone || 'غير متوفر',
        address: order.address || 'غير متوفر',
        vendor_name: order.vendor_name || 'غير معروف',
        total: order.total,
        status: order.status,
        created_at: order.created_at
      }));

      setOrders(transformedOrders);
    } catch (err) {
      console.error('Error fetching orders:', err);
      let errorMessage = 'فشل في جلب الطلبات. ';
      
      if (err.message.includes('timeout')) {
        errorMessage += 'انتهت مهلة الاتصال بالخادم.';
      } else if (err.message.includes('network')) {
        errorMessage += 'يرجى التحقق من اتصال الإنترنت.';
      } else if (err.message.includes('Database error')) {
        errorMessage += err.message;
      } else {
        errorMessage += 'حدث خطأ غير متوقع.';
      }
      
      setError(errorMessage);
      toast.error(errorMessage);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchOrders();
  }, [fetchOrders]);

  const formatCellValue = (value, field) => {
    if (value === null || value === undefined) return 'غير متوفر';
    
    if (field === 'created_at') {
      return new Date(value).toLocaleString('ar-EG');
    }
    
    if (field === 'total') {
      return `${Number(value).toFixed(2)} شيكل`;
    }
    
    return String(value);
  };

  const handleActionClick = (order) => {
    setSelectedOrder(order);
    setShowProcessingModal(true);
  };

  return (
    <div className="p-4 relative">
      <h2 className="text-xl font-bold mb-4">قائمة الطلبات</h2>

      {loading && <p className="text-center py-4">جاري التحميل...</p>}
      {error && (
        <div className="text-red-500 text-center py-4 mb-4">
          <p>{error}</p>
          <button
            onClick={fetchOrders}
            className="mt-2 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 transition-colors"
          >
            إعادة المحاولة
          </button>
        </div>
      )}

      {!loading && !error && (
        <div className="overflow-x-auto shadow-md rounded-lg">
          <table className="min-w-full bg-white">
            <thead className="bg-gray-100">
              <tr>
                {DISPLAY_FIELDS.map((field) => (
                  <th key={field} className="p-3 text-right border-b">
                    {FIELD_LABELS[field]}
                  </th>
                ))}
                <th className="p-3 text-right border-b">الإجراءات</th>
              </tr>
            </thead>
            <tbody>
              {orders.length > 0 ? (
                orders.map((order) => (
                  <tr key={order.id} className="hover:bg-gray-50 transition-colors">
                    {DISPLAY_FIELDS.map((field) => (
                      <td 
                        key={`${order.id}-${field}`} 
                        className="p-3 border-b text-right"
                      >
                        {field === 'address' && order.address ? (
                          <a
                            href={getGoogleMapsLink(order.address)}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-blue-500 hover:underline hover:text-blue-700"
                            title="فتح في خرائط Google"
                          >
                            {order.address}
                            <svg 
                              className="w-4 h-4 inline-block mr-1" 
                              fill="none" 
                              stroke="currentColor" 
                              viewBox="0 0 24 24"
                            >
                              <path 
                                strokeLinecap="round" 
                                strokeLinejoin="round" 
                                strokeWidth={2} 
                                d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" 
                              />
                            </svg>
                          </a>
                        ) : (
                          formatCellValue(order[field], field)
                        )}
                      </td>
                    ))}
                    <td className="p-3 border-b">
                      <button
                        onClick={() => handleActionClick(order)}
                        className="px-3 py-1 bg-blue-500 text-white rounded hover:bg-blue-600 transition-colors"
                      >
                        إجراءات
                      </button>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td 
                    colSpan={DISPLAY_FIELDS.length + 1} 
                    className="p-4 text-center text-gray-500"
                  >
                    لا توجد طلبات متاحة
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {showProcessingModal && selectedOrder && (
        <Transition appear show={showProcessingModal} as={Fragment}>
          <Dialog 
            as="div" 
            className="fixed inset-0 z-50 overflow-y-auto" 
            onClose={() => {
              setShowProcessingModal(false);
              fetchOrders();
            }}
          >
            <div className="min-h-screen px-4 text-center">
              <Transition.Child
                as={Fragment}
                enter="ease-out duration-300"
                enterFrom="opacity-0"
                enterTo="opacity-100"
                leave="ease-in duration-200"
                leaveFrom="opacity-100"
                leaveTo="opacity-0"
              >
                <Dialog.Overlay className="fixed inset-0 bg-black bg-opacity-50" />
              </Transition.Child>

              <span
                className="inline-block h-screen align-middle"
                aria-hidden="true"
              >
                &#8203;
              </span>
              
              <Transition.Child
                as={Fragment}
                enter="ease-out duration-300"
                enterFrom="opacity-0 scale-95"
                enterTo="opacity-100 scale-100"
                leave="ease-in duration-200"
                leaveFrom="opacity-100 scale-100"
                leaveTo="opacity-0 scale-95"
              >
                <div className="inline-block w-full max-w-3xl my-8 text-right align-middle transition-all transform">
                  <OrderProcessing 
                    order={selectedOrder} 
                    onClose={() => {
                      setShowProcessingModal(false);
                      fetchOrders();
                    }}
                    isModal={true}
                  />
                </div>
              </Transition.Child>
            </div>
          </Dialog>
        </Transition>
      )}
    </div>
  );
}