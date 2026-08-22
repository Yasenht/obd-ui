# تطبيق فاحص OBD عبر BLE

هذا المجلد يحتوي على طبقة تطبيق Flutter أولية قابلة للدمج مع مشروع Flutter جديد. التطبيق مبني على الاتصال BLE الموجود في firmware المرفق لجهاز Freematics، وليس على Bluetooth Classic.

> **التوافق المؤكد من المصدر:** خدمة BLE هي `ABF0`، خاصية إرسال الأوامر هي `FFE1`، وخاصية استقبال الردود هي `FFE2`. الاسم الافتراضي المعلن هو `FreematicsPlus`.[1]

## الوظائف المنفذة

تتضمن الواجهة البحث عن جميع أجهزة BLE القريبة، وإظهار اسم الجهاز ومعرفه وقوة الإشارة، وتحديد جهاز Freematics، والاتصال والفصل وإظهار الحالة. كما تتضمن إدخال أمر ELM327 يدوي، وأزراراً لقراءة DTC وVIN وحرارة المحرك وRPM ومسح الأكواد، وعرض الرد الخام، وتخزين سجل آخر 100 عملية فحص محلياً.

| المكوّن | الملف | المسؤولية |
|---|---|---|
| نموذج البيانات | `lib/models.dart` | قراءة PID وسجل الفحص والتسلسل JSON |
| النقل BLE | `lib/ble_obd_service.dart` | المسح، الاتصال، اكتشاف الخدمة، الكتابة إلى FFE1، استقبال FFE2 |
| البروتوكول | `lib/obd_protocol.dart` | أوامر ELM327 وفك DTC/VIN/RPM/الحرارة |
| التخزين | `lib/history_repository.dart` | حفظ سجل الفحوصات باستخدام SharedPreferences |
| الواجهة | `lib/main.dart` | لوحة الاتصال، الأوامر، النتائج، السجل |

## كيف تتم عملية الاتصال

يبدأ التطبيق بعملية scan ثم يختار المستخدم الجهاز المناسب. بعد الاتصال يعيد التطبيق اكتشاف الخدمات، لأن خصائص GATT يجب إعادة اكتشافها بعد كل إعادة اتصال. يبحث التطبيق عن `ABF0`، ثم يربط `FFE1` بقناة الكتابة و`FFE2` بقناة الردود. بعد تفعيل notifications يرسل أوامر التهيئة `ATZ`, `ATE0`, و`ATH0`.

عند الضغط على زر قراءة RPM، يرسل التطبيق النص `010C\r` إلى `FFE1`. firmware يقرأ القيمة المكتوبة داخل حدث `ESP_GATTS_WRITE_EVT` ويضعها في `cmd_cmd_queue`. بعد تنفيذ الأمر على جسر OBD/ELM327 يرسل الجهاز الرد النصي عبر `FFE2`. التطبيق يجمع أجزاء الإشعار في buffer، ثم ينتظر 250ms من الهدوء قبل تحليل الرد، لأن إشعار BLE واحداً قد لا يمثل الرد الكامل.[1] [2]

| الوظيفة | أمر ELM327 | أساس فك الرد |
|---|---|---|
| DTC | `03\r` | الرد يبدأ غالباً بـ `43`، وكل زوج بايت يتحول إلى P/C/B/U code |
| VIN | `0902\r` | الرد يبدأ بـ `49 02 01` وقد يصل على إطارات متعددة |
| RPM | `010C\r` | `(A × 256 + B) / 4` بعد `41 0C` |
| حرارة سائل التبريد | `0105\r` | `A - 40` بعد `41 05` |
| مسح DTC | `04\r` | رد نصي من وحدة التحكم |

## التشغيل داخل مشروع Flutter

أنشئ مشروعاً جديداً ثم انسخ محتوى `lib/` وملف `pubspec.yaml` إلى المشروع، وبعدها شغّل:

```bash
flutter pub get
flutter run
```

الإصدار المثبت في `pubspec.yaml` هو `flutter_blue_plus: 2.3.12`. توصي وثائق الحزمة بتثبيت إصدار محدد، وتوضح أن الحزمة تعمل كـ BLE Central، وأن التسلسل الصحيح هو scan ثم connect ثم discoverServices ثم setNotifyValue ثم write.[3]

## أذونات Android

أضف محتوى الملف `platform_snippets/android_manifest_additions.xml` إلى `android/app/src/main/AndroidManifest.xml`، واضبط `minSdkVersion` إلى 21 أو أعلى. أذونات Android الحديثة هي `BLUETOOTH_SCAN` و`BLUETOOTH_CONNECT`، مع أذونات التوافق للإصدارات القديمة.[3]

## إعداد iOS

أضف المفتاح الموجود في `platform_snippets/ios_info_plist_additions.xml` إلى `ios/Runner/Info.plist`. يجب تشغيل التطبيق على جهاز iPhone حقيقي، لأن محاكيات iOS لا توفر BLE فعلياً.[3]

## ملاحظة عن البروتوكول الثنائي المقترح

ملف المتطلبات يقترح مستقبلاً بروتوكولاً ثنائياً يبدأ بـ `0xAA` مع command/length/payload/XOR. هذا التصميم **غير موجود في firmware المرفق**؛ المصدر الحالي يستقبل أوامر نصية ASCII عبر `FFE1` ويرسل ردوداً نصية عبر `FFE2`. لذلك ينفذ التطبيق الحالي مسار ELM327 ASCII أولاً، ويمكن إضافة `BinaryFrameCodec` لاحقاً عند تحديث firmware مع الحفاظ على طبقة BLE نفسها.

## القيود الحالية والاختبار المطلوب

لا يمكن اختبار الاتصال الفعلي داخل بيئة التطوير الحالية لعدم توفر جهاز Freematics وسيارة متصلة. قبل اعتماد التطبيق في الإنتاج، اختبر أجهزة Android وiOS حقيقية، وجرّب ردوداً مجزأة، وردود `NO DATA`، وVIN متعدد الإطارات، وانقطاع الاتصال أثناء تنفيذ أمر. كما يجب عدم استخدام أزرار UDS أو CAN الخام قبل إضافة صلاحيات وسياج أمان مناسبين.

## المراجع

[1]: https://github.com/stanleyhuangyc/Freematics "Freematics official source repository"
[2]: https://github.com/stanleyhuangyc/Freematics/blob/master/libraries/FreematicsPlus/utility/ble_spp_server.c "Freematics BLE SPP server"
[3]: https://pub.dev/packages/flutter_blue_plus "flutter_blue_plus package documentation"
