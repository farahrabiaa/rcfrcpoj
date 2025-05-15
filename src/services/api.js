import axios from 'axios';
import { supabase } from '../lib/supabase';
import { getApiKey, setApiKeyHeaders } from '../lib/apiKeyAuth';

// Determine the base URL based on environment
const getBaseUrl = () => {
  // Check if we're in a production environment (Netlify)
  if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
    // Use Supabase Edge Function for API
    return `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/api`;
  }
  
  // For local development, use the WordPress API
  return window.khdmkmData?.restUrl || '/wp-json/khdmkm/v1';
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

// Categories API service
export const categoriesApi = {
  getAll: async () => {
    try {
      const { data, error } = await supabase
        .from('categories')
        .select('*');
        
      if (error) throw error;
      return { data };
    } catch (error) {
      console.error('Error fetching categories:', error);
      
      // Try fallback to API
      try {
        const response = await api.get('/categories');
        return { data: response.data };
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        
        // Fallback to mock data
        return { 
          data: [
            { id: 1, name: 'مطاعم', slug: 'restaurants', description: 'جميع أنواع المطاعم والمأكولات' },
            { id: 2, name: 'سوبر ماركت', slug: 'supermarkets', description: 'محلات البقالة والسوبر ماركت' },
            { id: 3, name: 'مشروبات ساخنة', slug: 'hot-beverages', description: 'القهوة والشاي والمشروبات الساخنة' },
            { id: 4, name: 'عصائر', slug: 'juices', description: 'العصائر الطازجة والمشروبات الباردة' },
            { id: 5, name: 'حلويات', slug: 'desserts', description: 'الحلويات والكيك' }
          ]
        };
      }
    }
  },
  
  getOne: async (id) => {
    try {
      const { data, error } = await supabase
        .from('categories')
        .select('*')
        .eq('id', id)
        .single();
        
      if (error) throw error;
      return { data };
    } catch (error) {
      console.error('Error fetching category:', error);
      
      // Try fallback to API
      try {
        const response = await api.get(`/categories/${id}`);
        return { data: response.data };
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        return { data: null };
      }
    }
  },
  
  create: async (categoryData) => {
    try {
      const { data, error } = await supabase
        .from('categories')
        .insert([categoryData])
        .select();
        
      if (error) throw error;
      return { data: data[0] };
    } catch (error) {
      console.error('Error creating category:', error);
      
      // Try fallback to API
      try {
        const response = await api.post('/categories', categoryData);
        return { data: response.data };
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        throw error;
      }
    }
  },
  
  update: async (id, categoryData) => {
    try {
      const { data, error } = await supabase
        .from('categories')
        .update(categoryData)
        .eq('id', id)
        .select();
        
      if (error) throw error;
      return { data: data[0] };
    } catch (error) {
      console.error('Error updating category:', error);
      
      // Try fallback to API
      try {
        const response = await api.put(`/categories/${id}`, categoryData);
        return { data: response.data };
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        throw error;
      }
    }
  },
  
  delete: async (id) => {
    try {
      const { error } = await supabase
        .from('categories')
        .delete()
        .eq('id', id);
        
      if (error) throw error;
      return { success: true };
    } catch (error) {
      console.error('Error deleting category:', error);
      
      // Try fallback to API
      try {
        await api.delete(`/categories/${id}`);
        return { success: true };
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        throw error;
      }
    }
  }
};

// Ratings API service
export const ratingsApi = {
  getByType: async (type, page = 1) => {
    try {
      const { data, error } = await supabase
        .from('ratings')
        .select('*')
        .eq('to_type', type)
        .order('created_at', { ascending: false })
        .range((page - 1) * 10, page * 10 - 1);

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error fetching ratings:', error);
      return [];
    }
  },

  add: async (ratingData) => {
    try {
      const { data, error } = await supabase
        .from('ratings')
        .insert([ratingData])
        .select();

      if (error) throw error;
      return data[0];
    } catch (error) {
      console.error('Error adding rating:', error);
      throw error;
    }
  },

  getReport: async (type, year) => {
    try {
      // Try to use Supabase RPC function
      const { data, error } = await supabase.rpc('get_ratings_report', {
        p_type: type,
        p_year: year
      });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error fetching ratings report:', error);
      
      // Try fallback to API
      try {
        const response = await api.get(`/ratings/report/${type}/${year}`);
        return response.data;
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        return null;
      }
    }
  }
};

