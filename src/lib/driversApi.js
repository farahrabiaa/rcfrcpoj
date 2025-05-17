import { supabase } from './supabase';

/**
 * الحصول على قائمة السائقين
 * @param {Object} options - خيارات الفلترة
 * @returns {Promise<Array>} - قائمة السائقين
 */
export const getDrivers = async (options = {}) => {
  try {
    let query = supabase
      .from('drivers')
      .select(`
        *,
        user:user_id(*)
      `);
    
    // تطبيق الفلاتر
    if (options.status) {
      query = query.eq('status', options.status);
    }
    
    if (options.search) {
      query = query.or(`name.ilike.%${options.search}%,phone.ilike.%${options.search}%,email.ilike.%${options.search}%`);
    }
    
    if (options.vehicle_type) {
      query = query.eq('vehicle_type', options.vehicle_type);
    }
    
    if (options.area) {
      query = query.contains('working_areas', [options.area]);
    }
    
    // ترتيب النتائج
    query = query.order('created_at', { ascending: false });
    
    const { data, error } = await query;
    
    if (error) throw error;
    return data || [];
  } catch (error) {
    console.error('Error fetching drivers:', error);
    throw error;
  }
};

/**
 * الحصول على سائق محدد
 * @param {string} id - معرف السائق
 * @returns {Promise<Object>} - بيانات السائق
 */
export const getDriver = async (id) => {
  try {
    const { data, error } = await supabase
      .from('drivers')
      .select(`
        *,
        user:user_id(*)
      `)
      .eq('id', id)
      .single();
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error fetching driver:', error);
    throw error;
  }
};

/**
 * الحصول على السائقين المتاحين
 * @returns {Promise<Array>} - قائمة السائقين المتاحين
 */
export const getAvailableDrivers = async () => {
  try {
    const { data, error } = await supabase
      .from('drivers')
      .select(`
        *,
        user:user_id(*)
      `)
      .eq('status', 'available')
      .order('rating', { ascending: false });
    
    if (error) throw error;
    return data || [];
  } catch (error) {
    console.error('Error fetching available drivers:', error);
    throw error;
  }
};

/**
 * الحصول على السائقين حسب المنطقة
 * @param {string} area - المنطقة
 * @returns {Promise<Array>} - قائمة السائقين في المنطقة
 */
export const getDriversByArea = async (area) => {
  try {
    const { data, error } = await supabase.rpc(
      'get_available_drivers_for_area',
      { p_area: area }
    );
    
    if (error) throw error;
    return data || [];
  } catch (error) {
    console.error('Error fetching drivers by area:', error);
    throw error;
  }
};

/**
 * تحديث موقع السائق
 * @param {string} id - معرف السائق
 * @param {number} latitude - خط العرض
 * @param {number} longitude - خط الطول
 * @returns {Promise<Object>} - بيانات السائق المحدثة
 */
export const updateDriverLocation = async (id, latitude, longitude) => {
  try {
    const { data, error } = await supabase
      .from('drivers')
      .update({
        latitude,
        longitude,
        last_location_update: new Date().toISOString()
      })
      .eq('id', id)
      .select();
    
    if (error) throw error;
    return data[0];
  } catch (error) {
    console.error('Error updating driver location:', error);
    throw error;
  }
};

/**
 * تحديث حالة السائق
 * @param {string} id - معرف السائق
 * @param {string} status - الحالة الجديدة (offline, available, busy)
 * @returns {Promise<Object>} - بيانات السائق المحدثة
 */
export const updateDriverStatus = async (id, status) => {
  try {
    const { data, error } = await supabase
      .from('drivers')
      .update({ status })
      .eq('id', id)
      .select();
    
    if (error) throw error;
    return data[0];
  } catch (error) {
    console.error('Error updating driver status:', error);
    throw error;
  }
};

/**
 * إنشاء سائق جديد
 * @param {Object} driverData - بيانات السائق
 * @returns {Promise<Object>} - بيانات السائق الجديد
 */
export const createDriver = async (driverData) => {
  try {
    // إنشاء مستخدم مخصص جديد
    const { data: userId, error: userError } = await supabase.rpc(
      'add_custom_user',
      {
        p_username: driverData.username,
        p_password: driverData.password,
        p_name: driverData.name,
        p_email: driverData.email || null,
        p_phone: driverData.phone,
        p_role: 'driver'
      }
    );
    
    if (userError) throw userError;
    
    // إنشاء سائق جديد
    const { data: driverData2, error: driverError } = await supabase
      .from('drivers')
      .insert([{
        user_id: userId,
        name: driverData.name,
        phone: driverData.phone,
        email: driverData.email,
        status: driverData.status || 'offline',
        commission_rate: driverData.commission_rate || 15,
        vehicle_type: driverData.vehicle_type || 'motorcycle',
        vehicle_model: driverData.vehicle_model,
        vehicle_year: driverData.vehicle_year,
        vehicle_plate: driverData.vehicle_plate,
        working_areas: driverData.working_areas || []
      }])
      .select();
    
    if (driverError) throw driverError;
    
    // إضافة السائق إلى المستخدمين المصادقين
    const { error: authError } = await supabase.rpc('register_driver_in_auth', {
      p_driver_id: driverData2[0].id
    });
    
    if (authError) {
      console.error('Error registering driver in auth system:', authError);
      // نستمر حتى لو فشلت هذه الخطوة
    }
    
    return driverData2[0];
  } catch (error) {
    console.error('Error creating driver:', error);
    throw error;
  }
};

