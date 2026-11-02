import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'fault_details_screen.dart';

enum DtcSystem {
  powertrain('P', 'المحرك / ناقل الحركة', Icons.car_repair_rounded),
  chassis('C', 'الشاسي', Icons.directions_rounded),
  body('B', 'هيكل السيارة', Icons.accessibility_new_rounded),
  network('U', 'الشبكة والاتصالات', Icons.settings_input_antenna_rounded),
  unknown('', 'نظام غير معروف', Icons.help_outline_rounded);

  const DtcSystem(this.prefix, this.displayName, this.icon);
  final String prefix;
  final String displayName;
  final IconData icon;

  static DtcSystem fromCode(String code) {
    if (code.isEmpty) return unknown;
    for (final s in DtcSystem.values) {
      if (s.prefix.isNotEmpty && s.prefix == code[0].toUpperCase()) return s;
    }
    return unknown;
  }
}

/// الشاشة الثانية: قائمة أعطال السيارة المكتشفة من آخر فحص فعلي.
class FaultsScreen extends StatelessWidget {
  const FaultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.controller;
    final palette = Palette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('أعطال السيارة'),
        actions: [
          IconButton(
            tooltip: 'فحص جديد',
            onPressed: controller.busy ? null : () => controller.readDtc(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: ErrorBanner(
                message: controller.error!,
                onDismiss: controller.clearError,
              ),
            ),
          Expanded(
            child: _buildBody(context, controller, palette),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppController controller,
    Palette palette,
  ) {
    if (controller.busy) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('جارٍ قراءة الأكواد من الجهاز...'),
          ],
        ),
      );
    }

    if (!controller.hasReadDtc) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyState(
                icon: Icons.pending_actions_rounded,
                title: 'لم يُجرَ فحص بعد',
                message: 'لا يمكن عرض الأعطال قبل تنفيذ فحص فعلي عبر '
                    'الاتصال بجهاز التشخيص OBD-II.',
                action: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed:
                        controller.busy ? null : () => controller.readDtc(),
                    icon: const Icon(Icons.bolt_rounded, size: 20),
                    label: const Text('فحص أكواد الأعطال الآن'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final codes = controller.dtcCodes;
    if (codes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyState(
                icon: Icons.verified_rounded,
                title: 'لا توجد أعطال مسجلة',
                message:
                    'نتيجة الفحص الفعلي (${_scanTimeText(controller.lastDtcScanTime)}) '
                    'تُبيّن أن نظام المركبة لا يحتفظ بأكواد أعطال حالياً.',
              ),
              Text(
                'لا يمكن اعتبار ذلك ضماناً دائماً — كرر الفحص دورياً.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: codes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final code = codes[index];
        final system = DtcSystem.fromCode(code);
        return _FaultTile(
          code: code,
          system: system,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FaultDetailsScreen(code: code),
              ),
            );
          },
        );
      },
    );
  }

  String _scanTimeText(DateTime? time) {
    if (time == null) return 'غير معروف';
    return formatRecordTime(time.toLocal());
  }
}

// ============================================================
/// بطاقة عطل واحدة في القائمة.
// ============================================================

class _FaultTile extends StatelessWidget {
  const _FaultTile({
    required this.code,
    required this.system,
    required this.onTap,
  });

  final String code;
  final DtcSystem system;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(system.icon, color: AppColors.error, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        DtcCodeBadge(code: code),
                        const SizedBox(width: 8),
                        // الخطورة غير متوفرة محلياً — تتطلب ربط خدمة الأعطال.
                        Text(
                          'الخطورة: غير محدد',
                          style: TextStyle(
                            fontSize: 10,
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      system.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'اضغط للتفاصيل · الحالة: غير متوفرة (يتطلب ربط API)',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
