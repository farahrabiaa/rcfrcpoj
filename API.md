# توثيق واجهة برمجة التطبيقات (API)

## نقاط النهاية المتاحة

### العملاء (Customers)

#### الحصول على قائمة العملاء
```
GET /wp-json/khdmkm/v1/customers
```
- يتطلب صلاحيات المدير
- يعيد قائمة بجميع العملاء

#### حذف عميل
```
DELETE /wp-json/khdmkm/v1/customers/{id}
```
- يتطلب صلاحيات المدير
- يحذف العميل المحدد بواسطة المعرف

### الطلبات (Orders)

#### الحصول على جميع الطلبات
```
GET /wp-json/khdmkm/v1/orders
```
- يعيد قائمة بجميع الطلبات مع معلومات العملاء والبائعين

#### الحصول على طلبات بائع معين
```
GET /wp-json/khdmkm/v1/vendor/orders?vendor_id={id}
```
- يعيد قائمة بطلبات البائع المحدد

#### تحديث حالة الطلب
```
POST /wp-json/khdmkm/v1/orders/update-status
```
المعاملات:
```json
{
  "order_id": "number",
  "status": "string"
}
```

### السائقين (Drivers)

#### تحديث موقع السائق
```
POST /wp-json/khdmkm/v1/driver/location
```
المعاملات:
```json
{
  "user_id": "number",
  "latitude": "number",
  "longitude": "number",
  "status": "string"
}
```

#### الحصول على مواقع السائقين
```
GET /wp-json/khdmkm/v1/drivers/location
```
- يعيد قائمة بمواقع السائقين النشطين في آخر 15 دقيقة

#### الحصول على السائقين المتاحين
```
GET /wp-json/khdmkm/v1/drivers/available
```
- يعيد قائمة بالسائقين المتاحين حالياً

### المنتجات (Products)

#### إدارة المنتجات
```
GET /wp-json/khdmkm/v1/products
```
- يعيد قائمة بجميع المنتجات

```
POST /wp-json/khdmkm/v1/products
```
المعاملات:
```json
{
  "name": "string",
  "price": "number",
  "description": "string",
  "vendor_id": "number"
}
```

#### الحصول على منتج محدد
```
GET /wp-json/khdmkm/v1/products/{id}
```
- يعيد تفاصيل المنتج المحدد مع الإضافات

#### إضافة ملحقات للمنتج
```
POST /wp-json/khdmkm/v1/products/{id}/addons
```
المعاملات:
```json
{
  "addons": [
    {
      "name": "string",
      "price": "number",
      "is_default": "boolean",
      "is_required": "boolean"
    }
  ]
}
```

### المحفظة (Wallet)

#### الحصول على محفظة البائع
```
GET /wp-json/khdmkm/v1/wallet/vendor/{vendor_id}
```
- يعيد معلومات محفظة البائع

#### الحصول على محفظة السائق
```
GET /wp-json/khdmkm/v1/wallet/driver/{driver_id}
```
- يعيد معلومات محفظة السائق

### التقييمات (Ratings)

#### إضافة تقييم جديد
```
POST /wp-json/khdmkm/v1/ratings
```
المعاملات:
```json
{
  "order_id": "number",
  "from_type": "string", // customer, vendor, or driver
  "from_id": "number",
  "to_type": "string", // customer, vendor, or driver
  "to_id": "number",
  "rating": "number", // 1-5
  "comment": "string"
}
```

#### الحصول على تقييمات
```
GET /wp-json/khdmkm/v1/ratings/{type}/{id}
```
- النوع يمكن أن يكون: vendor, driver, أو customer
- يعيد قائمة بالتقييمات للمستخدم المحدد

#### الحصول على تقرير التقييمات الشهري
```
GET /wp-json/khdmkm/v1/ratings/report/{type}/{year}
```
- النوع يمكن أن يكون: vendor أو driver
- يعيد تقرير شهري بمتوسط التقييمات وعددها

### المعلومات المالية (Financial)

#### الحصول على ملخص مالي
```
GET /wp-json/khdmkm/v1/financial/summary
```
- يتطلب صلاحيات المدير
- يعيد ملخص مالي للنظام

#### الحصول على عمولات الإدارة
```
GET /wp-json/khdmkm/v1/financial/commissions
```
- يتطلب صلاحيات المدير
- يعيد معلومات عن عمولات الإدارة

#### الحصول على أرصدة البائعين
```
GET /wp-json/khdmkm/v1/financial/vendor-balances
```
- يتطلب صلاحيات المدير
- يعيد معلومات عن أرصدة البائعين

#### الحصول على أرصدة السائقين
```
GET /wp-json/khdmkm/v1/financial/driver-balances
```
- يتطلب صلاحيات المدير
- يعيد معلومات عن أرصدة السائقين

### الإعلانات (Advertisements)

#### الحصول على الإعلانات
```
GET /wp-json/khdmkm/v1/advertisements
```
- يعيد قائمة بجميع الإعلانات

#### إضافة إعلان جديد
```
POST /wp-json/khdmkm/v1/advertisements
```
المعاملات:
```json
{
  "title": "string",
  "description": "string",
  "vendor_id": "number",
  "image_url": "string",
  "link": "string",
  "start_date": "date",
  "end_date": "date",
  "status": "string",
  "type": "string",
  "position": "string",
  "priority": "number"
}
```

#### تحديث إعلان
```
PUT /wp-json/khdmkm/v1/advertisements/{id}
```
المعاملات: نفس معاملات إضافة إعلان جديد

#### حذف إعلان
```
DELETE /wp-json/khdmkm/v1/advertisements/{id}
```
- يحذف الإعلان المحدد بواسطة المعرف

### المصادقة (Authentication)

#### تسجيل الدخول
```
POST /wp-json/khdmkm/v1/auth/login
```
المعاملات:
```json
{
  "username": "string",
  "password": "string"
}
```

#### تسجيل الخروج
```
POST /wp-json/khdmkm/v1/auth/logout
```
- يقوم بتسجيل خروج المستخدم الحالي

#### الحصول على معلومات المستخدم الحالي
```
GET /wp-json/khdmkm/v1/auth/me
```
- يعيد معلومات المستخدم الحالي

## الأمان والصلاحيات

- بعض النقاط تتطلب صلاحيات المدير (`manage_options`)
- معظم النقاط متاحة للمستخدمين المسجلين
- يتم التحقق من الصلاحيات تلقائياً

## التعامل مع الأخطاء

جميع نقاط النهاية تعيد:
- 200: نجاح العملية
- 201: تم إنشاء العنصر بنجاح
- 400: خطأ في المعاملات
- 401: غير مصرح
- 403: ممنوع
- 404: العنصر غير موجود
- 500: خطأ في الخادم