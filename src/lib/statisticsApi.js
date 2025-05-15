import { supabase } from './supabase';

/**
 * الحصول على إحصائيات عامة للنظام
 * @returns {Promise<Object>} - الإحصائيات العامة
 */
export const getGeneralStats = async () => {
  try {
    // إحصائيات المبيعات
    const { data: ordersData, error: ordersError } = await supabase
      .from('orders')
      .select('total');
    
    if (ordersError) throw ordersError;
    
    const totalSales = ordersData.reduce((sum, order) => sum + parseFloat(order.total || 0), 0);
    
    // عدد الطلبات
    const { count: totalOrders, error: countError } = await supabase
      .from('orders')
      .select('*', { count: 'exact', head: true });
    
    if (countError) throw countError;
    
    // عدد البائعين النشطين
    const { count: activeVendors, error: vendorsError } = await supabase
      .from('vendors')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'active');
    
    if (vendorsError) throw vendorsError;
    
    // عدد السائقين المتاحين
    const { count: activeDrivers, error: driversError } = await supabase
      .from('drivers')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'available');
    
    if (driversError) throw driversError;
    
    // عدد العملاء
    const { count: totalCustomers, error: customersError } = await supabase
      .from('customers')
      .select('*', { count: 'exact', head: true });
    
    if (customersError) throw customersError;
    
    return {
      totalSales,
      totalOrders: totalOrders || 0,
      activeVendors: activeVendors || 0,
      activeDrivers: activeDrivers || 0,
      totalCustomers: totalCustomers || 0
    };
  } catch (error) {
    console.error('Error fetching general stats:', error);
    throw error;
  }
};

/**
 * الحصول على إحصائيات المبيعات الشهرية
 * @param {number} year - السنة
 * @returns {Promise<Array>} - إحصائيات المبيعات الشهرية
 */
export const getMonthlySalesStats = async (year = new Date().getFullYear()) => {
  try {
    const { data, error } = await supabase
      .from('orders')
      .select('total, created_at');
    
    if (error) throw error;
    
    // تهيئة مصفوفة للمبيعات الشهرية
    const monthlySales = Array(12).fill(0);
    const monthlyOrders = Array(12).fill(0);
    
    // تجميع البيانات حسب الشهر
    data.forEach(order => {
      const orderDate = new Date(order.created_at);
      if (orderDate.getFullYear() === year) {
        const month = orderDate.getMonth();
        monthlySales[month] += parseFloat(order.total || 0);
        monthlyOrders[month] += 1;
      }
    });
    
    return {
      monthlySales,
      monthlyOrders
    };
  } catch (error) {
    console.error('Error fetching monthly sales stats:', error);
    throw error;
  }
};

/**
 * الحصول على أفضل المنتجات مبيعاً
 * @param {number} limit - عدد المنتجات المراد إرجاعها
 * @returns {Promise<Array>} - قائمة أفضل المنتجات مبيعاً
 */
export const getTopProducts = async (limit = 5) => {
  try {
    // في تطبيق حقيقي، ستحتاج إلى طريقة لتتبع مبيعات المنتجات
    // هنا سنستخدم عدد مرات ظهور المنتج في عناصر الطلبات كمؤشر
    
    // الحصول على عدد مرات ظهور كل منتج في عناصر الطلبات
    const { data: orderItemsData, error: orderItemsError } = await supabase
      .from('order_items')
      .select('product_id, quantity');
    
    if (orderItemsError) throw orderItemsError;
    
    // حساب عدد المبيعات لكل منتج
    const productSales = {};
    orderItemsData.forEach(item => {
      if (!productSales[item.product_id]) {
        productSales[item.product_id] = 0;
      }
      productSales[item.product_id] += item.quantity || 1;
    });
    
    // تحويل البيانات إلى مصفوفة وترتيبها
    const sortedProductIds = Object.entries(productSales)
      .sort(([, a], [, b]) => b - a)
      .slice(0, limit)
      .map(([id]) => id);
    
    if (sortedProductIds.length === 0) {
      return [];
    }
    
    // الحصول على بيانات المنتجات
    const { data: productsData, error: productsError } = await supabase
      .from('products')
      .select('id, name, price, image_url')
      .in('id', sortedProductIds);
    
    if (productsError) throw productsError;
    
    // إضافة عدد المبيعات لكل منتج
    return productsData.map(product => ({
      ...product,
      sales: productSales[product.id] || 0
    })).sort((a, b) => b.sales - a.sales);
  } catch (error) {
    console.error('Error fetching top products:', error);
    throw error;
  }
};

/**
 * الحصول على أحدث الطلبات
 * @param {number} limit - عدد الطلبات المراد إرجاعها
 * @returns {Promise<Array>} - قائمة أحدث الطلبات
 */
export const getLatestOrders = async (limit = 5) => {
  try {
    const { data, error } = await supabase
      .from('orders')
      .select(`
        id,
        customer:customer_id(name),
        total,
        status,
        created_at
      `)
      .order('created_at', { ascending: false })
      .limit(limit);
    
    if (error) throw error;
    
    return data || [];
  } catch (error) {
    console.error('Error fetching latest orders:', error);
    throw error;
  }
};

/**
 * الحصول على إحصائيات المالية
 * @returns {Promise<Object>} - الإحصائيات المالية
 */
export const getFinancialStats = async () => {
  try {
    // استخدام دالة RPC للحصول على ملخص مالي
    const { data, error } = await supabase.rpc('get_financial_summary');
    
    if (error) throw error;
    
    return data || {
      total_sales: 0,
      electronic_payments: 0,
      cash_payments: 0,
      admin_commissions: 0,
      vendor_balances: 0,
      driver_balances: 0
    };
  } catch (error) {
    console.error('Error fetching financial stats:', error);
    throw error;
  }
};

export default {
  getGeneralStats,
  getMonthlySalesStats,
  getTopProducts,
  getLatestOrders,
  getFinancialStats
};