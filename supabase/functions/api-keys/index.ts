import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import * as CryptoJS from "https://esm.sh/crypto-js@4.2.0";

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

// Validate API key
async function validateApiKey(consumerKey: string, consumerSecret: string) {
  try {
    // Get the API key from the database
    const { data, error } = await supabaseClient
      .from('api_keys')
      .select('*')
      .eq('consumer_key', consumerKey)
      .eq('status', 'active')
      .single();
    
    if (error || !data) return false;
    
    // Verify the secret
    const secretHash = CryptoJS.SHA256(consumerSecret).toString(CryptoJS.enc.Hex);
    const isValid = secretHash === data.consumer_secret_hash;
    
    if (isValid) {
      // Update last_used timestamp
      await supabaseClient
        .from('api_keys')
        .update({ last_used: new Date().toISOString() })
        .eq('id', data.id);
    }
    
    return isValid;
  } catch (error) {
    console.error('Error validating API key:', error);
    return false;
  }
}

// Check API key permissions
async function checkApiKeyPermission(consumerKey: string, permission: string) {
  try {
    const { data, error } = await supabaseClient
      .from('api_keys')
      .select('permissions')
      .eq('consumer_key', consumerKey)
      .eq('status', 'active')
      .single();
    
    if (error || !data) return false;
    
    return data.permissions.includes(permission);
  } catch (error) {
    console.error('Error checking API key permission:', error);
    return false;
  }
}

// Extract API key from request
function extractApiKey(req: Request) {
  // Check for Authorization header
  const authHeader = req.headers.get('Authorization');
  if (authHeader && authHeader.startsWith('Basic ')) {
    try {
      const base64Credentials = authHeader.split(' ')[1];
      const credentials = atob(base64Credentials).split(':');
      return {
        consumerKey: credentials[0],
        consumerSecret: credentials[1]
      };
    } catch (error) {
      console.error('Error extracting API key from Authorization header:', error);
    }
  }
  
  // Check for query parameters
  const url = new URL(req.url);
  const consumerKey = url.searchParams.get('consumer_key');
  const consumerSecret = url.searchParams.get('consumer_secret');
  
  if (consumerKey && consumerSecret) {
    return { consumerKey, consumerSecret };
  }
  
  return null;
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
  const path = url.pathname.replace('/api-keys', '');
  const method = req.method;

  try {
    // Validate endpoint
    if (path === '/validate' && method === 'POST') {
      const { consumer_key, consumer_secret } = await req.json();
      
      if (!consumer_key || !consumer_secret) {
        return new Response(
          JSON.stringify({ error: 'Consumer key and secret are required' }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          }
        );
      }
      
      const isValid = await validateApiKey(consumer_key, consumer_secret);
      
      return new Response(
        JSON.stringify({ valid: isValid }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Check permission endpoint
    if (path === '/check-permission' && method === 'POST') {
      const { consumer_key, permission } = await req.json();
      
      if (!consumer_key || !permission) {
        return new Response(
          JSON.stringify({ error: 'Consumer key and permission are required' }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          }
        );
      }
      
      const hasPermission = await checkApiKeyPermission(consumer_key, permission);
      
      return new Response(
        JSON.stringify({ has_permission: hasPermission }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Protected endpoints - require API key validation
    const apiKey = extractApiKey(req);
    
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'API key is required' }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 401,
        }
      );
    }
    
    const isValid = await validateApiKey(apiKey.consumerKey, apiKey.consumerSecret);
    
    if (!isValid) {
      return new Response(
        JSON.stringify({ error: 'Invalid API key' }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 401,
        }
      );
    }
    
    // Check required permissions based on method
    let requiredPermission = 'read';
    if (method === 'POST') requiredPermission = 'write';
    if (method === 'PUT' || method === 'PATCH') requiredPermission = 'write';
    if (method === 'DELETE') requiredPermission = 'delete';
    
    const hasPermission = await checkApiKeyPermission(apiKey.consumerKey, requiredPermission);
    
    if (!hasPermission) {
      return new Response(
        JSON.stringify({ error: `API key does not have ${requiredPermission} permission` }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 403,
        }
      );
    }
    
    // Example protected endpoints
    if (path === '/categories' && method === 'GET') {
      const { data, error } = await supabaseClient
        .from('categories')
        .select('*');
      
      if (error) throw error;
      
      return new Response(
        JSON.stringify(data),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    if (path === '/products' && method === 'GET') {
      const { data, error } = await supabaseClient
        .from('products')
        .select('*');
      
      if (error) throw error;
      
      return new Response(
        JSON.stringify(data),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    if (path === '/vendors' && method === 'GET') {
      const { data, error } = await supabaseClient
        .from('vendors')
        .select('*');
      
      if (error) throw error;
      
      return new Response(
        JSON.stringify(data),
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