import { supabase } from './supabase';

/**
 * الحصول على إعدادات النقاط
 * @returns {Promise<Object>} - إعدادات النقاط
 */
export const getPointsSettings = async () => {
  try {
    const { data, error } = await supabase
      .from('app_settings')
      .select('settings')
      .single();
    
    if (error) throw error;
    
    return data.settings.points || {
      points_value: 0.10,
      min_points_redeem: 100,
      points_expiry_days: 365,
      points_per_currency: 1.00,
      min_order_points: 10.00
    };
  } catch (error) {
    console.error('Error fetching points settings:', error);
    return {
      points_value: 0.10,
      min_points_redeem: 100,
      points_expiry_days: 365,
      points_per_currency: 1.00,
      min_order_points: 10.00
    };
  }
};

/**
 * الحصول على رصيد نقاط العميل
 * @param {string} customerId - معرف العميل
 * @returns {Promise<Object>} - رصيد النقاط
 */
export const getCustomerPointsBalance = async (customerId) => {
  try {
    const { data, error } = await supabase.rpc(
      'get_customer_points_balance',
      { p_customer_id: customerId }
    );
    
    if (error) throw error;
    
    return data;
  } catch (error) {
    console.error('Error fetching customer points balance:', error);
    return {
      balance: 0,
      total_earned: 0,
      total_spent: 0,
      last_activity: null,
      has_account: false
    };
  }
};

/**
 * الحصول على معاملات نقاط العميل
 * @param {string} customerId - معرف العميل
 * @param {number} limit - عدد المعاملات المراد استرجاعها
 * @param {number} offset - عدد المعاملات التي يجب تخطيها
 * @returns {Promise<Array>} - قائمة المعاملات
 */
export const getCustomerPointsTransactions = async (customerId, limit = 10, offset = 0) => {
  try {
    const { data, error } = await supabase.rpc(
      'get_customer_points_transactions',
      { 
        p_customer_id: customerId,
        p_limit: limit,
        p_offset: offset
      }
    );
    
    if (error) throw error;
    
    return data || [];
  } catch (error) {
    console.error('Error fetching customer points transactions:', error);
    return [];
  }
};

/**
 * إضافة نقاط للعميل
 * @param {string} customerId - معرف العميل
 * @param {number} amount - عدد النقاط
 * @param {string} description - وصف المعاملة
 * @param {string} orderId - معرف الطلب (اختياري)
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const addPointsToCustomer = async (customerId, amount, description, orderId = null) => {
  try {
    const { data, error } = await supabase.rpc(
      'add_customer_points',
      {
        p_customer_id: customerId,
        p_amount: amount,
        p_type: 'earn',
        p_description: description,
        p_order_id: orderId
      }
    );
    
    if (error) throw error;
    
    return true;
  } catch (error) {
    console.error('Error adding points to customer:', error);
    throw error;
  }
};

/**
 * استبدال نقاط العميل بمكافأة
 * @param {string} customerId - معرف العميل
 * @param {string} rewardId - معرف المكافأة
 * @returns {Promise<Object>} - بيانات الاستبدال
 */
export const redeemPointsForReward = async (customerId, rewardId) => {
  try {
    const { data, error } = await supabase.rpc(
      'redeem_points_for_reward',
      {
        p_customer_id: customerId,
        p_reward_id: rewardId
      }
    );
    
    if (error) throw error;
    
    return data;
  } catch (error) {
    console.error('Error redeeming points for reward:', error);
    throw error;
  }
};

/**
 * التحقق من صلاحية رمز الاستبدال
 * @param {string} code - رمز الاستبدال
 * @returns {Promise<Object>} - بيانات التحقق
 */
export const validateRedemptionCode = async (code) => {
  try {
    const { data, error } = await supabase.rpc(
      'validate_redemption_code',
      { p_code: code }
    );
    
    if (error) throw error;
    
    return data;
  } catch (error) {
    console.error('Error validating redemption code:', error);
    throw error;
  }
};

/**
 * تطبيق مكافأة على طلب
 * @param {string} orderId - معرف الطلب
 * @param {string} code - رمز الاستبدال
 * @returns {Promise<Object>} - بيانات التطبيق
 */
export const applyRewardToOrder = async (orderId, code) => {
  try {
    const { data, error } = await supabase.rpc(
      'apply_reward_to_order',
      {
        p_order_id: orderId,
        p_redemption_code: code
      }
    );
    
    if (error) throw error;
    
    return data;
  } catch (error) {
    console.error('Error applying reward to order:', error);
    throw error;
  }
};

/**
 * الحصول على المكافآت المتاحة
 * @param {string} customerId - معرف العميل (اختياري)
 * @returns {Promise<Array>} - قائمة المكافآت
 */
export const getAvailableRewards = async (customerId = null) => {
  try {
    const { data, error } = await supabase.rpc(
      'get_available_rewards',
      { p_customer_id: customerId }
    );
    
    if (error) throw error;
    
    return data || [];
  } catch (error) {
    console.error('Error fetching available rewards:', error);
    return [];
  }
};

/**
 * الحصول على عمليات استبدال العميل
 * @param {string} customerId - معرف العميل
 * @param {string} status - حالة الاستبدال (اختياري)
 * @param {number} limit - عدد العمليات المراد استرجاعها
 * @param {number} offset - عدد العمليات التي يجب تخطيها
 * @returns {Promise<Array>} - قائمة عمليات الاستبدال
 */
export const getCustomerRedemptions = async (customerId, status = null, limit = 10, offset = 0) => {
  try {
    const { data, error } = await supabase.rpc(
      'get_customer_redemptions',
      {
        p_customer_id: customerId,
        p_status: status,
        p_limit: limit,
        p_offset: offset
      }
    );
    
    if (error) throw error;
    
    return data || [];
  } catch (error) {
    console.error('Error fetching customer redemptions:', error);
    return [];
  }
};

/**
 * الحصول على العملاء مع أرصدة النقاط
 * @returns {Promise<Array>} - قائمة العملاء مع أرصدة النقاط
 */
export const getCustomersWithPoints = async () => {
  try {
    const { data, error } = await supabase.rpc('get_customers_with_points');
    
    if (error) throw error;
    
    return data || [];
  } catch (error) {
    console.error('Error fetching customers with points:', error);
    return [];
  }
};

export default {
  getPointsSettings,
  getCustomerPointsBalance,
  getCustomerPointsTransactions,
  addPointsToCustomer,
  redeemPointsForReward,
  validateRedemptionCode,
  applyRewardToOrder,
  getAvailableRewards,
  getCustomerRedemptions,
  getCustomersWithPoints
};