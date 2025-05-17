import { supabase } from './supabase';

/**
 * الحصول على طرق الدفع المتاحة
 * @returns {Promise<Array>} - قائمة طرق الدفع
 */
export const getPaymentMethods = async () => {
  try {
    const { data, error } = await supabase
      .from('payment_methods')
      .select('*')
      .eq('status', 'active')
      .order('id');
    
    if (error) throw error;
    return data || [];
  } catch (error) {
    console.error('Error fetching payment methods:', error);
    throw error;
  }
};

/**
 * الحصول على رصيد المحفظة لمستخدم معين
 * @param {string} userId - معرف المستخدم
 * @returns {Promise<Object>} - بيانات الرصيد
 */
export const getWalletBalance = async (userId) => {
  try {
    const { data, error } = await supabase.rpc('get_wallet_balance', { p_user_id: userId });
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error fetching wallet balance:', error);
    throw error;
  }
};

/**
 * الحصول على معاملات المحفظة
 * @param {string} walletId - معرف المحفظة
 * @param {Object} options - خيارات الفلترة
 * @returns {Promise<Array>} - قائمة المعاملات
 */
export const getWalletTransactions = async (walletId, options = {}) => {
  try {
    const { data, error } = await supabase.rpc(
      'get_wallet_transactions',
      {
        p_wallet_id: walletId,
        p_limit: options.limit || 10,
        p_offset: options.offset || 0,
        p_type: options.type || null,
        p_status: options.status || null
      }
    );
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error fetching wallet transactions:', error);
    throw error;
  }
};

/**
 * الحصول على محافظ البائعين
 * @returns {Promise<Array>} - قائمة محافظ البائعين
 */
export const getVendorWallets = async () => {
  try {
    // Direct query instead of RPC
    const { data, error } = await supabase
      .from('vendor_wallets')
      .select(`
        *,
        vendor:vendor_id (
          id,
          store_name,
          status,
          user_id
        )
      `);
    
    if (error) throw error;
    return data || [];
  } catch (error) {
    console.error('Error fetching vendor wallets:', error);
    throw error;
  }
};

/**
 * الحصول على محافظ السائقين
 * @returns {Promise<Array>} - قائمة محافظ السائقين
 */
export const getDriverWallets = async () => {
  try {
    const { data, error } = await supabase
      .from('driver_wallets')
      .select(`
        *,
        driver:driver_id (
          id,
          name,
          status,
          user_id
        )
      `);
    
    if (error) throw error;
    return data || [];
  } catch (error) {
    console.error('Error fetching driver wallets:', error);
    throw error;
  }
};

/**
 * شحن رصيد محفظة بائع
 * @param {string} vendorId - معرف البائع
 * @param {number} amount - المبلغ المراد شحنه
 * @param {string} description - وصف المعاملة
 * @returns {Promise<Object>} - بيانات المعاملة
 */
export const chargeVendorWallet = async (vendorId, amount, description = 'شحن رصيد') => {
  try {
    const { data, error } = await supabase.rpc(
      'charge_vendor_wallet',
      {
        p_vendor_id: vendorId,
        p_amount: amount,
        p_description: description
      }
    );
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error charging vendor wallet:', error);
    throw error;
  }
};

/**
 * شحن رصيد محفظة بائع مباشرة
 * @param {string} vendorId - معرف البائع
 * @param {number} amount - المبلغ المراد شحنه
 * @param {string} description - وصف المعاملة
 * @returns {Promise<Object>} - بيانات المعاملة
 */
export const chargeVendorWalletDirect = async (vendorId, amount, description = 'شحن رصيد مباشر') => {
  try {
    const { data, error } = await supabase.rpc(
      'charge_vendor_wallet_direct',
      {
        p_vendor_id: vendorId,
        p_amount: amount,
        p_description: description
      }
    );
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error charging vendor wallet directly:', error);
    throw error;
  }
};

/**
 * شحن رصيد محفظة سائق
 * @param {string} driverId - معرف السائق
 * @param {number} amount - المبلغ المراد شحنه
 * @param {string} description - وصف المعاملة
 * @returns {Promise<Object>} - بيانات المعاملة
 */
