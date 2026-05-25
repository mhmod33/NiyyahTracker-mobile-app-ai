# إعداد حساب المدير (Admin)

## الطريقة 1 — من الكود (موصى بها)

1. افتح `lib/config/admin_config.dart`
2. أضف بريدك الذي تسجّل به في Firebase:

```dart
const List<String> kBootstrapAdminEmails = [
  'me653830@gmail.com',
];
```

3. سجّل الدخول بهذا البريد في التطبيق → يُعيَّن تلقائياً `role: admin` و `canUpload: true`
4. ستظهر **لوحة الإدارة** في الشاشة الرئيسية

## الطريقة 2 — من Firebase Console

1. [Firebase Console](https://console.firebase.google.com) → مشروعك → **Authentication** → انسخ **UID** للمستخدم
2. **Firestore** → مجموعة `users` → مستند `{uid}`
3. عدّل الحقول:
   - `role` → `"admin"`
   - `canUpload` → `true`

## رفع المقاطع للجميع (Admin) — بدون Storage

**لا تحتاج حساباً مدفوعاً (Blaze) ولا Firebase Storage.**

الملفات الصوتية تُقسَّم وتُحفظ في **Firestore** فقط:
- مجموعة `library_snippets` (بيانات المقطع)
- مجموعة فرعية `chunks` (أجزاء الملف)

يظهر لجميع المستخدمين المسجّلين تحت **مقتطفات بصائر**.

**حد الحجم:** حوالي **15 ميجا** لكل ملف mp3 (مناسب للمقتطفات).

## قواعد Firestore (مهم — مجاني)

انشر ملف `firestore.rules` فقط:

Firebase Console → **Firestore Database** → **Rules** → الصق المحتوى → **Publish**

لا حاجة لـ **Storage** أو ملف `storage.rules`.

## تفعيل الرفع لمستخدمين آخرين

1. سجّل دخولك كمدير
2. **لوحة الإدارة** → **إدارة صلاحية الرفع**
3. فعّل المفتاح بجانب أي مستخدم (غير المدير)

المستخدم بعد التفعيل يرى زر **رفع مقطع** في **مزامير القرآن** (محلياً على جهازه فقط ما لم يكن مديراً).