// API Key services
export const apiKeyApi = {
  validate: async (consumerKey, consumerSecret) => {
    try {
      const response = await api.post('/api-keys/validate', {
        consumer_key: consumerKey,
        consumer_secret: consumerSecret
      });
      return response.data;
    } catch (error) {
      console.error('Error validating API key:', error);
      return { valid: false };
    }
  },
  
  checkPermission: async (consumerKey, permission) => {
    try {
      const response = await api.post('/api-keys/check-permission', {
        consumer_key: consumerKey,
        permission
      });
      return response.data;
    } catch (error) {
      console.error('Error checking API key permission:', error);
      return { has_permission: false };
    }
  }
};

// Advertisements API service
export const advertisementsApi = {
  getAll: async () => {
    try {
      const { data, error } = await supabase
        .from('advertisements')
        .select(`
          *,
          vendor:vendor_id(*)
        `);
        
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error fetching advertisements:', error);
      
      // Try fallback to API
      try {
        const response = await api.get('/advertisements');
        return response.data;
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        return null;
      }
    }
  },
  
  create: async (adData) => {
    try {
      const { data, error } = await supabase
        .from('advertisements')
        .insert([adData])
        .select();
        
      if (error) throw error;
      return data[0];
    } catch (error) {
      console.error('Error creating advertisement:', error);
      
      // Try fallback to API
      try {
        const response = await api.post('/advertisements', adData);
        return response.data;
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        throw error;
      }
    }
  },
  
  update: async (id, adData) => {
    try {
      const { data, error } = await supabase
        .from('advertisements')
        .update(adData)
        .eq('id', id)
        .select();
        
      if (error) throw error;
      return data[0];
    } catch (error) {
      console.error('Error updating advertisement:', error);
      
      // Try fallback to API
      try {
        const response = await api.put(`/advertisements/${id}`, adData);
        return response.data;
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        throw error;
      }
    }
  },
  
  delete: async (id) => {
    try {
      const { error } = await supabase
        .from('advertisements')
        .delete()
        .eq('id', id);
        
      if (error) throw error;
      return { success: true };
    } catch (error) {
      console.error('Error deleting advertisement:', error);
      
      // Try fallback to API
      try {
        await api.delete(`/advertisements/${id}`);
        return { success: true };
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        throw error;
      }
    }
  }
};

// Financial API service
export const financialApi = {
  getSummary: async () => {
    try {
      // Try to use Supabase RPC function
      const { data, error } = await supabase.rpc('get_financial_summary');
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error fetching financial summary:', error);
      
      // Try fallback to API
      try {
        const response = await api.get('/financial/summary');
        return response.data;
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        return null;
      }
    }
  },
  
  getAdminCommissions: async () => {
    try {
      // Try fallback to API
      const response = await api.get('/financial/commissions');
      return response.data;
    } catch (error) {
      console.error('Error fetching admin commissions:', error);
      return null;
    }
  },
  
  getVendorBalances: async () => {
    try {
      // Try fallback to API
      const response = await api.get('/financial/vendor-balances');
      return response.data;
    } catch (error) {
      console.error('Error fetching vendor balances:', error);
      return null;
    }
  },
  
  getDriverBalances: async () => {
    try {
      // Try fallback to API
      const response = await api.get('/financial/driver-balances');
      return response.data;
    } catch (error) {
      console.error('Error fetching driver balances:', error);
      return null;
    }
  }
};

