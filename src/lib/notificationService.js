/**
 * Notification Service
 * Handles sound notifications and browser notifications for new orders
 */

// Audio instance for notification sound
let notificationSound = null;

// Initialize notification sound
export const initNotificationSound = () => {
  if (!notificationSound) {
    notificationSound = new Audio('/notification.mp3');
    notificationSound.preload = 'auto';
  }
};

// Play notification sound
export const playNotificationSound = () => {
  if (!notificationSound) {
    initNotificationSound();
  }
  
  try {
    // Reset the audio to the beginning if it's already playing
    notificationSound.pause();
    notificationSound.currentTime = 0;
    
    // Play the notification sound
    const playPromise = notificationSound.play();
    
    // Handle potential play() promise rejection (e.g., if user hasn't interacted with the page yet)
    if (playPromise !== undefined) {
      playPromise.catch(error => {
        console.warn('Audio playback was prevented:', error);
      });
    }
  } catch (error) {
    console.error('Error playing notification sound:', error);
  }
};

// Request browser notification permission
export const requestNotificationPermission = async () => {
  if (!('Notification' in window)) {
    console.warn('This browser does not support desktop notifications');
    return false;
  }
  
  if (Notification.permission === 'granted') {
    return true;
  }
  
  if (Notification.permission !== 'denied') {
    const permission = await Notification.requestPermission();
    return permission === 'granted';
  }
  
  return false;
};

// Show browser notification
export const showBrowserNotification = (title, options = {}) => {
  if (!('Notification' in window)) {
    return;
  }
  
  if (Notification.permission === 'granted') {
    const notification = new Notification(title, {
      icon: '/logo.svg',
      ...options
    });
    
    // Add click handler if provided
    if (options.onClick) {
      notification.onclick = options.onClick;
    }
    
    return notification;
  }
};

// Notify for new order
export const notifyNewOrder = (order) => {
  // Play sound notification
  playNotificationSound();
  
  // Show browser notification if permission is granted
  if (Notification.permission === 'granted') {
    const orderNumber = order.id.substring(0, 8);
    const title = `طلب جديد #${orderNumber}`;
    const options = {
      body: `تم استلام طلب جديد من ${order.customer?.name || 'زبون'}`,
      icon: '/logo.svg',
      badge: '/logo.svg',
      tag: `order-${order.id}`,
      requireInteraction: true,
      onClick: () => {
        window.focus();
        window.location.href = `/admin-dashboard/orders`;
      }
    };
    
    showBrowserNotification(title, options);
  }
};

export default {
  initNotificationSound,
  playNotificationSound,
  requestNotificationPermission,
  showBrowserNotification,
  notifyNewOrder
};