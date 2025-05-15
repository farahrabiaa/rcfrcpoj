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
  const path = url.pathname.replace('/categories-api', '');
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
    
    // Get all categories
    if (path === '/categories' && method === 'GET') {
      const { data, error } = await supabaseClient
        .from('categories')
        .select('*')
        .order('name');
      
      if (error) throw error;
      
      return new Response(
        JSON.stringify(data),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Get category by ID
    if (path.match(/\/categories\/\w+/) && method === 'GET') {
      const id = path.split('/').pop();
      
      const { data, error } = await supabaseClient
        .from('categories')
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
    
    // Create new category
    if (path === '/categories' && method === 'POST') {
      const body = await req.json();
      
      // Validate required fields
      if (!body.name || !body.slug) {
        return new Response(
          JSON.stringify({ error: 'Name and slug are required' }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          }
        );
      }
      
      const { data, error } = await supabaseClient
        .from('categories')
        .insert([{
          name: body.name,
          slug: body.slug,
          description: body.description || null,
          parent_id: body.parent_id || null
        }])
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
    
    // Update category
    if (path.match(/\/categories\/\w+/) && method === 'PUT') {
      const id = path.split('/').pop();
      const body = await req.json();
      
      // Validate required fields
      if (!body.name || !body.slug) {
        return new Response(
          JSON.stringify({ error: 'Name and slug are required' }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          }
        );
      }
      
      const { data, error } = await supabaseClient
        .from('categories')
        .update({
          name: body.name,
          slug: body.slug,
          description: body.description || null,
          parent_id: body.parent_id || null
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
    
    // Delete category
    if (path.match(/\/categories\/\w+/) && method === 'DELETE') {
      const id = path.split('/').pop();
      
      // Check if category has children
      const { data: children, error: childrenError } = await supabaseClient
        .from('categories')
        .select('id')
        .eq('parent_id', id);
      
      if (childrenError) throw childrenError;
      
      if (children && children.length > 0) {
        return new Response(
          JSON.stringify({ error: 'لا يمكن حذف التصنيف لأنه يحتوي على تصنيفات فرعية' }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          }
        );
      }
      
      // Check if category has products
      const { data: products, error: productsError } = await supabaseClient
        .from('products')
        .select('id')
        .eq('category_id', id);
      
      if (productsError) throw productsError;
      
      if (products && products.length > 0) {
        return new Response(
          JSON.stringify({ error: 'لا يمكن حذف التصنيف لأنه يحتوي على منتجات' }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
          }
        );
      }
      
      const { error } = await supabaseClient
        .from('categories')
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
    
    // Get category tree
    if (path === '/categories/tree' && method === 'GET') {
      const { data, error } = await supabaseClient
        .from('categories')
        .select('*')
        .order('name');
      
      if (error) throw error;
      
      // Build category tree
      const categoryMap = {};
      const rootCategories = [];
      
      // First, create a map of categories by ID
      data.forEach(category => {
        categoryMap[category.id] = { ...category, children: [] };
      });
      
      // Then, build the tree structure
      data.forEach(category => {
        if (category.parent_id && categoryMap[category.parent_id]) {
          categoryMap[category.parent_id].children.push(categoryMap[category.id]);
        } else {
          rootCategories.push(categoryMap[category.id]);
        }
      });
      
      return new Response(
        JSON.stringify(rootCategories),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Get products by category
    if (path.match(/\/categories\/\w+\/products/) && method === 'GET') {
      const id = path.split('/')[2];
      
      const { data, error } = await supabaseClient
        .from('products')
        .select(`
          *,
          vendor:vendor_id(store_name)
        `)
        .eq('category_id', id)
        .eq('status', 'active');
      
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