// Supabase API services
export const authApi = {
  login: async (credentials) => {
    try {
      // Try to use API key authentication
      const { consumer_key, consumer_secret } = credentials;
      
      if (consumer_key && consumer_secret) {
        const { valid } = await apiKeyApi.validate(consumer_key, consumer_secret);
        
        if (valid) {
          // Store API key in localStorage
          localStorage.setItem('apiKey', JSON.stringify({
            consumer_key,
            consumer_secret
          }));
          
          // Return mock user data
          return {
            user: {
              id: '00000000-0000-0000-0000-000000000001',
              email: 'api@example.com',
              role: 'api',
              name: 'API User'
            }
          };
        }
      }
      
      // Fall back to regular authentication
      const { email, password } = credentials;
      
      // Try to use Supabase
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password
      });
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error logging in:', error);
      
      // Try fallback to API
      try {
        const response = await api.post('/auth/login', credentials);
        return response.data;
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        throw error;
      }
    }
  },
  
  logout: async () => {
    try {
      // Remove API key from localStorage
      localStorage.removeItem('apiKey');
      
      // Try to use Supabase
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
      return { success: true };
    } catch (error) {
      console.error('Error logging out:', error);
      
      // Try fallback to API
      try {
        await api.post('/auth/logout');
        return { success: true };
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        throw error;
      }
    }
  },
  
  register: async (userData) => {
    try {
      // Try to use Supabase
      const { data, error } = await supabase.auth.signUp({
        email: userData.email,
        password: userData.password
      });
      
      if (error) throw error;
      
      // Create profile
      if (data.user) {
        const { error: profileError } = await supabase
          .from('profiles')
          .insert([
            {
              id: data.user.id,
              name: userData.name,
              role: userData.role || 'customer',
              ...userData
            }
          ]);
          
        if (profileError) throw profileError;
      }
      
      return data;
    } catch (error) {
      console.error('Error registering:', error);
      
      // Try fallback to API
      try {
        const response = await api.post('/auth/register', userData);
        return response.data;
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        throw error;
      }
    }
  },
  
  getCurrentUser: async () => {
    try {
      // Check if we're using API key authentication
      const apiKey = localStorage.getItem('apiKey');
      
      if (apiKey) {
        // Return mock user data for API key authentication
        return {
          id: '00000000-0000-0000-0000-000000000001',
          email: 'api@example.com',
          role: 'api',
          name: 'API User'
        };
      }
      
      // Try to use Supabase
      const { data, error } = await supabase.auth.getUser();
      if (error) throw error;
      
      if (data.user) {
        const { data: profile, error: profileError } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', data.user.id)
          .single();
          
        if (profileError) throw profileError;
        
        return { ...data.user, ...profile };
      }
      
      return null;
    } catch (error) {
      console.error('Error getting current user:', error);
      
      // Try fallback to API
      try {
        const response = await api.get('/auth/me');
        return response.data;
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        return null;
      }
    }
  }
};

// Products API service
export const productsApi = {
  getAll: async () => {
    try {
      const { data, error } = await supabase
        .from('products')
        .select(`
          *,
          vendor:vendor_id(store_name),
          category:category_id(name)
        `);
        
      if (error) throw error;
      return { data };
    } catch (error) {
      console.error('Error fetching products:', error);
      
      // Try fallback to API
      try {
        const response = await api.get('/products');
        return { data: response.data };
      } catch (apiError) {
        console.error('API fallback error:', apiError);
        
        // Fallback to mock data
        return { 
          data: [
            { 
              id: 1, 
              name: 'قهوة تركية', 
              description: 'قهوة تركية أصلية', 
              price: 15,
              vendor: { store_name: 'متجر كوفي' },
              category: { name: 'مشروبات ساخنة' }
            },
            { 
              id: 2, 
              name: 'شاي أخضر', 
              description: 'شاي أخضر صيني', 
              price: 10,
              vendor: { store_name: 'متجر الشاي' },
              category: { name: 'مشروبات ساخنة' }
            }
          ]
        };
      }
    }
  }
};

// Export all APIs
export default {
  auth: authApi,
  categories: categoriesApi,
  apiKey: apiKeyApi,
  ratings: ratingsApi,
  advertisements: advertisementsApi,
  financial: financialApi,
  products: productsApi
};