import React, { useState } from 'react';

export default function ApiKeyForm({ onSubmit, onCancel, loading }) {
  const [formData, setFormData] = useState({
    description: '',
    permissions: ['read']
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    onSubmit(formData);
  };

  const handlePermissionChange = (permission) => {
    setFormData(prev => {
      const newPermissions = prev.permissions.includes(permission)
        ? prev.permissions.filter(p => p !== permission)
        : [...prev.permissions, permission];
      
      return { ...prev, permissions: newPermissions };
    });
  };

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <h3 className="text-lg font-semibold mb-4">إنشاء مفتاح API جديد</h3>
      
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            الوصف
          </label>
          <input
            type="text"
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            className="w-full border rounded-md px-3 py-2"
            placeholder="مثال: تطبيق الجوال، موقع الويب، إلخ"
            required
          />
          <p className="mt-1 text-sm text-gray-500">
            أدخل وصفًا يساعدك على تذكر الغرض من هذا المفتاح
          </p>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            الصلاحيات
          </label>
          <div className="space-y-2">
            <label className="flex items-center">
              <input
                type="checkbox"
                checked={formData.permissions.includes('read')}
                onChange={() => handlePermissionChange('read')}
                className="rounded text-blue-600 focus:ring-blue-500 ml-2"
              />
              <span>قراءة (Read)</span>
              <span className="mr-2 text-sm text-gray-500">- الوصول للقراءة فقط</span>
            </label>
            
            <label className="flex items-center">
              <input
                type="checkbox"
                checked={formData.permissions.includes('write')}
                onChange={() => handlePermissionChange('write')}
                className="rounded text-blue-600 focus:ring-blue-500 ml-2"
              />
              <span>كتابة (Write)</span>
              <span className="mr-2 text-sm text-gray-500">- إنشاء وتحديث البيانات</span>
            </label>
            
            <label className="flex items-center">
              <input
                type="checkbox"
                checked={formData.permissions.includes('delete')}
                onChange={() => handlePermissionChange('delete')}
                className="rounded text-blue-600 focus:ring-blue-500 ml-2"
              />
              <span>حذف (Delete)</span>
              <span className="mr-2 text-sm text-gray-500">- حذف البيانات</span>
            </label>
          </div>
          <p className="mt-1 text-sm text-gray-500">
            حدد الصلاحيات التي تريد منحها لهذا المفتاح
          </p>
        </div>

        <div className="flex justify-end space-x-2 pt-4">
          <button
            type="button"
            onClick={onCancel}
            className="px-4 py-2 text-gray-600 hover:text-gray-800"
            disabled={loading}
          >
            إلغاء
          </button>
          <button
            type="submit"
            className={`px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 ${
              loading ? 'opacity-70 cursor-not-allowed' : ''
            }`}
            disabled={loading}
          >
            {loading ? 'جاري الإنشاء...' : 'إنشاء مفتاح'}
          </button>
        </div>
      </form>
    </div>
  );
}