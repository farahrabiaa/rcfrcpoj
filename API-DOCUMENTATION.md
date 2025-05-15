# توثيق واجهة برمجة التطبيقات (API) مع مصادقة مفتاح API

## المصادقة

### 1. مصادقة مفتاح API (Basic Authentication)

يمكنك استخدام المصادقة الأساسية (Basic Authentication) باستخدام مفتاح المستهلك (Consumer Key) وسر المستهلك (Consumer Secret):

```javascript
// المصادقة الأساسية باستخدام مفتاح API
const consumerKey = 'ck_19a63d91fecfe2694594ee707c966591';
const consumerSecret = 'cs_fa6ab8c5303318963c16ebdebe123ab9';
const credentials = btoa(`${consumerKey}:${consumerSecret}`);

// إضافة رأس المصادقة إلى الطلب
fetch('https://crfkmdhoruknzgkoyckv.supabase.co/functions/v1/api/categories', {
  headers: {
    'Authorization': `Basic ${credentials}`,
    'Content-Type': 'application/json'
  }
})
.then(response => response.json())
.then(data => console.log(data))
.catch(error => console.error('Error:', error));
```

### 2. مصادقة مفتاح API عبر معلمات URL

يمكنك أيضًا تمرير مفتاح API كمعلمات URL:

```javascript
fetch('https://crfkmdhoruknzgkoyckv.supabase.co/functions/v1/api/categories?consumer_key=ck_19a63d91fecfe2694594ee707c966591&consumer_secret=cs_fa6ab8c5303318963c16ebdebe123ab9')
  .then(response => response.json())
  .then(data => console.log(data))
  .catch(error => console.error('Error:', error));
```

> **ملاحظة أمنية**: يفضل استخدام المصادقة الأساسية عبر HTTPS لضمان أمان المفاتيح. تجنب استخدام معلمات URL في بيئة الإنتاج.

## نقاط النهاية المتاحة

### التصنيفات (Categories)

#### الحصول على جميع التصنيفات
```
GET /api/categories
```

#### الحصول على تصنيف محدد
```
GET /api/categories/{id}
```

#### إنشاء تصنيف جديد
```
POST /api/categories
```
المعاملات:
```json
{
  "name": "اسم التصنيف",
  "slug": "category-slug",
  "description": "وصف التصنيف",
  "parent_id": null
}
```

#### تحديث تصنيف
```
PUT /api/categories/{id}
```
المعاملات: نفس معاملات إنشاء تصنيف جديد

#### حذف تصنيف
```
DELETE /api/categories/{id}
```

### المنتجات (Products)

#### الحصول على جميع المنتجات
```
GET /api/products
```

#### الحصول على منتجات بائع محدد
```
GET /api/products?vendor_id={id}
```

#### الحصول على منتج محدد
```
GET /api/products/{id}
```

#### إنشاء منتج جديد
```
POST /api/products
```
المعاملات:
```json
{
  "vendor_id": "uuid",
  "category_id": "uuid",
  "name": "اسم المنتج",
  "description": "وصف المنتج",
  "price": 15.00,
  "wholesale_price": 12.00,
  "discount_price": 13.00,
  "status": "active",
  "stock": 100,
  "image_url": "https://example.com/image.jpg"
}
```

#### تحديث منتج
```
PUT /api/products/{id}
```
المعاملات: نفس معاملات إنشاء منتج جديد

#### حذف منتج
```
DELETE /api/products/{id}
```

### الطلبات (Orders)

#### الحصول على جميع الطلبات
```
GET /api/orders
```

#### الحصول على طلبات بائع محدد
```
GET /api/orders?vendor_id={id}
```

#### الحصول على طلبات سائق محدد
```
GET /api/orders?driver_id={id}
```

#### الحصول على طلبات زبون محدد
```
GET /api/orders?customer_id={id}
```

#### الحصول على طلب محدد
```
GET /api/orders/{id}
```

#### إنشاء طلب جديد
```
POST /api/orders
```
المعاملات:
```json
{
  "customer_id": "uuid",
  "vendor_id": "uuid",
  "status": "pending",
  "total": 45.00,
  "subtotal": 40.00,
  "delivery_fee": 5.00,
  "payment_method": "cash",
  "address": "عنوان التوصيل",
  "latitude": 31.5017,
  "longitude": 34.4668,
  "items": [
    {
      "product_id": "uuid",
      "quantity": 2,
      "price": 15.00,
      "addons_data": [
        { "id": "uuid", "name": "سكر", "price": 0 }
      ]
    },
    {
      "product_id": "uuid",
      "quantity": 1,
      "price": 10.00
    }
  ]
}
```

