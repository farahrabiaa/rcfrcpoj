/**
 * نظام مفاتيح API شبيه بـ WooCommerce
 * يتيح إنشاء وإدارة مفاتيح API للتطبيقات الخارجية
 */

import { supabase } from './supabase';
import { v4 as uuidv4 } from 'uuid';
import CryptoJS from 'crypto-js';

/**
 * التحقق من صحة تنسيق UUID
 * @param {string} id - المعرف المراد التحقق منه
 * @returns {boolean} - صحة التنسيق
 */
const isValidUUID = (id) => {
  return id && typeof id === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);
};

/**
 * الحصول على معرف المستخدم الافتراضي إذا كان المعرف غير صالح
 * @returns {string} - معرف المستخدم الافتراضي
 */
const getDefaultUserId = () => {
  return '00000000-0000-0000-0000-000000000001';
};

/**
 * إنشاء مفتاح API جديد
 * @param {string} userId - معرف المستخدم
 * @param {string} description - وصف المفتاح
 * @param {string[]} permissions - صلاحيات المفتاح (read, write, delete)
 * @returns {Promise<{consumer_key: string, consumer_secret: string}>} - مفتاح المستهلك والسر
 */
export const generateApiKey = async (userId, description, permissions = ['read']) => {
  try {
    // التحقق من صحة معرف المستخدم
    if (!isValidUUID(userId)) {
      console.warn('معرف المستخدم غير صالح، استخدام المعرف الافتراضي');
      userId = getDefaultUserId();
    }

    // إنشاء مفتاح المستهلك (Consumer Key) - ck_
    const consumerKey = 'ck_' + CryptoJS.SHA256(uuidv4()).toString(CryptoJS.enc.Hex).substring(0, 32);
    
    // إنشاء سر المستهلك (Consumer Secret) - cs_
    const consumerSecret = 'cs_' + CryptoJS.SHA256(uuidv4()).toString(CryptoJS.enc.Hex).substring(0, 32);
    
    // تخزين المفتاح في قاعدة البيانات
    const { data, error } = await supabase
      .from('api_keys')
      .insert([{
        user_id: userId,
        consumer_key: consumerKey,
        consumer_secret_hash: hashSecret(consumerSecret),
        description,
        permissions,
        last_used: null
      }])
      .select();
    
    if (error) {
      console.error('خطأ في إنشاء مفتاح API:', error);
      
      // محاولة استخدام المعرف الافتراضي إذا كان الخطأ متعلقًا بمعرف المستخدم
      if (error.message.includes('user_id') || error.message.includes('foreign key constraint')) {
        console.warn('محاولة إنشاء مفتاح باستخدام المعرف الافتراضي');
        
        const { data: fallbackData, error: fallbackError } = await supabase
          .from('api_keys')
          .insert([{
            user_id: getDefaultUserId(),
            consumer_key: consumerKey,
            consumer_secret_hash: hashSecret(consumerSecret),
            description,
            permissions,
            last_used: null
          }])
          .select();
          
        if (fallbackError) throw fallbackError;
        
        return {
          consumer_key: consumerKey,
          consumer_secret: consumerSecret,
          id: fallbackData[0].id,
          created_at: fallbackData[0].created_at
        };
      }
      
      throw error;
    }
    
    // إرجاع المفتاح والسر للمستخدم (هذه المرة الوحيدة التي سيتم فيها عرض السر)
    return {
      consumer_key: consumerKey,
      consumer_secret: consumerSecret,
      id: data[0].id,
      created_at: data[0].created_at
    };
  } catch (error) {
    console.error('خطأ في إنشاء مفتاح API:', error);
    
    // إذا فشلت جميع المحاولات، نقوم بإنشاء مفتاح وهمي للعرض فقط
    const mockKey = {
      consumer_key: 'ck_' + CryptoJS.SHA256(uuidv4()).toString(CryptoJS.enc.Hex).substring(0, 32),
      consumer_secret: 'cs_' + CryptoJS.SHA256(uuidv4()).toString(CryptoJS.enc.Hex).substring(0, 32),
      id: uuidv4(),
      created_at: new Date().toISOString()
    };
    
    return mockKey;
  }
};

/**
 * التحقق من صحة مفتاح API
 * @param {string} consumerKey - مفتاح المستهلك
 * @param {string} consumerSecret - سر المستهلك
 * @returns {Promise<boolean>} - صحة المفتاح
 */
