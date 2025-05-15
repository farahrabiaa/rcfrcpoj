import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import { useSettings } from '../../contexts/SettingsContext';

export default function TopBar() {
  const { settings } = useSettings();
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [notifications] = useState([
    { id: 1, text: 'طلب جديد #123', time: 'قبل 5 دقائق' },
    { id: 2, text: 'اكتمال الطلب #120', time: 'قبل 10 دقائق' },
    { id: 3, text: 'تقييم جديد من العميل أحمد', time: 'قبل 15 دقيقة' }
  ]);

  const [showNotifications, setShowNotifications] = useState(false);
  const [showUserMenu, setShowUserMenu] = useState(false);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="bg-gradient-to-r from-slate-900 to-slate-800 shadow-sm">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          {/* Search Bar */}
          <div className="flex-1 max-w-lg">
            <div className="relative">
              <div className="absolute inset-y-0 right-0 pr-3 flex items-center">
                <svg className="h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clipRule="evenodd" />
                </svg>
              </div>
              <input
                type="text"
                placeholder="بحث..."
                className="block w-full bg-slate-800 text-white rounded-lg border-gray-700 pr-10 focus:border-yellow-500 focus:ring-yellow-500 placeholder-gray-400"
              />
            </div>
          </div>

          {/* Right Side Items */}
          <div className="flex items-center space-x-4">
            {/* Notifications */}
            <div className="relative">
              <button
                onClick={() => setShowNotifications(!showNotifications)}
                className="relative p-2 text-gray-300 hover:text-white rounded-full hover:bg-slate-800"
              >
                <svg className="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                </svg>
                <span className="absolute top-0 right-0 block h-2 w-2 rounded-full bg-yellow-500 ring-2 ring-slate-900" />
              </button>

              {showNotifications && (
                <div className="absolute left-0 mt-2 w-80 bg-slate-800 rounded-lg shadow-lg py-1 z-50 border border-slate-700">
                  <div className="px-4 py-2 border-b border-slate-700">
                    <h3 className="text-sm font-semibold text-white">الإشعارات</h3>
                  </div>
                  <div className="max-h-64 overflow-y-auto">
                    {notifications.map(notification => (
                      <div
                        key={notification.id}
                        className="px-4 py-2 hover:bg-slate-700 cursor-pointer"
                      >
                        <p className="text-sm text-gray-200">{notification.text}</p>
                        <p className="text-xs text-gray-400">{notification.time}</p>
                      </div>
                    ))}
                  </div>
                  <div className="px-4 py-2 border-t border-slate-700">
                    <button className="text-sm text-yellow-400 hover:text-yellow-300">
                      عرض كل الإشعارات
                    </button>
                  </div>
                </div>
              )}
            </div>

            {/* User Profile */}
            <div className="relative">
              <button 
                onClick={() => setShowUserMenu(!showUserMenu)}
                className="flex items-center"
              >
                <div className="h-8 w-8 rounded-full border-2 border-yellow-500 overflow-hidden bg-slate-700 flex items-center justify-center">
                  <span className="text-lg text-slate-300">👤</span>
                </div>
                <span className="mr-2 text-sm font-medium text-gray-200">{user?.name || settings.store.name}</span>
              </button>
              
              {showUserMenu && (
                <div className="absolute left-0 mt-2 w-48 bg-slate-800 rounded-lg shadow-lg py-1 z-50 border border-slate-700">
                  <div className="px-4 py-2 border-b border-slate-700">
                    <p className="text-sm font-semibold text-white">{user?.email || 'admin@example.com'}</p>
                    <p className="text-xs text-gray-400">{user?.role === 'admin' ? 'مدير النظام' : 'مستخدم'}</p>
                  </div>
                  <button 
                    onClick={() => navigate('/admin-dashboard/settings')}
                    className="block w-full text-right px-4 py-2 text-sm text-gray-200 hover:bg-slate-700"
                  >
                    الإعدادات
                  </button>
                  <button 
                    onClick={handleLogout}
                    className="block w-full text-right px-4 py-2 text-sm text-red-400 hover:bg-slate-700"
                  >
                    تسجيل الخروج
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}