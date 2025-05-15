import dayjs from 'dayjs';
import 'dayjs/locale/ar'; // استدعاء اللغة العربية

dayjs.locale('ar'); // ضبط اللغة الافتراضية إلى العربية

/**
 * Format file size in bytes to a human-readable string
 * @param {number} bytes
 * @returns {string}
 */
export const formatSize = (bytes) => {
  if (!bytes || bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
};

/**
 * Format date to a readable Gregorian date with Arabic month name
 * @param {string|Date} date
 * @returns {string}
 */
export const formatDate = (date) => {
  if (!date) return '';
  return dayjs(date).format('D MMMM YYYY'); // مثل: 10 مايو 2025
};

/**
 * Format time to a human-readable string (hh:mm)
 * @param {string|Date} date
 * @returns {string}
 */
export const formatTime = (date) => {
  if (!date) return '';
  return dayjs(date).format('HH:mm');
};

/**
 * Format datetime to a human-readable string (D MMMM YYYY HH:mm)
 * @param {string|Date} date
 * @returns {string}
 */
export const formatDateTime = (date) => {
  if (!date) return '';
  return dayjs(date).format('D MMMM YYYY HH:mm');
};

/**
 * Format currency
 * @param {number} amount
 * @param {string} currency
 * @returns {string}
 */
export const formatCurrency = (amount, currency = 'ILS') => {
  if (amount == null) return '';
  const symbols = {
    ILS: '₪',
    USD: '$',
    EUR: '€',
    GBP: '£',
    JOD: 'د.أ'
  };
  const symbol = symbols[currency] || currency;
  return `${symbol}${parseFloat(amount).toFixed(2)}`;
};

/**
 * Get Hijri month name from month number
 * @param {number} month - Month number (1-12)
 * @returns {string} - Hijri month name in Arabic
 */
export const getHijriMonthName = (month) => {
  const hijriMonths = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الثاني',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة'
  ];
  
  // Check if month is valid (1-12)
  if (month >= 1 && month <= 12) {
    return hijriMonths[month - 1];
  }
  
  // Return empty string for invalid month
  return '';
};