#### تحديث حالة الطلب
```
PUT /api/orders/{id}/status
```
المعاملات:
```json
{
  "status": "accepted"
}
```

#### تعيين سائق للطلب
```
PUT /api/orders/{id}/driver
```
المعاملات:
```json
{
  "driver_id": "uuid"
}
```

### السائقين (Drivers)

#### الحصول على جميع السائقين
```
GET /api/drivers
```

#### الحصول على السائقين المتاحين
```
GET /api/drivers/available
```

#### تحديث موقع السائق
```
PUT /api/drivers/{id}/location
```
المعاملات:
```json
{
  "latitude": 31.5017,
  "longitude": 34.4668
}
```

#### تحديث حالة السائق
```
PUT /api/drivers/{id}/status
```
المعاملات:
```json
{
  "status": "available"
}
```

### المحفظة (Wallet)

#### الحصول على رصيد المحفظة
```
GET /api/wallet
```

#### الحصول على معاملات المحفظة
```
GET /api/wallet/transactions
```

#### إنشاء معاملة سحب
```
POST /api/wallet/withdraw
```
المعاملات:
```json
{
  "amount": 100.00
}
```

### التقييمات (Ratings)

#### إضافة تقييم جديد
```
POST /api/ratings
```
المعاملات:
```json
{
  "order_id": "uuid",
  "from_type": "customer",
  "from_id": "uuid",
  "to_type": "vendor",
  "to_id": "uuid",
  "rating": 5,
  "comment": "تعليق على التقييم"
}
```

#### الحصول على تقييمات
```
GET /api/ratings/{type}/{id}
```
حيث `type` يمكن أن يكون `vendor`, `driver`, أو `customer`

#### الحصول على تقرير التقييمات الشهري
```
GET /api/ratings/report/{type}/{year}
```
حيث `type` يمكن أن يكون `vendor` أو `driver`

### الإعلانات (Advertisements)

#### الحصول على جميع الإعلانات
```
GET /api/advertisements
```

#### إنشاء إعلان جديد
```
POST /api/advertisements
```
المعاملات:
```json
{
  "title": "عنوان الإعلان",
  "description": "وصف الإعلان",
  "vendor_id": "uuid",
  "image_url": "https://example.com/image.jpg",
  "link": "https://example.com",
  "start_date": "2025-01-01",
  "end_date": "2025-12-31",
  "status": "active",
  "type": "banner",
  "position": "home",
  "priority": 1
}
```

#### تحديث إعلان
```
PUT /api/advertisements/{id}
```
المعاملات: نفس معاملات إنشاء إعلان جديد

#### حذف إعلان
```
DELETE /api/advertisements/{id}
```

### الملفات والوسائط (Files & Media)

#### رفع ملف
```
POST /api/storage/upload/{bucket}
```
حيث `bucket` يمكن أن يكون `products`, `vendors`, `profiles`, `advertisements`, أو `general`

#### حذف ملف
```
DELETE /api/storage/remove/{bucket}/{path}
```

#### الحصول على قائمة الملفات
```
GET /api/storage/list/{bucket}
```

## أمثلة للاستخدام في تطبيقات مختلفة

### تطبيق الزبائن

```javascript
// المصادقة باستخدام مفتاح API
const consumerKey = 'ck_19a63d91fecfe2694594ee707c966591';
const consumerSecret = 'cs_fa6ab8c5303318963c16ebdebe123ab9';
const credentials = btoa(`${consumerKey}:${consumerSecret}`);

// إنشاء نسخة من axios مع إعدادات المصادقة
const api = axios.create({
  baseURL: 'https://crfkmdhoruknzgkoyckv.supabase.co/functions/v1/api',
  headers: {
    'Authorization': `Basic ${credentials}`,
    'Content-Type': 'application/json'
  }
});

// الحصول على قائمة المنتجات
api.get('/products')
  .then(response => {
    // عرض المنتجات في التطبيق
    console.log(response.data);
  })
  .catch(error => {
    console.error('Error:', error);
  });

// إنشاء طلب جديد
api.post('/orders', {
  customer_id: customerId,
  vendor_id: vendorId,
  status: 'pending',
  total: 45.00,
  subtotal: 40.00,
  delivery_fee: 5.00,
  payment_method: 'cash',
  address: 'عنوان التوصيل',
  latitude: 31.5017,
  longitude: 34.4668,
  items: [
    {
      product_id: productId1,
      quantity: 2,
      price: 15.00,
      addons_data: [
        { id: addonId1, name: 'سكر', price: 0 }
      ]
    },
    {
      product_id: productId2,
      quantity: 1,
      price: 10.00
    }
  ]
})
  .then(response => {
    console.log('تم إنشاء الطلب:', response.data);
  })
  .catch(error => {
    console.error('Error:', error);
  });
```

