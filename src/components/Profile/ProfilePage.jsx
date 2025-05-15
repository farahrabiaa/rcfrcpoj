import React, { useState, useEffect } from 'react';

export default function ProfilePage() {
  const [userData, setUserData] = useState({
    name: 'مستخدم',
    email: 'user@example.com',
    type: 'customer',
    orders: []
  });

  return (
    <div className="min-h-screen bg-gray-100 p-6">
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-lg shadow-md p-6 mb-6">
          <h1 className="text-2xl font-bold mb-4">حسابي</h1>
          <div className="space-y-4">
            <div>
              <label className="block text-gray-700 mb-2">الاسم</label>
              <p className="text-lg">{userData.name}</p>
            </div>
            <div>
              <label className="block text-gray-700 mb-2">البريد الإلكتروني</label>
              <p className="text-lg">{userData.email}</p>
            </div>
            <div>
              <label className="block text-gray-700 mb-2">نوع الحساب</label>
              <p className="text-lg">{userData.type === 'customer' ? 'زبون' : userData.type === 'vendor' ? 'بائع' : 'سائق'}</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-xl font-bold mb-4">طلباتي</h2>
          {userData.orders.length > 0 ? (
            <div className="space-y-4">
              {userData.orders.map(order => (
                <div key={order.id} className="border-b pb-4">
                  <p>رقم الطلب: #{order.id}</p>
                  <p>الحالة: {order.status}</p>
                  <p>المجموع: ₪{order.total}</p>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-600">لا توجد طلبات سابقة</p>
          )}
        </div>
      </div>
    </div>
  );
}