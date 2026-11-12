import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/dtc_analysis.dart';
import '../services/dtc_analysis_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'faults_screen.dart';

/// شاشة تفاصيل عطل واحد.
///
/// - الكود المُكتشف في آخر فحص: تُعرض حقول استجابة
///   `POST /api/analyze/dtc` كما وردت حرفياً (بلا حقول مضافة).
/// - الكود المُدخل يدوياً (مثل P4300): يُرسل وحده إلى الخدمة نفسها
///   (Gemini) وتُعرض محللاتها: الوصف/الأسباب/الأعراض/خطوات التشخيص/
///   الحلول/الخطورة.
class FaultDetailsScreen extends StatefulWidget {
  const FaultDetailsScreen({super.key, required this.code});

  final String code;

  @override
  State<FaultDetailsScreen> createState() => _FaultDetailsScreenState();
}

enum _DetailsState { loading, loaded, notFound, error }

class _FaultDetailsScreenState extends State<FaultDetailsScreen> {
  _DetailsState _state = _DetailsState.loading;
  DtcFault? _fault;
  String? _errorText;
  bool _manualLoadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // الأكواد المُكتشفة تُعرض من استجابة خدمة التحليل مباشرة،
    // لذا لا نرسل استعلاماً جديداً عنها.
    if (_manualLoadStarted || _detectedInScan) return;
    _manualLoadStarted = true;
    unawaited(_load());
  }

  bool get _detectedInScan => context.controller.dtcCodes
      .any((c) => c.toUpperCase() == widget.code.toUpperCase());

  /// إرسال الكود المُدخل يدوياً إلى `POST /api/analyze/dtc` واستخراج
  /// تحليل هذا الكود وحده من استجابة الخدمة.
  Future<void> _load() async {
    final service = context.controller.dtcAnalysisService;
    setState(() => _state = _DetailsState.loading);
    try {
      final result =
          await service.analyzeCodes([widget.code.toUpperCase()]);
      if (!mounted) return;
      final fault = result.faultForCode(widget.code);
      setState(() {
        _fault = fault;
        _state = fault == null
            ? _DetailsState.notFound
            : _DetailsState.loaded;
      });
    } on DtcAnalysisException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.message;
        _state = _DetailsState.error;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = '$error';
        _state = _DetailsState.error;
      });
    }
  }

  void _retryAnalysis(AppController app) {
    app.analyzeDtcCodes(app.dtcCodes);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final app = context.controller;
    final detected = _detectedInScan;
    final fault = detected ? app.dtcAnalysis?.faultForCode(widget.code) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.code.toUpperCase(),
            style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1)),
        actions: [
          IconButton(
            tooltip: detected ? 'إعادة تحليل الأكواد' : 'إعادة تحليل الكود',
            onPressed: detected
                ? (app.dtcAnalysisLoading ? null : () => _retryAnalysis(app))
                : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ترويسة الكود + المصدر (خدمة التحليل أو إدخال يدوي)
            _HeaderCard(
              code: widget.code.toUpperCase(),
              system: DtcSystem.fromCode(widget.code),
              detectedInScan: detected,
              fault: fault,
            ),
            const SizedBox(height: 16),

            if (detected)
              ..._buildAnalysisContent(context, app, fault)
            else
              ..._buildManualContent(context),

            const SizedBox(height: 16),

            // إخلاء مسؤولية ثابت — إجباري لعدم التشخيص القاطع من الكود
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(kRadiusSmall),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الأسباب المحتملة تحتاج فحصاً فعلياً لتأكيدها، وقد '
                      'تختلف تسميات ومعاني بعض الأكواد بحسب الشركة '
                      'الصانعة وطراز السيارة. لا تعتمد على الكود وحده '
                      'كقرار إصلاح نهائي.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: palette.text,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// محتوى الكود المُكتشف: استجابة خدمة تحليل الأكواد فقط.
  List<Widget> _buildAnalysisContent(
    BuildContext context,
    AppController app,
    DtcFault? fault,
  ) {
    if (app.dtcAnalysisLoading && fault == null) {
      return const [_LoadingCard(message: 'جارٍ تحليل الكود عبر الخدمة...')];
    }

    if (app.dtcAnalysisError != null) {
      return [
        _ErrorCard(
          message: app.dtcAnalysisError!,
          onRetry: () => _retryAnalysis(app),
        ),
      ];
    }

    if (fault == null) {
      return [
        _MissingAnalysisCard(
          message: app.dtcAnalysis == null
              ? 'لم يصل تحليل لهذا الكود من الخدمة بعد.'
              : 'لم تُرجع الخدمة تفاصيل لهذا الكود.',
        ),
      ];
    }

    if (fault.failed) {
      return [
        _MissingAnalysisCard(
          message: fault.error?.isNotEmpty == true
              ? fault.error!
              : 'تعذر تحليل رمز العطل',
          title: 'تعذر تحليل هذا الكود',
        ),
      ];
    }

    return [_DtcFaultCards(fault: fault)];
  }

  /// محتوى الكود اليدوي: نفس بطاقات تحليل الخدمة (Gemini).
  List<Widget> _buildManualContent(BuildContext context) {
    return [
      switch (_state) {
        _DetailsState.loading => const _LoadingCard(
            message: 'جارٍ تحليل الكود عبر الخدمة (قد يستغرق لحظات)...',
          ),
        _DetailsState.loaded => _fault?.failed ?? true
            ? _MissingAnalysisCard(
                message: _fault!.error?.isNotEmpty == true
                    ? _fault!.error!
                    : 'تعذر تحليل رمز العطل',
                title: 'تعذر تحليل هذا الكود',
              )
            : _DtcFaultCards(fault: _fault!),
        _DetailsState.notFound => _NotFoundCard(code: widget.code),
        _DetailsState.error => _ErrorCard(
            message: _errorText ?? 'خطأ غير معروف',
            onRetry: _load,
          ),
      },
    ];
  }
}

// ============================================================
// ترويسة الشاشة
// ============================================================

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.code,
    required this.system,
    required this.detectedInScan,
    this.fault,
  });

  final String code;
  final DtcSystem system;
  final bool detectedInScan;
  final DtcFault? fault;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final data = fault;
    final useEnglishName = data?.nameEn?.isNotEmpty == true;

    final headline = useEnglishName
        ? data!.nameEn!
        : (data?.title?.isNotEmpty == true
            ? data!.title!
            : (detectedInScan ? code : system.displayName));

    final subtitle = detectedInScan
        ? (data?.system?.isNotEmpty == true
            ? 'النظام: ${data!.system}'
            : 'مُكتشف في آخر فحص فعلي')
        : 'كود مُدخل يدوياً';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: 2,
                      color: AppColors.error,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'نسخ كود العطل',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم نسخ الكود $code')),
                    );
                  },
                  icon: Icon(Icons.copy_rounded,
                      size: 17, color: palette.textMuted),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                          fontSize: 14,
                        ),
                        textDirection:
                            useEnglishName ? TextDirection.ltr : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // شريحة النظام المعياري (من حرف الكود) تظهر دائماً.
                Chip(
                  avatar: Icon(
                    system.icon,
                    size: 15,
                    color: palette.onPrimary,
                  ),
                  label: Text('النظام: ${system.displayName}'),
                  labelStyle: TextStyle(fontSize: 11.5, color: palette.text),
                ),
                // حقول الخطورة/الحالة/الثقة من بيانات الخدمة إن وُجدت
                // (كود مكتشف أو مُدخل يدوياً على حد سواء).
                if (data?.severity?.isNotEmpty == true)
                  Chip(
                    label: Text('الخطورة: ${data!.severity}'),
                    labelStyle:
                        TextStyle(fontSize: 11.5, color: palette.text),
                  ),
                if (data?.status?.isNotEmpty == true)
                  Chip(
                    label: Text('الحالة: ${data!.status}'),
                    labelStyle:
                        TextStyle(fontSize: 11.5, color: palette.text),
                  ),
                if (data?.confidence != null)
                  Chip(
                    label: Text(
                      'الثقة: ${(data!.confidence! * 100).toStringAsFixed(0)}%',
                    ),
                    labelStyle:
                        TextStyle(fontSize: 11.5, color: palette.text),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// بطاقات استجابة /api/analyze/dtc
// ============================================================

/// يعرض كل حقول `DtcFault` التي أرجعتها الخدمة، بلا أي حقل مضاف.
class _DtcFaultCards extends StatelessWidget {
  const _DtcFaultCards({required this.fault});

  final DtcFault fault;

  @override
  Widget build(BuildContext context) {
    final scalarFields = <String, String?>{
      'category': fault.category,
      'type': fault.type,
      'nameEn': fault.nameEn,
      'title': fault.title,
      'description': fault.description,
      'system': fault.system,
      'meaning': fault.meaning,
      'severity': fault.severity,
      'severityPercentage': fault.severityPercentage == null
          ? null
          : '${fault.severityPercentage!.toStringAsFixed(0)}%',
      'severityExplanation': fault.severityExplanation,
      'status': fault.status,
      'confidence': fault.confidence == null
          ? null
          : '${(fault.confidence! * 100).toStringAsFixed(0)}%',
    };

    final listSections = <(String, IconData, List<String>)>[
      (
        'possibleCauses',
        Icons.help_outline_rounded,
        fault.possibleCauses,
      ),
      (
        'possibleSymptoms',
        Icons.sick_rounded,
        fault.possibleSymptoms,
      ),
      (
        'diagnosticSteps',
        Icons.checklist_rounded,
        fault.diagnosticSteps,
      ),
      (
        'solutions',
        Icons.build_circle_outlined,
        fault.solutions,
      ),
    ];

    final presentScalars = scalarFields.entries
        .where((e) => e.value != null && e.value!.trim().isNotEmpty)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (presentScalars.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in presentScalars)
                    _ApiFieldRow(
                      label: entry.key,
                      value: entry.value!,
                      ltr: entry.key == 'nameEn' ||
                          entry.key == 'category' ||
                          entry.key == 'type' ||
                          entry.key == 'severity' ||
                          entry.key == 'status',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        for (final section in listSections)
          if (section.$3.isNotEmpty) ...[
            _ApiListCard(
              title: section.$1,
              icon: section.$2,
              items: section.$3,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

/// سطر واحد من حقول الاستجابة — يعرض اسم الحقل كما ورد مع قيمته.
class _ApiFieldRow extends StatelessWidget {
  const _ApiFieldRow({
    required this.label,
    required this.value,
    this.ltr = false,
  });

  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: palette.textMuted,
              fontWeight: FontWeight.w700,
            ),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              color: palette.text,
              height: 1.5,
            ),
            textDirection: ltr ? TextDirection.ltr : null,
          ),
        ],
      ),
    );
  }
}

