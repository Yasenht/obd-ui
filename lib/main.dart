import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'controllers/app_controller.dart';
import 'controllers/app_scope.dart';
import 'screens/main_shell.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  final controller = AppController();
  await controller.loadPreferences();
  unawaited(controller.loadHistory());
  runApp(AppScope(controller: controller, child: const ObdScannerApp()));
}

class ObdScannerApp extends StatefulWidget {
  const ObdScannerApp({super.key});

  @override
  State<ObdScannerApp> createState() => _ObdScannerAppState();
}

class _ObdScannerAppState extends State<ObdScannerApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DriveScope — فاحص OBD',
      themeMode: controller.themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // دعم العربية الكامل: اتجاه RTL عبر كامل شجرة التطبيق.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: _showSplash ? const SplashScreen() : _BootShell(),
    );
  }
}

/// غلاف الهيكل الرئيسي — يُشغّل الخدمات (BLE/HTTP) مرة واحدة عند
/// إقلاع الواجهة، بنفس تسلسل الإقلاع السابق (أذونات + بث + HTTP).
class _BootShell extends StatefulWidget {
  const _BootShell();

  @override
  State<_BootShell> createState() => _BootShellState();
}

class _BootShellState extends State<_BootShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.of(context).startServices();
    });
  }

  @override
  Widget build(BuildContext context) => const MainShell();
}

// ============================================================
// شاشة الترحيب السريعة (هوية زيتونية)
// ============================================================

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oliveDark,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.85, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.28),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  size: 52,
                  color: Color(0xFFDCE6C8),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'DriveScope',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkText,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'مركز تشخيص المركبات عبر OBD-II',
                style: TextStyle(
                  color: Color(0xFFDCE6C8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
