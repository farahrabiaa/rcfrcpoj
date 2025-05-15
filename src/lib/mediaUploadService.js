import { supabase } from './supabase';
import { getApiKey, setApiKeyHeaders } from './apiKeyAuth';

// Base URL for API
const getBaseUrl = () => {
  // Check if we're in a production environment
  if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
    // Use Supabase Edge Function for API
    return `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/media-upload`;
  }
  
  // For local development, use the local API
  return '/api/media-upload';
};

/**
 * Upload a file to Supabase Storage
 * @param {File} file - The file to upload
 * @param {string} bucket - The bucket name
 * @param {string} folder - The folder path within the bucket
 * @returns {Promise<{path: string, url: string}>} - The file path and public URL
 */
export const uploadFile = async (file, bucket = 'general', folder = '') => {
  try {
    // Create form data
    const formData = new FormData();
    formData.append('file', file);
    formData.append('bucket', bucket);
    formData.append('folder', folder);
    
    // Get API key
    const apiKey = getApiKey();
    const headers = {};
    
    if (apiKey) {
      // Add API key authentication to headers
      Object.assign(headers, setApiKeyHeaders({}, apiKey));
    }
    
    // Upload the file
    const response = await fetch(`${getBaseUrl()}/upload`, {
      method: 'POST',
      headers,
      body: formData
    });
    
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'Error uploading file');
    }
    
    const data = await response.json();
    
    return {
      path: data.path,
      url: data.url,
      id: data.id,
      name: data.name,
      size: data.size,
      type: data.type
    };
  } catch (error) {
    console.error('Error uploading file:', error);
    
    // Fallback to direct Supabase Storage upload
    try {
      console.log('Falling back to direct Supabase Storage upload');
      
      // Create a unique file name
      const fileExt = file.name.split('.').pop();
      const fileName = `${Math.random().toString(36).substring(2, 15)}_${Date.now()}.${fileExt}`;
      
      // Create the full path
      const filePath = folder ? `${folder}/${fileName}` : fileName;
      
      // Upload the file
      const { data, error } = await supabase.storage
        .from(bucket)
        .upload(filePath, file, {
          cacheControl: '3600',
          upsert: false
        });
      
      if (error) throw error;
      
      // Get the public URL
      const { data: { publicUrl } } = supabase.storage
        .from(bucket)
        .getPublicUrl(filePath);
      
      return {
        path: data.path,
        url: publicUrl,
        name: file.name,
        size: file.size,
        type: file.type
      };
    } catch (fallbackError) {
      console.error('Fallback upload failed:', fallbackError);
      throw fallbackError;
    }
  }
};

/**
 * Delete a file from Supabase Storage
 * @param {string} path - The file path
 * @param {string} bucket - The bucket name
 * @returns {Promise<boolean>} - Success status
 */
export const deleteFile = async (path, bucket = 'general') => {
  try {
    // Get API key
    const apiKey = getApiKey();
    const headers = {
      'Content-Type': 'application/json'
    };
    
    if (apiKey) {
      // Add API key authentication to headers
      Object.assign(headers, setApiKeyHeaders(headers, apiKey));
    }
    
    // Try to delete using the API
    const response = await fetch(`${getBaseUrl()}/files/${path}`, {
      method: 'DELETE',
      headers
    });
    
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'Error deleting file');
    }
    
    return true;
  } catch (error) {
    console.error('Error deleting file:', error);
    
    // Fallback to direct Supabase Storage delete
    try {
      console.log('Falling back to direct Supabase Storage delete');
      
      const { error } = await supabase.storage
        .from(bucket)
        .remove([path]);
      
      if (error) throw error;
      
      return true;
    } catch (fallbackError) {
      console.error('Fallback delete failed:', fallbackError);
      throw fallbackError;
    }
  }
};

/**
 * List files in a bucket/folder
 * @param {string} bucket - The bucket name
 * @param {string} folder - The folder path within the bucket
 * @returns {Promise<Array>} - Array of files
 */
export const listFiles = async (bucket = 'general', folder = '') => {
  try {
    // Get API key
    const apiKey = getApiKey();
    const headers = {};
    
    if (apiKey) {
      // Add API key authentication to headers
      Object.assign(headers, setApiKeyHeaders(headers, apiKey));
    }
    
    // Try to list files using the API
    const response = await fetch(`${getBaseUrl()}/files?bucket=${bucket}&folder=${folder}`, {
      headers
    });
    
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'Error listing files');
    }
    
    const data = await response.json();
    
    return data.data || [];
  } catch (error) {
    console.error('Error listing files:', error);
    
    // Fallback to direct Supabase Storage list
    try {
      console.log('Falling back to direct Supabase Storage list');
      
      const { data, error } = await supabase.storage
        .from(bucket)
        .list(folder);
      
      if (error) throw error;
      
      return data || [];
    } catch (fallbackError) {
      console.error('Fallback list failed:', fallbackError);
      return [];
    }
  }
};

export default {
  uploadFile,
  deleteFile,
  listFiles
};