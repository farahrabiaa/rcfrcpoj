import React, { useState } from 'react';
import { Dialog } from '@headlessui/react';
import { toast } from 'react-toastify';

export default function ApiKeyList({ 
  apiKeys, 
  onRevoke, 
  onActivate,
  onUpdateDescription,
  onUpdatePermissions
}) {
  const [editingKey, setEditingKey] = useState(null);
  const [editDescription, setEditDescription] = useState('');
  const [editPermissions, setEditPermissions] = useState([]);
  const [showEditModal, setShowEditModal] = useState(false);

  const handleEdit = (key) => {
    setEditingKey(key);
    setEditDescription(key.description);
    setEditPermissions(key.permissions);
    setShowEditModal(true);
  };

  const handleSaveEdit = () => {
    if (editingKey) {
      if (editDescription !== editingKey.description) {
        onUpdateDescription(editingKey.id, editDescription);
      }
      
      if (JSON.stringify(editPermissions) !== JSON.stringify(editingKey.permissions)) {
        onUpdatePermissions(editingKey.id, editPermissions);
      }
    }
    
    setShowEditModal(false);
    setEditingKey(null);
  };

  const handlePermissionChange = (permission) => {
    setEditPermissions(prev => {
      const newPermissions = prev.includes(permission)
        ? prev.filter(p => p !== permission)
        : [...prev, permission];
      
      return newPermissions;
    });
  };

  const formatDate = (dateString) => {
    if (!dateString) return 'لم يستخدم بعد';
    
    return new Date(dateString).toLocaleString('ar-SA', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  if (apiKeys.length === 0) {
    return (
      <div className="bg-white rounded-lg shadow-md p-8 text-center">
        <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
        </svg>
        <h3 className="mt-2 text-sm font-medium text-gray-900">لا توجد مفاتيح API</h3>
        <p className="mt-1 text-sm text-gray-500">ابدأ بإنشاء مفتاح API جديد للوصول إلى واجهة برمجة التطبيقات.</p>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow-md overflow-hidden">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">الوصف</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">المفتاح</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">الصلاحيات</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">تاريخ الإنشاء</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">آخر استخدام</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">الحالة</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">الإجراءات</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {apiKeys.map(key => (
              <tr key={key.id}>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="text-sm font-medium text-gray-900">{key.description}</div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center">
                    <code className="text-sm font-mono bg-gray-100 px-2 py-1 rounded">
                      {key.consumer_key}
                    </code>
                    <button
                      onClick={() => {
                        navigator.clipboard.writeText(key.consumer_key);
                        toast.success('تم نسخ المفتاح');
                      }}
                      className="mr-2 text-blue-600 hover:text-blue-800"
                    >
                      نسخ
                    </button>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex flex-wrap gap-1">
                    {key.permissions.includes('read') && (
                      <span className="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800">
                        قراءة
                      </span>
                    )}
                    {key.permissions.includes('write') && (
                      <span className="px-2 py-1 text-xs rounded-full bg-green-100 text-green-800">
                        كتابة
                      </span>
                    )}
                    {key.permissions.includes('delete') && (
                      <span className="px-2 py-1 text-xs rounded-full bg-red-100 text-red-800">
                        حذف
                      </span>
                    )}
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {formatDate(key.created_at)}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {formatDate(key.last_used)}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`px-2 py-1 text-xs rounded-full ${
                    key.status === 'active' 
                      ? 'bg-green-100 text-green-800' 
                      : 'bg-red-100 text-red-800'
                  }`}>
                    {key.status === 'active' ? 'نشط' : 'معطل'}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <button
                    onClick={() => handleEdit(key)}
                    className="text-blue-600 hover:text-blue-800 ml-3"
                  >
                    تعديل
                  </button>
                  {key.status === 'active' ? (
                    <button
                      onClick={() => onRevoke(key.id)}
                      className="text-red-600 hover:text-red-800"
                    >
                      تعطيل
                    </button>
                  ) : (
                    <button
                      onClick={() => onActivate(key.id)}
                      className="text-green-600 hover:text-green-800"
                    >
                      تفعيل
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Edit Modal */}
      <Dialog
        open={showEditModal}
        onClose={() => setShowEditModal(false)}
        className="fixed inset-0 z-50 overflow-y-auto"
      >
        <div className="flex items-center justify-center min-h-screen">
          <Dialog.Overlay className="fixed inset-0 bg-black opacity-30" />

          <div className="relative bg-white rounded-lg p-8 max-w-md w-full mx-4">
            <Dialog.Title className="text-2xl font-bold mb-6">
              تعديل مفتاح API
            </Dialog.Title>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  الوصف
                </label>
                <input
                  type="text"
                  value={editDescription}
                  onChange={(e) => setEditDescription(e.target.value)}
                  className="w-full border rounded-md px-3 py-2"
                  placeholder="مثال: تطبيق الجوال، موقع الويب، إلخ"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  الصلاحيات
                </label>
                <div className="space-y-2">
                  <label className="flex items-center">
                    <input
                      type="checkbox"
                      checked={editPermissions.includes('read')}
                      onChange={() => handlePermissionChange('read')}
                      className="rounded text-blue-600 focus:ring-blue-500 ml-2"
                    />
                    <span>قراءة (Read)</span>
                    <span className="mr-2 text-sm text-gray-500">- الوصول للقراءة فقط</span>
                  </label>
                  
                  <label className="flex items-center">
                    <input
                      type="checkbox"
                      checked={editPermissions.includes('write')}
                      onChange={() => handlePermissionChange('write')}
                      className="rounded text-blue-600 focus:ring-blue-500 ml-2"
                    />
                    <span>كتابة (Write)</span>
                    <span className="mr-2 text-sm text-gray-500">- إنشاء وتحديث البيانات</span>
                  </label>
                  
                  <label className="flex items-center">
                    <input
                      type="checkbox"
                      checked={editPermissions.includes('delete')}
                      onChange={() => handlePermissionChange('delete')}
                      className="rounded text-blue-600 focus:ring-blue-500 ml-2"
                    />
                    <span>حذف (Delete)</span>
                    <span className="mr-2 text-sm text-gray-500">- حذف البيانات</span>
                  </label>
                </div>
              </div>

              <div className="flex justify-end space-x-2 pt-4">
                <button
                  type="button"
                  onClick={() => setShowEditModal(false)}
                  className="px-4 py-2 text-gray-600 hover:text-gray-800"
                >
                  إلغاء
                </button>
                <button
                  type="button"
                  onClick={handleSaveEdit}
                  className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
                >
                  حفظ التغييرات
                </button>
              </div>
            </div>
          </div>
        </div>
      </Dialog>
    </div>
  );
}