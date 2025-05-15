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

// Validate token
async function validateToken(token) {
  // In a real app, you would validate the token against a database
  // For this example, we'll just return true
  return true;
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
  const path = url.pathname.replace('/api', '');
  const method = req.method;

  // Get authorization header
  const authHeader = req.headers.get('Authorization');
  
  // Check if token is required for this endpoint
  const isPublicEndpoint = path.startsWith('/public') || path === '/auth/login' || path === '/auth/register';
  
  if (!isPublicEndpoint && (!authHeader || !authHeader.startsWith('Bearer '))) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      }
    );
  }
  
  // Extract and validate token for protected endpoints
  if (!isPublicEndpoint) {
    const token = authHeader.split(' ')[1];
    const isValid = await validateToken(token);
    
    if (!isValid) {
      return new Response(
        JSON.stringify({ error: 'Invalid token' }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 401,
        }
      );
    }
  }

  try {
    // Categories endpoints
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
    
    if (path === '/categories' && method === 'POST') {
      const body = await req.json();
      
      const { data, error } = await supabaseClient
        .from('categories')
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
    
    if (path.match(/\/categories\/\w+/) && method === 'PUT') {
      const id = path.split('/').pop();
      const body = await req.json();
      
      const { data, error } = await supabaseClient
        .from('categories')
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
    
    if (path.match(/\/categories\/\w+/) && method === 'DELETE') {
      const id = path.split('/').pop();
      
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
    
    // Mock financial summary endpoint
    if (path === '/financial/summary' && method === 'GET') {
      const data = {
        total_sales: 85000,
        electronic_payments: 55000,
        cash_payments: 30000,
        admin_commissions: 12500,
        vendor_balances: 45000,
        driver_balances: 18000
      };
      
      return new Response(JSON.stringify(data), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }
    
    // Mock financial commissions endpoint
    if (path === '/financial/commissions' && method === 'GET') {
      const data = {
        total: 12500,
        fromVendors: 8500,
        fromDrivers: 4000,
        pendingFromVendors: 1200,
        pendingFromDrivers: 800,
        byPaymentType: {
          electronic: 7500,
          cash: 5000
        },
        monthly: [2100, 2300, 2500, 2800, 2800, 0, 0, 0, 0, 0, 0, 0]
      };
      
      return new Response(JSON.stringify(data), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }
    
    // Mock vendor balances endpoint
    if (path === '/financial/vendor-balances' && method === 'GET') {
      const data = {
        total: 45000,
        available: 42000,
        pending: 3000,
        byPaymentType: {
          electronic: 28000,
          cash: 17000
        },
        monthly: [7000, 7500, 8000, 8500, 9000, 0, 0, 0, 0, 0, 0, 0]
      };
      
      return new Response(JSON.stringify(data), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }
    
    // Mock driver balances endpoint
    if (path === '/financial/driver-balances' && method === 'GET') {
      const data = {
        total: 18000,
        available: 16500,
        pending: 1500,
        byPaymentType: {
          electronic: 10000,
          cash: 8000
        },
        monthly: [3000, 3200, 3500, 3800, 4000, 0, 0, 0, 0, 0, 0, 0]
      };
      
      return new Response(JSON.stringify(data), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }
    
    // Mock ratings report endpoint
    if (path.match(/\/ratings\/report\/\w+\/\d{4}/) && method === 'GET') {
      const parts = path.split('/');
      const type = parts[parts.length - 2];
      const year = parts[parts.length - 1];
      
      const data = [];
      for (let i = 1; i <= 12; i++) {
        // Only add data for past months in the current year
        const currentDate = new Date();
        const currentYear = currentDate.getFullYear();
        const currentMonth = currentDate.getMonth() + 1;
        
        if (parseInt(year) < currentYear || (parseInt(year) === currentYear && i <= currentMonth)) {
          data.push({
            month: i,
            avg_rating: (4 + Math.random()).toFixed(1),
            count: Math.floor(Math.random() * 50) + 10
          });
        } else {
          data.push({
            month: i,
            avg_rating: 0,
            count: 0
          });
        }
      }
      
      return new Response(JSON.stringify(data), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }
    
    // Mock ratings endpoint
    if (path.match(/\/ratings\/\w+\/\d+/) && method === 'GET') {
      const parts = path.split('/');
      const type = parts[parts.length - 2];
      const id = parts[parts.length - 1];
      
      const data = [];
      const names = ['أحمد محمد', 'سارة خالد', 'محمد علي', 'ليلى إبراهيم', 'خالد عمر'];
      const comments = [
        'خدمة ممتازة وسريعة',
        'منتجات رائعة وجودة عالية',
        'سائق محترف وتوصيل سريع',
        'توصيل في الوقت المحدد',
        'تجربة رائعة، سأطلب مرة أخرى بالتأكيد',
        'منتجات جيدة، لكن التوصيل تأخر قليلاً'
      ];
      
      // Generate random ratings
      for (let i = 0; i < 5; i++) {
        const date = new Date();
        date.setDate(date.getDate() - Math.floor(Math.random() * 30));
        
        data.push({
          id: i + 1,
          from_name: names[Math.floor(Math.random() * names.length)],
          rating: Math.floor(Math.random() * 2) + 4, // 4 or 5 stars
          comment: comments[Math.floor(Math.random() * comments.length)],
          created_at: date.toISOString()
        });
      }
      
      return new Response(JSON.stringify(data), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }
    
    // Add ratings endpoint
    if (path === '/ratings' && method === 'POST') {
      const body = await req.json();
      
      // In a real app, we would save this to the database
      return new Response(JSON.stringify({ message: 'تم إضافة التقييم بنجاح' }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 201,
      });
    }
    
    // Mock advertisements endpoint
    if (path === '/advertisements' && method === 'GET') {
      const data = [
        { 
          id: 1, 
          title: 'عرض خاص على القهوة',
          description: 'خصم 20% على جميع أنواع القهوة',
          vendor_name: 'متجر كوفي',
          vendor_id: 1,
          image_url: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?q=80&w=1000&auto=format&fit=crop',
          link: '/products/coffee',
          start_date: '2025-01-01',
          end_date: '2025-12-31',
          status: 'active',
          type: 'banner',
          position: 'home',
          priority: 1,
          clicks: 245,
          views: 1250
        },
        {
          id: 2,
          title: 'توصيل مجاني',
          description: 'توصيل مجاني لجميع الطلبات فوق 50₪',
          vendor_name: 'متجر الشاي',
          vendor_id: 2,
          image_url: 'https://images.unsplash.com/photo-1577554105754-720c1bc90fca?q=80&w=1000&auto=format&fit=crop',
          link: '/vendors/tea-shop',
          start_date: '2025-01-15',
          end_date: '2025-12-15',
          status: 'active',
          type: 'popup',
          position: 'checkout',
          priority: 2,
          clicks: 120,
          views: 800
        }
      ];
      
      return new Response(JSON.stringify(data), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
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