/**
 * تحديث بيانات سائق
 * @param {string} id - معرف السائق
 * @param {Object} driverData - بيانات السائق المحدثة
 * @returns {Promise<Object>} - بيانات السائق المحدثة
 */
export const updateDriver = async (id, driverData) => {
  try {
    // الحصول على معرف المستخدم المرتبط بالسائق
    const { data: driverInfo, error: driverGetError } = await supabase
      .from('drivers')
      .select('user_id')
      .eq('id', id)
      .single();
    
    if (driverGetError) throw driverGetError;
    
    // تحديث بيانات المستخدم المخصص
    if (driverInfo.user_id) {
      const updateData = {
        name: driverData.name,
        email: driverData.email,
        phone: driverData.phone,
        updated_at: new Date().toISOString()
      };
      
      const { error: userError } = await supabase
        .from('custom_users')
        .update(updateData)
        .eq('id', driverInfo.user_id);
      
      if (userError) throw userError;
      
      // إذا تم تغيير كلمة المرور
      if (driverData.password) {
        const { error: passwordError } = await supabase.rpc(
          'change_custom_user_password',
          { 
            p_user_id: driverInfo.user_id,
            p_new_password: driverData.password
          }
        );
        
        if (passwordError) throw passwordError;
      }
    }
    
    // تحديث بيانات السائق
    const { data, error } = await supabase
      .from('drivers')
      .update({
        name: driverData.name,
        phone: driverData.phone,
        email: driverData.email,
        status: driverData.status,
        commission_rate: driverData.commission_rate,
        vehicle_type: driverData.vehicle_type,
        vehicle_model: driverData.vehicle_model,
        vehicle_year: driverData.vehicle_year,
        vehicle_plate: driverData.vehicle_plate,
        working_areas: driverData.working_areas,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select();
    
    if (error) throw error;
    
    return data[0];
  } catch (error) {
    console.error('Error updating driver:', error);
    throw error;
  }
};

/**
 * حذف سائق
 * @param {string} id - معرف السائق
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const deleteDriver = async (id) => {
  try {
    // الحصول على معرف المستخدم المرتبط بالسائق
    const { data: driverInfo, error: driverGetError } = await supabase
      .from('drivers')
      .select('user_id')
      .eq('id', id)
      .single();
    
    if (driverGetError) throw driverGetError;
    
    // حذف السائق
    const { error: driverError } = await supabase
      .from('drivers')
      .delete()
      .eq('id', id);
    
    if (driverError) throw driverError;
    
    // حذف المستخدم المخصص
    if (driverInfo.user_id) {
      const { error: userError } = await supabase
        .from('custom_users')
        .delete()
        .eq('id', driverInfo.user_id);
      
      if (userError) throw userError;
    }
    
    return true;
  } catch (error) {
    console.error('Error deleting driver:', error);
    throw error;
  }
};

/**
 * الحصول على سائقي البائع
 * @param {string} vendorId - معرف البائع
 * @returns {Promise<Array>} - قائمة سائقي البائع
 */
export const getVendorDrivers = async (vendorId) => {
  try {
    const { data, error } = await supabase.rpc(
      'get_vendor_drivers',
      { p_vendor_id: vendorId }
    );
    
    if (error) throw error;
    return data || [];
  } catch (error) {
    console.error('Error fetching vendor drivers:', error);
    throw error;
  }
};

/**
 * تعيين سائق لبائع
 * @param {string} vendorId - معرف البائع
 * @param {string} driverId - معرف السائق
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const assignDriverToVendor = async (vendorId, driverId) => {
  try {
    const { error } = await supabase
      .from('vendor_drivers')
      .insert([{ vendor_id: vendorId, driver_id: driverId }]);
    
    if (error) throw error;
    return true;
  } catch (error) {
    console.error('Error assigning driver to vendor:', error);
    throw error;
  }
};

/**
 * إلغاء تعيين سائق من بائع
 * @param {string} vendorId - معرف البائع
 * @param {string} driverId - معرف السائق
 * @returns {Promise<boolean>} - نجاح العملية
 */
export const unassignDriverFromVendor = async (vendorId, driverId) => {
  try {
    const { error } = await supabase
      .from('vendor_drivers')
      .delete()
      .eq('vendor_id', vendorId)
      .eq('driver_id', driverId);
    
    if (error) throw error;
    return true;
  } catch (error) {
    console.error('Error unassigning driver from vendor:', error);
    throw error;
  }
};

export default {
  getDrivers,
  getDriver,
  getAvailableDrivers,
  getDriversByArea,
  updateDriverLocation,
  updateDriverStatus,
  createDriver,
  updateDriver,
  deleteDriver,
  getVendorDrivers,
  assignDriverToVendor,
  unassignDriverFromVendor
};