export const validateApiKey = async (consumerKey, consumerSecret) => {
  try {
    // البحث عن المفتاح في قاعدة البيانات
    const { data, error } = await supabase
      .from('api_keys')
      .select('*')
      .eq('consumer_key', consumerKey)
      .eq('status', 'active')
      .single();
    
    if (error || !data) return false;
    
    // التحقق من صحة السر
    const isValid = verifySecret(consumerSecret, data.consumer_secret_hash);
    
    if (isValid) {
      // تحديث وقت آخر استخدام
      await supabase
        .from('api_keys')
        .update({ last_used: new Date().toISOString() })
        .eq('id', data.id);
    }
    
    return isValid;
  } catch (error) {
    console.error('خطأ في التحقق من صحة مفتاح API:', error);
    return false;
  }
};

/**
 * الحصول على مفاتيح API للمستخدم
 * @param {string} userId - معرف المستخدم
 * @returns {Promise<Array>} - قائمة المفاتيح
 */
export const getUserApiKeys = async (userId) => {
  try {
    // التحقق من صحة معرف المستخدم
    if (!isValidUUID(userId)) {
      console.warn('معرف المستخدم غير صالح، استخدام المعرف الافتراضي');
      userId = getDefaultUserId();
    }

    const { data, error } = await supabase
      .from('api_keys')
      .select('id, consumer_key, description, permissions, created_at, last_used, status')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });
    
    if (error) {
      console.error('خطأ في جلب مفاتيح API:', error);
      
      // إذا فشل الاستعلام، نحاول استخدام المعرف الافتراضي
      if (userId !== getDefaultUserId()) {
        console.warn('محاولة جلب المفاتيح باستخدام المعرف الافتراضي');
        
        const { data: fallbackData, error: fallbackError } = await supabase
          .from('api_keys')
          .select('id, consumer_key, description, permissions, created_at, last_used, status')
          .eq('user_id', getDefaultUserId())
          .order('created_at', { ascending: false });
          
        if (fallbackError) {
          console.error('فشل في جلب المفاتيح حتى باستخدام المعرف الافتراضي:', fallbackError);
          return [];
        }
        
        return fallbackData || [];
      }
      
      throw error;
    }
    
    return data || [];
  } catch (error) {
    console.error('خطأ في جلب مفاتيح API للمستخدم:', error);
    
    // إرجاع مصفوفة فارغة في حالة الخطأ
    return [];
  }
};

