# توثيق نقاط نهاية Supabase

هذا المستند يوضح نقاط النهاية المتاحة للاستخدام في تطبيقات الزبائن والسائقين والبائعين.

## المصادقة

جميع الطلبات تتطلب مصادقة باستخدام إحدى الطرق التالية:

### 1. مصادقة المستخدم (JWT)

```javascript
// تسجيل الدخول والحصول على رمز JWT
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'password'
});

// استخدام الرمز في الطلبات اللاحقة
// يتم إدارته تلقائيًا بواسطة مكتبة Supabase
```

### 2. مصادقة مفتاح API

```javascript
// المصادقة الأساسية باستخدام مفتاح API
const consumerKey = 'ck_xxxxxxxxxxxxxxxxxxxx';
const consumerSecret = 'cs_xxxxxxxxxxxxxxxxxxxx';
const credentials = btoa(`${consumerKey}:${consumerSecret}`);

fetch('https://crfkmdhoruknzgkoyckv.supabase.co/functions/v1/api/categories', {
  headers: {
    'Authorization': `Basic ${credentials}`
  }
});
```

## نقاط نهاية المستخدمين

### تسجيل الدخول

```javascript
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'password'
});
```

### تسجيل الخروج

```javascript
const { error } = await supabase.auth.signOut();
```

### التسجيل

```javascript
const { data, error } = await supabase.auth.signUp({
  email: 'user@example.com',
  password: 'password'
});

// إنشاء ملف تعريف المستخدم
const { error: profileError } = await supabase
  .from('profiles')
  .insert([
    {
      id: data.user.id,
      name: 'اسم المستخدم',
      role: 'customer', // يمكن أن تكون 'customer', 'vendor', 'driver'
      phone: '0599123456'
    }
  ]);
```

### الحصول على المستخدم الحالي

```javascript
const { data: { user }, error } = await supabase.auth.getUser();

// الحصول على ملف تعريف المستخدم
const { data: profile, error: profileError } = await supabase
  .from('profiles')
  .select('*')
  .eq('id', user.id)
  .single();
```

## نقاط نهاية التصنيفات

### الحصول على جميع التصنيفات

```javascript
const { data, error } = await supabase
  .from('categories')
  .select('*');
```

### الحصول على تصنيف محدد

```javascript
const { data, error } = await supabase
  .from('categories')
  .select('*')
  .eq('id', categoryId)
  .single();
```

### إنشاء تصنيف جديد

```javascript
const { data, error } = await supabase
  .from('categories')
  .insert([
    {
      name: 'اسم التصنيف',
      slug: 'category-slug',
      description: 'وصف التصنيف'
    }
  ])
  .select();
```

### تحديث تصنيف

```javascript
const { data, error } = await supabase
  .from('categories')
  .update({
    name: 'اسم التصنيف الجديد',
    description: 'وصف التصنيف الجديد'
  })
  .eq('id', categoryId)
  .select();
```

### حذف تصنيف

```javascript
const { error } = await supabase
  .from('categories')
  .delete()
  .eq('id', categoryId);
```

## نقاط نهاية المنتجات

### الحصول على جميع المنتجات

```javascript
const { data, error } = await supabase
  .from('products')
  .select('*');
```

### الحصول على منتجات بائع محدد

```javascript
const { data, error } = await supabase
  .from('products')
  .select('*')
  .eq('vendor_id', vendorId);
```

### الحصول على منتج محدد مع الإضافات

```javascript
const { data, error } = await supabase
  .from('products')
  .select(`
    *,
    product_addons(*)
  `)
  .eq('id', productId)
  .single();
```

### إنشاء منتج جديد

```javascript
const { data, error } = await supabase
  .from('products')
  .insert([
    {
      vendor_id: vendorId,
      category_id: categoryId,
      name: 'اسم المنتج',
      description: 'وصف المنتج',
      price: 15.00,
      wholesale_price: 12.00,
      discount_price: 13.00,
      status: 'active', // يمكن أن تكون 'active', 'inactive', 'draft'
      stock: 100,
      image_url: 'https://example.com/image.jpg'
    }
  ])
  .select();
```

### تحديث منتج

```javascript
const { data, error } = await supabase
  .from('products')
  .update({
    name: 'اسم المنتج الجديد',
    price: 20.00
  })
  .eq('id', productId)
  .select();
```

