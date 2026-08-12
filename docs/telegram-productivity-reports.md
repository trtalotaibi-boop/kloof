# KLOOF Telegram Productivity Reports

## الهدف
إرسال تقرير إنتاجية أسبوعي وشهري من بيانات Firestore إلى Telegram بدون تعديل مسار الحجز داخل تطبيق KLOOF.

## الجدول
- أسبوعي: السبت 09:00 بتوقيت الرياض.
- شهري: يوم 1 الساعة 09:15 بتوقيت الرياض، ويغطي الشهر السابق.
- يمكن تشغيل التقرير يدويًا من GitHub Actions واختيار `weekly` أو `monthly`.

## البيانات المستخدمة حاليًا
من مجموعة `bookings` في Firestore:
- `barberId`
- `customerId`
- `status`
- `createdAt`

الحالات المدعومة:
- `pending`
- `accepted`
- `rejected`
- `completed`

> ملاحظة: قيمة الحلاقة أو الإيراد غير موجودة في سجل الحجز الحالي؛ لذلك التقرير لا يخمّن الدخل ولا يعرض رقمًا ماليًا غير موثوق.

## الأسرار المطلوبة في GitHub
أضف Repository Secrets التالية:

1. `FIREBASE_SERVICE_ACCOUNT_JSON`
   - JSON كامل لحساب خدمة Firebase يملك صلاحية قراءة Firestore فقط قدر الإمكان.
2. `TELEGRAM_BOT_TOKEN`
   - Token البوت من BotFather.
3. `TELEGRAM_CHAT_ID`
   - Chat ID للمحادثة التي تستقبل التقرير.

Repository Variable اختيارية:
- `KLOOF_TARGET_BARBERS` — الافتراضي `5`.

## الأمان
- لا يوضع Telegram token أو Firebase credentials داخل Flutter أو داخل ملفات المصدر.
- Workflow يملك `contents: read` فقط.
- سكربت التقرير يقرأ بيانات الحجز ولا يكتب أو يعدّل Firestore.
- فشل التقرير لا يوقف التطبيق ولا يغير الحجوزات.

## مقياس الإنتاجية
الدرجة من 100 مبنية على:
- نشاط الحلاقين: 20%
- قبول الطلبات: 20%
- إكمال الحجوزات المقبولة: 25%
- نسبة أول عميل/حلاق خلال الفترة: 15%
- الحلاقات المكتملة لكل حلاق نشط: 20%

الإشارة:
- 75–100: 🟢 استمر
- 50–74: 🟡 عدّل
- أقل من 50: 🔴 راجع قبل التوسع

هذه الحدود معايير قرار داخلية للاختبار وليست حقائق سوقية.

## تشغيل يدوي للتأكد
بعد إضافة الأسرار:
1. افتح GitHub Actions.
2. اختر `KLOOF Productivity Report`.
3. اختر `Run workflow`.
4. اختر `weekly` أولًا.
5. تأكد أن الرسالة وصلت Telegram وأن الأرقام منطقية قبل الاعتماد على الجدولة.

## خطة الرجوع
إذا ظهرت مشكلة:
1. عطّل Workflow `KLOOF Productivity Report` أو احذفه.
2. لا حاجة لأي تعديل في Flutter أو Firestore.
3. يمكن حذف الملفات التالية فقط:
   - `.github/workflows/kloof-productivity-report.yml`
   - `scripts/kloof_telegram_report.py`
   - `scripts/requirements-report.txt`

لا يوجد migration ولا تعديل schema، لذلك الرجوع لا يؤثر على بيانات KLOOF الحالية.
