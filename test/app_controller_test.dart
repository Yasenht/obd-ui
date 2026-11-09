import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:DriveScope/controllers/app_controller.dart';

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

  group('التوجيه المباشر لرد قراءة الأعطال (بلا parseDtc)', () {
    test('يقسّم رد الجهاز النصي إلى عناصر المصفوفة كما هي', () {
      // الرد الفعلي الذي ترسله المركبة — يوجّه للباك إند مباشرة.
      expect(
        AppController.splitDtcTokens('P0128, P0420, P0430'),
        ['P0128', 'P0420', 'P0430'],
      );
    });

    test('يقبل أي فاصل (فاصلة/فاصلة منقوطة/مسافة/سطر) والحروف الصغيرة', () {
      expect(
        AppController.splitDtcTokens('p0128 p0420\r\np0430'),
        ['P0128', 'P0420', 'P0430'],
      );
      expect(
        AppController.splitDtcTokens('P0128;P0420;P0430'),
        ['P0128', 'P0420', 'P0430'],
      );
      expect(
        AppController.splitDtcTokens('P0128,P0420,P0430'),
        ['P0128', 'P0420', 'P0430'],
      );
    });

    test('لا يفكّ البايتات ولا يتحقق من الصيغة — يوجّه العناصر كما وصلت',
        () {
      // إثبات عدم المرور على parseDtc: بايتات mode-03 لا تُحوَّل إلى
      // أكواد P/C/B/U، بل تبقى عناصر خام توجّه كما هي.
      expect(
        AppController.splitDtcTokens('43 03 30 00 40 40 07 03'),
        ['43', '03', '30', '00', '40', '40', '07', '03'],
      );
    });

    test('يتجاهل الفراغات والعناصر الفارغة', () {
      expect(
        AppController.splitDtcTokens('  P0128 ,  , P0420  '),
        ['P0128', 'P0420'],
      );
      expect(AppController.splitDtcTokens(''), isEmpty);
      expect(AppController.splitDtcTokens('   \r\n '), isEmpty);
    });
  });
}