### حذف منتج

```javascript
const { error } = await supabase
  .from('products')
  .delete()
  .eq('id', productId);
```

### إضافة ملحقات للمنتج

```javascript
const { data, error } = await supabase
  .from('product_addons')
  .insert([
    {
      product_id: productId,
      name: 'اسم الملحق',
      price: 2.00,
      is_default: false,
      is_required: false
    }
  ])
  .select();
```

## نقاط نهاية الطلبات

### الحصول على جميع الطلبات

```javascript
const { data, error } = await supabase
  .from('orders')
  .select(`
    *,
    customer:customer_id(*),
    vendor:vendor_id(*),
    driver:driver_id(*)
  `);
```

### الحصول على طلبات بائع محدد

```javascript
const { data, error } = await supabase
  .from('orders')
  .select(`
    *,
    customer:customer_id(*),
    driver:driver_id(*)
  `)
  .eq('vendor_id', vendorId);
```

### الحصول على طلبات سائق محدد

```javascript
const { data, error } = await supabase
  .from('orders')
  .select(`
    *,
    customer:customer_id(*),
    vendor:vendor_id(*)
  `)
  .eq('driver_id', driverId);
```

### الحصول على طلبات زبون محدد

```javascript
const { data, error } = await supabase
  .from('orders')
  .select(`
    *,
    vendor:vendor_id(*),
    driver:driver_id(*)
  `)
  .eq('customer_id', customerId);
```

### الحصول على تفاصيل طلب محدد مع العناصر

```javascript
// الحصول على الطلب
const { data: order, error } = await supabase
  .from('orders')
  .select(`
    *,
    customer:customer_id(*),
    vendor:vendor_id(*),
    driver:driver_id(*)
  `)
  .eq('id', orderId)
  .single();

// الحصول على عناصر الطلب
const { data: items, error: itemsError } = await supabase
  .from('order_items')
  .select(`
    *,
    product:product_id(*)
  `)
  .eq('order_id', orderId);
```

### إنشاء طلب جديد

```javascript
// إنشاء الطلب
const { data: order, error } = await supabase
  .from('orders')
  .insert([
    {
      customer_id: customerId,
      vendor_id: vendorId,
      status: 'pending',
      total: 45.00,
      subtotal: 40.00,
      delivery_fee: 5.00,
      payment_method: 'cash', // يمكن أن تكون 'cash', 'electronic', 'wallet'
      address: 'عنوان التوصيل',
      latitude: 31.5017,
      longitude: 34.4668
    }
  ])
  .select();

// إضافة عناصر الطلب
const { data: items, error: itemsError } = await supabase
  .from('order_items')
  .insert([
    {
      order_id: order[0].id,
      product_id: productId1,
      quantity: 2,
      price: 15.00,
      addons_data: JSON.stringify([
        { id: addonId1, name: 'سكر', price: 0 }
      ])
    },
    {
      order_id: order[0].id,
      product_id: productId2,
      quantity: 1,
      price: 10.00,
      addons_data: null
    }
  ]);
```

### تحديث حالة الطلب

```javascript
const { data, error } = await supabase
  .from('orders')
  .update({ status: 'accepted' })
  .eq('id', orderId)
  .select();
```

### تعيين سائق للطلب

```javascript
const { data, error } = await supabase
  .from('orders')
  .update({ 
    driver_id: driverId,
    status: 'delivering'
  })
  .eq('id', orderId)
  .select();
```

## نقاط نهاية السائقين

### الحصول على جميع السائقين

```javascript
const { data, error } = await supabase
  .from('drivers')
  .select('*');
```

### الحصول على السائقين المتاحين

```javascript
const { data, error } = await supabase
  .from('drivers')
  .select('*')
  .eq('status', 'available');
```

### تحديث موقع السائق

```javascript
const { data, error } = await supabase
  .from('drivers')
  .update({
    latitude: 31.5017,
    longitude: 34.4668,
    last_location_update: new Date().toISOString()
  })
  .eq('id', driverId)
  .select();
```

### تحديث حالة السائق

```javascript
const { data, error } = await supabase
  .from('drivers')
  .update({ status: 'available' }) // يمكن أن تكون 'available', 'busy', 'offline'
  .eq('id', driverId)
  .select();
```