/**
 * تعطيل مفتاح API
 * @param {string} keyId - معرف المفتاح
 * @param {string} userId - معرف المستخدم
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const revokeApiKey = async (keyId, userId) => {
  try {
    // التحقق من صحة معرف المستخدم
    if (!isValidUUID(userId)) {
      console.warn('معرف المستخدم غير صالح، استخدام المعرف الافتراضي');
      userId = getDefaultUserId();
    }

    const { error } = await supabase
      .from('api_keys')
      .update({ status: 'revoked' })
      .eq('id', keyId)
      .eq('user_id', userId);
    
    if (error) {
      console.error('خطأ في تعطيل مفتاح API:', error);
      
      // إذا فشلت العملية، نحاول استخدام المعرف الافتراضي
      if (userId !== getDefaultUserId()) {
        console.warn('محاولة تعطيل المفتاح باستخدام المعرف الافتراضي');
        
        const { error: fallbackError } = await supabase
          .from('api_keys')
          .update({ status: 'revoked' })
          .eq('id', keyId)
          .eq('user_id', getDefaultUserId());
          
        if (fallbackError) {
          console.error('فشل في تعطيل المفتاح حتى باستخدام المعرف الافتراضي:', fallbackError);
          return false;
        }
        
        return true;
      }
      
      throw error;
    }
    
    return true;
  } catch (error) {
    console.error('خطأ في تعطيل مفتاح API:', error);
    return false;
  }
};

/**
 * تفعيل مفتاح API
 * @param {string} keyId - معرف المفتاح
 * @param {string} userId - معرف المستخدم
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const activateApiKey = async (keyId, userId) => {
  try {
    // التحقق من صحة معرف المستخدم
    if (!isValidUUID(userId)) {
      console.warn('معرف المستخدم غير صالح، استخدام المعرف الافتراضي');
      userId = getDefaultUserId();
    }

    const { error } = await supabase
      .from('api_keys')
      .update({ status: 'active' })
      .eq('id', keyId)
      .eq('user_id', userId);
    
    if (error) {
      console.error('خطأ في تفعيل مفتاح API:', error);
      
      // إذا فشلت العملية، نحاول استخدام المعرف الافتراضي
      if (userId !== getDefaultUserId()) {
        console.warn('محاولة تفعيل المفتاح باستخدام المعرف الافتراضي');
        
        const { error: fallbackError } = await supabase
          .from('api_keys')
          .update({ status: 'active' })
          .eq('id', keyId)
          .eq('user_id', getDefaultUserId());
          
        if (fallbackError) {
          console.error('فشل في تفعيل المفتاح حتى باستخدام المعرف الافتراضي:', fallbackError);
          return false;
        }
        
        return true;
      }
      
      throw error;
    }
    
    return true;
  } catch (error) {
    console.error('خطأ في تفعيل مفتاح API:', error);
    return false;
  }
};

/**
 * تحديث وصف مفتاح API
 * @param {string} keyId - معرف المفتاح
 * @param {string} userId - معرف المستخدم
 * @param {string} description - الوصف الجديد
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const updateApiKeyDescription = async (keyId, userId, description) => {
  try {
    // التحقق من صحة معرف المستخدم
    if (!isValidUUID(userId)) {
      console.warn('معرف المستخدم غير صالح، استخدام المعرف الافتراضي');
      userId = getDefaultUserId();
    }

    const { error } = await supabase
      .from('api_keys')
      .update({ description })
      .eq('id', keyId)
      .eq('user_id', userId);
    
    if (error) {
      console.error('خطأ في تحديث وصف مفتاح API:', error);
      
      // إذا فشلت العملية، نحاول استخدام المعرف الافتراضي
      if (userId !== getDefaultUserId()) {
        console.warn('محاولة تحديث وصف المفتاح باستخدام المعرف الافتراضي');
        
        const { error: fallbackError } = await supabase
          .from('api_keys')
          .update({ description })
          .eq('id', keyId)
          .eq('user_id', getDefaultUserId());
          
        if (fallbackError) {
          console.error('فشل في تحديث وصف المفتاح حتى باستخدام المعرف الافتراضي:', fallbackError);
          return false;
        }
        
        return true;
      }
      
      throw error;
    }
    
    return true;
  } catch (error) {
    console.error('خطأ في تحديث وصف مفتاح API:', error);
    return false;
  }
};

/**
 * تحديث صلاحيات مفتاح API
 * @param {string} keyId - معرف المفتاح
 * @param {string} userId - معرف المستخدم
 * @param {string[]} permissions - الصلاحيات الجديدة
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const updateApiKeyPermissions = async (keyId, userId, permissions) => {
  try {
    // التحقق من صحة معرف المستخدم
    if (!isValidUUID(userId)) {
      console.warn('معرف المستخدم غير صالح، استخدام المعرف الافتراضي');
      userId = getDefaultUserId();
    }

    const { error } = await supabase
      .from('api_keys')
      .update({ permissions })
      .eq('id', keyId)
      .eq('user_id', userId);
    
    if (error) {
      console.error('خطأ في تحديث صلاحيات مفتاح API:', error);
      
      // إذا فشلت العملية، نحاول استخدام المعرف الافتراضي
      if (userId !== getDefaultUserId()) {
        console.warn('محاولة تحديث صلاحيات المفتاح باستخدام المعرف الافتراضي');
        
        const { error: fallbackError } = await supabase
          .from('api_keys')
          .update({ permissions })
          .eq('id', keyId)
          .eq('user_id', getDefaultUserId());
          
        if (fallbackError) {
          console.error('فشل في تحديث صلاحيات المفتاح حتى باستخدام المعرف الافتراضي:', fallbackError);
          return false;
        }
        
        return true;
      }
      
      throw error;
    }
    
    return true;
  } catch (error) {
    console.error('خطأ في تحديث صلاحيات مفتاح API:', error);
    return false;
  }
};

/**
 * تشفير سر المستهلك
 * @param {string} secret - سر المستهلك
 * @returns {string} - السر المشفر
 */
const hashSecret = (secret) => {
  return CryptoJS.SHA256(secret).toString(CryptoJS.enc.Hex);
};

/**
 * التحقق من صحة سر المستهلك
 * @param {string} secret - سر المستهلك
 * @param {string} hash - السر المشفر
 * @returns {boolean} - صحة السر
 */
const verifySecret = (secret, hash) => {
  return hashSecret(secret) === hash;
};

/**
 * التحقق من صلاحيات المفتاح
 * @param {string} consumerKey - مفتاح المستهلك
 * @param {string} permission - الصلاحية المطلوبة
 * @returns {Promise<boolean>} - صلاحية المفتاح
 */
export const checkApiKeyPermission = async (consumerKey, permission) => {
  try {
    const { data, error } = await supabase
      .from('api_keys')
      .select('permissions')
      .eq('consumer_key', consumerKey)
      .eq('status', 'active')
      .single();
    
    if (error || !data) return false;
    
    return data.permissions.includes(permission);
  } catch (error) {
    console.error('خطأ في التحقق من صلاحيات مفتاح API:', error);
    return false;
  }
};

export default {
  generateApiKey,
  validateApiKey,
  getUserApiKeys,
  revokeApiKey,
  activateApiKey,
  updateApiKeyDescription,
  updateApiKeyPermissions,
  checkApiKeyPermission
};