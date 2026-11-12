import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:DriveScope/controllers/app_controller.dart';
import 'package:DriveScope/controllers/app_scope.dart';
import 'package:DriveScope/main.dart';
import 'package:DriveScope/screens/main_shell.dart';
import 'package:DriveScope/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  testWidgets('تظهر شاشة الترحيب عند الإقلاع', (WidgetTester tester) async {
    final controller = AppController();
    await tester.pumpWidget(
      AppScope(controller: controller, child: const ObdScannerApp()),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('DriveScope'), findsOneWidget);

    // إزالة الشجرة قبل انقضاء مؤقت شاشة الترحيب، ثم تفريغ المؤقت.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1600));
  });

  testWidgets('شريط التنقل يحتوي تبويبات الرئيسية والأعطال والسجل والإعدادات',
      (WidgetTester tester) async {
    final controller = AppController();
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const MainShell(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('الأعطال'), findsOneWidget);
    expect(find.text('السجل'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('مرحباً بك في مركز تشخيص سيارتك'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('قسم مسح الأكواد وزر «مسح الأكواد المخزنة» يظهران في تبويب الأعطال',
      (WidgetTester tester) async {
    final controller = AppController();
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const MainShell(),
        ),
      ),
    );

    // الانتقال إلى تبويب «الأعطال».
    await tester.tap(find.text('الأعطال'));
    await tester.pump();

    // القسمان مُضافان مع زرّيهما — بلا اتصال، الزران ظاهران لكنهما
    // معطّلان بعنوان «اتصل بالجهاز أولاً».
    expect(find.text('أكواد إطار التجميد (أمر 02)'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
    expect(find.text('مسح أكواد الأعطال (أمر 04)'), findsOneWidget);
    // زرّا القسمين معاً (كلاهما معطّل بلا اتصال).
    expect(find.text('اتصل بالجهاز أولاً'), findsNWidgets(2));
    expect(find.byIcon(Icons.delete_sweep_rounded), findsOneWidget);
    expect(find.text('إلغاء'), findsNothing); // نافذة التأكيد غير مفتوحة

    controller.dispose();
  });
}