## نقاط نهاية المحفظة

### الحصول على رصيد المحفظة

```javascript
const { data, error } = await supabase
  .from('wallets')
  .select('*')
  .eq('user_id', userId)
  .single();
```

### الحصول على معاملات المحفظة

```javascript
const { data, error } = await supabase
  .from('wallet_transactions')
  .select('*')
  .eq('wallet_id', walletId)
  .order('created_at', { ascending: false });
```

### إنشاء معاملة سحب

```javascript
// استخدم وظيفة RPC لإجراء عملية السحب
const { data, error } = await supabase.rpc('withdraw_from_wallet', {
  p_wallet_id: walletId,
  p_amount: amount
});
```

## نقاط نهاية التقييمات

### إضافة تقييم جديد

```javascript
const { data, error } = await supabase
  .from('ratings')
  .insert([
    {
      order_id: orderId,
      from_type: 'customer', // يمكن أن تكون 'customer', 'vendor', 'driver'
      from_id: customerId,
      to_type: 'vendor', // يمكن أن تكون 'customer', 'vendor', 'driver'
      to_id: vendorId,
      rating: 5, // من 1 إلى 5
      comment: 'تعليق على التقييم'
    }
  ])
  .select();
```

### الحصول على تقييمات

```javascript
const { data, error } = await supabase
  .from('ratings')
  .select('*')
  .eq('to_type', 'vendor') // يمكن أن تكون 'customer', 'vendor', 'driver'
  .eq('to_id', vendorId);
```

### الحصول على تقرير التقييمات الشهري

```javascript
// استخدم وظيفة RPC للحصول على تقرير التقييمات
const { data, error } = await supabase.rpc('get_ratings_report', {
  p_type: 'vendor', // يمكن أن تكون 'vendor', 'driver'
  p_year: 2025
});
```

## نقاط نهاية الإعلانات

### الحصول على جميع الإعلانات

```javascript
const { data, error } = await supabase
  .from('advertisements')
  .select(`
    *,
    vendor:vendor_id(*)
  `);
```

### إنشاء إعلان جديد

```javascript
const { data, error } = await supabase
  .from('advertisements')
  .insert([
    {
      title: 'عنوان الإعلان',
      description: 'وصف الإعلان',
      vendor_id: vendorId,
      image_url: 'https://example.com/image.jpg',
      link: 'https://example.com',
      start_date: '2025-01-01',
      end_date: '2025-12-31',
      status: 'active', // يمكن أن تكون 'draft', 'pending', 'active', 'expired'
      type: 'banner', // يمكن أن تكون 'banner', 'popup', 'slider'
      position: 'home', // يمكن أن تكون 'home', 'category', 'product', 'checkout'
      priority: 1
    }
  ])
  .select();
```

### تحديث إعلان

```javascript
const { data, error } = await supabase
  .from('advertisements')
  .update({
    title: 'عنوان الإعلان الجديد',
    status: 'active'
  })
  .eq('id', advertisementId)
  .select();
```

### حذف إعلان

```javascript
const { error } = await supabase
  .from('advertisements')
  .delete()
  .eq('id', advertisementId);
```

## نقاط نهاية الملفات والوسائط

### رفع ملف

```javascript
const { data, error } = await supabase.storage
  .from('products') // اسم المجلد، يمكن أن يكون 'products', 'vendors', 'profiles', 'advertisements', 'general'
  .upload('filename.jpg', file, {
    cacheControl: '3600',
    upsert: false
  });
```

### الحصول على رابط عام للملف

```javascript
const { data: { publicUrl } } = supabase.storage
  .from('products')
  .getPublicUrl('filename.jpg');
```

### حذف ملف

```javascript
const { error } = await supabase.storage
  .from('products')
  .remove(['filename.jpg']);
```

### الحصول على قائمة الملفات

```javascript
const { data, error } = await supabase.storage
  .from('products')
  .list();
```

## نقاط نهاية مفاتيح API

### إنشاء مفتاح API جديد

```javascript
// هذه العملية تتم عادة من خلال واجهة المستخدم
// ولكن يمكن إجراؤها برمجيًا كما يلي:

const { data, error } = await supabase
  .from('api_keys')
  .insert([
    {
      user_id: userId,
      consumer_key: 'ck_' + generateRandomString(32),
      consumer_secret_hash: hashSecret(consumerSecret),
      description: 'وصف المفتاح',
      permissions: ['read', 'write', 'delete'],
      status: 'active'
    }
  ])
  .select();
```

