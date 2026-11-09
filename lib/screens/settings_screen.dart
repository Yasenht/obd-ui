import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../obd_protocol.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// شاشة الإعدادات: المظهر، أدوات الاتصال الفنية (المنفذ اليدوي
/// وسجل BLE)، وأدوات الصيانة.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _manualCommandController =
      TextEditingController();

  @override
  void dispose() {
    _manualCommandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.controller;
    final palette = Palette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'المظهر',
              subtitle: 'اختر وضع العرض — يُحفظ التحديد تلقائياً',
              icon: Icons.palette_rounded,
            ),
            const SizedBox(height: 10),
            _buildThemeSelector(context, controller, palette),
            const SizedBox(height: 20),
            SectionHeader(
              title: 'أدوات فنية',
              subtitle: 'المنفذ اليدوي وسجل BLE — للمتقنين والتشخيص المتقدم',
              icon: Icons.terminal_rounded,
            ),
            const SizedBox(height: 10),
            _buildManualTerminal(context, controller, palette),
            const SizedBox(height: 12),
            _buildDebugLogCard(context, controller, palette),
            const SizedBox(height: 20),
            SectionHeader(
              title: 'حول',
              subtitle: 'DriveScope — فحص المركبات عبر OBD-II',
              icon: Icons.info_rounded,
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.bug_report_rounded),
                title: const Text('الإصدار'),
                subtitle: const Text('0.1.0+1'),
                dense: true,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // اختيار وضع المظهر (فاتح / داكن / حسب النظام)
  // ============================================================

  Widget _buildThemeSelector(
    BuildContext context,
    AppController controller,
    Palette palette,
  ) {
    return Column(
      children: ThemeMode.values
          .map(
            (mode) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ThemeOptionTile(
                mode: mode,
                title: switch (mode) {
                  ThemeMode.light => 'الفاتح',
                  ThemeMode.dark => 'الداكن',
                  ThemeMode.system => 'حسب النظام',
                },
                subtitle: switch (mode) {
                  ThemeMode.light => 'خلفية فاتحة وألوان زيتونية أكثف',
                  ThemeMode.dark => 'خلفية داكنة مريحة للعين ليل فاتح',
                  ThemeMode.system => 'يتبع إعداد النظام على جهازك',
                },
                icon: switch (mode) {
                  ThemeMode.light => Icons.light_mode_rounded,
                  ThemeMode.dark => Icons.dark_mode_rounded,
                  ThemeMode.system => Icons.settings_suggest_rounded,
                },
                selected: controller.themeMode == mode,
                onTap: () => controller.setThemeMode(mode),
              ),
            ),
          )
          .toList(),
    );
  }

  // ============================================================
  // المنفذ اليدوي (أوامر ELM327 مخصصة)
  // ============================================================

  Widget _buildManualTerminal(
    BuildContext context,
    AppController controller,
    Palette palette,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.terminal_rounded,
                    size: 18, color: palette.onPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'المنفذ اليدوي (ELM327)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: palette.text,
                    ),
                  ),
                ),
                if (controller.connected)
                  StatusPill(status: controller.status, compact: true)
                else
                  Text(
                    'يتطلب اتصالاً',
                    style: TextStyle(fontSize: 10.5, color: palette.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCommandController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: 'مثال: 010C أو BATT',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendManual(controller),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      controller.busy ? null : () => _sendManual(controller),
                  child: const Text('إرسال'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendManual(AppController controller) async {
    final typed = _manualCommandController.text;
    final response = await controller.sendManualCommand(typed);
    _manualCommandController.clear();
    if (!mounted) return;
    if (response != null) {
      // النتيجة تُشرح بمعناها ووحدتها (مثل "حرارة سائل التبريد: 76 °C")
      // بدل عرض الكود أو الرقم فقط.
      final reading = controller.lastPidReading;
      final summary = reading != null
          ? '${reading.label}: ${reading.displayValue}'
          : ObdParser.describeCommandResult(typed, response);
      showResultSheet(
        context,
        title: 'الرد الواصل',
        success: true,
        summary: summary,
        raw: response,
      );
    } else {
      showResultSheet(
        context,
        title: 'لم يصل رد',
        success: false,
        summary: controller.error,
      );
    }
  }

  // ============================================================
  // سجل BLE الفني
  // ============================================================

  Widget _buildDebugLogCard(
    BuildContext context,
    AppController controller,
    Palette palette,
  ) {
    final logs = controller.debugLogs.reversed.take(60).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'سجل BLE الفني (BLE Debug Log)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: palette.text,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'مسح السجل',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => controller.clearDebugLogs(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(kRadiusSmall),
                border: Border.all(color: palette.border),
              ),
              child: logs.isEmpty
                  ? Text(
                      'لم تصل رسائل بعد. ابحث عن جهاز وقم بالاتصال.',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 11.5,
                      ),
                    )
                  : SingleChildScrollView(
                      child: SelectableText(
                        logs.join('\n\n'),
                        style: TextStyle(
                          color: palette.onPrimary,
                          fontSize: 10,
                          fontFamily: 'monospace',
                          height: 1.35,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final accent = selected ? palette.onPrimary : palette.textMuted;
    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: BorderSide(
          color: selected ? palette.onPrimary : palette.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? palette.onPrimary : palette.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
