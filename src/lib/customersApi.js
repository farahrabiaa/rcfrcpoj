import { supabase } from './supabase';

/**
 * الحصول على قائمة الزبائن
 * @param {Object} options - خيارات الفلترة
 * @returns {Promise<Array>} - قائمة الزبائن
 */
export const getCustomers = async (options = {}) => {
  try {
    // استخدام وظيفة RPC للحصول على جميع الزبائن
    const { data, error } = await supabase.rpc('get_all_customers');
    
    if (error) throw error;
    
    return data || [];
  } catch (error) {
    console.error('Error fetching customers:', error);
    throw error;
  }
};

/**
 * الحصول على زبون محدد
 * @param {string} id - معرف الزبون
 * @returns {Promise<Object>} - بيانات الزبون
 */
export const getCustomer = async (id) => {
  try {
    const { data, error } = await supabase
      .from('customers')
      .select('*')
      .eq('id', id)
      .single();
    
    if (error) throw error;
    
    return data;
  } catch (error) {
    console.error('Error fetching customer:', error);
    throw error;
  }
};

/**
 * إنشاء زبون جديد
 * @param {Object} customerData - بيانات الزبون
 * @returns {Promise<Object>} - بيانات الزبون المنشأ
 */
export const createCustomer = async (customerData) => {
  try {
    const { data, error } = await supabase
      .from('customers')
      .insert([customerData])
      .select();
    
    if (error) throw error;
    
    return data[0];
  } catch (error) {
    console.error('Error creating customer:', error);
    throw error;
  }
};

/**
 * تحديث زبون
 * @param {string} id - معرف الزبون
 * @param {Object} customerData - بيانات الزبون المحدثة
 * @returns {Promise<Object>} - بيانات الزبون المحدثة
 */
export const updateCustomer = async (id, customerData) => {
  try {
    const { data, error } = await supabase
      .from('customers')
      .update(customerData)
      .eq('id', id)
      .select();
    
    if (error) throw error;
    
    return data[0];
  } catch (error) {
    console.error('Error updating customer:', error);
    throw error;
  }
};

/**
 * حذف زبون
 * @param {string} id - معرف الزبون
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const deleteCustomer = async (id) => {
  try {
    const { error } = await supabase
      .from('customers')
      .delete()
      .eq('id', id);
    
    if (error) throw error;
    
    return true;
  } catch (error) {
    console.error('Error deleting customer:', error);
    throw error;
  }
};

/**
 * تحديث حالة الزبون
 * @param {string} id - معرف الزبون
 * @param {string} status - الحالة الجديدة
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const updateCustomerStatus = async (id, status) => {
  try {
    const { error } = await supabase
      .from('customers')
      .update({ status })
      .eq('id', id);
    
    if (error) throw error;
    
    return true;
  } catch (error) {
    console.error('Error updating customer status:', error);
    throw error;
  }
};

export default {
  getCustomers,
  getCustomer,
  createCustomer,
  updateCustomer,
  deleteCustomer,
  updateCustomerStatus
};