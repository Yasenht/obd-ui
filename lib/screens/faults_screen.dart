import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/dtc_analysis.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'fault_details_screen.dart';

/// أنظمة الكود المعيارية (تُستخدم فقط في شاشة التفاصيل اليدوية
/// عند غياب بيانات خدمة التحليل — لا تُعرض ضمن بيانات الأعطال).
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

/// الشاشة الثانية: قائمة أعطال السيارة من آخر فحص فعلي، مع تفاصيل
/// كل كود من استجابة `POST /api/analyze/dtc`.
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
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: EmptyState(
              icon: Icons.pending_actions_rounded,
              title: 'لم يُجرَ فحص بعد',
              message: 'لا يمكن عرض الأعطال قبل تنفيذ فحص فعلي عبر '
                  'الاتصال بجهاز التشخيص OBD-II.',
              action: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: controller.busy ? null : () => controller.readDtc(),
                  icon: const Icon(Icons.bolt_rounded, size: 20),
                  label: const Text('فحص أكواد الأعطال الآن'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _FreezeFrameSection(),
          const SizedBox(height: 12),
          const _ClearFaultsSection(),
        ],
      );
    }

    final codes = controller.dtcCodes;
    final analysis = controller.dtcAnalysis;

    if (codes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          EmptyState(
            icon: Icons.verified_rounded,
            title: analysis?.title.isNotEmpty == true
                ? analysis!.title
                : 'لا توجد أعطال مسجلة',
            message: analysis?.description.isNotEmpty == true
                ? analysis!.description
                : 'نتيجة الفحص الفعلي (${_scanTimeText(controller.lastDtcScanTime)}) '
                    'تُبيّن أن نظام المركبة لا يحتفظ بأكواد أعطال حالياً.',
            compact: true,
          ),
          if (controller.dtcAnalysisLoading) ...[
            const SizedBox(height: 14),
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
          if (controller.dtcAnalysisError != null) ...[
            const SizedBox(height: 14),
            _AnalysisErrorCard(
              message: controller.dtcAnalysisError!,
              onRetry: () => controller.analyzeDtcCodes(codes),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'لا يمكن اعتبار ذلك ضماناً دائماً — كرر الفحص دورياً.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: palette.textMuted),
          ),
          const SizedBox(height: 16),
          const _FreezeFrameSection(),
          const SizedBox(height: 12),
          const _ClearFaultsSection(),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.readDtc(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // ملخص استجابة الخدمة (العنوان/الوصف/العدد) كما وردت.
          if (analysis != null) _AnalysisHeader(analysis: analysis),

          if (controller.dtcAnalysisLoading) ...[
            const SizedBox(height: 8),
            _AnalysisLoadingBar(count: codes.length),
          ],

          if (controller.dtcAnalysisError != null) ...[
            const SizedBox(height: 8),
            _AnalysisErrorCard(
              message: controller.dtcAnalysisError!,
              onRetry: () => controller.analyzeDtcCodes(codes),
            ),
          ],

          const SizedBox(height: 4),
          ...codes.map((code) {
            return _FaultTile(
              code: code,
              fault: analysis?.faultForCode(code),
              analysisLoading: controller.dtcAnalysisLoading,
              analysisFailed: controller.dtcAnalysisError != null,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FaultDetailsScreen(code: code),
                  ),
                );
              },
            );
          }),
          const SizedBox(height: 16),
          const _FreezeFrameSection(),
          const SizedBox(height: 12),
          const _ClearFaultsSection(),
        ],
      ),
    );
  }

  String _scanTimeText(DateTime? time) =>
      time == null ? 'غير معروف' : formatRecordTime(time.toLocal());
}

// ============================================================
// ترويسة استجابة الخدمة
// ============================================================

class _AnalysisHeader extends StatelessWidget {
  const _AnalysisHeader({required this.analysis});

