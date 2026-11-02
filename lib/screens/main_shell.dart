import 'package:flutter/material.dart';

import '../controllers/app_scope.dart';
import '../theme/app_colors.dart';
import 'faults_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// الهيكل الرئيسي: شريط تنقّل سفلي بأربع تبويبات مع حماية حالة
/// الشاشات عبر IndexedStack (لا يُفقد البيانات عند التنقل).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// عرف ثابت للوحدة — ولا يُستخدم إلا للـ debugging.
  static const String debugLabel = 'MainShell';

  /// الوصول إلى حالة الهيكل (لتغيير التبويب من الشاشات الأخرى).
  static MainShellState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _index = 0;

  void selectTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final controller = context.controller;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          FaultsScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: selectTab,
        height: 66,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: palette.onPrimary),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: controller.dtcCodes.isNotEmpty,
              label: Text('${controller.dtcCodes.length}'),
              backgroundColor: AppColors.error,
              child: const Icon(Icons.warning_amber_outlined),
            ),
            selectedIcon: const Icon(Icons.warning_amber_rounded),
            label: 'الأعطال',
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded, color: palette.onPrimary),
            label: 'السجل',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon:
                Icon(Icons.settings_rounded, color: palette.onPrimary),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}

/// فتح تبويب الأعطال من أي شاشة (مثل زر «عرض الأعطال والتفاصيل» في الرئيسية).
void openFaultsTab(BuildContext context) {
  MainShell.maybeOf(context)?.selectTab(1);
}
