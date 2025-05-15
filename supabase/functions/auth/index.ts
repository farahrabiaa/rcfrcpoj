import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

// CORS headers
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
};

// Create a Supabase client
const supabaseClient = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
);

// Generate a random token
function generateToken(length = 64) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let token = '';
  const array = new Uint8Array(length);
  crypto.getRandomValues(array);
  for (let i = 0; i < length; i++) {
    token += chars[array[i] % chars.length];
  }
  return token;
}

// Handle requests
serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: corsHeaders,
      status: 204,
    });
  }

  // Get the path and method
  const url = new URL(req.url);
  const path = url.pathname.replace('/auth', '');
  const method = req.method;

  try {
    // Login endpoint
    if (path === '/login' && method === 'POST') {
      const { email, password } = await req.json();
      
      // Validate input
      if (!email || !password) {
        return new Response(
          JSON.stringify({ error: 'Email and password are required' }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          }
        );
      }
      
      // Sign in with Supabase
      const { data, error } = await supabaseClient.auth.signInWithPassword({
        email,
        password,
      });
      
      if (error) {
        return new Response(
          JSON.stringify({ error: error.message }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 401,
          }
        );
      }
      
      // Get user profile
      const { data: profile, error: profileError } = await supabaseClient
        .from('profiles')
        .select('*')
        .eq('id', data.user.id)
        .single();
      
      if (profileError) {
        console.error('Error fetching profile:', profileError);
      }
      
      // Generate a token
      const token = generateToken();
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 7); // 7 days from now
      
      // Return user data and token
      return new Response(
        JSON.stringify({
          user: {
            id: data.user.id,
            email: data.user.email,
            role: profile?.role || 'customer',
            name: profile?.name || data.user.email,
            ...profile
          },
          token,
          expires_at: expiresAt.toISOString()
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Register endpoint
    if (path === '/register' && method === 'POST') {
      const { email, password, name, role } = await req.json();
      
      // Validate input
      if (!email || !password || !name) {
        return new Response(
          JSON.stringify({ error: 'Email, password, and name are required' }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          }
        );
      }
      
      // Sign up with Supabase
      const { data, error } = await supabaseClient.auth.signUp({
        email,
        password,
      });
      
      if (error) {
        return new Response(
          JSON.stringify({ error: error.message }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          }
        );
      }
      
      // Create profile
      if (data.user) {
        const { error: profileError } = await supabaseClient
          .from('profiles')
          .insert([
            {
              id: data.user.id,
              name,
              role: role || 'customer',
            }
          ]);
        
        if (profileError) {
          console.error('Error creating profile:', profileError);
          return new Response(
            JSON.stringify({ error: 'Error creating user profile' }),
            {
              headers: { ...corsHeaders, "Content-Type": "application/json" },
              status: 500,
            }
          );
        }
      }
      
      // Generate a token
      const token = generateToken();
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 7); // 7 days from now
      
      // Return user data and token
      return new Response(
        JSON.stringify({
          user: {
            id: data.user.id,
            email: data.user.email,
            role: role || 'customer',
            name
          },
          token,
          expires_at: expiresAt.toISOString()
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 201,
        }
      );
    }
    
    // Get current user endpoint
    if (path === '/me' && method === 'GET') {
      // Get authorization header
      const authHeader = req.headers.get('Authorization');
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return new Response(
          JSON.stringify({ error: 'Unauthorized' }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 401,
          }
        );
      }
      
      // Extract token
      const token = authHeader.split(' ')[1];
      
      // In a real app, you would validate the token here
      // For this example, we'll just return a mock user
      
      return new Response(
        JSON.stringify({
          id: '123',
          email: 'user@example.com',
          role: 'admin',
          name: 'مستخدم النظام'
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Logout endpoint
    if (path === '/logout' && method === 'POST') {
      // In a real app, you would invalidate the token here
      
      return new Response(
        JSON.stringify({ message: 'تم تسجيل الخروج بنجاح' }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Default response for unhandled endpoints
    return new Response(
      JSON.stringify({ error: 'Endpoint not found' }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 404,
      }
    );
    
  } catch (error) {
    console.error(error);
    
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});