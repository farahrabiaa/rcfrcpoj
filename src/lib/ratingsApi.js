import { supabase } from './supabase';

/**
 * الحصول على تقييمات حسب النوع
 * @param {string} type - نوع التقييم (vendor, driver, customer)
 * @param {string} id - معرف الكيان (اختياري)
 * @returns {Promise<Array>} - قائمة التقييمات
 */
export const getRatingsByType = async (type, id = null) => {
  try {
    const { data, error } = await supabase.rpc(
      'get_ratings_by_type',
      { 
        p_type: type,
        p_id: id
      }
    );
    
    if (error) throw error;
    return data || [];
  } catch (error) {
    console.error('Error fetching ratings:', error);
    throw error;
  }
};

/**
 * الحصول على إحصائيات التقييمات
 * @param {string} type - نوع التقييم (vendor, driver, customer)
 * @param {string} id - معرف الكيان (اختياري)
 * @returns {Promise<Object>} - إحصائيات التقييمات
 */
export const getRatingsStats = async (type, id = null) => {
  try {
    const { data, error } = await supabase.rpc(
      'get_ratings_stats',
      { 
        p_type: type,
        p_id: id
      }
    );
    
    if (error) throw error;
    return data || { average: 0, total: 0, distribution: {} };
  } catch (error) {
    console.error('Error fetching ratings stats:', error);
    throw error;
  }
};

/**
 * إضافة تقييم جديد
 * @param {Object} ratingData - بيانات التقييم
 * @returns {Promise<Object>} - بيانات التقييم المضاف
 */
export const addRating = async (ratingData) => {
  try {
    // التحقق من وجود البيانات المطلوبة
    if (!ratingData.order_id || !ratingData.from_type || !ratingData.from_id || 
        !ratingData.to_type || !ratingData.to_id || !ratingData.rating) {
      throw new Error('جميع الحقول المطلوبة غير متوفرة');
    }
    
    // التحقق من صحة نوع المرسل والمستقبل
    if (!['customer', 'vendor', 'driver'].includes(ratingData.from_type) || 
        !['customer', 'vendor', 'driver'].includes(ratingData.to_type)) {
      throw new Error('نوع المرسل أو المستقبل غير صالح');
    }
    
    // التحقق من صحة التقييم
    if (ratingData.rating < 1 || ratingData.rating > 5) {
      throw new Error('التقييم يجب أن يكون بين 1 و 5');
    }
    
    const { data, error } = await supabase
      .from('ratings')
      .insert([{
        order_id: ratingData.order_id,
        from_type: ratingData.from_type,
        from_id: ratingData.from_id,
        to_type: ratingData.to_type,
        to_id: ratingData.to_id,
        rating: ratingData.rating,
        comment: ratingData.comment
      }])
      .select();
    
    if (error) throw error;
    return data[0];
  } catch (error) {
    console.error('Error adding rating:', error);
    throw error;
  }
};

/**
 * الحصول على تقرير التقييمات الشهري
 * @param {string} type - نوع التقييم (vendor, driver)
 * @param {number} year - السنة
 * @returns {Promise<Array>} - تقرير التقييمات الشهري
 */
export const getRatingsReport = async (type, year) => {
  try {
    const { data, error } = await supabase.rpc(
      'get_ratings_report',
      { 
        p_type: type,
        p_year: year
      }
    );
    
    if (error) throw error;
    return data || [];
  } catch (error) {
    console.error('Error fetching ratings report:', error);
    throw error;
  }
};

/**
 * الحصول على تقييمات طلب معين
 * @param {string} orderId - معرف الطلب
 * @returns {Promise<Array>} - قائمة التقييمات
 */
export const getOrderRatings = async (orderId) => {
  try {
    const { data, error } = await supabase
      .from('ratings')
      .select(`
        *,
        from_customer:from_id(name),
        from_vendor:from_id(store_name),
        from_driver:from_id(name),
        to_customer:to_id(name),
        to_vendor:to_id(store_name),
        to_driver:to_id(name)
      `)
      .eq('order_id', orderId);
    
    if (error) throw error;
    
    // تحويل البيانات إلى شكل أسهل للاستخدام
    const transformedData = data.map(rating => {
      let fromName, toName;
      
      if (rating.from_type === 'customer') fromName = rating.from_customer?.name;
      else if (rating.from_type === 'vendor') fromName = rating.from_vendor?.store_name;
      else if (rating.from_type === 'driver') fromName = rating.from_driver?.name;
      
      if (rating.to_type === 'customer') toName = rating.to_customer?.name;
      else if (rating.to_type === 'vendor') toName = rating.to_vendor?.store_name;
      else if (rating.to_type === 'driver') toName = rating.to_driver?.name;
      
      return {
        ...rating,
        from_name: fromName,
        to_name: toName
      };
    });
    
    return transformedData;
  } catch (error) {
    console.error('Error fetching order ratings:', error);
    throw error;
  }
};

export default {
  getRatingsByType,
  getRatingsStats,
  addRating,
  getRatingsReport,
  getOrderRatings
};