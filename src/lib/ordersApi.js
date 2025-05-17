import { supabase } from './supabase';

/**
 * الحصول على قائمة الطلبات
 * @param {Object} options - خيارات الفلترة
 * @returns {Promise<Array>} - قائمة الطلبات
 */
export const getOrders = async (options = {}) => {
  try {
    let query = supabase
      .from('orders')
      .select(`
        *,
        customer:customer_id(*),
        vendor:vendor_id(*),
        driver:driver_id(*)
      `);
    
    // تطبيق الفلاتر
    if (options.status) {
      query = query.eq('status', options.status);
    }
    
    if (options.vendorId) {
      query = query.eq('vendor_id', options.vendorId);
    }
    
    if (options.driverId) {
      query = query.eq('driver_id', options.driverId);
    }
    
    if (options.customerId) {
      query = query.eq('customer_id', options.customerId);
    }
    
    if (options.startDate && options.endDate) {
      query = query.gte('created_at', options.startDate).lte('created_at', options.endDate);
    }
    
    // ترتيب النتائج
    query = query.order('created_at', { ascending: false });
    
    const { data, error } = await query;
    
    if (error) throw error;
    
    // جلب عناصر الطلب لكل طلب
    const ordersWithItems = await Promise.all(
      data.map(async (order) => {
        const { data: itemsData, error: itemsError } = await supabase
          .from('order_items')
          .select(`
            *,
            product:product_id(*)
          `)
          .eq('order_id', order.id);
        
        if (itemsError) {
          console.error('Error fetching order items:', itemsError);
          return { ...order, items: [] };
        }
        
        return { ...order, items: itemsData || [] };
      })
    );
    
    return ordersWithItems;
  } catch (error) {
    console.error('Error fetching orders:', error);
    throw error;
  }
};

/**
 * الحصول على طلب محدد
 * @param {string} orderId - معرف الطلب
 * @returns {Promise<Object>} - بيانات الطلب
 */
export const getOrder = async (orderId) => {
  try {
    const { data, error } = await supabase
      .from('orders')
      .select(`
        *,
        customer:customer_id(*),
        vendor:vendor_id(*),
        driver:driver_id(*)
      `)
      .eq('id', orderId)
      .single();
    
    if (error) throw error;
    
    // جلب عناصر الطلب
    const { data: itemsData, error: itemsError } = await supabase
      .from('order_items')
      .select(`
        *,
        product:product_id(*)
      `)
      .eq('order_id', orderId);
    
    if (itemsError) throw itemsError;
    
    return { ...data, items: itemsData || [] };
  } catch (error) {
    console.error('Error fetching order:', error);
    throw error;
  }
};

/**
 * تحديث حالة الطلب
 * @param {string} orderId - معرف الطلب
 * @param {string} status - الحالة الجديدة
 * @param {string} note - ملاحظة حول التغيير
 * @returns {Promise<Object>} - الطلب المحدث
 */
export const updateOrderStatus = async (orderId, status, note = '') => {
  try {
    // Use the simplified function
    const { data, error } = await supabase.rpc(
      'update_order_status_simple',
      { 
        p_order_id: orderId,
        p_status: status,
        p_note: note
      }
    );
    
    if (error) throw error;
    
    if (!data) {
      throw new Error('فشل في تحديث حالة الطلب');
    }

    // Get updated order
    const { data: orderData, error: orderError } = await supabase
      .from('orders')
      .select('*')
      .eq('id', orderId)
      .single();
    
    if (orderError) throw orderError;
    
    return orderData;
  } catch (error) {
    console.error('Error updating order status:', error);
    throw error;
  }
};

/**
 * تعيين سائق للطلب
 * @param {string} orderId - معرف الطلب
 * @param {string} driverId - معرف السائق
 * @returns {Promise<Object>} - الطلب المحدث
 */
