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
  const path = url.pathname.replace('/media-upload', '');
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
    
    // Handle file upload
    if (path === '/upload' && method === 'POST') {
      try {
        const formData = await req.formData();
        const file = formData.get('file');
        const bucket = formData.get('bucket') || 'general';
        const folder = formData.get('folder') || '';
        
        if (!file || !(file instanceof File)) {
          return new Response(
            JSON.stringify({ error: 'No file provided' }),
            {
              headers: { ...corsHeaders, "Content-Type": "application/json" },
              status: 400,
            }
          );
        }
        
        // Create a unique file name
        const fileExt = file.name.split('.').pop();
        const fileName = `${Math.random().toString(36).substring(2, 15)}_${Date.now()}.${fileExt}`;
        
        // Create the full path
        const filePath = folder ? `${folder}/${fileName}` : fileName;
        
        // Upload the file to Supabase Storage
        const { data: uploadData, error: uploadError } = await supabaseClient.storage
          .from(bucket.toString())
          .upload(filePath, file, {
            cacheControl: '3600',
            upsert: false
          });
        
        if (uploadError) throw uploadError;
        
        // Get the public URL
        const { data: { publicUrl } } = supabaseClient.storage
          .from(bucket.toString())
          .getPublicUrl(filePath);
        
        // Get file metadata
        let width, height, duration;
        
        // Store file info in media_files table
        const { data: fileData, error: fileError } = await supabaseClient
          .from('media_files')
          .insert([{
            filename: fileName,
            original_filename: file.name,
            file_path: filePath,
            file_size: file.size,
            mime_type: file.type,
            bucket: bucket.toString(),
            width,
            height,
            duration,
            is_public: true
          }])
          .select();
        
        if (fileError) {
          console.error('Error storing file metadata:', fileError);
          // Continue anyway, we'll just return the file URL
        }
        
        return new Response(
          JSON.stringify({
            success: true,
            url: publicUrl,
            path: filePath,
            bucket: bucket.toString(),
            id: fileData?.[0]?.id || null,
            name: file.name,
            size: file.size,
            type: file.type
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          }
        );
      } catch (error) {
        console.error('Error uploading file:', error);
        return new Response(
          JSON.stringify({ error: 'Error uploading file', details: error.message }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 500,
          }
        );
      }
    }
    
    // Get media files
    if (path === '/files' && method === 'GET') {
      const bucket = url.searchParams.get('bucket');
      const type = url.searchParams.get('type');
      const search = url.searchParams.get('search');
      const page = parseInt(url.searchParams.get('page') || '1');
      const pageSize = parseInt(url.searchParams.get('pageSize') || '20');
      
      // Build query
      let query = supabaseClient
        .from('media_files')
        .select('*', { count: 'exact' });
      
      // Apply filters
      if (bucket) {
        query = query.eq('bucket', bucket);
      }
      
      if (type) {
        query = query.ilike('mime_type', `${type}/%`);
      }
      
      if (search) {
        query = query.or(`filename.ilike.%${search}%,original_filename.ilike.%${search}%,alt_text.ilike.%${search}%,title.ilike.%${search}%,description.ilike.%${search}%`);
      }
      
      // Apply pagination
      const from = (page - 1) * pageSize;
      const to = from + pageSize - 1;
      query = query.range(from, to).order('created_at', { ascending: false });
      
      const { data, error, count } = await query;
      
      if (error) throw error;
      
      // Transform data to include public URLs
      const transformedData = data.map(file => {
        const { data: { publicUrl } } = supabaseClient.storage
          .from(file.bucket)
          .getPublicUrl(file.file_path);
        
        return {
          ...file,
          url: publicUrl
        };
      });
      
      return new Response(
        JSON.stringify({
          data: transformedData,
          count,
          page,
          pageSize,
          totalPages: Math.ceil((count || 0) / pageSize)
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }
    
    // Delete file
    if (path.match(/\/files\/\w+/) && method === 'DELETE') {
      const id = path.split('/').pop();
      
      // Get file info first
      const { data: fileData, error: fileError } = await supabaseClient
        .from('media_files')
        .select('*')
        .eq('id', id)
        .single();
      
      if (fileError) throw fileError;
      
      // Delete from storage
      const { error: storageError } = await supabaseClient.storage
        .from(fileData.bucket)
        .remove([fileData.file_path]);
      
      if (storageError) {
        console.error('Error deleting from storage:', storageError);
        // Continue anyway, we'll remove it from the database
      }
      
      // Delete from database
      const { error } = await supabaseClient
        .from('media_files')
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