import { supabase } from './supabase';

/**
 * الحصول على قائمة عملاء الجملة
 * @returns {Promise<Array>} - قائمة عملاء الجملة
 */
export const getWholesaleCustomers = async () => {
  try {
    const { data, error } = await supabase
      .from('customer_wholesale_tiers')
      .select(`
        customer_id,
        tier_id,
        status,
        approved_at,
        created_at,
        customer:customer_id(*),
        tier:tier_id(*)
      `);
    
    if (error) throw error;
    
    // تحويل البيانات إلى الشكل المطلوب
    const customers = data.map(item => ({
      id: item.customer_id,
      company_name: item.customer?.wholesale_info?.company_name || 'شركة بدون اسم',
      tier_id: item.tier_id,
      tax_number: item.customer?.wholesale_info?.tax_number || '',
      contact_name: item.customer?.name,
      contact_phone: item.customer?.phone,
      contact_email: item.customer?.email || '',
      total_purchases: item.customer?.wholesale_info?.total_purchases || 0,
      status: item.status,
      approval_date: item.approved_at,
      last_purchase_date: item.customer?.wholesale_info?.last_purchase_date,
      tier: item.tier
    }));
    
    return customers;
  } catch (error) {
    console.error('Error fetching wholesale customers:', error);
    throw error;
  }
};

/**
 * الحصول على عميل جملة محدد
 * @param {string} id - معرف العميل
 * @returns {Promise<Object>} - بيانات عميل الجملة
 */
export const getWholesaleCustomer = async (id) => {
  try {
    const { data, error } = await supabase
      .from('customer_wholesale_tiers')
      .select(`
        customer_id,
        tier_id,
        status,
        approved_at,
        created_at,
        customer:customer_id(*),
        tier:tier_id(*)
      `)
      .eq('customer_id', id)
      .single();
    
    if (error) throw error;
    
    return {
      id: data.customer_id,
      company_name: data.customer?.wholesale_info?.company_name || 'شركة بدون اسم',
      tier_id: data.tier_id,
      tax_number: data.customer?.wholesale_info?.tax_number || '',
      contact_name: data.customer?.name,
      contact_phone: data.customer?.phone,
      contact_email: data.customer?.email || '',
      total_purchases: data.customer?.wholesale_info?.total_purchases || 0,
      status: data.status,
      approval_date: data.approved_at,
      last_purchase_date: data.customer?.wholesale_info?.last_purchase_date,
      billing_address: data.customer?.wholesale_info?.billing_address || data.customer?.address || '',
      shipping_address: data.customer?.wholesale_info?.shipping_address || data.customer?.address || '',
      notes: data.customer?.wholesale_info?.notes || data.customer?.notes || '',
      tier: data.tier
    };
  } catch (error) {
    console.error('Error fetching wholesale customer:', error);
    throw error;
  }
};

