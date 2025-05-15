import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import {
  ChartBarIcon,
  ShoppingBagIcon,
  UserGroupIcon,
  TruckIcon,
  BuildingStorefrontIcon,
  BellIcon,
  CubeIcon,
  Cog6ToothIcon,
  ArrowRightOnRectangleIcon,
  MegaphoneIcon,
  TagIcon,
  GiftIcon,
  TicketIcon,
  StarIcon,
  ShareIcon,
  UsersIcon,
  PhotoIcon,
  ScaleIcon,
  CreditCardIcon,
  ChartPieIcon,
  BanknotesIcon,
  KeyIcon,
  WalletIcon
} from '@heroicons/react/24/outline';

// القائمة الجانبية
const menuItems = [
  { id: 'overview', label: 'الإحصائيات', icon: ChartBarIcon },
  { id: 'financial-dashboard', label: 'لوحة المعلومات المالية', icon: BanknotesIcon },
  { id: 'orders', label: 'الطلبات', icon: ShoppingBagIcon },
  {
    id: 'products-management',
    label: 'إدارة المنتجات',
    icon: CubeIcon,
    subItems: [
      { id: 'products', label: 'المنتجات' },
      { id: 'products-management', label: 'إدارة المنتجات' },
      { id: 'categories', label: 'التصنيفات' }
    ]
  },
  {
    id: 'vendors-management',
    label: 'إدارة البائعين',
    icon: BuildingStorefrontIcon,
    subItems: [
      { id: 'vendors', label: 'قائمة البائعين' },
      { id: 'vendors-list', label: 'عرض البائعين' },
      { id: 'add-vendor', label: 'إضافة بائع' },
      { id: 'vendor-categories-table', label: 'أقسام المتاجر' }
    ]
  },
  {
    id: 'drivers-management',
    label: 'إدارة السائقين',
    icon: TruckIcon,
    subItems: [
      { id: 'drivers', label: 'قائمة السائقين' },
      { id: 'add-driver', label: 'إضافة سائق' }
    ]
  },
  { id: 'shipping-methods', label: 'طرق التوصيل', icon: TruckIcon },
  {
    id: 'payments-management',
    label: 'إدارة المدفوعات',
    icon: CreditCardIcon,
    subItems: [
      { id: 'payments', label: 'طرق الدفع' },
      { id: 'wallet', label: 'المحفظة' },
      { id: 'wallet-settings', label: 'إعدادات المحفظة' },
      { id: 'wallet-charging', label: 'شحن المحافظ' }
    ]
  },
  {
    id: 'customers-management',
    label: 'إدارة الزبائن',
    icon: UserGroupIcon,
    subItems: [
      { id: 'customers', label: 'قائمة الزبائن' },
      { id: 'add-customer', label: 'إضافة زبون' }
    ]
  },
  { id: 'wholesale', label: 'عملاء الجملة', icon: ScaleIcon },
  {
    id: 'users-management',
    label: 'إدارة المستخدمين',
    icon: UsersIcon,
    subItems: [
      { id: 'users', label: 'مستخدمي النظام' }
    ]
  },
  { id: 'media', label: 'الوسائط', icon: PhotoIcon },
  { id: 'api-keys', label: 'مفاتيح API', icon: KeyIcon },
  {
    id: 'ratings',
    label: 'التقييمات',
    icon: StarIcon,
    subItems: [
      { id: 'vendor-ratings', label: 'تقييمات المتاجر' },
      { id: 'driver-ratings', label: 'تقييمات السائقين' },
      { id: 'customer-ratings', label: 'تقييمات الزبائن' },
      { id: 'ratings-report', label: 'تقرير التقييمات الشهري' }
    ]
  },
  { id: 'advertisements', label: 'الإعلانات', icon: MegaphoneIcon },
  { id: 'coupons', label: 'كوبونات الخصم', icon: TicketIcon },
  { id: 'points-rewards', label: 'النقاط والمكافآت', icon: GiftIcon },
  { id: 'referral', label: 'نظام الإحالة', icon: ShareIcon },
  { id: 'notifications', label: 'الإشعارات', icon: BellIcon },
  { id: 'settings', label: 'الإعدادات', icon: Cog6ToothIcon }
];

