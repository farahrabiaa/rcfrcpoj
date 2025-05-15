import { supabase } from './supabase';

/**
 * الحصول على قائمة ملفات الوسائط
 * @param {Object} options - خيارات الفلترة
 * @returns {Promise<Array>} - قائمة ملفات الوسائط
 */
export const getMediaFiles = async (options = {}) => {
  try {
    let query = supabase
      .from('media_files')
      .select('*', { count: 'exact' });
    
    // تطبيق الفلاتر
    if (options.bucket) {
      query = query.eq('bucket', options.bucket);
    }
    
    if (options.type) {
      query = query.ilike('mime_type', `${options.type}%`);
    }
    
    if (options.search) {
      query = query.or(`filename.ilike.%${options.search}%,original_filename.ilike.%${options.search}%,alt_text.ilike.%${options.search}%,title.ilike.%${options.search}%`);
    }
    
    // ترتيب النتائج
    query = query.order('created_at', { ascending: false });
    
    // تطبيق الصفحات
    if (options.page && options.limit) {
      const from = (options.page - 1) * options.limit;
      const to = from + options.limit - 1;
      query = query.range(from, to);
    }
    
    const { data, error, count } = await query;
    
    if (error) throw error;
    
    // تحويل البيانات لتشمل روابط عامة
    const transformedData = data.map(file => {
      const { data: { publicUrl } } = supabase.storage
        .from(file.bucket)
        .getPublicUrl(file.file_path);
      
      return {
        ...file,
        url: publicUrl,
        type: file.mime_type.startsWith('image/') ? 'image' : 
              file.mime_type.startsWith('video/') ? 'video' : 
              file.mime_type.startsWith('audio/') ? 'audio' : 'document'
      };
    });
    
    return {
      data: transformedData,
      count,
      page: options.page || 1,
      limit: options.limit || transformedData.length
    };
  } catch (error) {
    console.error('Error fetching media files:', error);
    throw error;
  }
};

/**
 * الحصول على ملف وسائط محدد
 * @param {string} id - معرف الملف
 * @returns {Promise<Object>} - بيانات الملف
 */
export const getMediaFile = async (id) => {
  try {
    const { data, error } = await supabase
      .from('media_files')
      .select('*')
      .eq('id', id)
      .single();
    
    if (error) throw error;
    
    // إضافة الرابط العام
    const { data: { publicUrl } } = supabase.storage
      .from(data.bucket)
      .getPublicUrl(data.file_path);
    
    return {
      ...data,
      url: publicUrl,
      type: data.mime_type.startsWith('image/') ? 'image' : 
            data.mime_type.startsWith('video/') ? 'video' : 
            data.mime_type.startsWith('audio/') ? 'audio' : 'document'
    };
  } catch (error) {
    console.error('Error fetching media file:', error);
    throw error;
  }
};

/**
 * تحديث بيانات ملف وسائط
 * @param {string} id - معرف الملف
 * @param {Object} fileData - بيانات الملف المحدثة
 * @returns {Promise<Object>} - بيانات الملف المحدثة
 */
export const updateMediaFile = async (id, fileData) => {
  try {
    // تحديد الحقول المسموح بتحديثها
    const allowedFields = ['alt_text', 'title', 'description', 'is_public'];
    const updates = {};
    
    for (const field of allowedFields) {
      if (fileData[field] !== undefined) {
        updates[field] = fileData[field];
      }
    }
    
    // إضافة تاريخ التحديث
    updates.updated_at = new Date().toISOString();
    
    const { data, error } = await supabase
      .from('media_files')
      .update(updates)
      .eq('id', id)
      .select();
    
    if (error) throw error;
    
    // إضافة الرابط العام
    const { data: { publicUrl } } = supabase.storage
      .from(data[0].bucket)
      .getPublicUrl(data[0].file_path);
    
    return {
      ...data[0],
      url: publicUrl,
      type: data[0].mime_type.startsWith('image/') ? 'image' : 
            data[0].mime_type.startsWith('video/') ? 'video' : 
            data[0].mime_type.startsWith('audio/') ? 'audio' : 'document'
    };
  } catch (error) {
    console.error('Error updating media file:', error);
    throw error;
  }
};

/**
 * حذف ملف وسائط
 * @param {string} id - معرف الملف
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const deleteMediaFile = async (id) => {
  try {
    // الحصول على معلومات الملف أولاً
    const { data: fileData, error: fileError } = await supabase
      .from('media_files')
      .select('*')
      .eq('id', id)
      .single();
    
    if (fileError) throw fileError;
    
    // حذف الملف من التخزين
    const { error: storageError } = await supabase.storage
      .from(fileData.bucket)
      .remove([fileData.file_path]);
    
    if (storageError) {
      console.error('Error deleting from storage:', storageError);
      // استمر على أي حال، سنحذفه من قاعدة البيانات
    }
    
    // حذف من قاعدة البيانات
    const { error } = await supabase
      .from('media_files')
      .delete()
      .eq('id', id);
    
    if (error) throw error;
    
    return true;
  } catch (error) {
    console.error('Error deleting media file:', error);
    throw error;
  }
};

/**
 * زيادة عدد استخدامات الملف
 * @param {string} id - معرف الملف
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const incrementMediaUsage = async (id) => {
  try {
    const { error } = await supabase.rpc('increment_media_usage', { p_media_id: id });
    
    if (error) throw error;
    
    return true;
  } catch (error) {
    console.error('Error incrementing media usage:', error);
    return false; // لا نرمي الخطأ هنا لأنها عملية غير حرجة
  }
};

export default {
  getMediaFiles,
  getMediaFile,
  updateMediaFile,
  deleteMediaFile,
  incrementMediaUsage
};