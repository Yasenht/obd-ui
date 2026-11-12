import 'package:flutter_test/flutter_test.dart';

import 'package:DriveScope/obd_protocol.dart';

void main() {
  test('يفك RPM من رد ELM327', () {
    final reading = ObdParser.parsePid(pid: 0x0C, response: '41 0C 1A F8\r');
    expect(reading.value, 1726);
    expect(reading.unit, 'RPM');
  });

  test('يفك حرارة سائل التبريد', () {
    final reading = ObdParser.parsePid(pid: 0x05, response: '41 05 7B\r');
    expect(reading.value, 83);
    expect(reading.unit, '°C');
  });

  test('يفك تعديل وقود قصير/طويل المدى بالنسبة المئوية (SAE)', () {
    // صيغة SAE J1979: النسبة = (A - 128) × 100 / 128.
    // "41 06 40" → (64-128)*100/128 = -50%.
    final stft = ObdParser.parsePid(pid: 0x06, response: '41 06 40\r');
    expect(stft.label, 'تعديل وقود قصير المدى (STFT)');
    expect(stft.value, -50);
    expect(stft.unit, '%');

    // "41 07 C0" → (192-128)*100/128 = +50%.
    final ltft = ObdParser.parsePid(pid: 0x07, response: '41 07 C0\r');
    expect(ltft.label, 'تعديل وقود طويل المدى (LTFT)');
    expect(ltft.value, 50);
    expect(ltft.unit, '%');

    // قيمة غير صحيحة: "41 06 83" → 3*100/128 = 2.34375.
    final stft2 = ObdParser.parsePid(pid: 0x06, response: '41 06 83\r');
    expect(stft2.value, closeTo(2.34375, 0.00001));
  });

  test('يفك رد الفيرموير المباشر السالب للتعديل كنسبة كما هو', () {
    // الفيرموير يرد برقم محوّل جاهز (Freematics readPID) وقد يكون
    // سالباً — يجب قبوله كقيمة مباشرة لا كسلسلة hex.
    final stft = ObdParser.parsePid(pid: 0x06, response: '-33\r');
    expect(stft.value, -33);
    expect(stft.unit, '%');
    expect(stft.displayValue, '-33 %');

    final ltft = ObdParser.parsePid(pid: 0x07, response: '7\r');
    expect(ltft.value, 7);
    expect(ltft.displayValue, '7 %');
  });

  test('يرمّز تعديل الوقود المئوي إلى صيغة 41 خام', () {
    // العكس: A = (النسبة × 128 / 100) + 128.
    expect(ObdParser.toRawObdResponse('0106', '-50'), '41 06 40');
    expect(ObdParser.toRawObdResponse('0107', '50'), '41 07 C0');
    expect(ObdParser.toRawObdResponse('0107', '-10'), '41 07 73');
  });

  test('يفك 0100 كخريطة أوامر مدعومة لا كسقيمة خام', () {
    // الرد القياسي "41 00 BE 3F B8 13": كل بت (MSB أولاً) يمثل PID.
    final reading = ObdParser.parsePid(
      pid: 0x00,
      response: '41 00 BE 3F B8 13\r',
    );
    expect(reading.label, 'الأوامر المدعومة (01–20)');
    expect(reading.value, 19);
    expect(
      reading.displayValue,
      'مدعوم (19 أمراً في النطاق 01–20): '
      '01، 03، 04، 05، 06، 07، 0B، 0C، 0D، 0E، 0F، 10، 11، 13، 14، '
      '15، 1C، 1F، 20',
    );
  });

  test('يفك 0100 من صيغة الجسر بلا صدى الأمر (بدون 41 00)', () {
    // بعض الجسور تطبع الخريطة مباشرة "BE 3F B8 13" دون "41 00".
    final reading = ObdParser.parsePid(
      pid: 0x00,
      response: 'BE 3F B8 13\r',
    );
    expect(reading.value, 19);
    expect(reading.displayValue, contains('0C'));
  });

  test('يعرض جهد وحدة التحكم 0142 بالفولت', () {
    // 0x34DA = 13530 ميلي فولت -> 13.53 V
    final reading = ObdParser.parsePid(pid: 0x42, response: '41 42 34 DA\r');
    expect(reading.label, 'جهد وحدة التحكم');
    expect(reading.value, 13.53);
    expect(reading.unit, 'V');
    expect(reading.displayValue, '13.53 V');
  });

  test('يعرض الحمل 0104 والوقود 012F بالنسبة المئوية', () {
    final load = ObdParser.parsePid(pid: 0x04, response: '41 04 99\r');
    expect(load.label, 'حمل المحرك المحسوب');
    expect(load.value, 60); // 153*100/255 = 60%
    expect(load.displayValue, '60 %');

    final fuel = ObdParser.parsePid(pid: 0x2F, response: '41 2F 80\r');
    expect(fuel.label, 'مستوى الوقود');
    expect(fuel.unit, '%');
  });

  test('يفك 0101 حالة MIL وعدد الأكواد', () {
    // A = 0x81 -> MIL مضاءة وعدد أكواد واحد.
    final reading = ObdParser.parsePid(pid: 0x01, response: '41 01 81\r');
    expect(reading.value, 1);
    expect(reading.displayValue, 'MIL: مضاء • عدد الأكواد: 1');
  });

  test('يفك أكواد DTC القياسية', () {
    final codes = ObdParser.parseDtc('43 01 08 01 09 00 00\r');
    expect(codes, ['P0108', 'P0109']);
  });

  test('يفك مصفوفة أمثلة الجهاز: P3000 وP0703 وكود C من الصيغة القياسية',
      () {
    // الرد القياسي CAN: "43" + عدّاد (03) + زوج بايتات لكل كود.
    // (30,00)=P3000 — (40,40)=C0040 — (07,03)=P0703.
    final codes = ObdParser.parseDtc('43 03 30 00 40 40 07 03\r');
    expect(codes, ['P3000', 'C0040', 'P0703']);
  });

  test('يفك المصفوفة نفسها مع بطانة أصفار وأسطر مرقّمة', () {
    final codes = ObdParser.parseDtc(
      '0: 43 03 30 00 40 40 07\r\n1: 03 00 00 00 00\r',
    );
    expect(codes, ['P3000', 'C0040', 'P0703']);
  });

  test('يفك المصفوفة بلا بايت عدّاد (صيغة الفيرموير القديمة)', () {
    // عدد بايتات فردي؟ لا: أزواج الأكواد + إغلاق "00 00" = عدد زوجي
    // فلا يُعتمد بايت عدّاد، والفك يبدأ من أول زوج.
    final codes = ObdParser.parseDtc('43 30 00 40 40 07 03 00 00\r');
    expect(codes, ['P3000', 'C0040', 'P0703']);
  });

  test('تُتجاهل أسطر SEARCHING/BUS INIT الواردة قبل الرد 43', () {
    // جسور ELM327 تطبع بانر البحث عن البروتوكول قبل أول رد وضع 03 —
    // كان isError يرمي الرد كله فتظهر الأكواد خالية (السيارة "سليمة").
    final codes = ObdParser.parseDtc(
      'SEARCHING...\r\n43 03 30 00 40 40 07 03\r',
    );
    expect(codes, ['P3000', 'C0040', 'P0703']);

    final codes2 = ObdParser.parseDtc('BUS INIT\r\n43 01 08\r');
    expect(codes2, ['P0108']);
  });

  test('لا أكواد عند خطأ صريح بلا رد 43', () {
    expect(ObdParser.parseDtc('SEARCHING...\r\nNO DATA\r'), isEmpty);
    expect(ObdParser.parseDtc('ERROR\r'), isEmpty);
    expect(ObdParser.parseDtc('43 00\r'), isEmpty);
    expect(ObdParser.parseDtc('43 00 00\r'), isEmpty);
  });

  test('يفك الأكواد من الرد النصي الحرفي بلا رد 43 (صيغة الجهاز الجديدة)',
      () {
    // الجهاز قد يرد بالأكواد كنص مباشر دون "43 ..." البايتي إطلاقاً:
    // "P0128, P0420, P0430" — كما وردت من مركبة حقيقية.
    final codes = ObdParser.parseDtc('P0128, P0420, P0430');
    expect(codes, ['P0128', 'P0420', 'P0430']);
  });

  test('يفك الرد النصي بأي فاصل وحساس الحالة', () {
    // فواصل متفرقة: فاصلة/مسافة/سطر جديد/CRLF.
    expect(
      ObdParser.parseDtc('p0128 p0420 p0430'),
      ['P0128', 'P0420', 'P0430'],
    );
    expect(
      ObdParser.parseDtc('P0128\r\nP0420\r\nP0430\r'),
      ['P0128', 'P0420', 'P0430'],
    );
    expect(ObdParser.parseDtc('P0128,P0420,P0430'), ['P0128', 'P0420', 'P0430']);
    expect(ObdParser.parseDtc('P0420'), ['P0420']);
  });

  test('الرد النصي يمر خلف البانر الوسيط لا خلف الخطأ الحقيقي', () {
    expect(
      ObdParser.parseDtc('SEARCHING...\r\nP0128, P0420, P0430'),
      ['P0128', 'P0420', 'P0430'],
    );
  });

  test('الرد النصي يندمج مع الصيغة البايتية بلا تكرار', () {
    // أكواد من الصيغتين معاً — التكرار يُزال والترتيب محفوظ.
    final codes = ObdParser.parseDtc('43 01 08\r\nP0128, P0108, P0430');
    expect(codes, ['P0108', 'P0128', 'P0430']);
  });

  test('يلتقط أنواع الأنظمة الأربعة في الرد النصي (P/C/B/U)', () {
    final codes = ObdParser.parseDtc('P0128 C0040 B1234 U0155');
    expect(codes, ['P0128', 'C0040', 'B1234', 'U0155']);
  });

  test('النمط النصي لا يلتقط أجزاء من كلمات أو أرقام غريبة', () {
    // "P" اللاحقة بحرف/بنية غير صالحة لا تُلتقط؛ ولا قصاصات داخل كلمات.
    expect(ObdParser.parseDtc('POWER B000 ST0123 X1234'), isEmpty);
    expect(ObdParser.parseDtc('STAR P12345'), isEmpty); // 5 صيغات لا 3.
  });

  test('يفك أكواد DTC بصيغة فيرموير Freematics المحدثة (DTCS?)', () {
    // رد أمر "DTCS?" بعد رقعة firmware_patch/: صيغة mode-03 قياسية
    // تصل في إشعار BLE واحد منتهياً بـ \\r
    final codes = ObdParser.parseDtc('43 01 08 01 09 01 11 01 15 00 00\r');
    expect(codes, ['P0108', 'P0109', 'P0111', 'P0115']);
  });

  test('يرد بدون أكواد عند رد 43 00 00', () {
    final codes = ObdParser.parseDtc('43 00 00\r');
    expect(codes, isEmpty);
  });

  test('يفك أكواد فيرموير v5 دون فاصل 00 00 (DTCS? يطبع الأكواد حتى أول صفر)',
      () {
    // رقعة firmware_patch/telelogger_dtc.patch تطبع "43" ثم زوج بايتات
    // لكل كود حتى أول dtc[i]==0 دون إغلاق "00 00" إلزامي.
    final codes = ObdParser.parseDtc('43 01 08 01 09\r');
    expect(codes, ['P0108', 'P0109']);
  });

  test('يفك الصيغة القياسية CAN مع بايت عدّاد الأكواد بلا إزاحة', () {
    // إطار CAN أحادي: 43 [عدد=01] [كود 02 09] [بطانة أصفار].
    // المحلل القديم كان يقترن بعد الـ43 مباشرة فيظهر P0102 إلخ.
    final codes = ObdParser.parseDtc('43 01 02 09 00 00 00 00\r');
    expect(codes, ['P0209']);
  });

  test('يفك رد وضع 02 (إطار التجميد) بصيغة الفيرموير بايت وضع 42', () {
    // الفيرموير v5 بعد التحديث يجيب على "02" بنفس صيغة وضع 03 لكن
    // بايت الوضع "42" بدل "43" (الرد يكرر رقم الوضع + 0x40):
    // "42 [عدد=02] 01 08 01 09" → P0108، P0109.
    final codes = ObdParser.parseDtc('42 02 01 08 01 09\r');
    expect(codes, ['P0108', 'P0109']);
  });

  test('يفك رد وضع 02 (إطار التجميد) بصيغة CAN القياسية مع عدّاد', () {
    // إطار CAN أحادي لوضع 02: 42 [عدد=01] [كود 02 09] [بطانة أصفار]
    // → P0209 — نفس منطق وضع 03 مع بايت وضع مختلف.
    final codes = ObdParser.parseDtc('42 01 02 09 00 00 00 00\r');
    expect(codes, ['P0209']);
  });

  test('يرد وضع 02 بدون أكواد عند رد 42 00 00', () {
    final codes = ObdParser.parseDtc('42 00 00\r');
    expect(codes, isEmpty);
  });

  test('يفك إطارين CAN المرقّمين (عدة أكواد) مع العدّاد دون إزاحة', () {
    // "0: 43 04 ..." ثم "1: ..." تُدمج في سطر واحد قبل الفك،
    // والعدّاد = 04 يطابق عدد الأكواد الفعلية.
    final codes = ObdParser.parseDtc(
      '0: 43 04 01 08 01 09 01\r\n1: 11 01 15 00 00 00 00\r',
    );
    expect(codes, ['P0108', 'P0109', 'P0111', 'P0115']);
  });

  test('يرفض بايت عدّاد غير صالح ويعود للفك بلا عدّاد (فيرموير)', () {
    // rest فردي (7 بايتات) لكن العدد المعلن 03 لا يطابق عدد أزواج
    // الأكواد غير الصفرية (زوجان ثم 00 00) — يُرفض العدد ويُفك
    // الرد بالصيغة القديمة بلا إزاحة: P0301، P0801، P0900.
    final codes = ObdParser.parseDtc('43 03 01 08 01 09 00 00\r');
    expect(codes, ['P0301', 'P0801', 'P0900']);
  });

  test('يفك VIN النصي المساند من فيرموير Freematics (parsePlainVin)', () {
    expect(ObdParser.parsePlainVin('WVWZZ8ZW123456789\r'), 'WVWZZ8ZW123456789');
    expect(ObdParser.parsePlainVin('N/A\r'), isNull);
    expect(ObdParser.parsePlainVin('ERROR\r'), isNull);
  });

  test('يفك VIN متعدد الأسطر', () {
    final vin = ObdParser.parseVin(
        '0: 49 02 01 57 56 57 5A 5A\r\n1: 38 5A 57 31 32 33 34 35 36 37 38 39 30 31 32 33 34\r');
    expect(vin, 'WVWZZ8ZW123456789');
  });

  test('يتعرف على أخطاء ELM327', () {
    expect(ObdParser.isError('NO DATA\r'), isTrue);
    expect(ObdParser.isError('41 0C 1A F8\r'), isFalse);
  });

  test('يعدّل ردود Freematics الرقمية إلى صيغة 41 XX التي يفهمها الـ Backend',
      () {
    // الأمثلة القياسية: الرد الرقمي المباشر من فيرموير Freematics
    // (مثل "1726") يجب أن يُرسل للـ Backend بصيغة ELM327 الخام.
    expect(
      ObdParser.toRawObdResponse('010C', '1726'),
      '41 0C 1A F8', // (0x1A*256+0xF8)/4 = 1726 دورة/دقيقة
    );
    expect(
      ObdParser.toRawObdResponse('010D', '80'),
      '41 0D 50', // 0x50 = 80 كلم/س
    );
    expect(
      ObdParser.toRawObdResponse('0105', '76'),
      '41 05 74', // 0x74 - 40 = 76°C
    );
    expect(
      ObdParser.toRawObdResponse('0111', '50'),
      '41 11 80', // 0x80*100/255 ≈ 50%
    );
  });

  test('لا يعدّل الردود الجاهزة، ولا يرسل غير القابلة للترميز إلى الـ Backend',
      () {
    // رد خام أصلاً (41 0C ...) يُمرر كما هو
    expect(
      ObdParser.toRawObdResponse('010C', '41 0C 1A F8'),
      '41 0C 1A F8',
    );
    // الرد الخام مع مسافات مفقودة يُمرر كما هو
    expect(
      ObdParser.toRawObdResponse('010D', '410D50'),
      '410D50',
    );
    // "BATT" من فيرموير يُرمز كـ PID 0x42: 12.34V -> 0x3034
    expect(ObdParser.toRawObdResponse('BATT', '12.34'), '41 42 30 34');
    // أوامر النص (VIN/DTCS؟/ERROR/N-A) لا تُرسل إلى الـ Backend إطلاقاً
    expect(ObdParser.toRawObdResponse('VIN', 'WVWZZZZZ'), isEmpty);
    expect(ObdParser.toRawObdResponse('DTCS?', '43 01 08'), isEmpty);
    expect(ObdParser.toRawObdResponse('010C', 'ERROR'), isEmpty);
    expect(ObdParser.toRawObdResponse('010C', 'N/A'), isEmpty);
    // PID بلا صيغة ترميز معروفة: لا يُرسل رقماً خاماً غير مقبول
    expect(ObdParser.toRawObdResponse('0100', '150'), isEmpty);
  });

  test('يرمز جميع PIDs المدعومة بصيغة 41 XX القياسية', () {
    expect(ObdParser.toRawObdResponse('0104', '60'),
        '41 04 99'); // حمل 60% -> A=153
    expect(ObdParser.toRawObdResponse('012F', '50'),
        '41 2F 80'); // وقود 50% -> A=127
    expect(ObdParser.toRawObdResponse('010F', '30'),
        '41 0F 46'); // هواء 30°C -> A=70
    expect(ObdParser.toRawObdResponse('010B', '99'),
        '41 0B 63'); // ضغط السحب -> A=99
    expect(ObdParser.toRawObdResponse('0133', '101'),
        '41 33 65'); // بارومتر -> A=101
    expect(
        ObdParser.toRawObdResponse('0142', '13.53'), '41 42 34 DA'); // 13530mV
  });
}
