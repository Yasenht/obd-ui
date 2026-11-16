import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:drive_scope/controllers/app_controller.dart';
import 'package:drive_scope/controllers/app_scope.dart';
import 'package:drive_scope/main.dart';
import 'package:drive_scope/screens/main_shell.dart';
import 'package:drive_scope/theme/app_theme.dart';

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
    expect(find.text('مسح أكواد الأعطال (أمر DTCCLR)'), findsOneWidget);
    // زرّا القسمين معاً (كلاهما معطّل بلا اتصال).
    expect(find.text('اتصل بالجهاز أولاً'), findsNWidgets(2));
    expect(find.byIcon(Icons.delete_sweep_rounded), findsOneWidget);
    expect(find.text('إلغاء'), findsNothing); // نافذة التأكيد غير مفتوحة

    controller.dispose();
  });

  testWidgets('منتقي الماركة: البحث الحي والاختيار من الورقة السفلية',
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

    // فتح منتقي الماركة من حقل القيمة (داخل نطاق الضغط).
    await tester.tap(find.text('اضغط للاختيار والبحث'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // الورقة مفتوحة: حقل البحث (بتلميحه الفريد) والقائمة كاملة.
    expect(find.text('ماركة السيارة'), findsWidgets);
    expect(find.text('ابحث…'), findsOneWidget);
    expect(find.text('Toyota'), findsOneWidget);
    expect(find.text('Nissan'), findsOneWidget);

    // البحث الحي: "toy" يُبقي Toyota ويزيل البقية (غير حساس للحالة).
    await tester.enterText(find.widgetWithText(TextField, 'ابحث…'), 'toy');
    await tester.pump();
    expect(find.text('Toyota'), findsOneWidget);
    expect(find.text('Nissan'), findsNothing);

    // إزالة البحث ثم الاختيار.
    await tester.enterText(find.widgetWithText(TextField, 'ابحث…'), '');
    await tester.pump();
    await tester.tap(find.text('Toyota'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // القيمة اختيرت: الحقل يعرضها والموديل صار متاحاً.
    expect(controller.vehicleMake, 'Toyota');
    expect(find.text('Toyota'), findsOneWidget);
    expect(find.text('اختر موديلاً'), findsOneWidget);

    // منتقي سنة الصنع: نفس الآلية مع بحث رقمي.
    // الحقل أسفل الشاشة بعد توسّع ملخص الاختيار — تمرير أولاً.
    await tester.scrollUntilVisible(
      find.text('اختر سنة الصنع'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('اختر سنة الصنع'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // البحث الرقمي: "201" يُبقي 2015 ويزيل 2026.
    await tester.enterText(find.widgetWithText(TextField, 'ابحث…'), '201');
    await tester.pump();
    expect(find.text('2015'), findsOneWidget);
    expect(find.text('2026'), findsNothing);

    // إزالة البحث ثم الاختيار — 2015 أسفل نافذة القائمة الكسولة،
    // فيُمرَّر حتى يظهر قبل الضغط عليه.
    await tester.enterText(find.widgetWithText(TextField, 'ابحث…'), '');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('2015'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('2015'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // السنة اختيرت: الحقل يعرضها ووحدة التحكم تسجّلها.
    expect(controller.vehicleYear, 2015);
    expect(find.text('2015'), findsOneWidget);

    controller.dispose();
  });
}
