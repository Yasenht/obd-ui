# DriveScope — ملاحظات إعادة التصميم والتكامل

## 1) البنية بعد إعادة التصميم

```
lib/
  main.dart                     ← MaterialApp، شاشة الترحيب، تشغيل الخدمات
  theme/
    app_colors.dart             ← لوحة الألوان الزيتونية + Palette حسب الوضع
    app_theme.dart              ← ThemeData فاتح/داكن (ColorScheme كامل)
  controllers/
    app_controller.dart         ← الحالة المشتركة (ChangeNotifier): اتصال، فحص،
                                  سجل، بيانات حية، تحليل API، المظهر
    app_scope.dart              ← InheritedNotifier (بدون حزم خارجية)
  screens/
    main_shell.dart             ← شريط تنقل سفلي + IndexedStack (حفظ الحالة)
    home_screen.dart            ← الرئيسية: ترحيب، اتصال، فحص سريع، بحث يدوي، ملخص
    home_widgets/home_sections.dart ← كارت الاتصال + قسم البيانات الحية
    faults_screen.dart          ← قائمة الأعطال
    fault_details_screen.dart   ← تفاصيل العطل (نقطة تكامل API)
    history_screen.dart         ← سجل التشخيص مع بحث مُخفَّف (300ms)
    settings_screen.dart        ← المظهر (فاتح/داكن/النظام)، المنفذ اليدوي، سجل BLE
  widgets/common.dart           ← مكونات مشتركة (ترويسات، شرائح، حالات فراغ...)
  services/dtc_analysis_service.dart ← عميل POST /api/analyze/dtc (تحليل أكواد 03)
  models/dtc_analysis.dart      ← نماذج AnalyzeDtcSchema / DtcFaultSchema
  ble_obd_service.dart          ← بدون تغيير: BLE/GATT (ABF0/FFE1/FFE2)
  obd_protocol.dart             ← بدون تغيير: فك DTC/PID/VIN
  obd_analysis_api.dart         ← بدون تغيير: تحليل الردود عبر API
  history_repository.dart       ← بدون تغيير: تخزين محلي (SharedPreferences)
```

## 2) ما حُفظ من الوظائف السابقة

- البحث/الاتصال/الفصل عبر BLE ومنطق خدمة ABF0 والخصائص FFE1/FFE2.
- فحص أكواد الأعطال بالكامل (03 ثم DTCS? مع فحوص صحة الرد والرسائل التشخيصية).
- قراءة PID (RPM/السرعة/الحرارة/...) وجهد البطارية و VIN.
- البيانات الحية عبر BLE كل 5 ثوانٍ (RPM/سرعة/حرارة التبريد/جهد).
- تحليل الردود عبر API (أصبح معروضاً في بطاقة «التحليل الذكي»).
- المنفذ اليدوي ELM327 وسجل BLE الفني (نُقلا إلى شاشة الإعدادات).
- مسح أكواد الأعطال المخزنة بأمر 04 من تبويب «الأعطال» — بنقرة واحدة
  بعد نافذة تأكيد إجبارية (لا إدخال يدوي)، وتُزامَن القائمة المحلية
  بعد نجاح المسح.
- قراءة أكواد إطار التجميد (Freeze Frame / وضع 02) بأمر "02" من تبويب
  «الأعطال» — بنقرة واحدة (أمر قراءة آمن بلا تأكيد). الفيرموير v5
  يرد بصيغة وضع 03 نفسها لكن بايت الوضع "42" بدل "43"، وتُفك الأكواد
  محلياً بـ `ObdParser.parseDtc` (يقبل 43 و42) قبل إرسالها للتحليل.
- سجل العمليات المحلي (عرض/بحث/نسخ/مسح).
- الأجهزة: عرض أول 3 مع «عرض المزيد» ورسائل الأذونات/عدم وجود أجهزة.

## 3) تحليل أكواد الأعطال (03) عبر `/api/analyze/dtc`

هذا المسار خاص بأوامر الأعطال فقط (`03` و`DTCS?` و`DTC?`)؛ باقي
الأوامر تبقى على خدمة تحليل الردود القديمة بلا تغيير.

