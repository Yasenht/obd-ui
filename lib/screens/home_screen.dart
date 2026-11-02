import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'fault_details_screen.dart';
import 'home_widgets/home_sections.dart';
import 'main_shell.dart';

/// إجراءات الفحص السريع المتاحة في الشاشة الرئيسية.
enum QuickScanAction { dtc, engineStatus, liveData, emissions, vehicleInfo }

/// الشاشة الأولى: الترحيب، الاتصال بالجهاز، الفحص السريع،
/// البحث اليدوي عن كود عطل، وملخص نتيجة آخر فحص.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _dtcCodeController = TextEditingController();
  final FocusNode _dtcCodeFocus = FocusNode();
  bool _showAllDevices = false;

  /// نمط كود العطل المقصود هداياً في حقل الإدخال (P0301 مثلاً).
  static final RegExp _dtcPattern =
      RegExp(r'^[PCBU][0-3][0-9A-F]{3}$', caseSensitive: false);

  @override
  void dispose() {
    _dtcCodeController.dispose();
    _dtcCodeFocus.dispose();
    super.dispose();
  }

  // ============================================================
  // إجراءات الشاشة
  // ============================================================

  Future<void> _runQuickAction(QuickScanAction action) async {
    final controller = context.controller;

    // كل الإجراءات (عدا الانتقال إلى البيانات الحية) تتطلب اتصالاً فعلياً.
    // لا نختلق نتيجة ناجحة بلا جهاز.
    if (action != QuickScanAction.liveData && !controller.connected) {
      showResultSheet(
        context,
        title: 'يلزم الاتصال أولاً',
        success: false,
        summary: 'اتصل بجهاز التشخيص OBD-II من قسم «الاتصال بجهاز التشخيص» '
            'قبل تنفيذ هذا الفحص.',
      );
      return;
    }

    switch (action) {
      case QuickScanAction.dtc:
        final raw = await controller.readDtc();
        if (!mounted) return;
        if (raw != null) {
          final codes = controller.dtcCodes;
          showResultSheet(
            context,
            title: 'فحص أكواد الأعطال',
            success: true,
            summary: codes.isEmpty
                ? 'لا توجد أكواد أعطال مسجلة في وحدة التحكم حالياً (وفق رد الجهاز الفعلي).'
                : 'عُثر على ${codes.length} ${codes.length == 1 ? 'كود عطل' : 'أكواد أعطال'}: '
                    '${codes.join('، ')}',
            raw: raw,
            note: codes.isEmpty
                ? null
                : 'افتح تبويب «الأعطال» لعرض التفاصيل ونسخ الأكواد.',
          );
        } else {
          showResultSheet(
            context,
            title: 'فحص أكواد الأعطال',
            success: false,
            summary:
                controller.error ?? 'فشل الفحص — راجع رسالة الخطأ في الشاشة.',
          );
        }
        break;

      case QuickScanAction.engineStatus:
        final reading =
            await controller.readPid(0x05, 'فحص حالة المحرك (حرارة التبريد)');
        if (!mounted) return;
        if (reading != null) {
          // جهد البطارية ضمن فحص الحالة — يُقرأ من الجهاز فعلاً فقط.
          final battery = await controller.readBattery();
          if (!mounted) return;
          showResultSheet(
            context,
            title: 'حالة المحرك',
            success: true,
            summary: [
              '${reading.label}: ${reading.displayValue}',
              if (battery != null) 'جهد البطارية: $battery V',
            ].join('\n'),
            raw: reading.raw,
            note: 'الحرارة خارج النطاق الطبيعي (~80-105°م) أو جهد بطارية '
                'أقل من ~12 فولت قد يدل على مشكلة — التأكيد يتطلب فحصاً فعلياً.',
          );
        } else {
          showResultSheet(
            context,
            title: 'حالة المحرك',
            success: false,
            summary: controller.error ?? 'فشل قراءة حالة المحرك.',
          );
        }
        break;

      case QuickScanAction.liveData:
        // تفعيل البث الحي وتمرير الشاشة إلى قسم البيانات الحية.
        if (controller.connected && !controller.liveEnabled) {
          controller.toggleLive(true);
        }
        HomeSections.scrollToLiveSection(context);
        break;

      case QuickScanAction.emissions:
        // جهوزية الانبعاثات: Mode-01 PID 01 (حالة MIL + جاهزية المراقبات).
        // الرد يُعرض خاماً مع توضيح — لا يُفهم ضمنياً إلا بعد تهيئة
        // محلله عبر الـ API (مستقبلياً عبر تحليل نفس خدمة الأوامر).
        final raw = await controller.executeCommand(
          'فحص جهوزية الانبعاثات (PID 01)',
          '0101\r',
        );
        if (!mounted) return;
        if (raw != null) {
          showResultSheet(
            context,
            title: 'جهوزية الانبعاثات',
            success: true,
            summary: 'وصل رد من الجهاز — انظر الرد الخام أدناه.',
            raw: raw,
            note: 'لا يزال فك صيغة PID 01 (جاهزية أنظمة الانبعاثات) غير '
                'مهيأَ محلياً؛ نتائج الانبعاثات النهائية تُعرض بعد ربط '
                'خدمة التحليل الخاصة بالجهوزية.',
          );
        } else {
          showResultSheet(
            context,
            title: 'جهوزية الانبعاثات',
            success: false,
            summary: controller.error ?? 'فشل الطلب — تأكد من الاتصال.',
          );
        }
        break;

      case QuickScanAction.vehicleInfo:
        final vin = await controller.readVin();
        if (!mounted) return;
        if (vin != null) {
          showResultSheet(
            context,
            title: 'معلومات المركبة (VIN)',
            success: true,
            summary: vin,
            note: 'رقم الهيكل مُقروء من الجهاز مباشرة.',
          );
        } else {
          showResultSheet(
            context,
            title: 'معلومات المركبة (VIN)',
            success: false,
            summary: controller.error ?? 'فشل قراءة رقم الهيكل.',
          );
        }
        break;
    }
  }

  void _submitManualCode() {
    final text = _dtcCodeController.text.trim().toUpperCase();
    if (text.isEmpty) {
      _showValidationHint('أدخل كود العطل أولاً — مثال: P0301');
      return;
    }
    if (!_dtcPattern.hasMatch(text)) {
      _showValidationHint(
          'كود غير صالح: "$text". الصيغة القياسية: حرف (P/C/B/U) '
          'ثم 4 خانات، مثل P0301.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FaultDetailsScreen(code: text),
      ),
    );
  }

  void _showValidationHint(String message) {
    // استخدام معلومة تحقق محلية — لا رسالة نجاح مزيّفة.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // البناء
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final controller = context.controller;
    final palette = Palette.of(context);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_car_rounded,
                  color: palette.onPrimary, size: 22),
              const SizedBox(width: 8),
              Text('DriveScope',
                  style: Theme.of(context).appBarTheme.titleTextStyle),
            ],
          ),
          actions: const [
            _HomeStatusIndicator(),
            SizedBox(width: 12),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: controller.scan,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: kScreenPadding,
            key: HomeSections.scrollKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWelcome(context, controller),
                if (controller.error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(
                    message: controller.error!,
                    onDismiss: controller.clearError,
                  ),
                ],
                const SizedBox(height: 12),

                // قسم الاتصال (عُنوانه في كارت الاتصال نفسه).
                HomeSections.connectionCard(
                  context,
                  showAllDevices: _showAllDevices,
                  onToggleShowAll: () =>
                      setState(() => _showAllDevices = !_showAllDevices),
                ),
                const SizedBox(height: 20),

                liveDataSection(
                  context,
                  key: HomeSections.liveSectionKey,
                ),
                const SizedBox(height: 20),

                SectionHeader(
                  title: 'الفحص السريع',
                  subtitle: 'تنفّذ عمليات فحص بنقرة واحدة',
                  icon: Icons.bolt_rounded,
                ),
                const SizedBox(height: 10),
                _buildQuickScanGrid(context, controller),
                const SizedBox(height: 20),

                SectionHeader(
                  title: 'البحث عن عطل يدوياً',
                  subtitle: 'أدخل كود عطل قياسي مثل P0301 لعرض تفاصيله',
                  icon: Icons.search_rounded,
                ),
                const SizedBox(height: 10),
                _buildManualCodeCard(context, controller),
                const SizedBox(height: 20),

                SectionHeader(
                  title: 'نتيجة آخر فحص تشخيصي',
                  subtitle: 'ملخص حالة السيارة حسب آخر قراءة فعلية',
                  icon: Icons.assessment_rounded,
                ),
                const SizedBox(height: 10),
                _buildResultsSummary(context, controller),
                const SizedBox(height: 20),

                SectionHeader(
                  title: 'التحليل الذكي لآخر رد',
                  subtitle: 'تحليل رد الجهاز عبر خدمة التحليل (API)',
                  icon: Icons.psychology_alt_rounded,
                ),
                const SizedBox(height: 10),
                _buildAnalysisCard(context, controller),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- قسم الترحيب ----

  Widget _buildWelcome(BuildContext context, AppController controller) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.olive,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.engineering_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مرحباً بك في مركز تشخيص سيارتك',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اتصل بجهاز التشخيص وافحص حالة سيارتك في دقائق',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- شبكة الفحص السريع ----

  Widget _buildQuickScanGrid(BuildContext context, AppController controller) {
    final items = [
      (
        QuickScanAction.dtc,
        Icons.error_outline_rounded,
        'فحص أكواد الأعطال',
        'قراءة الأكواد المسجلة'
      ),
      (
        QuickScanAction.engineStatus,
        Icons.car_repair_rounded,
        'حالة المحرك',
        'حرارة سائل التبريد'
      ),
      (
        QuickScanAction.liveData,
        Icons.monitor_heart_rounded,
        'بيانات حية',
        'RPM/سرعة/جهد مباشر'
      ),
      (
        QuickScanAction.emissions,
        Icons.eco_rounded,
        'جهوزية الانبعاثات',
        'Mode 01 PID 01'
      ),
      (
        QuickScanAction.vehicleInfo,
        Icons.badge_rounded,
        'معلومات المركبة',
        'رقم الهيكل VIN'
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossCount = constraints.maxWidth > 560 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: crossCount == 2 ? 1.45 : 1.35,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final (action, icon, title, subtitle) = items[index];
            return _QuickScanTile(
              icon: icon,
              title: title,
              subtitle: subtitle,
              enabled: !controller.busy,
              onTap: () => _runQuickAction(action),
            );
          },
        );
      },
    );
  }

  // ---- كارت البحث اليدوي ----

  Widget _buildManualCodeCard(BuildContext context, AppController controller) {
    final palette = Palette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dtcCodeController,
                    focusNode: _dtcCodeFocus,
                    textInputAction: TextInputAction.search,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 5,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      letterSpacing: 2,
                      color: palette.text,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'مثال: P0301',
                      counterText: '',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                    onSubmitted: (_) => _submitManualCode(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _submitManualCode,
                icon: const Icon(Icons.travel_explore_rounded, size: 20),
                label: const Text('تحليل الكود'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- كارت ملخص النتائج ----

  Widget _buildResultsSummary(BuildContext context, AppController controller) {
    final palette = Palette.of(context);
    final hasScan = controller.hasReadDtc;
    final codes = controller.dtcCodes;

    final IconData icon;
    final String title;
    final String message;
    final Color accent;

    if (!hasScan) {
      icon = Icons.pending_actions_rounded;
      title = 'لم يكتمل الفحص بعد';
      message = 'لا توجد بيانات كافية — اتصل بالجهاز ونفّذ «فحص أكواد الأعطال» '
          'قبل الحكم على حالة السيارة.';
      accent = palette.textMuted;
    } else if (codes.isEmpty) {
      icon = Icons.verified_rounded;
      title = 'لا توجد أعطال مسجلة';
      message =
          'وفق رد الجهاز الفعلي في آخر فحص (${_formatTime(controller.lastDtcScanTime)}).';
      accent = palette.onPrimary;
    } else {
      icon = Icons.error_rounded;
      title =
          '${codes.length} ${codes.length == 1 ? 'عطل مكتشف' : 'أعطال مكتشفة'}';
      message = 'آخر فحص: ${_formatTime(controller.lastDtcScanTime)} — '
          '${codes.take(3).join('، ')}${codes.length > 3 ? ' ...' : ''}';
      accent = AppColors.error;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: accent == palette.textMuted
                              ? palette.text
                              : accent,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message,
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
            if (hasScan) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        codes.isEmpty ? palette.onPrimary : AppColors.error,
                  ),
                  onPressed:
                      codes.isEmpty ? null : () => openFaultsTab(context),
                  icon: const Icon(Icons.list_alt_rounded, size: 20),
                  label: Text(codes.isEmpty
                      ? 'لا شيء للعرض (فحص سليم)'
                      : 'عرض الأعطال والتفاصيل'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) => time == null
      ? 'غير معروف'
      : DateFormat('d MMM • HH:mm', 'ar').format(time.toLocal());

  // ---- بطاقة التحليل الذكي (خدمة API) ----

  Widget _buildAnalysisCard(BuildContext context, AppController controller) {
    final palette = Palette.of(context);
    final analysis = controller.lastApiAnalysis;

    if (controller.apiLoading && analysis == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'جارٍ إرسال الرد إلى خدمة التحليل...',
                  style: TextStyle(fontSize: 12.5, color: palette.textMuted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (analysis == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: EmptyState(
            compact: true,
            icon: controller.apiError != null
                ? Icons.cloud_off_rounded
                : Icons.auto_awesome_rounded,
            title: controller.apiError != null
                ? 'تعذر تحليل الرد عبر API'
                : 'لا يوجد تحليل بعد',
            message: controller.apiError ??
                'نفّذ أي فحص أو أرسل أمراً بعد الاتصال بالجهاز، وسيظهر هنا '
                    'تحليل الخدمة عند توفره.',
          ),
        ),
      );
    }

    String label(String? value) {
      switch (value?.toLowerCase()) {
        case 'warning':
          return 'تحذير';
        case 'error':
          return 'خطأ';
        case 'critical':
          return 'حرج';
        case 'high':
          return 'مرتفع';
        case 'medium':
          return 'متوسط';
        case 'low':
          return 'منخفض';
        case 'info':
          return 'معلومات';
        case 'success':
          return 'سليم';
        default:
          return value ?? 'غير محدد';
      }
    }

    final values = analysis['values'] is Map
        ? Map<String, dynamic>.from(analysis['values'] as Map)
        : <String, dynamic>{};
    final dtcs = analysis['dtcs'] is List
        ? (analysis['dtcs'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final confidence = analysis['confidence'];
    final status = analysis['status']?.toString();
    final severity = analysis['severity']?.toString();

    Widget detail(String title, dynamic value, IconData icon) {
      if (value == null || value.toString().trim().isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: palette.onPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      color: palette.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.text,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.apiLoading) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Icon(Icons.analytics_rounded,
                    size: 18, color: palette.onPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    analysis['title']?.toString() ?? 'نتيجة التحليل',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: palette.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(label: Text('الحالة: ${label(status)}')),
                Chip(label: Text('الخطورة: ${label(severity)}')),
                if (confidence is num)
                  Chip(
                      label: Text(
                          'الثقة: ${(confidence * 100).toStringAsFixed(0)}%')),
              ],
            ),
            const Divider(height: 20),
            detail('شرح التحليل', analysis['explanation'],
                Icons.info_outline_rounded),
            detail('المشكلة المحتملة', analysis['problem'],
                Icons.warning_amber_rounded),
            detail('التوصية', analysis['recommendation'],
                Icons.build_circle_outlined),
            if (values.isNotEmpty)
              detail(
                'القيم المستخرجة',
                values.entries.map((e) => '${e.key}: ${e.value}').join(' | '),
                Icons.sensors_rounded,
              ),
            if (dtcs.isNotEmpty)
              detail('رموز الأعطال (DTC)', dtcs.join('، '),
                  Icons.error_outline_rounded),
            if (controller.apiError != null) ...[
              const SizedBox(height: 4),
              Text(
                controller.apiError!,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.warning, height: 1.4),
              ),
            ],
            if (controller.lastApiCommand.isNotEmpty) ...[
              const Divider(height: 18),
              Text(
                'الأمر: ${controller.lastApiCommand}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                  color: palette.textMuted,
                ),
                textDirection: TextDirection.ltr,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// مؤشر حالة مصغّر في شريط التطبيق — يفتح كارت الاتصال عند الضغط.
class _HomeStatusIndicator extends StatelessWidget {
  const _HomeStatusIndicator();

  @override
  Widget build(BuildContext context) {
    final controller = context.controller;
    return GestureDetector(
      onTap: () => HomeSections.scrollToConnection(context),
      child: StatusPill(status: controller.status, compact: true),
    );
  }
}

// ============================================================
/// بلاطة فحص سريع واحدة.
// ============================================================

class _QuickScanTile extends StatelessWidget {
  const _QuickScanTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: BorderSide(color: palette.border),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(kRadius),
        splashColor: palette.onPrimary.withOpacity(0.10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: palette.onPrimary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: palette.onPrimary),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: palette.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
