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
    const secretHash = await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(consumerSecret)
    );
    const hashHex = Array.from(new Uint8Array(secretHash))
      .map(b => b.toString(16).padStart(2, "0"))
      .join("");
    
    const isValid = hashHex === data.consumer_secret_hash;
    
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
  const path = url.pathname.replace('/drivers-api', '');
  const method = req.method;

  try {
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
    
    // Get all drivers
    if (path === '/drivers' && method === 'GET') {
      const { data, error } = await supabaseClient
        .from('drivers')
        .select(`
          *,
          user:user_id(*)
        `)
        .order('created_at', { ascending: false });
      
      if (error) throw error;
      
      return new Response(
        JSON.stringify(data),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Get driver by ID
    if (path.match(/\/drivers\/\w+/) && method === 'GET') {
      const id = path.split('/').pop();
      
      const { data, error } = await supabaseClient
        .from('drivers')
        .select(`
          *,
          user:user_id(*)
        `)
        .eq('id', id)
        .single();
      
      if (error) throw error;
      
      return new Response(
        JSON.stringify(data),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Get available drivers
    if (path === '/drivers/available' && method === 'GET') {
      const { data, error } = await supabaseClient
        .from('drivers')
        .select(`
          *,
          user:user_id(*)
        `)
        .eq('status', 'available')
        .order('rating', { ascending: false });
      
      if (error) throw error;
      
      return new Response(
        JSON.stringify(data),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Get drivers by area
    if (path === '/drivers/by-area' && method === 'GET') {
      const area = url.searchParams.get('area');
      
      if (!area) {
        return new Response(
          JSON.stringify({ error: 'Area parameter is required' }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          }
        );
      }
      
      const { data, error } = await supabaseClient.rpc(
        'get_available_drivers_for_area',
        { p_area: area }
      );
      
      if (error) throw error;
      
      return new Response(
        JSON.stringify(data),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Update driver location
    if (path.match(/\/drivers\/\w+\/location/) && method === 'PUT') {
      const id = path.split('/')[2];
      const body = await req.json();
      
      const { latitude, longitude } = body;
      
      if (!latitude || !longitude) {
        return new Response(
          JSON.stringify({ error: 'Latitude and longitude are required' }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          }
        );
      }
      
      const { data, error } = await supabaseClient
        .from('drivers')
        .update({
          latitude,
          longitude,
          last_location_update: new Date().toISOString()
        })
        .eq('id', id)
        .select();
      
      if (error) throw error;
      
      return new Response(
        JSON.stringify(data[0]),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Update driver status
    if (path.match(/\/drivers\/\w+\/status/) && method === 'PUT') {
      const id = path.split('/')[2];
      const body = await req.json();
      
      const { status } = body;
      
      if (!status || !['offline', 'available', 'busy'].includes(status)) {
        return new Response(
          JSON.stringify({ error: 'Valid status is required (offline, available, busy)' }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          }
        );
      }
      
      const { data, error } = await supabaseClient
        .from('drivers')
        .update({ status })
        .eq('id', id)
        .select();
      
      if (error) throw error;
      
      return new Response(
        JSON.stringify(data[0]),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Create new driver
    if (path === '/drivers' && method === 'POST') {
      const body = await req.json();
      
      // Validate required fields
      if (!body.name || !body.phone || !body.username || !body.password) {
        return new Response(
          JSON.stringify({ error: 'Name, phone, username and password are required' }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          }
        );
      }
      
      // 1. Create custom user
      const { data: userData, error: userError } = await supabaseClient.rpc(
        'add_custom_user',
        {
          p_username: body.username,
          p_password: body.password,
          p_name: body.name,
          p_email: body.email || null,
          p_phone: body.phone,
          p_role: 'driver'
        }
      );
      
      if (userError) throw userError;
      
      // 2. Create driver
      const { data: driverData, error: driverError } = await supabaseClient
        .from('drivers')
        .insert([{
          user_id: userData,
          name: body.name,
          phone: body.phone,
          email: body.email,
          status: body.status || 'offline',
          commission_rate: body.commission_rate || 15,
          vehicle_type: body.vehicle_type || 'motorcycle',
          vehicle_model: body.vehicle_model,
          vehicle_year: body.vehicle_year,
          vehicle_plate: body.vehicle_plate,
          working_areas: body.working_areas || []
        }])
        .select();
      
      if (driverError) throw driverError;
      
      return new Response(
        JSON.stringify(driverData[0]),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 201,
        }
      );
    }
    
    // Update driver
    if (path.match(/\/drivers\/\w+/) && method === 'PUT') {
      const id = path.split('/').pop();
      const body = await req.json();
      
      // Validate required fields
      if (!body.name || !body.phone) {
        return new Response(
          JSON.stringify({ error: 'Name and phone are required' }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          }
        );
      }
      
      // Get driver to get user_id
      const { data: driverData, error: driverGetError } = await supabaseClient
        .from('drivers')
        .select('user_id')
        .eq('id', id)
        .single();
      
      if (driverGetError) throw driverGetError;
      
      // 1. Update custom user
      const { error: userError } = await supabaseClient
        .from('custom_users')
        .update({
          name: body.name,
          email: body.email,
          phone: body.phone,
          updated_at: new Date().toISOString()
        })
        .eq('id', driverData.user_id);
      
      if (userError) throw userError;
      
      // If password is provided, update it
      if (body.password) {
        const { data: hashData, error: hashError } = await supabaseClient.rpc(
          'hash_password',
          { password: body.password }
        );
        
        if (hashError) throw hashError;
        
        const { error: passwordError } = await supabaseClient
          .from('custom_users')
          .update({ password_hash: hashData })
          .eq('id', driverData.user_id);
        
        if (passwordError) throw passwordError;
      }
      
      // 2. Update driver
      const { data: updatedDriver, error: driverError } = await supabaseClient
        .from('drivers')
        .update({
          name: body.name,
          phone: body.phone,
          email: body.email,
          status: body.status,
          commission_rate: body.commission_rate,
          vehicle_type: body.vehicle_type,
          vehicle_model: body.vehicle_model,
          vehicle_year: body.vehicle_year,
          vehicle_plate: body.vehicle_plate,
          working_areas: body.working_areas,
          updated_at: new Date().toISOString()
        })
        .eq('id', id)
        .select();
      
      if (driverError) throw driverError;
      
      return new Response(
        JSON.stringify(updatedDriver[0]),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Delete driver
    if (path.match(/\/drivers\/\w+/) && method === 'DELETE') {
      const id = path.split('/').pop();
      
      // Get driver to get user_id
      const { data: driverData, error: driverGetError } = await supabaseClient
        .from('drivers')
        .select('user_id')
        .eq('id', id)
        .single();
      
      if (driverGetError) throw driverGetError;
      
      // 1. Delete driver
      const { error: driverError } = await supabaseClient
        .from('drivers')
        .delete()
        .eq('id', id);
      
      if (driverError) throw driverError;
      
      // 2. Delete custom user
      const { error: userError } = await supabaseClient
        .from('custom_users')
        .delete()
        .eq('id', driverData.user_id);
      
      if (userError) throw userError;
      
      return new Response(
        JSON.stringify({ success: true }),
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