- الطلب: `POST https://backend-obd.onrender.com/api/analyze/dtc`
- الجسم (مطابق `InputAnalyzeDtcSchema`): `{ "codes": ["P0301", "P0171"] }`
  (مصفوفة نصوص، بحد أقصى 100، والخدمة تعيد «السيارة سليمة» عند الفراغ).
- الأكواد تُفكّ محلياً من رد الجهاز أولاً وتُعرض فوراً، ثم يُرسَل الطلب
  في الخلفية وتُحدَّث الشاشة تلقائياً عند وصول الاستجابة (مع حالات
  تحميل/خطأ/إعادة محاولة).
- الاستجابة تُقرأ كما هي (`success`, `codes`, `status`, `title`,
  `description`, `totalFaults`, `faults[]`) ويعرض كل عطل في قائمة
  الأعطال سطراً بسطر، مع كل حقول `DtcFaultSchema` في شاشة التفاصيل
  (`category`, `type`, `nameEn`, `title`, `description`, `system`,
  `meaning`, `severity`, `severityPercentage`, `severityExplanation`,
  `possibleCauses`, `possibleSymptoms`, `diagnosticSteps`, `solutions`,
  `status`, `confidence`) — بلا أي حقل مضاف.
- مدخلات فشل كود واحد `{code, success:false, error}` تُعرض كما هي.
- الملفات: `lib/models/dtc_analysis.dart`،
  `lib/services/dtc_analysis_service.dart`، وطريقة
  `AppController.analyzeDtcCodes`، وشاشتا `faults`/`fault_details`.

## 4) تفاصيل الكود المُدخل يدوياً (مثال P4300)

شاشة تفاصيل العطل ترسل الكود المُدخل يدوياً وحده إلى
`POST /api/analyze/dtc` (الجسم `{ "codes": ["P4300"] }`) عبر
`DtcAnalysisService.analyzeCodes`، وتعرض تحليل الخدمة (المدعوم
بـ Gemini) ببطاقات الحقول نفسها المعروضة للأكواد المكتشفة:
`category`, `type`, `nameEn`, `title`, `description`, `system`,
`meaning`, `severity`, `severityPercentage`, `severityExplanation`,
`possibleCauses`, `possibleSymptoms`, `diagnosticSteps`, `solutions`,
`status`, `confidence` — بلا أي حقل مضاف، مع شارات النظام
المعياري (من حرف الكود) والخطورة/الحالة/الثقة إن وُجدا.
حالات التحميل/خطأ الشبكة/كود فاشل/غير مُعاد تُعرض صراحة،
وزر الإعادة في شريط التطبيق يعيد الطلب.

## 5) البيانات التي لا تُختلق

- لا تظهر أجهزة وهمية؛ القائمة من `FlutterBluePlus` فقط.
- لا تظهر أعطال أو «سيارة سليمة» قبل فحص فعلي (`hasReadDtc`).
- جهوزية الانبعاثات تعرض الرد الخام فقط حتى تُربَط خدمة فك PID 01.
- الخطورة/الحالة في الأعطال تُعرض فقط من حقول استجابة خدمة التحليل،
  ولا تُختلق عند غيابها.
- تفاصيل العطل اليدوي (مثل P4300) تُجلب من `POST /api/analyze/dtc`
  عبر خدمة التحليل نفسها (Gemini) وتُعرض بأ حقول بدون إضافة،
  مع تنبيه أن الأسباب تحتاج فحصاً فعلياً وقد تختلف بحسب المصنّع.

## 6) المظهر

- فاتح/داكن/حسب النظام، محفوظ في SharedPreferences تحت `app_theme_mode_v1`.
- الهوية: زيتوني `#556B2F` / داكن `#354522` / فاتح `#8FA765`،
  خلفيات `#F7F8F4` و`#151813`، تحذير `#E8A23A`، خطأ `#D95757`.
- الألوان الدلالية مضبوطة للتباين في الوضعين (نص داكن على الزيتوني
  الفاتح في الوضع الداكن).
