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

  test('يفك أكواد DTC القياسية', () {
    final codes = ObdParser.parseDtc('43 01 08 01 09 00 00\r');
    expect(codes, ['P0108', 'P0109']);
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

  test('يفك أكواد فيرموير v5 دون فاصل 00 00 (DTCS? يطبع الأكواد حتى أول صفر)', () {
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
    final vin = ObdParser.parseVin('0: 49 02 01 57 56 57 5A 5A\r\n1: 38 5A 57 31 32 33 34 35 36 37 38 39 30 31 32 33 34\r');
    expect(vin, 'WVWZZ8ZW123456789');
  });

  test('يتعرف على أخطاء ELM327', () {
    expect(ObdParser.isError('NO DATA\r'), isTrue);
    expect(ObdParser.isError('41 0C 1A F8\r'), isFalse);
  });

  test('يعدّل ردود Freematics الرقمية إلى صيغة 41 XX التي يفهمها الـ Backend', () {
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

  test('لا يعدّل الردود الجاهزة، ولا يرسل غير القابلة للترميز إلى الـ Backend', () {
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
    expect(ObdParser.toRawObdResponse('0104', '60'), '41 04 99'); // حمل 60% -> A=153
    expect(ObdParser.toRawObdResponse('012F', '50'), '41 2F 80'); // وقود 50% -> A=127
    expect(ObdParser.toRawObdResponse('010F', '30'), '41 0F 46'); // هواء 30°C -> A=70
    expect(ObdParser.toRawObdResponse('010B', '99'), '41 0B 63'); // ضغط السحب -> A=99
    expect(ObdParser.toRawObdResponse('0133', '101'), '41 33 65'); // بارومتر -> A=101
    expect(ObdParser.toRawObdResponse('0142', '13.53'), '41 42 34 DA'); // 13530mV
  });
}