/**
 * تحويل عميل عادي إلى عميل جملة
 * @param {string} customerId - معرف العميل
 * @param {Object} wholesaleData - بيانات الجملة
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const convertToWholesaleCustomer = async (customerId, wholesaleData) => {
  try {
    // تحديث بيانات العميل
    const { error: customerError } = await supabase
      .from('customers')
      .update({
        wholesale_info: {
          company_name: wholesaleData.company_name,
          tax_number: wholesaleData.tax_number,
          billing_address: wholesaleData.billing_address,
          shipping_address: wholesaleData.shipping_address,
          notes: wholesaleData.notes
        }
      })
      .eq('id', customerId);
    
    if (customerError) throw customerError;
    
    // ربط العميل بمستوى الجملة
    const { error: tierError } = await supabase.rpc(
      'convert_to_wholesale_customer',
      {
        p_customer_id: customerId,
        p_tier_id: wholesaleData.tier_id,
        p_status: wholesaleData.status || 'pending'
      }
    );
    
    if (tierError) throw tierError;
    
    return true;
  } catch (error) {
    console.error('Error converting to wholesale customer:', error);
    throw error;
  }
};

/**
 * تحديث حالة عميل الجملة
 * @param {string} customerId - معرف العميل
 * @param {string} status - الحالة الجديدة (pending, approved, rejected)
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const updateWholesaleCustomerStatus = async (customerId, status) => {
  try {
    const { error } = await supabase.rpc(
      'update_wholesale_customer_status',
      {
        p_customer_id: customerId,
        p_status: status
      }
    );
    
    if (error) throw error;
    return true;
  } catch (error) {
    console.error('Error updating wholesale customer status:', error);
    throw error;
  }
};

/**
 * تحديث بيانات عميل الجملة
 * @param {string} customerId - معرف العميل
 * @param {Object} wholesaleData - بيانات الجملة المحدثة
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const updateWholesaleCustomer = async (customerId, wholesaleData) => {
  try {
    // تحديث بيانات العميل
    const { error: customerError } = await supabase
      .from('customers')
      .update({
        name: wholesaleData.contact_name,
        phone: wholesaleData.contact_phone,
        email: wholesaleData.contact_email,
        wholesale_info: {
          company_name: wholesaleData.company_name,
          tax_number: wholesaleData.tax_number,
          billing_address: wholesaleData.billing_address,
          shipping_address: wholesaleData.shipping_address,
          notes: wholesaleData.notes
        }
      })
      .eq('id', customerId);
    
    if (customerError) throw customerError;
    
    // تحديث مستوى العميل
    if (wholesaleData.tier_id) {
      const { error: tierError } = await supabase.rpc(
        'convert_to_wholesale_customer',
        {
          p_customer_id: customerId,
          p_tier_id: wholesaleData.tier_id,
          p_status: wholesaleData.status || 'pending'
        }
      );
      
      if (tierError) throw tierError;
    }
    
    return true;
  } catch (error) {
    console.error('Error updating wholesale customer:', error);
    throw error;
  }
};

/**
 * إلغاء حالة عميل الجملة
 * @param {string} customerId - معرف العميل
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const removeWholesaleStatus = async (customerId) => {
  try {
    // حذف العلاقة بين العميل ومستوى الجملة
    const { error: relationError } = await supabase
      .from('customer_wholesale_tiers')
      .delete()
      .eq('customer_id', customerId);
    
    if (relationError) throw relationError;
    
    // إزالة معلومات الجملة من العميل
    const { error: customerError } = await supabase
      .from('customers')
      .update({
        wholesale_info: null
      })
      .eq('id', customerId);
    
    if (customerError) throw customerError;
    
    return true;
  } catch (error) {
    console.error('Error removing wholesale status:', error);
    throw error;
  }
};

/**
 * الحصول على مستويات الجملة
 * @returns {Promise<Array>} - قائمة مستويات الجملة
 */
export const getWholesaleTiers = async () => {
  try {
    const { data, error } = await supabase
      .from('wholesale_tiers')
      .select('*')
      .order('min_purchase_amount', { ascending: true });
    
    if (error) throw error;
    return data || [];
  } catch (error) {
    console.error('Error fetching wholesale tiers:', error);
    throw error;
  }
};

/**
 * حساب سعر الجملة للمنتج
 * @param {string} productId - معرف المنتج
 * @param {string} customerId - معرف العميل
 * @param {number} quantity - الكمية
 * @returns {Promise<number>} - سعر الجملة
 */
export const calculateWholesalePrice = async (productId, customerId, quantity = 1) => {
  try {
    const { data, error } = await supabase.rpc(
      'calculate_wholesale_price',
      {
        p_product_id: productId,
        p_customer_id: customerId,
        p_quantity: quantity
      }
    );
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error calculating wholesale price:', error);
    throw error;
  }
};

/**
 * التحقق من أهلية الطلب للحصول على أسعار الجملة
 * @param {string} customerId - معرف العميل
 * @param {number} orderTotal - إجمالي الطلب
 * @returns {Promise<boolean>} - أهلية الطلب
 */
export const isEligibleForWholesalePricing = async (customerId, orderTotal) => {
  try {
    const { data, error } = await supabase.rpc(
      'is_eligible_for_wholesale_pricing',
      {
        p_customer_id: customerId,
        p_order_total: orderTotal
      }
    );
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error checking wholesale eligibility:', error);
    throw error;
  }
};

export default {
  getWholesaleCustomers,
  getWholesaleCustomer,
  convertToWholesaleCustomer,
  updateWholesaleCustomerStatus,
  updateWholesaleCustomer,
  removeWholesaleStatus,
  getWholesaleTiers,
  calculateWholesalePrice,
  isEligibleForWholesalePricing
};