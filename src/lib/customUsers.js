import { supabase } from './supabase';

/**
 * الحصول على قائمة المستخدمين المخصصين
 * @returns {Promise<Array>} - قائمة المستخدمين
 */
export const getCustomUsers = async () => {
  try {
    const { data, error } = await supabase
      .from('custom_users')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (error) throw error;
    
    return data || [];
  } catch (error) {
    console.error('Error fetching custom users:', error);
    throw error;
  }
};

/**
 * إضافة مستخدم مخصص جديد
 * @param {Object} userData - بيانات المستخدم
 * @returns {Promise<Object>} - بيانات المستخدم المضاف
 */
export const addCustomUser = async (userData) => {
  try {
    // استخدام وظيفة RPC لإضافة مستخدم جديد
    const { data, error } = await supabase.rpc(
      'add_custom_user',
      {
        p_username: userData.username || userData.email,
        p_password: userData.password,
        p_name: userData.name,
        p_email: userData.email,
        p_phone: userData.phone || '',
        p_role: userData.role || 'customer'
      }
    );
    
    if (error) throw error;
    
    return data;
  } catch (error) {
    console.error('Error adding custom user:', error);
    throw error;
  }
};

/**
 * تحديث مستخدم مخصص
 * @param {string} id - معرف المستخدم
 * @param {Object} userData - بيانات المستخدم المحدثة
 * @returns {Promise<Object>} - بيانات المستخدم المحدث
 */
export const updateCustomUser = async (id, userData) => {
  try {
    const updateData = {
      name: userData.name,
      email: userData.email,
      phone: userData.phone,
      role: userData.role,
      status: userData.status,
      updated_at: new Date().toISOString()
    };
    
    // إضافة كلمة المرور فقط إذا تم تغييرها
    if (userData.password) {
      const { data: hashData, error: hashError } = await supabase.rpc(
        'hash_password',
        { password: userData.password }
      );
      
      if (hashError) throw hashError;
      
      updateData.password_hash = hashData;
    }
    
    const { data, error } = await supabase
      .from('custom_users')
      .update(updateData)
      .eq('id', id)
      .select();
    
    if (error) throw error;
    
    return data[0];
  } catch (error) {
    console.error('Error updating custom user:', error);
    throw error;
  }
};

/**
 * حذف مستخدم مخصص
 * @param {string} id - معرف المستخدم
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const deleteCustomUser = async (id) => {
  try {
    const { error } = await supabase
      .from('custom_users')
      .delete()
      .eq('id', id);
    
    if (error) throw error;
    
    return true;
  } catch (error) {
    console.error('Error deleting custom user:', error);
    throw error;
  }
};

/**
 * تسجيل الدخول باستخدام المستخدم المخصص
 * @param {string} username - اسم المستخدم أو البريد الإلكتروني
 * @param {string} password - كلمة المرور
 * @returns {Promise<Object>} - بيانات المستخدم
 */
export const loginCustomUser = async (username, password) => {
  try {
    // استخدام وظيفة RPC للتحقق من صحة بيانات الدخول
    const { data, error } = await supabase.rpc(
      'direct_login',
      { username, password }
    );
    
    if (error) throw error;
    
    if (!data.success) {
      throw new Error(data.message || 'فشل تسجيل الدخول');
    }
    
    return data.user;
  } catch (error) {
    console.error('Error logging in custom user:', error);
    throw error;
  }
};

/**
 * الحصول على مستخدم مخصص بواسطة المعرف
 * @param {string} id - معرف المستخدم
 * @returns {Promise<Object>} - بيانات المستخدم
 */
export const getCustomUserById = async (id) => {
  try {
    const { data, error } = await supabase
      .from('custom_users')
      .select('*')
      .eq('id', id)
      .single();
    
    if (error) throw error;
    
    return data;
  } catch (error) {
    console.error('Error fetching custom user by ID:', error);
    throw error;
  }
};

/**
 * الحصول على مستخدم مخصص بواسطة اسم المستخدم
 * @param {string} username - اسم المستخدم
 * @returns {Promise<Object>} - بيانات المستخدم
 */
export const getCustomUserByUsername = async (username) => {
  try {
    const { data, error } = await supabase
      .from('custom_users')
      .select('*')
      .eq('username', username)
      .single();
    
    if (error) throw error;
    
    return data;
  } catch (error) {
    console.error('Error fetching custom user by username:', error);
    throw error;
  }
};

/**
 * الحصول على مستخدم مخصص بواسطة البريد الإلكتروني
 * @param {string} email - البريد الإلكتروني
 * @returns {Promise<Object>} - بيانات المستخدم
 */
export const getCustomUserByEmail = async (email) => {
  try {
    const { data, error } = await supabase
      .from('custom_users')
      .select('*')
      .eq('email', email)
      .single();
    
    if (error) throw error;
    
    return data;
  } catch (error) {
    console.error('Error fetching custom user by email:', error);
    throw error;
  }
};

export default {
  getCustomUsers,
  addCustomUser,
  updateCustomUser,
  deleteCustomUser,
  loginCustomUser,
  getCustomUserById,
  getCustomUserByUsername,
  getCustomUserByEmail
};