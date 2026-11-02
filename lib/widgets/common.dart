import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../ble_obd_service.dart';
import '../theme/app_colors.dart';

/// نصف قطر الزوايا الموحد.
const double kRadius = 16.0;
const double kRadiusSmall = 12.0;
const EdgeInsets kScreenPadding = EdgeInsets.fromLTRB(16, 8, 16, 24);

// ============================================================
// ترويسة قسم موحدة
// ============================================================

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: palette.onPrimary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: palette.onPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                  color: palette.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 12, color: palette.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (action != null) ...[action!, const SizedBox(width: 4)],
      ],
    );
  }
}

// ============================================================
// شريحة حالة الاتصال
// ============================================================

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.compact = false});

  final ObdConnectionStatus status;
  final bool compact;

  static Color colorOf(ObdConnectionStatus status, BuildContext context) {
    final palette = Palette.of(context);
    switch (status) {
      case ObdConnectionStatus.connected:
        // أخضر زيتوني واضح في الوضع الفاتح، وأفتح منه في الداكن للتباين.
        return palette.isDark ? AppColors.oliveLight : const Color(0xFF4E7F3A);
      case ObdConnectionStatus.connecting:
      case ObdConnectionStatus.scanning:
        return AppColors.warning;
      case ObdConnectionStatus.error:
        return AppColors.error;
      case ObdConnectionStatus.disconnected:
        return palette.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorOf(status, context);
    final label = switch (status) {
      ObdConnectionStatus.connected => 'متصل',
      ObdConnectionStatus.connecting => 'جارٍ الاتصال',
      ObdConnectionStatus.scanning => 'جارٍ البحث',
      ObdConnectionStatus.error => 'خطأ بالاتصال',
      ObdConnectionStatus.disconnected => 'غير متصل',
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (status) {
              ObdConnectionStatus.connected =>
                Icons.bluetooth_connected_rounded,
              ObdConnectionStatus.connecting ||
              ObdConnectionStatus.scanning =>
                Icons.bluetooth_searching_rounded,
              ObdConnectionStatus.error => Icons.bluetooth_disabled_rounded,
              ObdConnectionStatus.disconnected => Icons.bluetooth_rounded,
            },
            color: color,
            size: compact ? 12 : 14,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10.5 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// لافتة خطأ قابلة للإغلاق
// ============================================================

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(kRadiusSmall),
        border: Border.all(color: AppColors.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded,
                  size: 16, color: AppColors.error),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}

// ============================================================
// حالة فراغ أنيقة
// ============================================================

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: compact ? 12 : 28, horizontal: compact ? 4 : 20),
      child: Column(
        children: [
          Container(
            width: compact ? 48 : 64,
            height: compact ? 48 : 64,
            decoration: BoxDecoration(
              color: palette.onPrimary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child:
                Icon(icon, size: compact ? 24 : 30, color: palette.onPrimary),
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 13.5 : 15,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 11.5 : 12.5,
              color: palette.textMuted,
              height: 1.5,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

// ============================================================
/// بطاقة مؤشر قراءة حية (RPM / سرعة / جهد)
// ============================================================

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(kRadiusSmall),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: palette.text,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
/// شارة كود عطل احادية العرض (LTR مونّوسبيس) وقابلة للنسخ.
// ============================================================

class DtcCodeBadge extends StatelessWidget {
  const DtcCodeBadge({
    super.key,
    required this.code,
    this.compact = false,
  });

  final String code;
  final bool compact;

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نسخ الكود $code')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _copy(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: Palette.of(context).onPrimary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                fontSize: compact ? 12 : 14,
                color: Palette.of(context).onPrimary,
                letterSpacing: 0.5,
              ),
              textDirection: TextDirection.ltr,
            ),
            SizedBox(width: compact ? 2 : 4),
            Icon(
              Icons.copy_rounded,
              size: compact ? 10 : 12,
              color: Palette.of(context).onPrimary.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
/// ورقة نتيجة موحّدة (ورقة سفلية) لأي فحص سريع.
// ============================================================

Future<void> showResultSheet(
  BuildContext context, {
  required String title,
  String? summary,
  String? raw,
  required bool success,
  String? note,
}) {
  final palette = Palette.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 6,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  success ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: success ? palette.onPrimary : AppColors.error,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: palette.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (summary != null && summary.isNotEmpty)
              Text(
                summary,
                style: TextStyle(
                  fontSize: 14,
                  color: palette.text,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            if (raw != null && raw.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(kRadiusSmall),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        raw,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          color: palette.text,
                          height: 1.5,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'نسخ الرد الخام',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: raw));
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم النسخ')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15, color: palette.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: palette.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}

// ============================================================
/// تنسيق تاريخ/ساعة عربي موحّد.
// ============================================================

final DateFormat kDateFormatter = DateFormat('EEEE d MMMM yyyy', 'ar');
final DateFormat kTimeFormatter = DateFormat('HH:mm', 'ar');

String formatRecordTime(DateTime time) =>
    '${kDateFormatter.format(time)} • ${kTimeFormatter.format(time)}';