### الحصول على مفاتيح API للمستخدم

```javascript
const { data, error } = await supabase
  .from('api_keys')
  .select('id, consumer_key, description, permissions, created_at, last_used, status')
  .eq('user_id', userId);
```

### تعطيل مفتاح API

```javascript
const { error } = await supabase
  .from('api_keys')
  .update({ status: 'revoked' })
  .eq('id', keyId)
  .eq('user_id', userId);
```

### تفعيل مفتاح API

```javascript
const { error } = await supabase
  .from('api_keys')
  .update({ status: 'active' })
  .eq('id', keyId)
  .eq('user_id', userId);
```

## نقاط نهاية إعدادات التطبيق

### الحصول على إعدادات التطبيق

```javascript
const { data, error } = await supabase
  .from('app_settings')
  .select('*')
  .limit(1)
  .single();
```

### تحديث إعدادات التطبيق

```javascript
// هذه العملية تتطلب صلاحيات المدير
const { error } = await supabase
  .from('app_settings')
  .update({ settings: newSettings })
  .eq('id', settingsId);
```

## ملاحظات هامة

1. **المصادقة**: تأكد من تضمين رمز المصادقة في جميع الطلبات.
2. **التعامل مع الأخطاء**: دائمًا تحقق من وجود أخطاء في الاستجابة.
3. **الصلاحيات**: تأكد من أن المستخدم لديه الصلاحيات المناسبة للعملية.
4. **التحقق من البيانات**: تحقق من صحة البيانات قبل إرسالها إلى الخادم.
5. **الأمان**: لا تخزن بيانات حساسة على جهاز العميل.

## أمثلة للاستخدام في تطبيقات مختلفة

### تطبيق الزبائن

```javascript
// تسجيل الدخول
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'customer@example.com',
  password: 'password'
});

// الحصول على قائمة المنتجات
const { data: products, error: productsError } = await supabase
  .from('products')
  .select('*')
  .eq('status', 'active');

// إنشاء طلب جديد
const { data: order, error: orderError } = await supabase
  .from('orders')
  .insert([
    {
      customer_id: customerId,
      vendor_id: vendorId,
      status: 'pending',
      total: 45.00,
      subtotal: 40.00,
      delivery_fee: 5.00,
      payment_method: 'cash',
      address: 'عنوان التوصيل',
      latitude: 31.5017,
      longitude: 34.4668
    }
  ])
  .select();
```

### تطبيق السائقين

```javascript
// تسجيل الدخول
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'driver@example.com',
  password: 'password'
});

// تحديث حالة وموقع السائق
const { data: driver, error: driverError } = await supabase
  .from('drivers')
  .update({
    status: 'available',
    latitude: 31.5017,
    longitude: 34.4668,
    last_location_update: new Date().toISOString()
  })
  .eq('id', driverId)
  .select();

// الحصول على الطلبات المسندة للسائق
const { data: orders, error: ordersError } = await supabase
  .from('orders')
  .select(`
    *,
    customer:customer_id(*),
    vendor:vendor_id(*)
  `)
  .eq('driver_id', driverId)
  .eq('status', 'delivering');
```

### تطبيق البائعين

```javascript
// تسجيل الدخول
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'vendor@example.com',
  password: 'password'
});

// الحصول على طلبات البائع
const { data: orders, error: ordersError } = await supabase
  .from('orders')
  .select(`
    *,
    customer:customer_id(*),
    driver:driver_id(*)
  `)
  .eq('vendor_id', vendorId);

// تحديث حالة طلب
const { data: updatedOrder, error: updateError } = await supabase
  .from('orders')
  .update({ status: 'accepted' })
  .eq('id', orderId)
  .eq('vendor_id', vendorId)
  .select();

// إضافة منتج جديد
const { data: product, error: productError } = await supabase
  .from('products')
  .insert([
    {
      vendor_id: vendorId,
      category_id: categoryId,
      name: 'اسم المنتج',
      description: 'وصف المنتج',
      price: 15.00,
      status: 'active',
      stock: 100
    }
  ])
  .select();
```