/// بطاقة قائمة (أسباب/أعراض/خطوات/حلول) من حقول الاستجابة.
class _ApiListCard extends StatelessWidget {
  const _ApiListCard({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: palette.onPrimary),
                const SizedBox(width: 8),
                Text(
                  '$title:',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Icon(Icons.remove,
                          size: 10, color: palette.textMuted),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: palette.text,
                          height: 1.55,
                        ),
                      ),
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
// حالات المحتوى
// ============================================================

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({this.message = 'جارٍ استرجاع تفاصيل العطل...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة توضح غياب بيانات الخدمة لهذا الكود تحديداً.
class _MissingAnalysisCard extends StatelessWidget {
  const _MissingAnalysisCard({
    required this.message,
    this.title = 'لا توجد تفاصيل لهذا الكود',
  });

  final String message;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: EmptyState(
          compact: true,
          icon: Icons.search_off_rounded,
          title: title,
          message: message,
        ),
      ),
    );
  }
}

class _NotFoundCard extends StatelessWidget {
  const _NotFoundCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            EmptyState(
              compact: true,
              icon: Icons.search_off_rounded,
              title: 'الكود غير موجود في قاعدة البيانات',
              message: 'لم تُرجع الخدمة معلومات للكود $code — قد يكون '
                  'خاصاً بمصنّع معين.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            EmptyState(
              compact: true,
              icon: Icons.cloud_off_rounded,
              title: 'فشل تحميل المعلومات',
              message: message,
              action: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

