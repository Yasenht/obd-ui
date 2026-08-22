# نتائج التحليل الفنية

## المتطلبات

التطبيق المطلوب هو تطبيق Flutter يعمل كـ BLE Central، ويعرض الأجهزة القريبة، يسمح باختيار جهاز Freematics، يعرض حالة الاتصال، يرسل أوامر OBD/ELM327، يعرض الأعطال والبيانات السريعة، ويحفظ سجل الفحوصات.

## Freematics BLE GATT

المصدر المرفق ومصدر GitHub الحالي يستخدمان خدمة BLE ذات UUID قصير `ABF0`، واسم إعلان افتراضي `FreematicsPlus`.

الخاصية الفعلية المفعلة لإرسال أوامر التطبيق إلى الجهاز هي `FFE1`، وتدعم الكتابة مع أو بدون رد. الخاصية الفعلية لاستقبال الردود من الجهاز هي `FFE2`، وتدعم القراءة والإشعارات مع CCCD. الخصائص `FFE3` و`FFE4` موجودة في التعريف لكنها معطلة داخل `#if 0` في المصدر الحالي، لذلك لا ينبغي أن يعتمد التطبيق عليها.

عند الكتابة إلى `FFE1`، ينسخ firmware البيانات إلى طابور أوامر (`cmd_cmd_queue`) مع إضافة محرف إنهاء صفري. وعند إرسال الرد، تستعمل الدالة `ble_send_response` الخاصية `FFE2` عبر indication/notification. عند الاتصال يضبط firmware حالة الاتصال، وعند الانفصال يعيد تشغيل advertising.

## أوامر ELM327/OBD المؤكدة من FreematicsOBD.cpp

| الوظيفة | الأمر المرسل | شكل الرد/المعالجة |
|---|---:|---|
| تهيئة الجهاز | `ATZ\r` ثم `ATE0\r` و`ATH0\r` | ردود نصية مثل `OK` |
| قراءة PID | `01XX\r`، حيث `XX` رقم PID | يبحث firmware عن `41 XX` ثم يفك البيانات |
| قراءة DTC | `03\r` | يبحث عن `43` ثم يحول كل زوج بايت إلى كود DTC |
| مسح DTC | `04\r` | يرسل الأمر وينتظر الرد |
| VIN | `0902\r` | رد متعدد الإطارات يبدأ عادةً بـ `49 02 01` ويعاد تجميعه |
| RPM | `010C\r` | القيمة الخام `AB` و`CD`: `(A*256+B)/4` |
| حرارة سائل التبريد | `0105\r` | البايت الخام ناقص 40 درجة مئوية |

الردود من الجهاز نصية ASCII وتنتهي عادةً بـ CR/LF أو prompt حسب طبقة الربط. لذلك يستخدم التطبيق محلل أسطر/مخزن مؤقت، ولا يفترض أن كل إشعار BLE يمثل رداً كاملاً.

## flutter_blue_plus

توثيق الحزمة الحالي يوضح أن `flutter_blue_plus` يعمل بدور BLE Central، ويحتاج إلى بدء scan ثم الاتصال ثم `discoverServices()` بعد كل اتصال أو إعادة اتصال. يجب تفعيل الإشعارات على خاصية الرد بواسطة `setNotifyValue(true)`، والكتابة إلى خاصية الأوامر. يجب إضافة أذونات Android `BLUETOOTH_SCAN` و`BLUETOOTH_CONNECT`، وأذونات التوافق للإصدارات القديمة، وإضافة `NSBluetoothAlwaysUsageDescription` إلى iOS.

الإصدار الذي ظهر في Pub.dev أثناء التحليل هو `2.3.12`. سيتم تثبيت إصدار محدد في `pubspec.yaml` لتجنب تغييرات API غير المتوقعة.

## حدود مهمة

لا يوجد داخل مجلد المشروع الحالي مشروع Flutter كامل أو ملفات `android/` و`ios/` أو `pubspec.yaml`. لذلك ستكون النتيجة الأولية حزمة Flutter مصدرية منظمة يمكن نسخها إلى مشروع Flutter جديد، مع ملفات أذونات Android/iOS وإرشادات الدمج. لا يمكن اختبار BLE فعلياً داخل بيئة sandbox لعدم توفر جهاز Freematics حقيقي.

## مصادر

1. https://github.com/stanleyhuangyc/Freematics/tree/master
2. https://github.com/stanleyhuangyc/Freematics/blob/master/libraries/FreematicsPlus/utility/ble_spp_server.c
3. https://github.com/chipweinberger/flutter_blue_plus
4. https://pub.dev/packages/flutter_blue_plus