export const assignDriverToOrder = async (orderId, driverId) => {
  try {
    const { data, error } = await supabase
      .from('orders')
      .update({ 
        driver_id: driverId,
        status: 'delivering'
      })
      .eq('id', orderId)
      .select();
    
    if (error) throw error;
    
    return data[0];
  } catch (error) {
    console.error('Error assigning driver:', error);
    throw error;
  }
};

/**
 * إضافة الطلب لقائمة انتظار السائقين
 * @param {string} orderId - معرف الطلب
 * @param {string} vendorId - معرف البائع
 * @returns {Promise<Object>} - بيانات قائمة الانتظار
 */
export const addOrderToWaitingList = async (orderId, vendorId) => {
  try {
    const { data, error } = await supabase
      .from('driver_waiting_list')
      .insert([{
        order_id: orderId,
        vendor_id: vendorId,
        status: 'pending'
      }])
      .select();
    
    if (error) throw error;
    
    // تحديث حالة الطلب
    await updateOrderStatus(orderId, 'waiting-for-driver');
    
    return data[0];
  } catch (error) {
    console.error('Error adding order to waiting list:', error);
    throw error;
  }
};

/**
 * الحصول على سجل حالات الطلب
 * @param {string} orderId - معرف الطلب
 * @returns {Promise<Array>} - سجل الحالات
 */
export const getOrderStatusHistory = async (orderId) => {
  try {
    // Try to use the new function first
    const { data, error } = await supabase.rpc(
      'get_order_status_history_with_users',
      { p_order_id: orderId }
    );
    
    if (error) {
      console.error('Error using RPC function:', error);
      
      // Fallback to direct query
      const { data: fallbackData, error: fallbackError } = await supabase
        .from('order_status_history')
        .select(`
          *,
          user:created_by(*)
        `)
        .eq('order_id', orderId)
        .order('created_at', { ascending: true });
      
      if (fallbackError) throw fallbackError;
      return fallbackData || [];
    }
    
    return data;
  } catch (error) {
    console.error('Error fetching order status history:', error);
    throw error;
  }
};

/**
 * الحصول على إحصائيات الطلبات
 * @returns {Promise<Object>} - إحصائيات الطلبات
 */
export const getOrdersStats = async () => {
  try {
    // إجمالي الطلبات
    const { count: totalOrders, error: totalError } = await supabase
      .from('orders')
      .select('*', { count: 'exact', head: true });
    
    if (totalError) throw totalError;
    
    // الطلبات حسب الحالة
    const statuses = ['pending', 'accepted', 'processing', 'ready', 'delivering', 'completed', 'rejected', 'cancelled'];
    const statusCounts = {};
    
    for (const status of statuses) {
      const { count, error } = await supabase
        .from('orders')
        .select('*', { count: 'exact', head: true })
        .eq('status', status);
      
      if (error) throw error;
      statusCounts[status] = count;
    }
    
    // الطلبات حسب طريقة الدفع
    const paymentMethods = ['cash', 'electronic', 'wallet'];
    const paymentCounts = {};
    
    for (const method of paymentMethods) {
      const { count, error } = await supabase
        .from('orders')
        .select('*', { count: 'exact', head: true })
        .eq('payment_method', method);
      
      if (error) throw error;
      paymentCounts[method] = count;
    }
    
    // إجمالي المبيعات
    const { data: salesData, error: salesError } = await supabase
      .from('orders')
      .select('total');
    
    if (salesError) throw salesError;
    
    const totalSales = salesData.reduce((sum, order) => sum + parseFloat(order.total), 0);
    
    return {
      totalOrders,
      statusCounts,
      paymentCounts,
      totalSales
    };
  } catch (error) {
    console.error('Error fetching orders stats:', error);
    throw error;
  }
};

export default {
  getOrders,
  getOrder,
  updateOrderStatus,
  assignDriverToOrder,
  addOrderToWaitingList,
  getOrderStatusHistory,
  getOrdersStats
};