  final DtcAnalysisResult analysis;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.report_gmailerrorred_rounded,
                    color: AppColors.error, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      analysis.title.isNotEmpty
                          ? analysis.title
                          : '${analysis.totalFaults} أعطال',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: palette.text,
                      ),
                    ),
                    if (analysis.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        analysis.description,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'totalFaults: ${analysis.totalFaults} • status: ${analysis.status}',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: palette.textMuted,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisLoadingBar extends StatelessWidget {
  const _AnalysisLoadingBar({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'جارٍ تحليل $count ${count == 1 ? 'كود' : 'أكواد'} عبر خدمة /api/analyze/dtc...',
                style: TextStyle(fontSize: 12, color: palette.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisErrorCard extends StatelessWidget {
  const _AnalysisErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.warning, height: 1.45),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('إعادة تحليل الأكواد'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
/// بطاقة عطل واحدة: كود + بيانات الاستجابة لكل كود.
/// ============================================================

class _FaultTile extends StatelessWidget {
  const _FaultTile({
    required this.code,
    required this.fault,
    required this.analysisLoading,
    required this.analysisFailed,
    required this.onTap,
  });

  final String code;
  final DtcFault? fault;
  final bool analysisLoading;
  final bool analysisFailed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final data = fault;
    final useEnglishName = data?.nameEn?.isNotEmpty == true;
    final headline = useEnglishName
        ? data!.nameEn!
        : (data?.title?.isNotEmpty == true ? data!.title! : code);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DtcCodeBadge(code: code),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: palette.text,
                      ),
                      textDirection: useEnglishName ? TextDirection.ltr : null,
                    ),
                  ),
                  Icon(Icons.chevron_left_rounded,
                      color: palette.textMuted, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              if (data == null)
                _StatusLine(
                  icon: analysisFailed
                      ? Icons.error_outline_rounded
                      : Icons.hourglass_top_rounded,
                  color: analysisFailed ? AppColors.warning : palette.textMuted,
                  text: analysisFailed
                      ? 'تعذر جلب تفاصيل هذا الكود من خدمة التحليل.'
                      : analysisLoading
                          ? 'جارٍ جلب التفاصيل من الخدمة...'
                          : 'لم تُرجع الخدمة تفاصيل لهذا الكود.',
                )
              else if (data.failed)
                _StatusLine(
                  icon: Icons.error_outline_rounded,
                  color: AppColors.error,
                  text: data.error?.isNotEmpty == true
                      ? data.error!
                      : 'تعذر تحليل رمز العطل',
                )
              else ...[
                // كل حقل معروض كما ورد من الاستجابة (بلا حقول مضافة).
                if (data.title?.isNotEmpty == true)
                  _FieldLine(label: 'العنوان', value: data.title!),
                if (data.description?.isNotEmpty == true)
                  _FieldLine(label: 'الوصف', value: data.description!),
                if (data.system?.isNotEmpty == true)
                  _FieldLine(label: 'النظام', value: data.system!),
                if (data.severity?.isNotEmpty == true)
                  _FieldLine(label: 'الخطورة', value: data.severity!),
                if (data.severityPercentage != null)
                  _FieldLine(
                    label: 'نسبة الخطورة',
                    value: '${data.severityPercentage!.toStringAsFixed(0)}%',
                  ),
                if (data.status?.isNotEmpty == true)
                  _FieldLine(label: 'الحالة', value: data.status!),
                if (data.confidence != null)
                  _FieldLine(
                    label: 'الثقة',
                    value: '${(data.confidence! * 100).toStringAsFixed(0)}%',
                  ),
                const SizedBox(height: 4),
                Text(
                  'اضغط لعرض بقية التفاصيل',
                  style: TextStyle(fontSize: 10, color: palette.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11.5, color: color, height: 1.45),
          ),
        ),
      ],
    );
  }
}

/// سطر «التسمية: القيمة» — يعرض حقل الاستجابة بقيمته.
class _FieldLine extends StatelessWidget {
  const _FieldLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 10.5,
                color: palette.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                color: palette.text,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// قسم قراءة أكواد إطار التجميد (أمر 02) — وضع Freeze Frame:
// الأكواد التي كانت سارية لحظة تخزين الإطار المجمد. أمر قراءة
// آمن بلا تأكيد (لا يحذف شيئاً)، بنقرة واحدة بلا إدخال يدوي.
// ============================================================

class _FreezeFrameSection extends StatelessWidget {
  const _FreezeFrameSection();

  Future<void> _read(BuildContext context) async {
    final controller = context.controller;
    final raw = await controller.readDtcFreezeFrame();
    if (!context.mounted) return;
    if (raw != null) {
      await showResultSheet(
        context,
        title: 'قراءة أكواد إطار التجميد',
        success: true,
        summary: 'نُفّذ الأمر 02 ووصل الرد. الأكواد المفكوكة تُعرض '
            'في قائمة الأعطال أعلاه، ويُطلب تحليلها من خدمة التحليل.',
        raw: raw,
      );
    } else {
      await showResultSheet(
        context,
        title: 'قراءة أكواد إطار التجميد',
        success: false,
        summary:
            controller.error ?? 'فشل إرسال الأمر 02 — راجع رسالة الخطأ.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final controller = context.controller;
    final enabled = controller.connected &&
        !controller.busy &&
        !controller.vehicleUnsupported;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.olive.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.camera_roll_rounded,
                      color: AppColors.olive, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أكواد إطار التجميد (أمر 02)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'يقرأ أكواد الأعطال المرتبطة بإطار التجميد '
                        'المخزّن لحظة تسجيل العطل (وضع 02) — أمر قراءة '
                        'آمن لا يحذف أو يغيّر شيئاً.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: enabled ? () => _read(context) : null,
                icon: const Icon(Icons.photo_camera_rounded, size: 20),
                label: Text(controller.connected
                    ? 'قراءة أكواد إطار التجميد'
                    : 'اتصل بالجهاز أولاً'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// قسم مسح أكواد الأعطال المخزنة (أمر 04) — إرسال بنقرة واحدة
// بعد تأكيد صريح من المستخدم، بلا إدخال يدوي.
// ============================================================

class _ClearFaultsSection extends StatelessWidget {
  const _ClearFaultsSection();

  /// نافذة تأكيد إجبارية قبل الإرسال: المسح يزيل الأكواد وإطار
  /// التجميد من ذاكرة وحدة التحكم نهائياً ولا يمكن التراجع عنه.
  Future<bool> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد مسح الأعطال'),
        content: const Text(
          'سيُرسَل الأمر 04 إلى وحدة التحكم وستُحذف كل أكواد الأعطال '
          'المخزنة مع بيانات إطار التجميد نهائياً.\n\n'
          'هل أنت متأكد من رغبتك في حذف هذه الأعطال؟ لا يمكن التراجع.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'نعم، امسح الأكواد',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _clear(BuildContext context) async {
    final controller = context.controller;
    if (!await _confirmClear(context)) return;

    final raw = await controller.clearFaultCodes();
    if (!context.mounted) return;
    if (raw != null) {
      await showResultSheet(
        context,
        title: 'مسح أكواد الأعطال',
        success: true,
        summary: 'نُفّذ الأمر 04 — ذاكرة الأكواد في وحدة التحكم مُمسحة. '
            'نفّذ «فحص أكواد الأعطال» للاطمئنان على النتيجة.',
        raw: raw,
      );
    } else {
      await showResultSheet(
        context,
        title: 'مسح أكواد الأعطال',
        success: false,
        summary:
            controller.error ?? 'فشل إرسال الأمر 04 — راجع رسالة الخطأ.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final controller = context.controller;
    final enabled = controller.connected &&
        !controller.busy &&
        !controller.vehicleUnsupported;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.delete_forever_rounded,
                      color: AppColors.error, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مسح أكواد الأعطال (أمر 04)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'يُرسل الأمر 04 إلى وحدة التحكم لمسح كل الأكواد '
                        'المخزنة وإطار التجميد — يُنفَّذ بعد تأكيدك فقط '
                        'ولا يمكن التراجع عنه.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                onPressed: enabled ? () => _clear(context) : null,
                icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                label: Text(controller.connected
                    ? 'مسح الأكواد المخزنة'
                    : 'اتصل بالجهاز أولاً'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
