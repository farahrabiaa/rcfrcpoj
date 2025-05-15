import { supabase } from './supabase';

/**
 * الحصول على قائمة الإعلانات
 * @param {Object} options - خيارات الفلترة
 * @returns {Promise<Array>} - قائمة الإعلانات
 */
export const getAdvertisements = async (options = {}) => {
  try {
    let query = supabase
      .from('advertisements')
      .select(`
        *,
        vendor:vendor_id(store_name)
      `);
    
    // تطبيق الفلاتر
    if (options.position) {
      query = query.eq('position', options.position);
    }
    
    if (options.type) {
      query = query.eq('type', options.type);
    }
    
    if (options.active) {
      const today = new Date().toISOString().split('T')[0];
      query = query
        .eq('status', 'active')
        .lte('start_date', today)
        .gte('end_date', today);
    }
    
    if (options.vendorId) {
      query = query.eq('vendor_id', options.vendorId);
    }
    
    // ترتيب النتائج
    query = query.order('priority', { ascending: true });
    
    const { data, error } = await query;
    
    if (error) throw error;
    
    return data || [];
  } catch (error) {
    console.error('Error fetching advertisements:', error);
    throw error;
  }
};

/**
 * الحصول على إعلان محدد
 * @param {string} id - معرف الإعلان
 * @returns {Promise<Object>} - بيانات الإعلان
 */
export const getAdvertisement = async (id) => {
  try {
    const { data, error } = await supabase
      .from('advertisements')
      .select(`
        *,
        vendor:vendor_id(store_name)
      `)
      .eq('id', id)
      .single();
    
    if (error) throw error;
    
    return data;
  } catch (error) {
    console.error('Error fetching advertisement:', error);
    throw error;
  }
};

/**
 * إنشاء إعلان جديد
 * @param {Object} adData - بيانات الإعلان
 * @returns {Promise<Object>} - بيانات الإعلان المنشأ
 */
export const createAdvertisement = async (adData) => {
  try {
    const { data, error } = await supabase
      .from('advertisements')
      .insert([adData])
      .select(`
        *,
        vendor:vendor_id(store_name)
      `);
    
    if (error) throw error;
    
    return data[0];
  } catch (error) {
    console.error('Error creating advertisement:', error);
    throw error;
  }
};

/**
 * تحديث إعلان
 * @param {string} id - معرف الإعلان
 * @param {Object} adData - بيانات الإعلان المحدثة
 * @returns {Promise<Object>} - بيانات الإعلان المحدثة
 */
export const updateAdvertisement = async (id, adData) => {
  try {
    const { data, error } = await supabase
      .from('advertisements')
      .update(adData)
      .eq('id', id)
      .select(`
        *,
        vendor:vendor_id(store_name)
      `);
    
    if (error) throw error;
    
    return data[0];
  } catch (error) {
    console.error('Error updating advertisement:', error);
    throw error;
  }
};

/**
 * حذف إعلان
 * @param {string} id - معرف الإعلان
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const deleteAdvertisement = async (id) => {
  try {
    const { error } = await supabase
      .from('advertisements')
      .delete()
      .eq('id', id);
    
    if (error) throw error;
    
    return true;
  } catch (error) {
    console.error('Error deleting advertisement:', error);
    throw error;
  }
};

/**
 * تسجيل مشاهدة إعلان
 * @param {string} id - معرف الإعلان
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const recordAdvertisementView = async (id) => {
  try {
    const { error } = await supabase.rpc('increment_advertisement_views', { p_ad_id: id });
    
    if (error) throw error;
    
    return true;
  } catch (error) {
    console.error('Error recording advertisement view:', error);
    return false; // لا نرمي الخطأ هنا لأنها عملية غير حرجة
  }
};

/**
 * تسجيل نقرة على إعلان
 * @param {string} id - معرف الإعلان
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const recordAdvertisementClick = async (id) => {
  try {
    const { error } = await supabase.rpc('increment_advertisement_clicks', { p_ad_id: id });
    
    if (error) throw error;
    
    return true;
  } catch (error) {
    console.error('Error recording advertisement click:', error);
    return false; // لا نرمي الخطأ هنا لأنها عملية غير حرجة
  }
};

/**
 * الحصول على إعلانات السلايدر
 * @returns {Promise<Array>} - قائمة إعلانات السلايدر
 */
export const getSliderAdvertisements = async () => {
  try {
    const { data, error } = await supabase
      .from('slider_advertisements')
      .select(`
        *,
        vendor:vendor_id(store_name)
      `)
      .eq('status', 'active')
      .lte('start_date', new Date().toISOString().split('T')[0])
      .gte('end_date', new Date().toISOString().split('T')[0])
      .order('priority', { ascending: true });
    
    if (error) throw error;
    
    return data || [];
  } catch (error) {
    console.error('Error fetching slider advertisements:', error);
    throw error;
  }
};

/**
 * تسجيل مشاهدة إعلان سلايدر
 * @param {string} id - معرف الإعلان
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const recordSliderView = async (id) => {
  try {
    const { error } = await supabase.rpc('increment_slider_views', { p_slider_id: id });
    
    if (error) throw error;
    
    return true;
  } catch (error) {
    console.error('Error recording slider view:', error);
    return false; // لا نرمي الخطأ هنا لأنها عملية غير حرجة
  }
};

/**
 * تسجيل نقرة على إعلان سلايدر
 * @param {string} id - معرف الإعلان
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const recordSliderClick = async (id) => {
  try {
    const { error } = await supabase.rpc('increment_slider_clicks', { p_slider_id: id });
    
    if (error) throw error;
    
    return true;
  } catch (error) {
    console.error('Error recording slider click:', error);
    return false; // لا نرمي الخطأ هنا لأنها عملية غير حرجة
  }
};

export default {
  getAdvertisements,
  getAdvertisement,
  createAdvertisement,
  updateAdvertisement,
  deleteAdvertisement,
  recordAdvertisementView,
  recordAdvertisementClick,
  getSliderAdvertisements,
  recordSliderView,
  recordSliderClick
};