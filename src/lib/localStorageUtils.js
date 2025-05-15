/**
 * وظائف مساعدة للتعامل مع التخزين المحلي
 */

/**
 * حفظ بيانات البائع في التخزين المحلي
 * @param {Object} vendorData - بيانات البائع
 */
export const saveVendorToLocalStorage = (vendorData) => {
  try {
    localStorage.setItem('pendingVendor', JSON.stringify(vendorData));
  } catch (error) {
    console.error('Error saving vendor to localStorage:', error);
  }
};

/**
 * الحصول على بيانات البائع من التخزين المحلي
 * @returns {Object|null} - بيانات البائع أو null إذا لم تكن موجودة
 */
export const getVendorFromLocalStorage = () => {
  try {
    const vendorData = localStorage.getItem('pendingVendor');
    return vendorData ? JSON.parse(vendorData) : null;
  } catch (error) {
    console.error('Error getting vendor from localStorage:', error);
    return null;
  }
};

/**
 * حذف بيانات البائع من التخزين المحلي
 */
export const removeVendorFromLocalStorage = () => {
  try {
    localStorage.removeItem('pendingVendor');
  } catch (error) {
    console.error('Error removing vendor from localStorage:', error);
  }
};

/**
 * حفظ بيانات السائق في التخزين المحلي
 * @param {Object} driverData - بيانات السائق
 */
export const saveDriverToLocalStorage = (driverData) => {
  try {
    localStorage.setItem('pendingDriver', JSON.stringify(driverData));
  } catch (error) {
    console.error('Error saving driver to localStorage:', error);
  }
};

/**
 * الحصول على بيانات السائق من التخزين المحلي
 * @returns {Object|null} - بيانات السائق أو null إذا لم تكن موجودة
 */
export const getDriverFromLocalStorage = () => {
  try {
    const driverData = localStorage.getItem('pendingDriver');
    return driverData ? JSON.parse(driverData) : null;
  } catch (error) {
    console.error('Error getting driver from localStorage:', error);
    return null;
  }
};

/**
 * حذف بيانات السائق من التخزين المحلي
 */
export const removeDriverFromLocalStorage = () => {
  try {
    localStorage.removeItem('pendingDriver');
  } catch (error) {
    console.error('Error removing driver from localStorage:', error);
  }
};

/**
 * حفظ بيانات الزبون في التخزين المحلي
 * @param {Object} customerData - بيانات الزبون
 */
export const saveCustomerToLocalStorage = (customerData) => {
  try {
    localStorage.setItem('pendingCustomer', JSON.stringify(customerData));
  } catch (error) {
    console.error('Error saving customer to localStorage:', error);
  }
};

/**
 * الحصول على بيانات الزبون من التخزين المحلي
 * @returns {Object|null} - بيانات الزبون أو null إذا لم تكن موجودة
 */
export const getCustomerFromLocalStorage = () => {
  try {
    const customerData = localStorage.getItem('pendingCustomer');
    return customerData ? JSON.parse(customerData) : null;
  } catch (error) {
    console.error('Error getting customer from localStorage:', error);
    return null;
  }
};

/**
 * حذف بيانات الزبون من التخزين المحلي
 */
export const removeCustomerFromLocalStorage = () => {
  try {
    localStorage.removeItem('pendingCustomer');
  } catch (error) {
    console.error('Error removing customer from localStorage:', error);
  }
};

/**
 * حفظ بيانات المستخدم المخصص في التخزين المحلي
 * @param {Object} userData - بيانات المستخدم
 */
export const saveCustomUserToLocalStorage = (userData) => {
  try {
    localStorage.setItem('pendingCustomUser', JSON.stringify(userData));
  } catch (error) {
    console.error('Error saving custom user to localStorage:', error);
  }
};

/**
 * الحصول على بيانات المستخدم المخصص من التخزين المحلي
 * @returns {Object|null} - بيانات المستخدم أو null إذا لم تكن موجودة
 */
export const getCustomUserFromLocalStorage = () => {
  try {
    const userData = localStorage.getItem('pendingCustomUser');
    return userData ? JSON.parse(userData) : null;
  } catch (error) {
    console.error('Error getting custom user from localStorage:', error);
    return null;
  }
};

/**
 * حذف بيانات المستخدم المخصص من التخزين المحلي
 */
export const removeCustomUserFromLocalStorage = () => {
  try {
    localStorage.removeItem('pendingCustomUser');
  } catch (error) {
    console.error('Error removing custom user from localStorage:', error);
  }
};

export default {
  saveVendorToLocalStorage,
  getVendorFromLocalStorage,
  removeVendorFromLocalStorage,
  saveDriverToLocalStorage,
  getDriverFromLocalStorage,
  removeDriverFromLocalStorage,
  saveCustomerToLocalStorage,
  getCustomerFromLocalStorage,
  removeCustomerFromLocalStorage,
  saveCustomUserToLocalStorage,
  getCustomUserFromLocalStorage,
  removeCustomUserFromLocalStorage
};