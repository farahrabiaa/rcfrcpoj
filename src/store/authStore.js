import { create } from 'zustand';
import { supabase } from '../lib/supabase';

export const useAuthStore = create((set) => ({
  user: null,
  loading: true,
  error: null,
  
  // Initialize auth state
  init: async () => {
    try {
      set({ loading: true });
      
      // Check if user is already logged in
      const { data: { session }, error } = await supabase.auth.getSession();
      
      if (error) throw error;
      
      if (session?.user) {
        // Get user profile
        const { data: profile, error: profileError } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', session.user.id)
          .single();
          
        if (profileError && profileError.code !== 'PGRST116') {
          console.error('Error fetching profile:', profileError);
        }
        
        set({ 
          user: { 
            ...session.user,
            ...profile
          },
          loading: false 
        });
      } else {
        set({ user: null, loading: false });
      }
    } catch (error) {
      console.error('Auth initialization error:', error);
      set({ error, loading: false });
    }
  },
  
  // Sign in
  signIn: async (email, password) => {
    try {
      set({ loading: true });
      
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password
      });
      
      if (error) throw error;
      
      // Get user profile
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', data.user.id)
        .single();
        
      if (profileError && profileError.code !== 'PGRST116') {
        console.error('Error fetching profile:', profileError);
      }
      
      set({ 
        user: { 
          ...data.user,
          ...profile
        },
        loading: false 
      });
      
      return data.user;
    } catch (error) {
      console.error('Sign in error:', error);
      set({ error, loading: false });
      throw error;
    }
  },
  
  // Sign out
  signOut: async () => {
    try {
      set({ loading: true });
      
      const { error } = await supabase.auth.signOut();
      
      if (error) throw error;
      
      set({ user: null, loading: false });
    } catch (error) {
      console.error('Sign out error:', error);
      set({ error, loading: false });
      throw error;
    }
  },
  
  // Update user
  updateUser: (userData) => {
    set({ user: { ...userData } });
  }
}));