export default function Sidebar({ activeTab, onTabChange }) {
  const navigate = useNavigate();
  const { logout } = useAuth();
  const [expandedItems, setExpandedItems] = useState({
    'products-management': false,
    'vendors-management': false,
    'drivers-management': false,
    'customers-management': false,
    'users-management': false,
    'ratings': false,
    'payments-management': true
  });

  const handleTabClick = (tabId) => {
    onTabChange(tabId);
    navigate(`/admin-dashboard/${tabId}`);
  };

  const toggleExpand = (itemId) => {
    setExpandedItems(prev => ({
      ...prev,
      [itemId]: !prev[itemId]
    }));
  };

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <aside className="fixed right-0 top-0 w-64 h-full flex flex-col bg-slate-900 text-white shadow-xl z-50">
      {/* الهيدر */}
      <div className="p-4 border-b border-slate-700/50 bg-gradient-to-r from-slate-900 to-slate-800">
        <div className="flex items-center justify-center">
          <div className="w-10 h-10 bg-blue-600 rounded-lg flex items-center justify-center text-white shadow-lg">
            🛒
          </div>
          <h2 className="mr-2 text-lg font-bold bg-gradient-to-r from-blue-400 to-blue-600 bg-clip-text text-transparent">
            لوحة التحكم
          </h2>
        </div>
      </div>

      {/* معلومات المستخدم */}
      <div className="p-4 border-b border-slate-700/50">
        <div className="flex items-center gap-3 bg-slate-800/50 p-3 rounded-lg">
          <div className="w-10 h-10 bg-slate-700 rounded-full flex items-center justify-center border-2 border-yellow-500">
            👤
          </div>
          <div>
            <h3 className="font-medium text-yellow-100">مدير النظام</h3>
            <p className="text-xs text-slate-400">admin@example.com</p>
          </div>
        </div>
      </div>

      {/* قائمة التنقل */}
      <nav className="flex-1 overflow-y-auto p-4 space-y-1.5">
        {menuItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id || (item.subItems && item.subItems.some(sub => activeTab === sub.id));
          const isExpanded = expandedItems[item.id];

          return (
            <div key={item.id}>
              <Link
                to={item.subItems ? "#" : `/admin-dashboard/${item.id}`}
                onClick={(e) => {
                  e.preventDefault();
                  if (item.subItems) {
                    toggleExpand(item.id);
                  } else {
                    handleTabClick(item.id);
                  }
                }}
                className={`flex items-center w-full px-4 py-3 rounded-lg transition-all duration-200 group ${
                  isActive ? 'bg-gradient-to-r from-yellow-600 to-yellow-700 text-white shadow-lg' : 'text-slate-300 hover:bg-slate-800/70 hover:text-white'
                }`}
              >
                <Icon className={`w-5 h-5 ml-3 ${isActive ? 'text-white' : 'text-slate-400'} group-hover:scale-110`} />
                <span className="font-medium">{item.label}</span>
                {item.subItems && (
                  <svg
                    className={`w-4 h-4 mr-auto transition-transform ${isExpanded ? 'rotate-180' : ''}`}
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                )}
              </Link>

              {item.subItems && isExpanded && (
                <div className="mt-1 mr-4 space-y-1">
                  {item.subItems.map((subItem) => (
                    <Link
                      key={subItem.id}
                      to={`/admin-dashboard/${subItem.id}`}
                      onClick={(e) => {
                        e.preventDefault();
                        handleTabClick(subItem.id);
                      }}
                      className={`flex items-center w-full px-4 py-2 rounded-lg transition-all duration-200 ${
                        activeTab === subItem.id ? 'bg-yellow-600/50 text-white' : 'text-slate-400 hover:bg-slate-800/30 hover:text-white'
                      }`}
                    >
                      <span className="text-sm">{subItem.label}</span>
                    </Link>
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </nav>

      {/* تسجيل الخروج */}
      <div className="p-4 border-t border-slate-700/50 bg-slate-900/50 backdrop-blur-sm">
        <button 
          onClick={handleLogout}
          className="flex items-center w-full px-4 py-2 text-slate-300 hover:text-white hover:bg-red-500/10 rounded-lg transition-colors group"
        >
          <ArrowRightOnRectangleIcon className="w-5 h-5 ml-3 group-hover:text-red-400" />
          <span className="group-hover:text-red-400">تسجيل الخروج</span>
        </button>
      </div>
    </aside>
  );
}