### تطبيق السائقين

```javascript
// المصادقة باستخدام مفتاح API
const consumerKey = 'ck_19a63d91fecfe2694594ee707c966591';
const consumerSecret = 'cs_fa6ab8c5303318963c16ebdebe123ab9';
const credentials = btoa(`${consumerKey}:${consumerSecret}`);

// إنشاء نسخة من axios مع إعدادات المصادقة
const api = axios.create({
  baseURL: 'https://crfkmdhoruknzgkoyckv.supabase.co/functions/v1/api',
  headers: {
    'Authorization': `Basic ${credentials}`,
    'Content-Type': 'application/json'
  }
});

// تحديث موقع وحالة السائق
api.put(`/drivers/${driverId}/location`, {
  latitude: 31.5017,
  longitude: 34.4668
})
  .then(response => {
    console.log('تم تحديث الموقع:', response.data);
  })
  .catch(error => {
    console.error('Error:', error);
  });

api.put(`/drivers/${driverId}/status`, {
  status: 'available'
})
  .then(response => {
    console.log('تم تحديث الحالة:', response.data);
  })
  .catch(error => {
    console.error('Error:', error);
  });

// الحصول على الطلبات المسندة للسائق
api.get(`/orders?driver_id=${driverId}`)
  .then(response => {
    console.log('الطلبات المسندة:', response.data);
  })
  .catch(error => {
    console.error('Error:', error);
  });
```

### تطبيق البائعين

```javascript
// المصادقة باستخدام مفتاح API
const consumerKey = 'ck_19a63d91fecfe2694594ee707c966591';
const consumerSecret = 'cs_fa6ab8c5303318963c16ebdebe123ab9';
const credentials = btoa(`${consumerKey}:${consumerSecret}`);

// إنشاء نسخة من axios مع إعدادات المصادقة
const api = axios.create({
  baseURL: 'https://crfkmdhoruknzgkoyckv.supabase.co/functions/v1/api',
  headers: {
    'Authorization': `Basic ${credentials}`,
    'Content-Type': 'application/json'
  }
});

// الحصول على طلبات البائع
api.get(`/orders?vendor_id=${vendorId}`)
  .then(response => {
    console.log('طلبات البائع:', response.data);
  })
  .catch(error => {
    console.error('Error:', error);
  });

// تحديث حالة طلب
api.put(`/orders/${orderId}/status`, {
  status: 'accepted'
})
  .then(response => {
    console.log('تم تحديث حالة الطلب:', response.data);
  })
  .catch(error => {
    console.error('Error:', error);
  });

// إضافة منتج جديد
api.post('/products', {
  vendor_id: vendorId,
  category_id: categoryId,
  name: 'اسم المنتج',
  description: 'وصف المنتج',
  price: 15.00,
  status: 'active',
  stock: 100
})
  .then(response => {
    console.log('تم إضافة المنتج:', response.data);
  })
  .catch(error => {
    console.error('Error:', error);
  });
```

## التعامل مع الأخطاء

جميع نقاط النهاية تعيد:
- 200: نجاح العملية
- 201: تم إنشاء العنصر بنجاح
- 400: خطأ في المعاملات
- 401: غير مصرح
- 403: ممنوع
- 404: العنصر غير موجود
- 500: خطأ في الخادم

مثال على التعامل مع الأخطاء:

```javascript
api.get('/products')
  .then(response => {
    console.log(response.data);
  })
  .catch(error => {
    if (error.response) {
      // الخادم استجاب برمز حالة خارج نطاق 2xx
      console.error('Error status:', error.response.status);
      console.error('Error data:', error.response.data);
      
      if (error.response.status === 401) {
        // إعادة توجيه المستخدم إلى صفحة تسجيل الدخول
        window.location.href = '/login';
      } else if (error.response.status === 403) {
        // عرض رسالة خطأ للمستخدم
        alert('ليس لديك صلاحية للوصول إلى هذا المورد');
      }
    } else if (error.request) {
      // تم إجراء الطلب ولكن لم يتم استلام استجابة
      console.error('No response received:', error.request);
      alert('فشل الاتصال بالخادم');
    } else {
      // حدث خطأ أثناء إعداد الطلب
      console.error('Error message:', error.message);
    }
  });
```