export const chargeDriverWallet = async (driverId, amount, description = 'شحن رصيد') => {
  try {
    const { data, error } = await supabase.rpc(
      'charge_driver_wallet',
      {
        p_driver_id: driverId,
        p_amount: amount,
        p_description: description
      }
    );
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error charging driver wallet:', error);
    throw error;
  }
};

/**
 * شحن رصيد محفظة سائق مباشرة
 * @param {string} driverId - معرف السائق
 * @param {number} amount - المبلغ المراد شحنه
 * @param {string} description - وصف المعاملة
 * @returns {Promise<Object>} - بيانات المعاملة
 */
export const chargeDriverWalletDirect = async (driverId, amount, description = 'شحن رصيد مباشر') => {
  try {
    const { data, error } = await supabase.rpc(
      'charge_driver_wallet_direct',
      {
        p_driver_id: driverId,
        p_amount: amount,
        p_description: description
      }
    );
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error charging driver wallet directly:', error);
    throw error;
  }
};

/**
 * الحصول على الإحصائيات المالية
 * @returns {Promise<Object>} - البيانات الإحصائية
 */
export const getFinancialStats = async () => {
  try {
    const { data, error } = await supabase.rpc('get_financial_summary');
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error fetching financial stats:', error);
    throw error;
  }
};

/**
 * الحصول على إعدادات الدفع
 * @returns {Promise<Object>} - إعدادات الدفع
 */
export const getPaymentSettings = async () => {
  try {
    const { data, error } = await supabase
      .from('app_settings')
      .select('settings')
      .single();
    
    if (error) throw error;
    
    // استخراج إعدادات الدفع
    const paymentSettings = data.settings.payment || {};
    return paymentSettings;
  } catch (error) {
    console.error('Error fetching payment settings:', error);
    throw error;
  }
};

/**
 * تحديث إعدادات الدفع
 * @param {Object} settings - الإعدادات الجديدة
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const updatePaymentSettings = async (settings) => {
  try {
    // أولاً، الحصول على الإعدادات الحالية
    const { data: currentData, error: fetchError } = await supabase
      .from('app_settings')
      .select('settings')
      .single();
    
    if (fetchError) throw fetchError;
    
    // تحديث قسم الدفع فقط
    const updatedSettings = {
      ...currentData.settings,
      payment: settings
    };
    
    // حفظ الإعدادات المحدثة
    const { error } = await supabase
      .from('app_settings')
      .update({ settings: updatedSettings })
      .eq('id', currentData.id);
    
    if (error) throw error;
    return true;
  } catch (error) {
    console.error('Error updating payment settings:', error);
    throw error;
  }
};

/**
 * الحصول على محفظة بائع محدد
 * @param {string} vendorId - معرف البائع
 * @returns {Promise<Object>} - بيانات محفظة البائع
 */
export const getVendorWallet = async (vendorId) => {
  try {
    const { data, error } = await supabase
      .from('vendor_wallets')
      .select(`
        *,
        vendor:vendor_id (
          id,
          store_name,
          status,
          user_id
        )
      `)
      .eq('vendor_id', vendorId)
      .single();
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error fetching vendor wallet:', error);
    throw error;
  }
};

/**
 * الحصول على محفظة سائق محدد
 * @param {string} driverId - معرف السائق
 * @returns {Promise<Object>} - بيانات محفظة السائق
 */
export const getDriverWallet = async (driverId) => {
  try {
    const { data, error } = await supabase
      .from('driver_wallets')
      .select(`
        *,
        driver:driver_id (
          id,
          name,
          status,
          user_id
        )
      `)
      .eq('driver_id', driverId)
      .single();
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error fetching driver wallet:', error);
    throw error;
  }
};

export default {
  getWalletBalance,
  getWalletTransactions,
  getVendorWallets,
  getDriverWallets,
  chargeVendorWallet,
  chargeVendorWalletDirect,
  chargeDriverWallet,
  chargeDriverWalletDirect,
  getFinancialStats,
  getPaymentSettings,
  updatePaymentSettings,
  getPaymentMethods,
  getVendorWallet,
  getDriverWallet
};