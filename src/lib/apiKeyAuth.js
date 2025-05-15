/**
 * API Key Authentication Module
 * 
 * This module provides functions for working with API keys for authentication.
 */

/**
 * Get the stored API key from localStorage
 * @returns {Object|null} - The API key object or null if not found
 */
export const getApiKey = () => {
  try {
    const apiKey = localStorage.getItem('apiKey');
    if (!apiKey) return null;
    
    return JSON.parse(apiKey);
  } catch (error) {
    console.error('Error getting API key:', error);
    return null;
  }
};

/**
 * Store an API key in localStorage
 * @param {Object} apiKey - The API key object with consumer_key and consumer_secret
 */
export const storeApiKey = (apiKey) => {
  try {
    localStorage.setItem('apiKey', JSON.stringify(apiKey));
  } catch (error) {
    console.error('Error storing API key:', error);
  }
};

/**
 * Remove the stored API key from localStorage
 */
export const removeApiKey = () => {
  localStorage.removeItem('apiKey');
};

/**
 * Check if an API key is stored
 * @returns {boolean} - True if an API key is stored, false otherwise
 */
export const hasApiKey = () => {
  return getApiKey() !== null;
};

/**
 * Set API key authentication headers
 * @param {Object} headers - The headers object to modify
 * @param {Object} apiKey - The API key object with consumer_key and consumer_secret
 * @returns {Object} - The modified headers object
 */
export const setApiKeyHeaders = (headers = {}, apiKey = getApiKey()) => {
  if (!apiKey) return headers;
  
  const { consumer_key, consumer_secret } = apiKey;
  const credentials = btoa(`${consumer_key}:${consumer_secret}`);
  
  return {
    ...headers,
    'Authorization': `Basic ${credentials}`
  };
};

/**
 * Create URL with API key parameters
 * @param {string} url - The base URL
 * @param {Object} apiKey - The API key object with consumer_key and consumer_secret
 * @returns {string} - The URL with API key parameters
 */
export const createApiKeyUrl = (url, apiKey = getApiKey()) => {
  if (!apiKey) return url;
  
  const { consumer_key, consumer_secret } = apiKey;
  const separator = url.includes('?') ? '&' : '?';
  
  return `${url}${separator}consumer_key=${consumer_key}&consumer_secret=${consumer_secret}`;
};

export default {
  getApiKey,
  storeApiKey,
  removeApiKey,
  hasApiKey,
  setApiKeyHeaders,
  createApiKeyUrl
};