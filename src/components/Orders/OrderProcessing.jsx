import React, { useState, useEffect, useCallback } from 'react';
import { toast } from 'react-toastify';
import { supabase } from '../../lib/supabase';
import { useAuthStore } from '../../store/authStore';
import { getOrderStatusHistory } from '../../lib/ordersApi';
import CustomerRatingForm from '../Rating/CustomerRatingForm';

export default function OrderProcessing({ order, onClose, onStatusUpdate }) {
  const { user } = useAuthStore();
  const [drivers, setDrivers] = useState([]);
  const [selectedDriver, setSelectedDriver] = useState(null);
  const [preparationTime, setPreparationTime] = useState('15');
  const [orderStatus, setOrderStatus] = useState(order.status);
  const [statusHistory, setStatusHistory] = useState([]);
  const [assignmentType, setAssignmentType] = useState('specific');
  const [showCustomerRating, setShowCustomerRating] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadingHistory, setLoadingHistory] = useState(true);
  const [addingToWaitingList, setAddingToWaitingList] = useState(false);
  const [statusNote, setStatusNote] = useState('');
  const [selectedStatus, setSelectedStatus] = useState(order.status);
  const [waitingListError, setWaitingListError] = useState(null);

  const statusOptions = [
    { value: 'pending', label: 'معلق' },
    { value: 'accepted', label: 'مقبول' },
    { value: 'processing', label: 'قيد التحضير' },
    { value: 'waiting-for-driver', label: 'في قائمة الانتظار' },
    { value: 'delivering', label: 'مع السائق' },
    { value: 'completed', label: 'مكتمل' },
    { value: 'cancelled', label: 'ملغي' }
  ];

  useEffect(() => {
    loadDrivers();
    loadStatusHistory();
  }, [user]);

  const loadDrivers = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('drivers')
        .select('id, name, status, rating, phone')
        .order('name');

      if (error) throw error;

      setDrivers(data || []);
    } catch (error) {
      console.error('Error loading drivers:', error);
      toast.error('حدث خطأ أثناء تحميل قائمة السائقين');
    } finally {
      setLoading(false);
    }
  };

  const loadStatusHistory = async () => {
    try {
      setLoadingHistory(true);
      const history = await getOrderStatusHistory(order.id);
      
      if (history && history.length > 0) {
        setStatusHistory(history.map(record => ({
          id: record.id,
          status: record.status,
          note: record.note || getDefaultStatusNote(record.status),
          created_at: record.created_at
        })));
      } else {
        setStatusHistory([
          { 
            id: 'initial', 
            status: order.status, 
            note: 'تم إنشاء الطلب', 
            created_at: order.created_at 
          }
        ]);
      }
    } catch (error) {
      console.error('Error loading status history:', error);
      setStatusHistory([
        { 
          id: 'initial', 
          status: order.status, 
          note: 'تم إنشاء الطلب', 
          created_at: order.created_at 
        }
      ]);
    } finally {
      setLoadingHistory(false);
    }
  };

  const addToWaitingList = async () => {

    try {
      setAddingToWaitingList(true);
      setWaitingListError(null);

      const { data: vendorData, error: vendorError } = await supabase
        .from('vendors')
        .select('id')
        .eq('store_name', order.vendor?.store_name)
        .single();

      if (vendorError) {
        console.error('Error fetching vendor:', vendorError);
        setWaitingListError('فشل في العثور على البائع');
        throw vendorError;
      }

      const { error } = await supabase
        .from('driver_waiting_list')
        .insert([{
          order_id: order.id,
          vendor_id: vendorData.id,
          status: 'pending'
        }]);

      if (error) {
        console.error('Error adding to waiting list:', error);
        setWaitingListError('فشل في إضافة الطلب لقائمة الانتظار');
        throw error;
      }

      await handleUpdateStatus('waiting-for-driver', 'تم إضافة الطلب لقائمة انتظار السائقين');
      toast.success('تم إضافة الطلب لقائمة انتظار السائقين');
    } catch (error) {
      console.error('Error adding to waiting list:', error);
      toast.error('حدث خطأ أثناء إضافة الطلب لقائمة الانتظار');
      setWaitingListError('حدث خطأ أثناء إضافة الطلب لقائمة الانتظار');
    } finally {
      setAddingToWaitingList(false);
    }
  };

  const handleAssignDriver = async () => {

    if (assignmentType === 'waiting-list') {
      await addToWaitingList();
      return;
    }

    if (!selectedDriver) {
      toast.error('الرجاء اختيار سائق');
      return;
    }
    
    try {
      const { error } = await supabase
        .from('orders')
        .update({ 
          driver_id: selectedDriver.id,
          status: 'delivering'
        })
        .eq('id', order.id);
      
      if (error) throw error;
      
      const { error: historyError } = await supabase
        .from('order_status_history')
        .insert([{
          order_id: order.id,
          status: 'delivering',
          note: `تم تعيين السائق ${selectedDriver.name}`,
          created_by: user.id
        }]);
      
      if (historyError) {
        console.error('Error adding status history:', historyError);
      }
      
      setOrderStatus('delivering');
      if (typeof onStatusUpdate === 'function') {
        onStatusUpdate(order.id, 'delivering');
      }
      await loadStatusHistory();
      
      toast.success(`تم تعيين السائق ${selectedDriver.name} للطلب`);
    } catch (error) {
      console.error('Error assigning driver:', error);
      toast.error('فشل في تعيين السائق');
    }
  };

  const getDefaultStatusNote = (status) => {
    switch (status) {
      case 'processing': return 'تم بدء تحضير الطلب';
      case 'delivering': return 'تم تحويل الطلب للتوصيل';
      case 'waiting-for-driver': return 'تم إضافة الطلب لقائمة انتظار السائقين';
      case 'completed': return 'تم إكمال الطلب';
      default: return `تم تغيير الحالة إلى ${getStatusText(status)}`;
    }
  };

  const handleUpdateStatus = async (newStatus, note = '') => {

    try {
      const { error: historyError } = await supabase
        .from('order_status_history')
        .insert([{
          order_id: order.id,
          status: newStatus,
          note: note || statusNote || getDefaultStatusNote(newStatus),
          created_by: user.id
        }]);

      if (historyError) throw historyError;
      
      const { error } = await supabase
        .from('orders')
        .update({ status: newStatus })
        .eq('id', order.id);
        
      if (error) throw error;

      setOrderStatus(newStatus);
      if (typeof onStatusUpdate === 'function') {
        onStatusUpdate(order.id, newStatus);
      }
      await loadStatusHistory();
      setStatusNote('');
      toast.success('تم تحديث حالة الطلب');
      
      if (newStatus === 'completed') {
        setShowCustomerRating(true);
      }
    } catch (error) {
      console.error('Error updating status:', error);
      toast.error('حدث خطأ أثناء تحديث الحالة');
    }
  };

  const getStatusText = (status) => {
    const option = statusOptions.find(opt => opt.value === status);
    return option ? option.label : status;
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'pending': return 'bg-yellow-100 text-yellow-800';
      case 'accepted': return 'bg-blue-100 text-blue-800';
      case 'rejected': return 'bg-red-100 text-red-800';
      case 'processing': return 'bg-yellow-100 text-yellow-800';
      case 'waiting-for-driver': return 'bg-orange-100 text-orange-800';
      case 'delivering': return 'bg-purple-100 text-purple-800';
      case 'completed': return 'bg-green-100 text-green-800';
      case 'cancelled': return 'bg-red-100 text-red-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const handleAcceptOrder = () => {
    handleUpdateStatus('accepted', 'تم قبول الطلب');
    toast.success('تم قبول الطلب بنجاح');
  };

  const handleRejectOrder = () => {
    handleUpdateStatus('rejected', 'تم رفض الطلب');
    toast.error('تم رفض الطلب');
  };

  const handleCustomerRatingComplete = () => {
    toast.success('تم تقييم الزبون بنجاح');
    setShowCustomerRating(false);
  };


  return (
    <div className="bg-white rounded-lg p-6">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-xl font-semibold">إجراءات الطلب #{order.id.substring(0, 8)}</h2>
        <button
          onClick={onClose}
          className="text-gray-500 hover:text-gray-700"
        >
          ✕
        </button>
      </div>

      {showCustomerRating ? (
        <CustomerRatingForm 
          orderId={order.id}
          driverId={selectedDriver?.id || order.driver_id}
          customerId={order.customer_id}
          onComplete={handleCustomerRatingComplete}
        />
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
            <div className="border rounded-lg p-4">
              <h3 className="font-semibold mb-3">معلومات الطلب</h3>
              <div className="space-y-2">
                <p>المتجر: {order.vendor?.store_name || 'غير محدد'}</p>
                <p>الزبون: {order.customer?.name || 'غير محدد'}</p>
                <p>المبلغ: ₪{parseFloat(order.total).toFixed(2)}</p>
                <div className="mt-4">
                  <h4 className="font-medium mb-2">المنتجات:</h4>
                  <ul className="list-disc list-inside">
                    {order.items?.map((item, index) => (
                      <li key={index}>
                        {item.product?.name || 'منتج'} × {item.quantity} (₪{parseFloat(item.price).toFixed(2)})
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            </div>

            <div className="border rounded-lg p-4">
              <h3 className="font-semibold mb-3">تعيين سائق</h3>
              <div className="space-y-4">
                <div className="flex space-x-4 mb-4">
                  <label className="flex items-center">
                    <input
                      type="radio"
                      value="specific"
                      checked={assignmentType === 'specific'}
                      onChange={(e) => setAssignmentType(e.target.value)}
                      className="ml-2"
                    />
                    تعيين سائق محدد
                  </label>
                  <label className="flex items-center">
                    <input
                      type="radio"
                      value="waiting-list"
                      checked={assignmentType === 'waiting-list'}
                      onChange={(e) => setAssignmentType(e.target.value)}
                      className="ml-2"
                    />
                    إضافة لقائمة الانتظار
                  </label>
                </div>

                {assignmentType === 'specific' && (
                  <select
                    className="w-full border rounded-md p-2"
                    value={selectedDriver?.id || ''}
                    onChange={(e) => {
                      const driver = drivers.find(d => d.id === e.target.value);
                      setSelectedDriver(driver || null);
                    }}
                  >
                    <option value="">اختر سائق</option>
                    {loading ? (
                      <option disabled>جاري تحميل السائقين...</option>
                    ) : (
                      drivers.map(driver => (
                        <option 
                          key={driver.id} 
                          value={driver.id}
                          disabled={driver.status === 'busy'}
                        >
                          {driver.name} ({driver.rating} ★) - {driver.status === 'available' ? 'متاح' : 'مشغول'}
                        </option>
                      ))
                    )}
                  </select>
                )}

                <button
                  onClick={handleAssignDriver}
                  disabled={addingToWaitingList || ((assignmentType === 'specific' && !selectedDriver) || orderStatus === 'delivering')}
                  className={`w-full text-white py-2 rounded-md transition-colors ${
                    addingToWaitingList || ((assignmentType === 'specific' && !selectedDriver) || orderStatus === 'delivering')
                      ? 'bg-gray-400 cursor-not-allowed'
                      : 'bg-blue-600 hover:bg-blue-700'
                  }`}
                >
                  {addingToWaitingList 
                    ? 'جاري الإضافة...'
                    : orderStatus === 'delivering'
                      ? 'تم تعيين السائق'
                      : assignmentType === 'waiting-list'
                        ? 'إضافة للقائمة'
                        : 'تعيين السائق'}
                </button>
                {waitingListError && (
                  <p className="mt-2 text-sm text-red-600">{waitingListError}</p>
                )}
              </div>
            </div>
          </div>

          {order.status === 'pending' && (
            <div className="border rounded-lg p-4 mb-6">
              <h3 className="font-semibold mb-4">قبول/رفض الطلب</h3>
              <div className="flex gap-4">
                <button
                  onClick={handleAcceptOrder}
                  className="flex-1 bg-green-600 text-white py-2 px-4 rounded-md hover:bg-green-700 transition-colors"
                >
                  قبول الطلب
                </button>
                <button
                  onClick={handleRejectOrder}
                  className="flex-1 bg-red-600 text-white py-2 px-4 rounded-md hover:bg-red-700 transition-colors"
                >
                  رفض الطلب
                </button>
              </div>
            </div>
          )}

          <div className="border rounded-lg p-4 mb-6">
            <h3 className="font-semibold mb-3">وقت التحضير</h3>
            <div className="flex items-center space-x-4">
              <input
                type="number"
                min="5"
                max="120"
                value={preparationTime}
                onChange={(e) => setPreparationTime(e.target.value)}
                className="border rounded-md p-2 w-24"
              />
              <span>دقيقة</span>
            </div>
          </div>

          <div className="border rounded-lg p-4 mb-6">
            <h3 className="font-semibold mb-3">تحديث الحالة</h3>
            <div className="space-y-4">
              <div>
                <select
                  value={selectedStatus}
                  onChange={(e) => setSelectedStatus(e.target.value)}
                  className="w-full border rounded-md p-2"
                >
                  {statusOptions.map(option => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <input
                  type="text"
                  value={statusNote}
                  onChange={(e) => setStatusNote(e.target.value)}
                  placeholder="ملاحظات (اختياري)"
                  className="w-full border rounded-md p-2"
                />
              </div>
              <button
                onClick={() => handleUpdateStatus(selectedStatus)}
                className="w-full bg-blue-500 text-white py-2 rounded-md hover:bg-blue-600 transition-colors"
              >
                تحديث الحالة
              </button>
            </div>
          </div>

          <div className="border rounded-lg p-4">
            <h3 className="font-semibold mb-3">سجل الحالات</h3>
            {loadingHistory ? (
              <div className="flex justify-center py-4">
                <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
              </div>
            ) : (
              <div className="space-y-3">
                {statusHistory.map((record) => (
                  <div key={record.id} className="flex items-center space-x-4 border-b pb-2">
                    <div className={`px-3 py-1 rounded-full ${getStatusColor(record.status)}`}>
                      {getStatusText(record.status)}
                    </div>
                    <div className="text-gray-600">
                      {record.note}
                    </div>
                    <div className="text-gray-500 text-sm">
                      {new Date(record.created_at).toLocaleTimeString('ar-SA')}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}