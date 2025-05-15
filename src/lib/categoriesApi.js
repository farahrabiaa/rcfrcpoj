import { supabase } from './supabase';
import { getApiKey, setApiKeyHeaders } from './apiKeyAuth';
import axios from 'axios';

// Base URL for API
const getBaseUrl = () => {
  // Check if we're in a production environment
  if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
    // Use Supabase Edge Function for API
    return `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/categories-api`;
  }
  
  // For local development, use the local API
  return '/api/categories';
};

// Create base axios instance
const api = axios.create({
  baseURL: getBaseUrl(),
  headers: {
    'Content-Type': 'application/json'
  }
});

// Request interceptor
api.interceptors.request.use((config) => {
  // Add API key authentication to headers
  const apiKey = getApiKey();
  if (apiKey) {
    config.headers = setApiKeyHeaders(config.headers, apiKey);
  }
  
  return config;
});

// Response interceptor
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Don't redirect to login if we're already there
      if (!window.location.pathname.includes('/login')) {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

/**
 * الحصول على قائمة التصنيفات
 * @returns {Promise<Array>} - قائمة التصنيفات
 */
export const getCategories = async () => {
  try {
    // أولاً، نحاول استخدام Supabase مباشرة
    const { data, error } = await supabase
      .from('categories')
      .select('*')
      .order('name');
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error fetching categories from Supabase:', error);
    
    // إذا فشل الاتصال المباشر، نستخدم API
    try {
      const response = await api.get('/categories');
      return response.data;
    } catch (apiError) {
      console.error('Error fetching categories from API:', apiError);
      throw apiError;
    }
  }
};

/**
 * الحصول على تصنيف محدد
 * @param {string} id - معرف التصنيف
 * @returns {Promise<Object>} - بيانات التصنيف
 */
export const getCategory = async (id) => {
  try {
    // أولاً، نحاول استخدام Supabase مباشرة
    const { data, error } = await supabase
      .from('categories')
      .select('*')
      .eq('id', id)
      .single();
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error fetching category from Supabase:', error);
    
    // إذا فشل الاتصال المباشر، نستخدم API
    try {
      const response = await api.get(`/categories/${id}`);
      return response.data;
    } catch (apiError) {
      console.error('Error fetching category from API:', apiError);
      throw apiError;
    }
  }
};

/**
 * الحصول على شجرة التصنيفات
 * @returns {Promise<Array>} - شجرة التصنيفات
 */
export const getCategoryTree = async () => {
  try {
    // أولاً، نحاول استخدام API
    const response = await api.get('/categories/tree');
    return response.data;
  } catch (error) {
    console.error('Error fetching category tree from API:', error);
    
    // إذا فشل الاتصال بالـ API، نبني الشجرة يدويًا
    try {
      const { data, error } = await supabase
        .from('categories')
        .select('*')
        .order('name');
      
      if (error) throw error;
      
      // بناء شجرة التصنيفات
      const categoryMap = {};
      const rootCategories = [];
      
      // أولاً، إنشاء خريطة للتصنيفات حسب المعرف
      data.forEach(category => {
        categoryMap[category.id] = { ...category, children: [] };
      });
      
      // ثم، بناء هيكل الشجرة
      data.forEach(category => {
        if (category.parent_id && categoryMap[category.parent_id]) {
          categoryMap[category.parent_id].children.push(categoryMap[category.id]);
        } else {
          rootCategories.push(categoryMap[category.id]);
        }
      });
      
      return rootCategories;
    } catch (supabaseError) {
      console.error('Error building category tree:', supabaseError);
      throw supabaseError;
    }
  }
};

/**
 * الحصول على منتجات تصنيف محدد
 * @param {string} id - معرف التصنيف
 * @returns {Promise<Array>} - قائمة المنتجات
 */
export const getCategoryProducts = async (id) => {
  try {
    // أولاً، نحاول استخدام Supabase مباشرة
    const { data, error } = await supabase
      .from('products')
      .select(`
        *,
        vendor:vendor_id(store_name)
      `)
      .eq('category_id', id)
      .eq('status', 'active');
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error fetching category products from Supabase:', error);
    
    // إذا فشل الاتصال المباشر، نستخدم API
    try {
      const response = await api.get(`/categories/${id}/products`);
      return response.data;
    } catch (apiError) {
      console.error('Error fetching category products from API:', apiError);
      throw apiError;
    }
  }
};

/**
 * إنشاء تصنيف جديد
 * @param {Object} categoryData - بيانات التصنيف
 * @returns {Promise<Object>} - بيانات التصنيف الجديد
 */
export const createCategory = async (categoryData) => {
  try {
    // أولاً، نحاول استخدام Supabase مباشرة
    const { data, error } = await supabase
      .from('categories')
      .insert([categoryData])
      .select();
    
    if (error) throw error;
    return data[0];
  } catch (error) {
    console.error('Error creating category in Supabase:', error);
    
    // إذا فشل الاتصال المباشر، نستخدم API
    try {
      const response = await api.post('/categories', categoryData);
      return response.data;
    } catch (apiError) {
      console.error('Error creating category via API:', apiError);
      throw apiError;
    }
  }
};

/**
 * تحديث تصنيف
 * @param {string} id - معرف التصنيف
 * @param {Object} categoryData - بيانات التصنيف المحدثة
 * @returns {Promise<Object>} - بيانات التصنيف المحدثة
 */
export const updateCategory = async (id, categoryData) => {
  try {
    // أولاً، نحاول استخدام Supabase مباشرة
    const { data, error } = await supabase
      .from('categories')
      .update(categoryData)
      .eq('id', id)
      .select();
    
    if (error) throw error;
    return data[0];
  } catch (error) {
    console.error('Error updating category in Supabase:', error);
    
    // إذا فشل الاتصال المباشر، نستخدم API
    try {
      const response = await api.put(`/categories/${id}`, categoryData);
      return response.data;
    } catch (apiError) {
      console.error('Error updating category via API:', apiError);
      throw apiError;
    }
  }
};

/**
 * حذف تصنيف
 * @param {string} id - معرف التصنيف
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const deleteCategory = async (id) => {
  try {
    // أولاً، نحاول استخدام Supabase مباشرة
    const { error } = await supabase
      .from('categories')
      .delete()
      .eq('id', id);
    
    if (error) throw error;
    return true;
  } catch (error) {
    console.error('Error deleting category in Supabase:', error);
    
    // إذا فشل الاتصال المباشر، نستخدم API
    try {
      await api.delete(`/categories/${id}`);
      return true;
    } catch (apiError) {
      console.error('Error deleting category via API:', apiError);
      throw apiError;
    }
  }
};

export default {
  getCategories,
  getCategory,
  getCategoryTree,
  getCategoryProducts,
  createCategory,
  updateCategory,
  deleteCategory
};