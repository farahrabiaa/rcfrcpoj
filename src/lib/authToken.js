import { supabase } from './supabase';
import CryptoJS from 'crypto-js';

/**
 * Generate a new authentication token
 * @returns {string} - The generated token
 */
export const generateToken = () => {
  // Generate a random string for the token
  const randomBytes = new Uint8Array(32);
  window.crypto.getRandomValues(randomBytes);
  return Array.from(randomBytes)
    .map(byte => byte.toString(16).padStart(2, '0'))
    .join('');
};

/**
 * Store the authentication token in localStorage
 * @param {string} token - The token to store
 * @param {number} expiresIn - Token expiration time in seconds (default: 7 days)
 */
export const storeToken = (token, expiresIn = 7 * 24 * 60 * 60) => {
  const expiresAt = new Date().getTime() + expiresIn * 1000;
  localStorage.setItem('authToken', token);
  localStorage.setItem('tokenExpiry', expiresAt.toString());
};

/**
 * Get the stored authentication token
 * @returns {string|null} - The stored token or null if not found or expired
 */
export const getToken = () => {
  const token = localStorage.getItem('authToken');
  const expiresAt = localStorage.getItem('tokenExpiry');
  
  if (!token || !expiresAt) {
    return null;
  }
  
  // Check if token is expired
  if (new Date().getTime() > parseInt(expiresAt)) {
    removeToken();
    return null;
  }
  
  return token;
};

/**
 * Remove the stored authentication token
 */
export const removeToken = () => {
  localStorage.removeItem('authToken');
  localStorage.removeItem('tokenExpiry');
};

/**
 * Check if the token is valid
 * @returns {boolean} - True if the token is valid, false otherwise
 */
export const isTokenValid = () => {
  return getToken() !== null;
};

/**
 * Refresh the token expiration time
 * @param {number} expiresIn - Token expiration time in seconds (default: 7 days)
 */
export const refreshToken = (expiresIn = 7 * 24 * 60 * 60) => {
  const token = getToken();
  if (token) {
    storeToken(token, expiresIn);
  }
};

/**
 * Set the token in the request headers
 * @param {Object} headers - The headers object to modify
 * @returns {Object} - The modified headers object
 */
export const setAuthHeaders = (headers = {}) => {
  const token = getToken();
  if (token) {
    return {
      ...headers,
      'Authorization': `Bearer ${token}`
    };
  }
  return headers;
};

export default {
  generateToken,
  storeToken,
  getToken,
  removeToken,
  isTokenValid,
  refreshToken,
  setAuthHeaders
};