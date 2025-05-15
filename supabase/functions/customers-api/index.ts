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
  const path = url.pathname.replace('/customers-api', '');
  const method = req.method;

  try {
    // Get all customers
    if (path === '/customers' && method === 'GET') {
      // Use a raw SQL query to avoid the relationship issue
      const { data, error } = await supabaseClient.rpc('get_all_customers');
      
      if (error) throw error;
      
      return new Response(
        JSON.stringify(data),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Get customer by ID
    if (path.match(/\/customers\/\w+/) && method === 'GET') {
      const id = path.split('/').pop();
      
      const { data, error } = await supabaseClient
        .from('customers')
        .select('*')
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
    
    // Create new customer
    if (path === '/customers' && method === 'POST') {
      const body = await req.json();
      
      const { data, error } = await supabaseClient
        .from('customers')
        .insert([body])
        .select();
      
      if (error) throw error;
      
      return new Response(
        JSON.stringify(data[0]),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 201,
        }
      );
    }
    
    // Update customer
    if (path.match(/\/customers\/\w+/) && method === 'PUT') {
      const id = path.split('/').pop();
      const body = await req.json();
      
      const { data, error } = await supabaseClient
        .from('customers')
        .update(body)
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
    
    // Delete customer
    if (path.match(/\/customers\/\w+/) && method === 'DELETE') {
      const id = path.split('/').pop();
      
      const { error } = await supabaseClient
        .from('customers')
        .delete()
        .eq('id', id);
      
      if (error) throw error;
      
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