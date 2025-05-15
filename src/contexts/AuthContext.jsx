import React, { createContext, useContext, useState, useEffect } from 'react';
import { toast } from 'react-toastify';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Check if user is already logged in
    const checkUser = async () => {
      try {
        setLoading(true);
        
        // Check if we have a user in localStorage (for demo purposes)
        const savedUserData = localStorage.getItem('userData');
        if (savedUserData) {
          try {
            const parsedUser = JSON.parse(savedUserData);
            setUser(parsedUser);
          } catch (e) {
            // Invalid JSON, remove it
            localStorage.removeItem('userData');
          }
        }
      } catch (error) {
        console.error('Error checking user:', error);
      } finally {
        setLoading(false);
      }
    };
    
    checkUser();
  }, []);

  const login = async (email, password) => {
    try {
      setLoading(true);
      
      // For development/demo purposes, allow mock login
      if (email === 'admin@example.com' || email === 'admin') {
        const userData = {
          id: '00000000-0000-0000-0000-000000000001',
          name: 'مدير النظام',
          email: 'admin@example.com',
          role: 'admin'
        };
        
        setUser(userData);
        
        // Store user data in localStorage for persistence
        localStorage.setItem('userData', JSON.stringify(userData));
        
        // Save credentials if rememberMe is checked
        if (localStorage.getItem('rememberMe') === 'true') {
          localStorage.setItem('rememberedEmail', email);
        }
        
        toast.success('تم تسجيل الدخول بنجاح');
        return userData;
      } else {
        throw new Error('بيانات الدخول غير صحيحة');
      }
    } catch (error) {
      console.error('Login error:', error);
      toast.error(error.message || 'فشل تسجيل الدخول');
      throw error;
    } finally {
      setLoading(false);
    }
  };

  const logout = async () => {
    try {
      setLoading(true);
      
      setUser(null);
      
      // Remove user data from localStorage
      localStorage.removeItem('userData');
      
      toast.info('تم تسجيل الخروج بنجاح');
    } catch (error) {
      console.error('Logout error:', error);
      toast.error('فشل تسجيل الخروج');
    } finally {
      setLoading(false);
    }
  };

  const isAuthenticated = () => {
    // Check if user is set in state
    if (user) return true;
    
    // If not in state, check localStorage as fallback
    const savedUserData = localStorage.getItem('userData');
    if (savedUserData) {
      try {
        const parsedUser = JSON.parse(savedUserData);
        // Set the user in state if found in localStorage
        if (!user) {
          setUser(parsedUser);
        }
        return true;
      } catch (e) {
        localStorage.removeItem('userData');
        return false;
      }
    }
    
    return false;
  };

  return (
    <AuthContext.Provider value={{ 
      user, 
      login, 
      logout,
      loading, 
      isAuthenticated
    }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export default AuthContext;