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
  const path = url.pathname.replace('/advertisements-api', '');
  const method = req.method;

  try {
    // Get all advertisements
    if (path === '/advertisements' && method === 'GET') {
      const position = url.searchParams.get('position');
      const active = url.searchParams.get('active') === 'true';
      
      let query = supabaseClient
        .from('advertisements')
        .select(`
          *,
          vendor:vendor_id(store_name)
        `);
      
      if (position) {
        query = query.eq('position', position);
      }
      
      if (active) {
        const today = new Date().toISOString().split('T')[0];
        query = query
          .eq('status', 'active')
          .lte('start_date', today)
          .gte('end_date', today);
      }
      
      query = query.order('priority', { ascending: true });
      
      const { data, error } = await query;
      
      if (error) throw error;
      
      return new Response(
        JSON.stringify(data),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Get advertisement by ID
    if (path.match(/\/advertisements\/\w+/) && method === 'GET') {
      const id = path.split('/').pop();
      
      const { data, error } = await supabaseClient
        .from('advertisements')
        .select(`
          *,
          vendor:vendor_id(store_name)
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
    
    // Record advertisement view
    if (path.match(/\/advertisements\/\w+\/view/) && method === 'POST') {
      const id = path.split('/')[2];
      
      await supabaseClient.rpc('increment_advertisement_views', { p_ad_id: id });
      
      return new Response(
        JSON.stringify({ success: true }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Record advertisement click
    if (path.match(/\/advertisements\/\w+\/click/) && method === 'POST') {
      const id = path.split('/')[2];
      
      await supabaseClient.rpc('increment_advertisement_clicks', { p_ad_id: id });
      
      // Get the advertisement to redirect to its link
      const { data, error } = await supabaseClient
        .from('advertisements')
        .select('link')
        .eq('id', id)
        .single();
      
      if (error) throw error;
      
      return new Response(
        JSON.stringify({ success: true, redirect: data.link }),
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