import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { toast } from 'react-toastify';

export default function Overview() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [stats, setStats] = useState({
    totalOrders: 0,
    totalRevenue: 0,
    totalCustomers: 0,
    totalVendors: 0,
    totalDrivers: 0,
    totalProducts: 0,
    averageOrderValue: 0,
    completionRate: 0
  });
  const [topVendors, setTopVendors] = useState([]);
  const [recentOrders, setRecentOrders] = useState([]);

  useEffect(() => {
    fetchStats();
    fetchTopVendors();
    fetchRecentOrders();
  }, []);

  const fetchStats = async () => {
    try {
      // Get total orders and revenue
      const { data: ordersData, error: ordersError } = await supabase
        .from('orders')
        .select('total, status');
      
      if (ordersError) throw ordersError;

      const totalOrders = ordersData.length;
      const totalRevenue = ordersData.reduce((sum, order) => sum + (parseFloat(order.total) || 0), 0);
      const completedOrders = ordersData.filter(order => order.status === 'completed').length;
      const completionRate = totalOrders > 0 ? (completedOrders / totalOrders) * 100 : 0;
      const averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;

      // Get total customers
      const { count: totalCustomers, error: customersError } = await supabase
        .from('customers')
        .select('id', { count: 'exact' });
      
      if (customersError) throw customersError;

      // Get total vendors
      const { count: totalVendors, error: vendorsError } = await supabase
        .from('vendors')
        .select('id', { count: 'exact' });
      
      if (vendorsError) throw vendorsError;

      // Get total drivers
      const { count: totalDrivers, error: driversError } = await supabase
        .from('drivers')
        .select('id', { count: 'exact' });
      
      if (driversError) throw driversError;

      // Get total products
      const { count: totalProducts, error: productsError } = await supabase
        .from('products')
        .select('id', { count: 'exact' });
      
      if (productsError) throw productsError;

      setStats({
        totalOrders,
        totalRevenue,
        totalCustomers,
        totalVendors,
        totalDrivers,
        totalProducts,
        averageOrderValue,
        completionRate
      });
    } catch (error) {
      console.error('Error fetching stats:', error);
      setError(error.message);
      toast.error('فشل في تحميل الإحصائيات');
    }
  };

  const fetchTopVendors = async () => {
    try {
      // Get vendors with their total orders and revenue
      const { data: vendorOrders, error: ordersError } = await supabase
        .from('orders')
        .select(`
          vendor_id,
          total,
          vendor:vendors(store_name)
        `)
        .not('vendor_id', 'is', null);
      
      if (ordersError) throw ordersError;

      // Calculate totals for each vendor
      const vendorStats = vendorOrders.reduce((acc, order) => {
        const vendorId = order.vendor_id;
        if (!acc[vendorId]) {
          acc[vendorId] = {
            id: vendorId,
            store_name: order.vendor?.store_name,
            total_orders: 0,
            total_revenue: 0
          };
        }
        acc[vendorId].total_orders++;
        acc[vendorId].total_revenue += parseFloat(order.total) || 0;
        return acc;
      }, {});

      // Convert to array and sort by revenue
      const sortedVendors = Object.values(vendorStats)
        .sort((a, b) => b.total_revenue - a.total_revenue)
        .slice(0, 5);

      setTopVendors(sortedVendors);
    } catch (error) {
      console.error('Error fetching vendor orders:', error);
      toast.error('فشل في تحميل بيانات البائعين');
    }
  };

  const fetchRecentOrders = async () => {
    try {
      const { data, error } = await supabase
        .from('orders')
        .select(`
          *,
          customer:customers(name),
          vendor:vendors(store_name),
          driver:drivers(name)
        `)
        .order('created_at', { ascending: false })
        .limit(5);
      
      if (error) throw error;
      
      setRecentOrders(data);
    } catch (error) {
      console.error('Error fetching recent orders:', error);
      toast.error('فشل في تحميل الطلبات الأخيرة');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 p-4 rounded-lg text-red-800">
        <h3 className="font-semibold mb-2">خطأ</h3>
        <p>{error}</p>
        <button 
          onClick={() => {
            setLoading(true);
            setError(null);
            fetchStats();
            fetchTopVendors();
            fetchRecentOrders();
          }}
          className="mt-4 bg-red-600 text-white px-4 py-2 rounded hover:bg-red-700"
        >
          إعادة المحاولة
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Statistics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold mb-2">إجمالي الطلبات</h3>
          <p className="text-3xl font-bold text-blue-600">{stats.totalOrders}</p>
        </div>
        
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold mb-2">إجمالي الإيرادات</h3>
          <p className="text-3xl font-bold text-green-600">
            ₪{stats.totalRevenue.toFixed(2)}
          </p>
        </div>
        
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold mb-2">متوسط قيمة الطلب</h3>
          <p className="text-3xl font-bold text-purple-600">
            ₪{stats.averageOrderValue.toFixed(2)}
          </p>
        </div>
        
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold mb-2">معدل إكمال الطلبات</h3>
          <p className="text-3xl font-bold text-orange-600">
            {stats.completionRate.toFixed(1)}%
          </p>
        </div>
        
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold mb-2">عدد العملاء</h3>
          <p className="text-3xl font-bold text-red-600">{stats.totalCustomers}</p>
        </div>
        
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold mb-2">عدد البائعين</h3>
          <p className="text-3xl font-bold text-indigo-600">{stats.totalVendors}</p>
        </div>
        
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold mb-2">عدد السائقين</h3>
          <p className="text-3xl font-bold text-yellow-600">{stats.totalDrivers}</p>
        </div>
        
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold mb-2">عدد المنتجات</h3>
          <p className="text-3xl font-bold text-pink-600">{stats.totalProducts}</p>
        </div>
      </div>

      {/* Top Vendors */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-xl font-semibold mb-4">أفضل البائعين</h3>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">المتجر</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">عدد الطلبات</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">إجمالي الإيرادات</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {topVendors.map((vendor) => (
                <tr key={vendor.id}>
                  <td className="px-6 py-4 whitespace-nowrap">{vendor.store_name}</td>
                  <td className="px-6 py-4 whitespace-nowrap">{vendor.total_orders}</td>
                  <td className="px-6 py-4 whitespace-nowrap">₪{vendor.total_revenue.toFixed(2)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Recent Orders */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-xl font-semibold mb-4">آخر الطلبات</h3>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">رقم الطلب</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">العميل</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">المتجر</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">السائق</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">المبلغ</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">الحالة</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">التاريخ</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {recentOrders.map((order) => (
                <tr key={order.id}>
                  <td className="px-6 py-4 whitespace-nowrap">{order.order_number}</td>
                  <td className="px-6 py-4 whitespace-nowrap">{order.customer?.name}</td>
                  <td className="px-6 py-4 whitespace-nowrap">{order.vendor?.store_name}</td>
                  <td className="px-6 py-4 whitespace-nowrap">{order.driver?.name || '-'}</td>
                  <td className="px-6 py-4 whitespace-nowrap">₪{parseFloat(order.total).toFixed(2)}</td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full ${
                      order.status === 'completed' ? 'bg-green-100 text-green-800' :
                      order.status === 'cancelled' ? 'bg-red-100 text-red-800' :
                      'bg-yellow-100 text-yellow-800'
                    }`}>
                      {order.status === 'completed' ? 'مكتمل' :
                       order.status === 'cancelled' ? 'ملغي' :
                       order.status === 'pending' ? 'معلق' :
                       order.status === 'processing' ? 'قيد المعالجة' :
                       order.status === 'delivering' ? 'قيد التوصيل' :
                       order.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    {new Date(order.created_at).toLocaleDateString('ar-SA')}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}