import React, { createContext, useContext, useState, useEffect } from 'react';
import { toast } from 'react-toastify';

const SettingsContext = createContext(null);

const DEFAULT_SETTINGS = {
  store: {
    name: 'متجر خدماتكم',
    description: 'نظام متكامل لإدارة المتجر',
    email: 'info@example.com',
    phone: '0599123456',
    address: 'غزة، فلسطين',
    logo: '/logo.svg',
    currency: 'ILS',
    language: 'ar'
  },
  social: {
    facebook: '',
    twitter: '',
    instagram: '',
    whatsapp: ''
  },
  notifications: {
    email: true,
    sms: false,
    push: true
  },
  login: {
    logo: '/logo.svg',
    background: '/login-bg.jpg'
  }
};

export const SettingsProvider = ({ children }) => {
  const [settings, setSettings] = useState(DEFAULT_SETTINGS);
  const [loading, setLoading] = useState(true);

  // Fetch settings from localStorage on initial load
  useEffect(() => {
    const savedSettings = localStorage.getItem('appSettings');
    if (savedSettings) {
      try {
        setSettings(JSON.parse(savedSettings));
      } catch (error) {
        console.error('Error parsing saved settings:', error);
        setSettings(DEFAULT_SETTINGS);
      }
    }
    setLoading(false);
  }, []);

  const saveSettings = async (newSettings) => {
    try {
      setLoading(true);
      
      // Save to localStorage
      localStorage.setItem('appSettings', JSON.stringify(newSettings));
      setSettings(newSettings);
      
      toast.success('تم حفظ الإعدادات بنجاح');
      return true;
    } catch (error) {
      console.error('Error saving settings:', error);
      toast.error('فشل في حفظ الإعدادات');
      return false;
    } finally {
      setLoading(false);
    }
  };

  const updateStoreName = async (name) => {
    try {
      const newSettings = {
        ...settings,
        store: {
          ...settings.store,
          name
        }
      };
      
      const success = await saveSettings(newSettings);
      return success;
    } catch (error) {
      console.error('Error updating store name:', error);
      return false;
    }
  };

  return (
    <SettingsContext.Provider value={{ 
      settings, 
      loading, 
      saveSettings,
      updateStoreName
    }}>
      {children}
    </SettingsContext.Provider>
  );
};

export const useSettings = () => {
  const context = useContext(SettingsContext);
  if (!context) {
    throw new Error('useSettings must be used within a SettingsProvider');
  }
  return context;
};

export default SettingsContext;