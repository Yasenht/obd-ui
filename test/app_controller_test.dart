import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drive_scope/controllers/app_controller.dart';
import 'package:drive_scope/obd_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('يُحفظ وضع المظهر محلياً ويُستعاد عند الإقلاع', () async {
    SharedPreferences.setMockInitialValues({
      'app_theme_mode_v1': 'system',
    });

    final controller = AppController();
    await controller.loadPreferences();
    expect(controller.themeMode, ThemeMode.system);

    await controller.setThemeMode(ThemeMode.light);
    expect(controller.themeMode, ThemeMode.light);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_theme_mode_v1'), 'light');

    // استعادة القيمة من التخزين بكنترولر جديد.
    final second = AppController();
    await second.loadPreferences();
    expect(second.themeMode, ThemeMode.light);
  });

  group('فكّ رد قراءة الأعطال عبر parseDtc قبل الإرسال للباك إند', () {
    test('الصيغة النصية الحرفية تُفك إلى أكواد صحيحة', () {
      // بعض الجسور ترسل الأكواد نصاً — parseDtc يلتقطها نصياً.
      expect(
        ObdParser.parseDtc('P0128, P0420, P0430'),
        ['P0128', 'P0420', 'P0430'],
      );
      expect(
        ObdParser.parseDtc('p0128 p0420\r\np0430'),
        ['P0128', 'P0420', 'P0430'],
      );
      expect(
        ObdParser.parseDtc('P0128;P0420;P0430'),
        ['P0128', 'P0420', 'P0430'],
      );
    });

    test('الصيغة البايتية القياسية "43 <عدد> <أزواج>" تُفك إلى أكواد', () {
      // الرد الفعلي لفيرموير Freematics المُرقّع — يجب أن يظهر في
      // التطبيق أكواد P/C/B/U (لا رموز خام مثل "43"/"02" تُرسل
      // إلى خدمة التحليل فتفشل في مخططها).
      expect(
        ObdParser.parseDtc('43 03 30 00 40 40 07 03\r'),
        ['P3000', 'C0040', 'P0703'],
      );
      expect(
        ObdParser.parseDtc('43 02 01 08 01 09\r'),
        ['P0108', 'P0109'],
      );
    });
  });
}
