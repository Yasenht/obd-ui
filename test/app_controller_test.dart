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
}
